-- Mission Control Mod - Main Control
-- Event registration and routing to entity-specific handlers

local flib_gui = require("__flib__.gui")

-- Entity modules
local passthrough_control = require("scripts.passthrough_combinator.control")
local passthrough_gui = require("scripts.passthrough_combinator.gui")
local globals = require("scripts.globals")
local entity_lib = require("lib.entity_lib")
local circuit_utils = require("lib.circuit_utils")

-- Entity name constants
local PASSTHROUGH_COMBINATOR = "passthrough-combinator"

-- Register custom input handler for pipette tool on GUI signal buttons
script.on_event("gui-pipette-signal", function(event)
    -- Check if hovering over a signal sprite-button with signal data
    if event.element and event.element.tags and event.element.tags.signal_sel then
        local signal_id = event.element.tags.signal_sel
        local player = game.get_player(event.player_index)

        if not player then return end

        -- Convert signal_id to PipetteID format
        local pipette_id = circuit_utils.signal_to_prototype(signal_id)

        if pipette_id then
            -- Try pipette with error handling
            pcall(function()
                player.pipette(pipette_id, signal_id.quality, true)
            end)
        end
    end
end)

-----------------------------------------------------------
-- LIFECYCLE EVENTS
-----------------------------------------------------------

script.on_init(function()
    log("[example-mod] on_init")
    globals.init_storage()
end)

script.on_configuration_changed(function(data)
    log("[example-mod] on_configuration_changed")
    -- Run migrations if needed
    globals.init_storage()  -- Ensure storage tables exist
end)

-----------------------------------------------------------
-- BUILD EVENT ROUTING
-----------------------------------------------------------

-- Helper to route build events
local function route_build_event(event)
    if entity_lib.is_type(event.entity, PASSTHROUGH_COMBINATOR) then
        passthrough_control.on_built(event)
    end
end

-- Register build events with filters
local build_filter = {
    {filter = "name", name = PASSTHROUGH_COMBINATOR},
    {filter = "ghost_name", name = PASSTHROUGH_COMBINATOR}
}

script.on_event(defines.events.on_built_entity, route_build_event, build_filter)
script.on_event(defines.events.on_robot_built_entity, route_build_event, build_filter)
script.on_event(defines.events.on_space_platform_built_entity, route_build_event, build_filter)
script.on_event(defines.events.script_raised_built, route_build_event, build_filter)
script.on_event(defines.events.script_raised_revive, route_build_event, build_filter)

-----------------------------------------------------------
-- DESTROY EVENT ROUTING
-----------------------------------------------------------

local function route_destroy_event(event)
    if entity_lib.is_type(event.entity, PASSTHROUGH_COMBINATOR) then
        passthrough_control.on_removed(event)
    end
end

local destroy_filter = {
    {filter = "name", name = PASSTHROUGH_COMBINATOR},
    {filter = "ghost_name", name = PASSTHROUGH_COMBINATOR}
}

script.on_event(defines.events.on_player_mined_entity, route_destroy_event, destroy_filter)
script.on_event(defines.events.on_robot_mined_entity, route_destroy_event, destroy_filter)
script.on_event(defines.events.on_space_platform_mined_entity, route_destroy_event, destroy_filter)
script.on_event(defines.events.on_entity_died, route_destroy_event, destroy_filter)
script.on_event(defines.events.script_raised_destroy, route_destroy_event, destroy_filter)

-----------------------------------------------------------
-- GUI EVENT ROUTING
-----------------------------------------------------------

-- Handle GUI opened events - let the GUI module decide if it's relevant
script.on_event(defines.events.on_gui_opened, function(event)
    passthrough_gui.on_gui_opened(event)
end)

-- Handle GUI closed events - let the GUI module decide if it's relevant
script.on_event(defines.events.on_gui_closed, function(event)
    passthrough_gui.on_gui_closed(event)
end)

-- Handle all GUI clicks - let the GUI module decide if it's relevant
script.on_event(defines.events.on_gui_click, function(event)
    passthrough_gui.on_gui_click(event)
end)

-- Handle all checkbox state changes - let the GUI module decide if it's relevant
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    passthrough_gui.on_gui_checked_state_changed(event)
end)

-----------------------------------------------------------
-- BLUEPRINT/COPY-PASTE ROUTING
-----------------------------------------------------------

script.on_event(defines.events.on_player_setup_blueprint, function(event)
    passthrough_control.on_player_setup_blueprint(event)
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
    passthrough_control.on_entity_settings_pasted(event)
end)

script.on_event(defines.events.on_entity_cloned, function(event)
    passthrough_control.on_entity_cloned(event)
end)

-----------------------------------------------------------
-- PERIODIC UPDATES
-----------------------------------------------------------

-- Update every 15 ticks (250ms) for signal processing
script.on_nth_tick(15, function(event)
    -- Route to entity update handlers
    passthrough_control.on_update(event)
end)

log("[example-mod] control.lua loaded")
