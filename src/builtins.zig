const std = @import("std");
const ArrayList = std.ArrayList;
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const interpret = @import("interpret.zig");
const DtVal = interpret.DtVal;
const Command = interpret.Command;
const Quote = interpret.Quote;
const Error = interpret.DtError;
const DtMachine = interpret.DtMachine;

const builtin = @import("builtin");

const main = @import("main.zig");

const Token = @import("tokens.zig").Token;

const bangDescription = "If nested, any commands or variables defined will be available in the calling scope.";

pub fn defineAll(machine: *DtMachine) !void {
    try machine.define("quit", "( -- ) Quit. Prints a warning if there are any values left on stack.", .{ .builtin = quit });
    try machine.define("exit", "( <exitcode> -- ) Exit with the specified exit code.", .{ .builtin = exit });
    try machine.define("version", "( -- <version> ) Produce the version of dt in use.", .{ .builtin = version });

    try machine.define("cwd", "( -- <dirname> ) Produce the current working directory.", .{ .builtin = cwd });
    if (builtin.os.tag != .wasi) {
        try machine.define("cd", "( <dirname> -- ) Change the process's working directory.", .{ .builtin = cd });
    }
    try machine.define("ls", "( -- [<filename>] ) Produce a quote of files and directories in the process's working directory.", .{ .builtin = ls });
    try machine.define("readf", "( <filename> -- <contents> ) Read a file's contents as a string.", .{ .builtin = readf });
    try machine.define("writef", "( <contents> <filename> -- ) Write a string as a file. If a file previously existed, it will be overwritten.", .{ .builtin = writef });
    try machine.define("appendf", "( <contents> <filename> -- ) Write a string to a file. If a file previously existed, the new content will be appended.", .{ .builtin = appendf });
    // TODO: pathsep/filesep, env get, env set

    if (builtin.os.tag != .wasi) {
        try machine.define("exec", "( <process> -- ) Execute a child process (from a String). When successful, returns stdout as a string. When unsuccessful, prints the child's stderr to stderr, and returns boolean false.", .{ .builtin = exec });
    }
    try machine.define("def!", "( <action> <name> -- ) Defines a new command. " ++ bangDescription, .{ .builtin = @"def!" });
    try machine.define("defs", "( -- [<name>] ) Produce a quote of all defined commands.", .{ .builtin = defs });
    try machine.define("def?", "( <name> -- <bool> ) Determine whether a command is defined.", .{ .builtin = @"def?" });
    try machine.define("usage", "( <name> -- <description> ) Print the usage notes of a given command.", .{ .builtin = usage });
    try machine.define("def-usage", "( <name> <description> -- ) Define the usage notes of a given command.", .{ .builtin = @"def-usage" });
    try machine.define(":", "( ... [<name>] -- ) Bind variables to a quote of names.", .{ .builtin = @":" });

    try machine.define("do!", "( <action> -- ? ) Execute an action. " ++ bangDescription, .{ .builtin = @"do!" });
    try machine.define("do", "( <action> -- ? ) Execute an action.", .{ .builtin = do });
    try machine.define("doin", "( <context> <action> -- ) Execute an action in a context.", .{ .builtin = doin });
    try machine.define("do!?", "( <action> <condition> -- ? ) Conditionally execute an action. " ++ bangDescription, .{ .builtin = @"do!?" });
    try machine.define("do?", "( <action> <condition> -- ? ) Conditionally execute an action.", .{ .builtin = @"do?" });
    try machine.define("loop", "( <action> -- ? ) Execute an action forever until it fails.", .{ .builtin = loop });

    try machine.define("dup", "( <a> -- <a> <a> ) Duplicate the most recent value.", .{ .builtin = dup });
    try machine.define("drop", "( <a> -- ) Drop the most recent value.", .{ .builtin = drop });
    try machine.define("swap", "( <a> <b> -- <b> <a> ) Swap the two most recent values.", .{ .builtin = swap });
    try machine.define("rot", "( <a> <b> <c> -- <c> <a> <b> ) Rotate the three most recent values.", .{ .builtin = rot });

    try machine.define("p", "( <a> -- ) Print the most recent value to standard output.", .{ .builtin = p });
    try machine.define("ep", "( <a> -- ) Print the most recent value to standard error.", .{ .builtin = ep });
    try machine.define("nl", "( -- ) Print a newline to standard output.", .{ .builtin = nl });
    try machine.define("enl", "( -- ) Print a newline to standard error.", .{ .builtin = enl });
    try machine.define("red", "( -- ) Print a control character for red to standard output and standard error.", .{ .builtin = red });
    try machine.define("green", "( -- ) Print a control character for green and bold (for the colorblind) to standard output and standard error.", .{ .builtin = green });
    try machine.define("norm", "( -- ) Print a control character to reset any styling to standard output and standard error.", .{ .builtin = norm });
    try machine.define(".s", "( -- ) Print the state of the process: all available values.", .{ .builtin = @".s" });

    try machine.define("rl", "( -- <line> ) Read a string from standard input until newline.", .{ .builtin = rl });
    try machine.define("rls", "( -- [<line>] ) Read strings, separated by newlines, from standard input until EOF. (For example: until ctrl+d in a Unix-like system, or until a pipe is closed.)", .{ .builtin = rls });
    try machine.define("procname", "( -- <name> ) Produce the name of the current process. This can be used, for example, to get the name of a shebang script.", .{ .builtin = procname });
    try machine.define("args", "( -- [<arg>] ) Produce the arguments provided to the process when it was launched.", .{ .builtin = args });
    try machine.define("eval", "( <code> -- ? ) Evaluate a string as dt commands and execute them.", .{ .builtin = eval });
    try machine.define("interactive?", "( -- <bool> ) Determine if the input mode is interactive (a TTY) or not.", .{ .builtin = @"interactive?" });

    try machine.define("+", "( <a> <b> -- <c> ) Add two numeric values.", .{ .builtin = @"+" });
    try machine.define("-", "( <a> <b> -- <c> ) Subtract two numeric values. In standard notation: a - b = c", .{ .builtin = @"-" });
    try machine.define("*", "( <a> <b> -- <c> ) Multiply two numeric values.", .{ .builtin = @"*" });
    try machine.define("/", "( <a> <b> -- <c> ) Divide two numeric values. In standard notation: a / b = c", .{ .builtin = @"/" });
    try machine.define("%", "( <a> <b> -- <c> ) Modulo two numeric values. In standard notation: a % b = c", .{ .builtin = @"%" });
    try machine.define("abs", "( <a> -- <b> ) Determine the absolute value of a number.", .{ .builtin = abs });
    try machine.define("rand", "( -- <a> ) Produces a random integer.", .{ .builtin = rand });

    try machine.define("eq?", "( <a> <b> -- <bool> ) Determine if two values are equal. Works for most types with coercion.", .{ .builtin = @"eq?" });
    try machine.define("gt?", "( <a> <b> -- <bool> ) Determine if a value is greater than another. In standard notation: a > b", .{ .builtin = @"gt?" });
    try machine.define("gte?", "( <a> <b> -- <bool> ) Determine if a value is greater-than/equal-to another. In standard notation: a ≧ b", .{ .builtin = @"gte?" });
    try machine.define("lt?", "( <a> <b> -- <bool> ) Determine if a value is less than another. In standard notation: a < b", .{ .builtin = @"lt?" });
    try machine.define("lte?", "( <a> <b> -- <bool> ) Determine if a value is less-than/equal-to another. In standard notation: a ≦ b", .{ .builtin = @"lte?" });

    try machine.define("and", "( <a> <b> -- <bool> ) Determine if two values are both truthy.", .{ .builtin = boolAnd });
    try machine.define("or", "( <a> <b> -- <bool> ) Determine if either of two values are truthy.", .{ .builtin = boolOr });
    try machine.define("not", "( <a> -- <bool> ) Determine the inverse truthiness of a value.", .{ .builtin = not });

    try machine.define("split", "( <string> <delim> -- [<substring>] ) Split a string on all occurrences of a delimiter.", .{ .builtin = split });
    try machine.define("join", "( [<substring>] <delim> -- <string> ) Join strings with a delimiter.", .{ .builtin = join });
    try machine.define("upcase", "( <string> -- <upper> ) Convert a string to its uppercase form.", .{ .builtin = upcase });
    try machine.define("downcase", "( <string> -- <lower> ) Convert a string to its lowercase form.", .{ .builtin = downcase });
    try machine.define("starts-with?", "( <string> <prefix> -- <bool> ) Determine if a string starts with a prefix.", .{ .builtin = startsWith });
    try machine.define("ends-with?", "( <string> <suffix> -- <bool> ) Determine if a string ends with a suffix.", .{ .builtin = endsWith });
    try machine.define("contains?", "( <haystack> <needle> -- <bool> ) With Strings, determine if a string contains a substring. With quotes, determine if a quote contains a value.", .{ .builtin = contains });

    try machine.define("map", "( <original> <action> -- <transformed> ) Apply an action to all values in a quote.", .{ .builtin = map });
    try machine.define("filter", "( <original> <condition> -- <preserved> ) Require some condition of all values in a quote. Truthy results are preserved, and falsy results are not.", .{ .builtin = filter });
    try machine.define("any?", "( <original> <condition> -- <bool> ) Determine whether any value in a quote passes a condition. Stops at the first truthy result.", .{ .builtin = any });
    try machine.define("len", "( <a> -- <length> ) The length of a string or quote. (Always 1 for single values.)", .{ .builtin = len });

    try machine.define("...", "( <original> -- ? ) Unpack a quote.", .{ .builtin = ellipsis });
    try machine.define("rev", "( <original> -- <reversed> ) Reverse a quote or string. Other types are unmodified.", .{ .builtin = rev });
    try machine.define("sort", "( [<a>] -- [<b>] ) Sort a list of values. When values are of different type, they are sorted in the following order: bool, int, float, string, command, deferred command, quote.", .{ .builtin = sort });
    try machine.define("quote", "( <a> -- [<a>] ) Quote a value.", .{ .builtin = quoteVal });
    try machine.define("quote-all", "( ? -- [<?>] ) Quote all current context.", .{ .builtin = quoteAll });
    try machine.define("anything?", "( -- <bool> ) True if any value is present.", .{ .builtin = @"anything?" });
    try machine.define("concat", "( [<a>] [<b>] -- [<c>] ) Concatenate two quotes. Values are coerced into quotes. (For String concatenation, see join.)", .{ .builtin = concat });
    try machine.define("push", "( [<a>] <b> -- [<c>] ) Push a value into a quote as its new last value.", .{ .builtin = push });
    try machine.define("pop", "( [<a>] -- [<b>] <c> ) Pop the last value from a quote.", .{ .builtin = pop });
    try machine.define("enq", "( <a> [<b>] -- [<c>] ) Enqueue a value into a quote as its new first value.", .{ .builtin = enq });
    try machine.define("deq", "( [<a>] -- <b> [<c>] ) Dequeue the first value from a quote.", .{ .builtin = deq });

    try machine.define("to-bool", "( <a> -- <bool> ) Coerce a value to a boolean.", .{ .builtin = @"to-bool" });
    try machine.define("to-int", "( <a> -- <int> ) Coerce a value to an integer.", .{ .builtin = @"to-int" });
    try machine.define("to-float", "( <a> -- <float> ) Coerce a value to a floating-point number.", .{ .builtin = @"to-float" });
    try machine.define("to-string", "( <a> -- <string> ) Coerce a value to a string.", .{ .builtin = @"to-string" });
    try machine.define("to-cmd", "( <a> -- <cmd> ) Coerce a value to a command.", .{ .builtin = @"to-cmd" });
    try machine.define("to-def", "( <a> -- <def> ) Coerce a value to a deferred command. (Read as \"definition\" or \"deferred\".)", .{ .builtin = @"to-def" });
    try machine.define("to-quote", "( <a> -- [<a>] ) Coerce value to a quote. To quote a quote, use quote.", .{ .builtin = @"to-quote" });

    try machine.define("inspire", "( -- <wisdom> ) Get inspiration.", .{ .builtin = inspire });
}

