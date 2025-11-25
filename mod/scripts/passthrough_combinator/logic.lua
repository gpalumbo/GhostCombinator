-- Mission Control Mod - Passthrough Combinator Logic
-- Core signal processing logic for the passthrough combinator
-- This combinator passes input signals directly to output without modification

local circuit_utils = require("lib.circuit_utils")

local logic = {}

--- Get the output signals for a passthrough combinator
--- For a passthrough combinator, output signals are identical to input signals
--- @param entity LuaEntity The passthrough combinator entity
--- @return table {red = array of Signal, green = array of Signal}
function logic.get_output_signals(entity)
    -- Passthrough behavior: output = input (no transformation)
    return circuit_utils.get_input_signals_raw(entity)
end

--- Process signals for a passthrough combinator (called each tick if needed)
--- Currently a no-op since arithmetic combinators handle passthrough natively
--- @param entity LuaEntity The passthrough combinator entity
--- @return boolean Success status
function logic.process_signals(entity)
    if not entity or not entity.valid then
        return false
    end

    -- The arithmetic combinator prototype handles signal passthrough natively
    -- when configured with "each" input and "+ 0" operation.
    -- This function exists for future enhancements (filtering, routing, etc.)

    return true
end

return logic