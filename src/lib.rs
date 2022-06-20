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

    pub fn higher(self) -> RailState {
        let (context, mut stack) = match self.context {
            Context::Quotation { context, parent } => (*context, *parent),
            Context::Main => panic!("Can't escape main"),
        };

        stack.push(RailVal::Quotation(self.stack));

        RailState {
            stack,
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
}

#[derive(Clone, Debug)]
pub enum RailVal {
    Boolean(bool),
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
            I64(n) => write!(fmt, "{:?}", n),
            Operator(o) => write!(fmt, "{:?}", o),
            Quotation(q) => write!(fmt, "{:?}", q),
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

    fn push(&mut self, term: RailVal) {
        self.terms.push(term)
    }

    fn len(&self) -> usize {
        self.terms.len()
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

    fn pop_operator(&mut self, context: &str) -> RailOp<'static> {
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

    fn is_empty(&self) -> bool {
        self.terms.is_empty()
    }
}

impl std::fmt::Display for Stack {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> Result<(), std::fmt::Error> {
        for term in &self.terms {
            term.fmt(f).unwrap();
            write!(f, " ").unwrap();
        }
        Ok(())
    }
}

fn type_panic_msg(context: &str, expected: &str, actual: RailVal) -> String {
    format!(
        "[Context: {}] Wanted {}, but got {:?}",
        context, expected, actual
    )
}