pub fn quit(dt: *DtMachine) !void {
    const ctx = try dt.popContext();

    if (ctx.items.len > 0) {
        try dt.red();
        try stderr.print("warning(quit): Exited with unused values: [ ", .{});

        for (ctx.items) |item| {
            try item.print(stderr);
            try stderr.print(" ", .{});
        }
        try stderr.print("] \n", .{});
        try dt.norm();
    }

    std.os.exit(0);
}

pub fn exit(dt: *DtMachine) !void {
    const log = std.log.scoped(.exit);

    const val = dt.pop() catch DtVal{ .int = 255 };
    var i = val.intoInt() catch it: {
        log.err("Attempted to exit with a value that could not be coerced to integer: {any}", .{val});
        log.err("The program will exit with status code of 1.", .{});
        break :it 1;
    };

    if (i < 0) {
        log.err("Attempted to exit with a value less than 0 ({})", .{i});
        log.err("The program will exit with status code of 1.", .{});
        i = 1;
    } else if (i > 255) {
        log.err("Attempted to exit with a value greater than 255 ({})", .{i});
        log.err("The program will exit with status code of 255.", .{});
        i = 255;
    }

    const code: u8 = @intCast(i);
    std.os.exit(code);
}

pub fn version(dt: *DtMachine) !void {
    try dt.push(.{ .string = main.version });
}

