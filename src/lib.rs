pub mod corelib;
pub mod prompt;

use crate::corelib::RailOp;
pub use corelib::operate;
use corelib::{new_dictionary, Dictionary};

#[derive(Clone, Debug)]
pub struct RailState {
    stack: Stack,
    dictionary: Dictionary,
    context: Context,
}

impl RailState {
    pub fn new(context: Context) -> RailState {
        let stack = Stack::new();
        let dictionary = new_dictionary();
        RailState {
            stack,
            dictionary,
            context,
        }
    }

    pub fn update_stack(self, stack: Stack) -> RailState {
        RailState {
            stack,
            dictionary: self.dictionary,
            context: self.context,
        }
    }

    pub fn deeper(self) -> RailState {
        let context = Context::Quotation {
            context: Box::new(self.context),
            parent: Box::new(self.stack),
        };
        RailState {
            stack: Stack::new(),
            dictionary: self.dictionary,
            context,
        }
    }

    pub fn in_main(&self) -> bool {
        matches!(self.context, Context::Main)
    }

    pub fn higher(self) -> RailState {
        let (context, mut stack) = match self.context {
            Context::Quotation { context, parent } => (*context, *parent),
            Context::String { context: _ } => {
                unreachable!("Should never try to escape while in a string")
            }
            Context::Comment { context: _ } => {
                unreachable!("Should never try to escape while in a comment")
            }
            Context::Main => panic!("Can't escape main"),
        };

        stack.push_quotation(self.stack);

        RailState {
            stack,
            dictionary: self.dictionary,
            context,
        }
    }

    pub fn enter_string(self) -> RailState {
        let context = Context::String {
            context: Box::new(self.context),
        };

        let mut stack = self.stack;

        stack.push_string(String::new());

        RailState {
            stack,
            dictionary: self.dictionary,
            context,
        }
    }

    pub fn in_string(&self) -> bool {
        matches!(self.context, Context::String { context: _ })
    }

    pub fn append_string(self, s: &str) -> RailState {
        self.append_string_exact(" ").append_string_exact(s)
    }

    pub fn append_string_exact(self, s: &str) -> RailState {
        let mut stack = self.stack.clone();
        let s = stack.pop_string("string_parser") + s;
        stack.push_string(s);
        self.update_stack(stack)
    }

    pub fn exit_string(self) -> RailState {
        let context = match self.context {
            Context::String { context } => *context,
            ctx => unreachable!(
                "can't exit string when not even in a string. Context: {:?}",
                ctx
            ),
        };

        RailState {
            stack: self.stack,
            dictionary: self.dictionary,
            context,
        }
    }

    pub fn enter_comment(self) -> RailState {
        let context = Context::Comment {
            context: Box::new(self.context),
        };

        RailState {
            stack: self.stack,
            dictionary: self.dictionary,
            context,
        }
    }

    pub fn in_comment(&self) -> bool {
        matches!(self.context, Context::Comment { context: _ })
    }

    pub fn exit_comment(self) -> RailState {
        let context = match self.context {
            Context::Comment { context } => *context,
            ctx => unreachable!(
                "can't exit comment when not even in a comment. Context: {:?}",
                ctx
            ),
        };

        RailState {
            stack: self.stack,
            dictionary: self.dictionary,
            context,
        }
    }
}

impl Default for RailState {
    fn default() -> Self {
        Self::new(Context::Main)
    }
}

#[derive(Clone, Debug)]
pub enum Context {
    Main,
    Quotation {
        context: Box<Context>,
        parent: Box<Stack>,
    },
    String {
        context: Box<Context>,
    },
    Comment {
        context: Box<Context>,
    },
}

#[derive(Clone, Debug)]
pub enum RailVal {
    Boolean(bool),
    // TODO: Make a "Numeric" typeclass. (And floating-point/rational numbers)
    I64(i64),
    Operator(RailOp<'static>),
    Quotation(Stack),
    String(String),
}

impl std::fmt::Display for RailVal {
    fn fmt(&self, fmt: &mut std::fmt::Formatter<'_>) -> Result<(), std::fmt::Error> {
        use RailVal::*;
        match self {
            Boolean(b) => write!(fmt, "{}", if *b { "true" } else { "false" }),
            I64(n) => write!(fmt, "{}", n),
            Operator(o) => write!(fmt, "{:?}", o),
            Quotation(q) => write!(fmt, "{}", q),
            String(s) => write!(fmt, "\"{}\"", s),
        }
    }
}

#[derive(Clone, Debug)]
pub struct Stack {
    terms: Vec<RailVal>,
}

impl Stack {
    fn new() -> Self {
        Stack { terms: vec![] }
    }

    fn len(&self) -> usize {
        self.terms.len()
    }

    fn is_empty(&self) -> bool {
        self.terms.is_empty()
    }

    fn push(&mut self, term: RailVal) {
        self.terms.push(term)
    }

    fn push_bool(&mut self, b: bool) {
        self.terms.push(RailVal::Boolean(b))
    }

    fn push_i64(&mut self, i: i64) {
        self.terms.push(RailVal::I64(i))
    }

    fn push_operator(&mut self, op: RailOp<'static>) {
        self.terms.push(RailVal::Operator(op))
    }

    fn push_quotation(&mut self, quot: Stack) {
        self.terms.push(RailVal::Quotation(quot))
    }

    fn push_string(&mut self, s: String) {
        self.terms.push(RailVal::String(s))
    }

    fn pop(&mut self) -> Option<RailVal> {
        self.terms.pop()
    }

    fn pop_bool(&mut self, context: &str) -> bool {
        match self.terms.pop().unwrap() {
            RailVal::Boolean(b) => b,
            rail_val => panic!("{}", type_panic_msg(context, "boolean", rail_val)),
        }
    }

    fn pop_i64(&mut self, context: &str) -> i64 {
        match self.terms.pop().unwrap() {
            RailVal::I64(n) => n,
            rail_val => panic!("{}", type_panic_msg(context, "i64", rail_val)),
        }
    }

    fn _pop_operator(&mut self, context: &str) -> RailOp<'static> {
        match self.terms.pop().unwrap() {
            RailVal::Operator(op) => op,
            rail_val => panic!("{}", type_panic_msg(context, "operator", rail_val)),
        }
    }

    fn pop_quotation(&mut self, context: &str) -> Stack {
        match self.terms.pop().unwrap() {
            RailVal::Quotation(quot) => quot,
            rail_val => panic!("{}", type_panic_msg(context, "quotation", rail_val)),
        }
    }

    fn pop_string(&mut self, context: &str) -> String {
        match self.terms.pop().unwrap() {
            RailVal::String(s) => s,
            rail_val => panic!("{}", type_panic_msg(context, "string", rail_val)),
        }
    }
}

impl std::fmt::Display for Stack {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> Result<(), std::fmt::Error> {
        write!(f, "[ ").unwrap();

        for term in &self.terms {
            term.fmt(f).unwrap();
            write!(f, " ").unwrap();
        }

        write!(f, "]").unwrap();

        Ok(())
    }
}

fn type_panic_msg(context: &str, expected: &str, actual: RailVal) -> String {
    format!(
        "[Context: {}] Wanted {}, but got {:?}",
        context, expected, actual
    )
}