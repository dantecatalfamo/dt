use crate::rail_machine::{run_quot, RailDef};

pub fn builtins() -> Vec<RailDef<'static>> {
    vec![
        RailDef::on_state("do", &["quot"], &["..."], |state| {
            let (quot, stack) = state.stack.clone().pop_quotation("do");
            let state = state.replace_stack(stack);
            run_quot(&quot, state)
        }),
        RailDef::on_state("doin", &["quot", "quot"], &["quot"], |state| {
            state.clone().update_stack(|stack| {
                let (quot, stack) = stack.pop_quotation("call-in");
                let (working_stack, stack) = stack.pop_quotation("call-in");

                let substate = state.contextless_child(working_stack); // TODO: Really just need dictionary.
                let substate = run_quot(&quot, substate);

                stack.push_quotation(substate.stack)
            })
        }),
        RailDef::on_state("def", &["quot", "s"], &[], |state| {
            state.update_stack_and_dict(|stack, dictionary| {
                let mut dictionary = dictionary;
                let (name, stack) = stack.pop_string("def");
                let (quot, stack) = stack.pop_quotation("def");
                dictionary.insert(name.clone(), RailDef::from_quot(&name, quot));
                (stack, dictionary)
            })
        }),
        RailDef::on_state("def?", &["s"], &["bool"], |state| {
            state.clone().update_stack(|stack| {
                let (name, stack) = stack.pop_string("def?");
                stack.push_bool(state.dictionary.contains_key(&name))
            })
        }),
        RailDef::on_state("undef", &["s"], &[], |state| {
            state.update_stack_and_dict(|stack, dictionary| {
                let mut dictionary = dictionary;
                let (name, stack) = stack.pop_string("undef");
                dictionary.remove(&name).unwrap_or_else(|| {
                    panic!("Cannot undef \"{}\", it was already undefined", name)
                });
                (stack, dictionary)
            })
        }),
    ]
}