pub fn cwd(dt: *DtMachine) !void {
    const theCwd = try std.process.getCwdAlloc(dt.alloc);
    try dt.push(.{ .string = theCwd });
}

pub fn cd(dt: *DtMachine) !void {
    const log = std.log.scoped(.cd);

    const val = try dt.pop();
    var path = val.intoString(dt) catch |e| return dt.rewind(log, val, e);

    if (std.mem.eql(u8, path, "~")) {
        // TODO: Consider windows and other OS conventions.
        path = try std.process.getEnvVarOwned(dt.alloc, "HOME");
    }

    std.os.chdir(path) catch |e| return dt.rewind(log, val, e);
}

pub fn ls(dt: *DtMachine) !void {
    const theCwd = try std.process.getCwdAlloc(dt.alloc);
    var dir = try std.fs.openIterableDirAbsolute(theCwd, .{});
    var entries = dir.iterate();

    var quote = Quote.init(dt.alloc);
    while (try entries.next()) |entry| {
        var name = try dt.alloc.dupe(u8, entry.name);
        try quote.append(.{ .string = name });
    }

    try dt.push(.{ .quote = quote });

    dir.close();
}

pub fn readf(dt: *DtMachine) !void {
    const log = std.log.scoped(.readf);

    const val = try dt.pop();
    const filename = val.intoString(dt) catch |e| return dt.rewind(log, val, e);

    // We get a Dir from CWD so we can resolve relative paths
    const theCwdPath = try std.process.getCwdAlloc(dt.alloc);
    var theCwd = try std.fs.openDirAbsolute(theCwdPath, .{});

    var contents = _readf(dt, log, theCwd, filename) catch |e| {
        try dt.red();
        switch (e) {
            error.IsDir => log.warn("\"{s}\" is a directory.", .{filename}),
            error.FileNotFound => log.warn("\"{s}\" not found.", .{filename}),
            else => {
                try dt.norm();
                return e;
            },
        }
        try dt.norm();
        return;
    };

    try dt.push(.{ .string = contents });
}

fn _readf(dt: *DtMachine, log: anytype, dir: std.fs.Dir, filename: []const u8) ![]const u8 {
    _ = log;
    var file = try dir.openFile(filename, .{ .mode = .read_only });
    defer file.close();
    return try file.readToEndAlloc(dt.alloc, std.math.pow(usize, 2, 16));
}

pub fn writef(dt: *DtMachine) !void {
    const log = std.log.scoped(.writef);

    const vals = try dt.popN(2);
    const filename = vals[1].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);
    const contents = vals[0].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);

    // We get a Dir from CWD so we can resolve relative paths
    const theCwdPath = try std.process.getCwdAlloc(dt.alloc);
    var theCwd = try std.fs.openDirAbsolute(theCwdPath, .{});

    try theCwd.writeFile(filename, contents);
    theCwd.close();
}

