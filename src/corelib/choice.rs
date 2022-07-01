use crate::rail_machine::{run_quote, RailDef};

pub fn builtins() -> Vec<RailDef<'static>> {
    vec![RailDef::on_state("opt", &["seq"], &[], |state| {
        // TODO: All conditions and all actions must have the same stack effect.
        let (mut options, stack) = state.stack.clone().pop_quote("opt");
        let mut state = state.replace_stack(stack);

        options.values.reverse();

        while !options.is_empty() {
            let (condition, opts) = options.pop_quote("opt");
            let (action, opts) = opts.pop_quote("opt");
            options = opts;

            // TODO: Should this be running in a way that can't alter the main stack?
            state = run_quote(&condition, state);
            let (success, stack) = state.stack.clone().pop_bool("opt");
            state = state.replace_stack(stack);

            if success {
                return run_quote(&action, state);
            }
        }

        state
    })]
}
