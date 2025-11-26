-- Mission Control Mod - Circuit Utilities
-- Provides helper functions for reading and manipulating circuit network signals

local circuit_utils = {}

--- Get all input signals from an entity's circuit connections (raw, no copy)
--- Returns direct references to the API's signal arrays. Treat as read-only.
--- Signal format: {signal = SignalID, count = int}
--- @param entity LuaEntity The entity to read signals from
--- @param wire_type defines.wire_type|nil Optional wire type filter (red or green)
--- @return table {red = array of Signal, green = array of Signal}
function circuit_utils.get_input_signals_raw(entity, wire_type)
    local empty = {}
    local result = {
        red = empty,
        green = empty
    }

    if not entity or not entity.valid then
        return result
    end

    -- Get red wire signals (if not filtered to green only)
    if not wire_type or wire_type == defines.wire_type.red then
        local red_signals = entity.get_signals(defines.wire_connector_id.combinator_input_red)
        if red_signals then
            result.red = red_signals
        end
    end

    -- Get green wire signals (if not filtered to red only)
    if not wire_type or wire_type == defines.wire_type.green then
        local green_signals = entity.get_signals(defines.wire_connector_id.combinator_input_green)
        if green_signals then
            result.green = green_signals
        end
    end

    return result
end

--- Check if entity has any circuit connections on specified connector
--- @param entity LuaEntity
--- @param connector_id defines.wire_connector_id|nil Optional connector to check (defaults to checking all)
--- @return boolean
function circuit_utils.has_circuit_connections(entity, connector_id)
    if not entity or not entity.valid then
        return false
    end

    -- If specific connector requested, check only that one
    if connector_id then
        local network = entity.get_circuit_network(connector_id)
        return network ~= nil
    end

    -- Check all possible wire connectors for combinators
    local connectors = {
        defines.wire_connector_id.combinator_input_red,
        defines.wire_connector_id.combinator_input_green,
        defines.wire_connector_id.combinator_output_red,
        defines.wire_connector_id.combinator_output_green
    }

    for _, conn_id in ipairs(connectors) do
        local network = entity.get_circuit_network(conn_id)
        if network then
            return true
        end
    end

    return false
end

--- Get the total count of a specific signal from input wires
--- @param entity LuaEntity
--- @param signal_id SignalID The signal to count
--- @param wire_type defines.wire_type|nil Optional wire type filter
--- @return integer Total count of the signal
function circuit_utils.get_signal_count(entity, signal_id, wire_type)
    if not entity or not entity.valid or not signal_id then
        return 0
    end

    local total = 0
    local signals = circuit_utils.get_input_signals_raw(entity, wire_type)

    -- Sum from red wire
    if not wire_type or wire_type == defines.wire_type.red then
        for _, signal_data in ipairs(signals.red) do
            if signal_data.signal.type == signal_id.type and signal_data.signal.name == signal_id.name then
                total = total + signal_data.count
            end
        end
    end

    -- Sum from green wire
    if not wire_type or wire_type == defines.wire_type.green then
        for _, signal_data in ipairs(signals.green) do
            if signal_data.signal.type == signal_id.type and signal_data.signal.name == signal_id.name then
                total = total + signal_data.count
            end
        end
    end

    return total
end


--- Format signal for display in GUI
--- @param signal_data table Signal data {signal = SignalID, count = integer}
--- @return string Formatted signal string
function circuit_utils.format_signal_for_display(signal_data)
    if not signal_data or not signal_data.signal then
        return "Invalid signal"
    end

    local signal_prototype = game.get_filtered_item_prototypes({{filter = "name", name = signal_data.signal.name}})[1]
    if not signal_prototype then
        signal_prototype = game.get_filtered_fluid_prototypes({{filter = "name", name = signal_data.signal.name}})[1]
    end
    if not signal_prototype then
        signal_prototype = game.virtual_signal_prototypes[signal_data.signal.name]
    end

    local display_name = signal_prototype and signal_prototype.localised_name or signal_data.signal.name
    return string.format("[%s=%s] x%d", signal_data.signal.type, signal_data.signal.name, signal_data.count)
end

--- Get count of signals on a specific wire connector
--- @param entity LuaEntity
--- @param connector_id defines.wire_connector_id (must include color, e.g., combinator_input_red)
--- @return integer Number of unique signals
function circuit_utils.get_signal_count_for_wire(entity, connector_id)
    if not entity or not entity.valid then
        return 0
    end

    local network = entity.get_circuit_network(connector_id)
    if not network or not network.signals then
        return 0
    end

    local count = 0
    for _ in pairs(network.signals) do
        count = count + 1
    end

    return count
end

function circuit_utils.signal_to_prototype(signal)
      if not signal or not signal.name then
        return nil
      end

      -- Default to "item" if type is nil
      local signal_type = signal.type or "item"

      -- Virtual signals cannot be pipetted
      if signal_type == "virtual" then
        signal_type = "virtual_signal"
      end

      -- Get the actual prototype object from the game
      if(not prototypes[signal_type]) then
        return nil
      end

      local prototype = prototypes[signal_type][signal.name]

      -- Return prototype and quality (quality can be nil)
      return prototype

end

return circuit_utils