pub fn appendf(dt: *DtMachine) !void {
    const log = std.log.scoped(.writef);

    const vals = try dt.popN(2);
    const filename = vals[1].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);
    const contents = vals[0].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);

    // We get a Dir from CWD so we can resolve relative paths
    const theCwdPath = try std.process.getCwdAlloc(dt.alloc);
    var theCwd = try std.fs.openDirAbsolute(theCwdPath, .{});
    defer theCwd.close();

    var file = try theCwd.openFile(filename, .{ .mode = .write_only });
    defer file.close();

    try file.seekFromEnd(0);
    try file.writeAll(contents);
}

pub fn exec(dt: *DtMachine) !void {
    const log = std.log.scoped(.exec);

    const val = try dt.pop();
    const childProcess = try val.intoString(dt);
    var childArgs = std.mem.splitAny(u8, childProcess, " \t");
    var argv = ArrayList([]const u8).init(dt.alloc);

    while (childArgs.next()) |arg| try argv.append(arg);

    var result = std.process.Child.exec(.{
        .allocator = dt.alloc,
        .argv = try argv.toOwnedSlice(),
    }) catch |e| return dt.rewind(log, val, e);

    switch (result.term) {
        .Exited => |code| if (code == 0) {
            const trimmed = std.mem.trimRight(u8, result.stdout, "\r\n");
            try dt.push(.{ .string = trimmed });
            return;
        },
        else => {
            try dt.red();
            log.warn("{s}", .{result.stderr});
            try dt.norm();

            try dt.push(.{ .bool = false });
        },
    }
}

pub fn @"def!"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"def!");

    const vals = try dt.popN(2);

    const quote = try vals[0].intoQuote(dt);
    const name = vals[1].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);

    try dt.define(name, name, .{ .quote = quote });
}

pub fn defs(dt: *DtMachine) !void {
    var quote = Quote.init(dt.alloc);
    var defNames = dt.defs.keyIterator();

    while (defNames.next()) |defName| {
        var cmdName = try dt.alloc.dupe(u8, defName.*);
        try quote.append(.{ .string = cmdName });
    }

    const items = quote.items;
    std.mem.sort(DtVal, items, dt, DtVal.isLessThan);

    try dt.push(.{ .quote = quote });
}

pub fn @"def?"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"def?");

    const val = try dt.pop();
    const name = val.intoString(dt) catch |e| return dt.rewind(log, val, e);

    try dt.push(.{ .bool = dt.defs.contains(name) });
}

pub fn usage(dt: *DtMachine) !void {
    const log = std.log.scoped(.usage);

    const val = try dt.pop();
    const cmdName = val.intoString(dt) catch |e| return dt.rewind(log, val, e);

    const cmd = dt.defs.get(cmdName) orelse return dt.rewind(log, val, Error.CommandUndefined);

    var description = try dt.alloc.dupe(u8, cmd.description);

    try dt.push(.{ .string = description });
}

pub fn @"def-usage"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"def-usage");

    const vals = try dt.popN(2);
    const name = vals[0].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);
    const description = vals[1].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);

    const cmd = dt.defs.get(name) orelse return dt.rewindN(2, log, vals, Error.CommandUndefined);

    try dt.define(name, description, cmd.action);
}

// Variable binding
pub fn @":"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@":");

    var termVal = try dt.pop();

    // Single term
    if (termVal.isCommand() or termVal.isDeferredCommand() or termVal.isString()) {
        const cmdName = try termVal.intoString(dt);

        const val = dt.pop() catch |e| return dt.rewind(log, termVal, e);

        var quote = Quote.init(dt.alloc);
        try quote.append(val);
        try dt.define(cmdName, cmdName, .{ .quote = quote });
        return;
    }

    // Multiple terms

    var terms = (try termVal.intoQuote(dt)).items;

    var vals = try dt.alloc.alloc(DtVal, terms.len);

    var i = terms.len;

    while (i > 0) : (i -= 1) {
        vals[i - 1] = dt.pop() catch |e| {
            while (i < terms.len) : (i += 1) {
                try dt.push(vals[i]);
            }
            return dt.rewind(log, termVal, e);
        };
    }

    for (terms, vals) |termV, val| {
        const term = try termV.intoString(dt);
        var quote = ArrayList(DtVal).init(dt.alloc);
        try quote.append(val);
        try dt.define(term, term, .{ .quote = quote });
    }
}

pub fn loop(dt: *DtMachine) !void {
    const val = try dt.pop();
    switch (val) {
        .command => |cmd| return while (true) try dt.handleCmd(cmd),
        .deferred_command => |cmd| return while (true) try dt.handleCmd(cmd),
        else => {},
    }

    const quote = try val.intoQuote(dt);
    const cmd = Command{ .name = "anonymous loop", .description = "", .action = .{ .quote = quote } };

    while (true) try cmd.run(dt);
}

pub fn dup(dt: *DtMachine) !void {
    const val = try dt.pop();
    try dt.push(val);
    try dt.push(val);
}

pub fn drop(dt: *DtMachine) !void {
    _ = try dt.pop();
}

pub fn swap(dt: *DtMachine) !void {
    const vals = try dt.popN(2);
    try dt.push(vals[1]);
    try dt.push(vals[0]);
}

// ... a b c (rot) ... c a b
//   [ 0 1 2 ]       [ 2 0 1 ]
pub fn rot(dt: *DtMachine) !void {
    const vals = try dt.popN(3);
    try dt.push(vals[2]);
    try dt.push(vals[0]);
    try dt.push(vals[1]);
}

pub fn p(dt: *DtMachine) !void {
    const val = try dt.pop();
    try _p(val, stdout);
}

pub fn ep(dt: *DtMachine) !void {
    const val = try dt.pop();
    try _p(val, stderr);
}

fn _p(val: DtVal, writer: std.fs.File.Writer) !void {
    switch (val) {
        // When printing strings, do not show " around a string.
        .string => |s| try writer.print("{s}", .{s}),
        else => try val.print(writer),
    }
}

pub fn nl(_: *DtMachine) !void {
    try stdout.print("\n", .{});
}

pub fn enl(_: *DtMachine) !void {
    try stderr.print("\n", .{});
}

pub fn red(dt: *DtMachine) !void {
    try dt.red();
}

pub fn green(dt: *DtMachine) !void {
    try dt.green();
}

pub fn norm(dt: *DtMachine) !void {
    try dt.norm();
}

pub fn @".s"(dt: *DtMachine) !void {
    try stderr.print("[ ", .{});

    var top = dt.nest.first orelse {
        try stderr.print("]", .{});
        return;
    };

    for (top.data.items) |val| {
        try val.print(stderr);
        try stderr.print(" ", .{});
    }

    try stderr.print("]\n", .{});
}

pub fn rl(dt: *DtMachine) !void {
    var line = ArrayList(u8).init(dt.alloc);
    try stdin.streamUntilDelimiter(line.writer(), '\n', null);

    try dt.push(.{ .string = line.items });
}

pub fn rls(dt: *DtMachine) !void {
    var lines = Quote.init(dt.alloc);

    while (true) {
        rl(dt) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        const val = try dt.pop();
        const line = try val.intoString(dt);
        try lines.append(.{ .string = line });
    }

    try dt.push(.{ .quote = lines });
}

pub fn procname(dt: *DtMachine) !void {
    var procArgs = try std.process.argsWithAllocator(dt.alloc);
    var name = procArgs.next() orelse return Error.ProcessNameUnknown;
    try dt.push(.{ .string = name });
}

pub fn args(dt: *DtMachine) !void {
    var quote = Quote.init(dt.alloc);
    var procArgs = try std.process.argsWithAllocator(dt.alloc);
    _ = procArgs.next(); // Discard process name

    while (procArgs.next()) |arg| {
        try quote.append(.{ .string = arg });
    }

    try dt.push(.{ .quote = quote });
}

pub fn eval(dt: *DtMachine) !void {
    const log = std.log.scoped(.eval);

    var val = try dt.pop();
    var code = val.intoString(dt) catch |e| return dt.rewind(log, val, e);

    var tokens = Token.parse(dt.alloc, code);
    while (try tokens.next()) |tok| {
        try dt.interpret(tok);
    }
}

pub fn @"interactive?"(state: *DtMachine) !void {
    try state.push(.{ .bool = std.io.getStdIn().isTty() });
}

pub fn @"+"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"+");

    const vals = try dt.popN(2);

    if (vals[0].isInt() and vals[1].isInt()) {
        const a = try vals[0].intoInt();
        const b = try vals[1].intoInt();

        const res = @addWithOverflow(a, b);

        if (res[1] == 1) return dt.rewindN(2, log, vals, Error.IntegerOverflow);

        try dt.push(.{ .int = res[0] });
        return;
    }

    const a = vals[0].intoFloat() catch |e| return dt.rewindN(2, log, vals, e);
    const b = vals[1].intoFloat() catch |e| return dt.rewindN(2, log, vals, e);

    try dt.push(.{ .float = a + b });
}

pub fn @"-"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"-");

    const vals = try dt.popN(2);

    if (vals[0].isInt() and vals[1].isInt()) {
        const a = try vals[0].intoInt();
        const b = try vals[1].intoInt();

        const res = @subWithOverflow(a, b);

        if (res[1] == 1) return dt.rewindN(2, log, vals, Error.IntegerUnderflow);

        try dt.push(.{ .int = res[0] });
        return;
    }

    const a = vals[0].intoFloat() catch |e| return dt.rewindN(2, log, vals, e);
    const b = vals[1].intoFloat() catch |e| return dt.rewindN(2, log, vals, e);

    try dt.push(.{ .float = a - b });
}

pub fn @"*"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"*");

    const vals = try dt.popN(2);

    if (vals[0].isInt() and vals[1].isInt()) {
        const a = try vals[0].intoInt();
        const b = try vals[1].intoInt();

        const res = @mulWithOverflow(a, b);

        if (res[1] == 1) return dt.rewindN(2, log, vals, Error.IntegerOverflow);

        try dt.push(.{ .int = res[0] });
        return;
    }

    const a = vals[0].intoFloat() catch |e| return dt.rewindN(2, log, vals, e);
    const b = vals[1].intoFloat() catch |e| return dt.rewindN(2, log, vals, e);

    try dt.push(.{ .float = a * b });
    return;
}

pub fn @"/"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"/");

    const vals = try dt.popN(2);

    if (vals[0].isInt() and vals[1].isInt()) {
        const a = try vals[0].intoInt();
        const b = try vals[1].intoInt();

        if (b == 0) return dt.rewindN(2, log, vals, Error.DivisionByZero);

        try dt.push(.{ .int = @divTrunc(a, b) });
        return;
    }

    const a = vals[0].intoFloat() catch |e| return dt.rewindN(2, log, vals, e);
    const b = vals[1].intoFloat() catch |e| return dt.rewindN(2, log, vals, e);

    if (b == 0) return dt.rewindN(2, log, vals, Error.DivisionByZero);

    try dt.push(.{ .float = a / b });
}

pub fn @"%"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"%");

    const vals = try dt.popN(2);

    if (vals[0].isInt() and vals[1].isInt()) {
        const a = try vals[0].intoInt();
        const b = try vals[1].intoInt();

        try dt.push(.{ .int = @mod(a, b) });
        return;
    }

    const a = vals[0].intoFloat() catch |e| return dt.rewindN(2, log, vals, e);
    const b = vals[1].intoFloat() catch |e| return dt.rewindN(2, log, vals, e);

    try dt.push(.{ .float = @mod(a, b) });
    return;
}

pub fn abs(dt: *DtMachine) !void {
    const log = std.log.scoped(.abs);

    const val = try dt.pop();

    if (val.isInt()) {
        const a = try val.intoInt();

        try dt.push(.{ .int = try std.math.absInt(a) });
        return;
    }

    const a = val.intoFloat() catch |e| return dt.rewind(log, val, e);

    try dt.push(.{ .float = std.math.fabs(a) });
}

pub fn rand(dt: *DtMachine) !void {
    const n = std.crypto.random.int(i64);
    try dt.push(.{ .int = n });
}

pub fn @"eq?"(dt: *DtMachine) !void {
    const vals = try dt.popN(2);
    const eq = DtVal.isEqualTo(dt, vals[0], vals[1]);
    try dt.push(.{ .bool = eq });
}

pub fn @"gt?"(dt: *DtMachine) !void {
    const vals = try dt.popN(2);
    const gt = DtVal.isLessThan(dt, vals[1], vals[0]);
    try dt.push(.{ .bool = gt });
}

pub fn @"gte?"(dt: *DtMachine) !void {
    const vals = try dt.popN(2);
    const gte = !DtVal.isLessThan(dt, vals[0], vals[1]);
    try dt.push(.{ .bool = gte });
}

pub fn @"lt?"(dt: *DtMachine) !void {
    const vals = try dt.popN(2);
    const lt = DtVal.isLessThan(dt, vals[0], vals[1]);
    try dt.push(.{ .bool = lt });
}

pub fn @"lte?"(dt: *DtMachine) !void {
    const vals = try dt.popN(2);
    const lte = !DtVal.isLessThan(dt, vals[1], vals[0]);
    try dt.push(.{ .bool = lte });
}

pub fn boolAnd(dt: *DtMachine) !void {
    var vals = try dt.popN(2);

    var a = vals[0].intoBool(dt);
    var b = vals[1].intoBool(dt);

    try dt.push(.{ .bool = a and b });
}

pub fn boolOr(dt: *DtMachine) !void {
    var vals = try dt.popN(2);

    var a = vals[0].intoBool(dt);
    var b = vals[1].intoBool(dt);

    try dt.push(.{ .bool = a or b });
}

pub fn not(dt: *DtMachine) !void {
    var val = try dt.pop();

    var a = val.intoBool(dt);
    try dt.push(.{ .bool = !a });
}

pub fn split(dt: *DtMachine) !void {
    const log = std.log.scoped(.split);

    var vals = try dt.popN(2);

    var str = vals[0].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);
    var delim = vals[1].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);

    if (delim.len > 0) {
        var parts = std.mem.split(u8, str, delim);
        var quote = Quote.init(dt.alloc);
        while (parts.next()) |part| {
            try quote.append(.{ .string = part });
        }
        try dt.push(.{ .quote = quote });
    } else {
        var quote = Quote.init(dt.alloc);
        for (str) |c| {
            var s = try dt.alloc.create([1]u8);
            s[0] = c;
            try quote.append(.{ .string = s });
        }
        try dt.push(.{ .quote = quote });
    }
}

pub fn join(dt: *DtMachine) !void {
    const log = std.log.scoped(.join);

    var vals = try dt.popN(2);

    if (!vals[0].isQuote()) {
        const str = vals[0].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);
        try dt.push(.{ .string = str });
        return;
    }

    var strs = try vals[0].intoQuote(dt);
    var delim = try vals[1].intoString(dt);

    var parts = try ArrayList([]const u8).initCapacity(dt.alloc, strs.items.len);
    for (strs.items) |part| {
        const s = try part.intoString(dt);
        try parts.append(s);
    }
    var acc = try std.mem.join(dt.alloc, delim, parts.items);
    try dt.push(.{ .string = acc });
}

pub fn upcase(dt: *DtMachine) !void {
    const log = std.log.scoped(.upcase);

    var val = try dt.pop();
    const before = val.intoString(dt) catch |e| return dt.rewind(log, val, e);

    const after = try std.ascii.allocUpperString(dt.alloc, before);

    try dt.push(.{ .string = after });
}

pub fn downcase(dt: *DtMachine) !void {
    const log = std.log.scoped(.downcase);

    var val = try dt.pop();
    const before = val.intoString(dt) catch |e| return dt.rewind(log, val, e);

    const after = try std.ascii.allocLowerString(dt.alloc, before);

    try dt.push(.{ .string = after });
}

pub fn startsWith(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"starts-with?");

    var vals = try dt.popN(2);

    var str = vals[0].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);
    var prefix = vals[1].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);

    try dt.push(.{ .bool = std.mem.startsWith(u8, str, prefix) });
}

pub fn endsWith(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"ends-with?");

    var vals = try dt.popN(2);

    var str = vals[0].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);
    var suffix = vals[1].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);

    try dt.push(.{ .bool = std.mem.endsWith(u8, str, suffix) });
}

pub fn contains(dt: *DtMachine) !void {
    const log = std.log.scoped(.contains);

    var vals = try dt.popN(2);

    if (vals[0].isString() and vals[1].isString()) {
        var str = vals[0].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);
        var substr = vals[1].intoString(dt) catch |e| return dt.rewindN(2, log, vals, e);

        try dt.push(.{ .bool = std.mem.containsAtLeast(u8, str, 1, substr) });
        return;
    }

    var child = try dt.child();

    var haystack = try vals[0].intoQuote(dt);
    var needle = vals[1];

    for (haystack.items) |item| {
        try child.push(item);
        try child.push(needle);
        try @"eq?"(&child);
        const found = (try child.pop()).intoBool(&child);
        if (found) {
            try dt.push(.{ .bool = true });
            return;
        }
    }

    try dt.push(.{ .bool = false });
}

pub fn @"do!"(dt: *DtMachine) !void {
    var val = try dt.pop();

    if (val.isCommand() or val.isDeferredCommand() or val.isString()) {
        const cmdName = try val.intoString(dt);

        try dt.handleCmd(cmdName);
        return;
    }

    const quote = try val.intoQuote(dt);

    for (quote.items) |v| try dt.handleVal(v);
}

// Same as do! but does not uplevel any definitions
pub fn do(dt: *DtMachine) !void {
    var val = try dt.pop();

    var jail = try dt.child();
    jail.nest = dt.nest;

    if (val.isCommand() or val.isDeferredCommand()) {
        const cmdName = try val.intoString(dt);

        try jail.handleCmd(cmdName);

        dt.nest = jail.nest;
        return;
    }

    const quote = try val.intoQuote(dt);

    for (quote.items) |v| try jail.handleVal(v);
    dt.nest = jail.nest;
}

pub fn @"do!?"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"do!?");

    var val = try dt.pop();
    const cond = val.intoBool(dt);

    try if (cond) @"do!"(dt) else drop(dt) catch |e| return dt.rewind(log, val, e);
}

pub fn @"do?"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"do?");

    var val = try dt.pop();
    const cond = val.intoBool(dt);

    try if (cond) do(dt) else drop(dt) catch |e| return dt.rewind(log, val, e);
}

pub fn doin(dt: *DtMachine) !void {
    const log = std.log.scoped(.doin);

    const vals = try dt.popN(2);

    const quote = try vals[0].intoQuote(dt);
    const f = vals[1];

    _doin(dt, quote, f) catch |e| return dt.rewindN(2, log, vals, e);
}

fn _doin(dt: *DtMachine, quote: Quote, f: DtVal) !void {
    var child = try dt.child();

    try child.push(.{ .quote = quote });
    try ellipsis(&child);
    try child.push(f);
    try do(&child);

    const resultQuote = try child.popContext();

    try dt.push(.{ .quote = resultQuote });
}

pub fn map(dt: *DtMachine) !void {
    const log = std.log.scoped(.map);

    const vals = try dt.popN(2);

    const quote = try vals[0].intoQuote(dt);
    const f = vals[1];

    _map(dt, quote, f) catch |e| return dt.rewindN(2, log, vals, e);
}

fn _map(dt: *DtMachine, as: Quote, f: DtVal) !void {
    var child = try dt.child();

    for (as.items) |a| {
        try child.push(a);
        try child.push(f);
        try do(&child);
    }

    const newQuote = try child.popContext();

    try dt.push(DtVal{ .quote = newQuote });
}

pub fn filter(dt: *DtMachine) !void {
    const log = std.log.scoped(.filter);

    const vals = try dt.popN(2);

    const quote = try vals[0].intoQuote(dt);
    const f = vals[1];

    _filter(dt, quote, f) catch |e| return dt.rewindN(2, log, vals, e);
}

fn _filter(dt: *DtMachine, as: Quote, f: DtVal) !void {
    var quote = Quote.init(dt.alloc);

    for (as.items) |a| {
        var child = try dt.child();

        try child.push(a);
        try child.push(f);
        try do(&child);

        var lastVal = try child.pop();
        var cond = lastVal.intoBool(dt);

        if (cond) {
            try quote.append(a);
        }
    }

    try dt.push(DtVal{ .quote = quote });
}

pub fn any(dt: *DtMachine) !void {
    const log = std.log.scoped(.any);

    const vals = try dt.popN(2);

    const quote = try vals[0].intoQuote(dt);
    const f = vals[1];

    if (quote.items.len == 0) {
        try dt.push(.{ .bool = false });
        return;
    }

    _any(dt, quote, f) catch |e| return dt.rewindN(2, log, vals, e);
}

fn _any(dt: *DtMachine, as: Quote, f: DtVal) !void {
    for (as.items) |a| {
        var child = try dt.child();

        try child.push(a);
        try child.push(f);
        try do(&child);

        var lastVal = try child.pop();
        var cond = lastVal.intoBool(dt);

        if (cond) {
            try dt.push(DtVal{ .bool = true });
            return;
        }
    }

    try dt.push(DtVal{ .bool = false });
}

pub fn pop(dt: *DtMachine) !void {
    const log = std.log.scoped(.pop);

    const val = try dt.pop();

    var quote = try val.intoQuote(dt);

    if (quote.items.len > 0) {
        const lastVal = quote.pop();
        try dt.push(DtVal{ .quote = quote });
        try dt.push(lastVal);
        return;
    }

    try dt.rewind(log, val, Error.StackUnderflow);
}

pub fn push(dt: *DtMachine) !void {
    const vals = try dt.popN(2);

    var pushMe = vals[1];
    var quote = try vals[0].intoQuote(dt);

    try quote.append(pushMe);
    try dt.push(DtVal{ .quote = quote });
}

pub fn enq(dt: *DtMachine) !void {
    const vals = try dt.popN(2);

    var pushMe = vals[0];
    var quote = try vals[1].intoQuote(dt);

    var newQuote = Quote.init(dt.alloc);
    try newQuote.append(pushMe);
    try newQuote.appendSlice(quote.items);

    try dt.push(.{ .quote = newQuote });
}

pub fn deq(dt: *DtMachine) !void {
    const log = std.log.scoped(.deq);

    const val = try dt.pop();

    var quote = try val.intoQuote(dt);

    if (quote.items.len == 0) {
        return dt.rewind(log, val, Error.StackUnderflow);
    }

    const firstVal = quote.orderedRemove(0);
    try dt.push(firstVal);
    try dt.push(DtVal{ .quote = quote });
}

pub fn len(dt: *DtMachine) !void {
    const val = try dt.pop();

    if (val.isString()) {
        const s = try val.intoString(dt);
        const length: i64 = @intCast(s.len);
        try dt.push(.{ .int = length });
        return;
    }

    const quote = try val.intoQuote(dt);
    const length: i64 = @intCast(quote.items.len);
    try dt.push(.{ .int = length });
}

pub fn ellipsis(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"...");

    const val = try dt.pop();

    var quote = val.intoQuote(dt) catch |e| return dt.rewind(log, val, e);

    // TODO: Push as slice
    for (quote.items) |v| {
        try dt.push(v);
    }
}

pub fn rev(dt: *DtMachine) !void {
    const log = std.log.scoped(.rev);
    _ = log;

    const val = try dt.pop();

    if (val.isQuote()) {
        const quote = try val.intoQuote(dt);
        const length = quote.items.len;

        var newItems = try dt.alloc.alloc(DtVal, length);
        for (quote.items, 0..) |v, i| {
            newItems[length - i - 1] = v;
        }

        var newQuote = Quote.fromOwnedSlice(dt.alloc, newItems);

        try dt.push(.{ .quote = newQuote });
        return;
    }

    if (val.isString()) {
        const str = try val.intoString(dt);
        var newStr = try dt.alloc.alloc(u8, str.len);

        for (str, 0..) |c, i| {
            newStr[str.len - 1 - i] = c;
        }

        try dt.push(.{ .string = newStr });
        return;
    }

    // Some scalar value.
    try dt.push(val);
}

pub fn sort(dt: *DtMachine) !void {
    const val = try dt.pop();

    // Scalar value
    if (!val.isQuote()) return try dt.push(val);

    const quote = try val.intoQuote(dt);
    const items = quote.items;
    std.mem.sort(DtVal, items, dt, DtVal.isLessThan);

    try dt.push(.{ .quote = quote });
}

pub fn quoteVal(dt: *DtMachine) !void {
    const val = try dt.pop();
    var quote = Quote.init(dt.alloc);
    try quote.append(val);
    try dt.push(.{ .quote = quote });
}

pub fn quoteAll(dt: *DtMachine) !void {
    try dt.quoteContext();
}

pub fn @"anything?"(dt: *DtMachine) !void {
    const top = dt.nest.first orelse return Error.ContextStackUnderflow;
    try dt.push(.{ .bool = top.data.items.len != 0 });
}

pub fn concat(dt: *DtMachine) !void {
    const vals = try dt.popN(2);

    var a = try vals[0].intoQuote(dt);
    var b = try vals[1].intoQuote(dt);

    try a.appendSlice(b.items);

    try dt.push(.{ .quote = a });
}

pub fn @"to-bool"(state: *DtMachine) !void {
    const val = try state.pop();
    const b = val.intoBool(state);
    try state.push(.{ .bool = b });
}

pub fn @"to-int"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"to-int");

    const val = try dt.pop();
    const i = val.intoInt() catch |e| return dt.rewind(log, val, e);
    try dt.push(.{ .int = i });
}

pub fn @"to-float"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"to-float");

    const val = try dt.pop();
    const f = val.intoFloat() catch |e| return dt.rewind(log, val, e);
    try dt.push(.{ .float = f });
}

pub fn @"to-string"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"to-string");

    const val = try dt.pop();
    const s = val.intoString(dt) catch |e| return dt.rewind(log, val, e);
    try dt.push(.{ .string = s });
}

pub fn @"to-cmd"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"to-cmd");

    const val = try dt.pop();
    const cmd = val.intoString(dt) catch |e| return dt.rewind(log, val, e);
    try dt.push(.{ .command = cmd });
}

pub fn @"to-def"(dt: *DtMachine) !void {
    const log = std.log.scoped(.@"to-def");

    const val = try dt.pop();
    const cmd = val.intoString(dt) catch |e| return dt.rewind(log, val, e);
    try dt.push(.{ .deferred_command = cmd });
}

pub fn @"to-quote"(dt: *DtMachine) !void {
    const val = try dt.pop();
    const quote = try val.intoQuote(dt);
    try dt.push(.{ .quote = quote });
}

pub fn inspire(dt: *DtMachine) !void {
    const i = std.crypto.random.uintLessThan(usize, dt.inspiration.len);
    try dt.push(.{ .string = dt.inspiration[i] });
}
