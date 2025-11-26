-- Ghost Combinator Mod - Main Control
-- Event registration and routing to entity-specific handlers
-- CRITICAL: Uses Factorio 2.0 APIs only!

local flib_gui = require("__flib__.gui")

-- Entity modules
local gc_control = require("scripts.ghost_combinator.control")
local gc_gui = require("scripts.ghost_combinator.gui")
local globals = require("scripts.globals")
local entity_lib = require("lib.entity_lib")
local circuit_utils = require("lib.circuit_utils")

-- Entity name constants
local GHOST_COMBINATOR = "ghost-combinator"

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
    log("[ghost-combinator] on_init")
    globals.init_storage()
end)

script.on_load(function()
    log("[ghost-combinator] on_load")
    -- No initialization needed on load - storage already exists
end)

script.on_configuration_changed(function(data)
    log("[ghost-combinator] on_configuration_changed")
    -- Run migrations if needed
    globals.init_storage()  -- Ensure storage tables exist
end)

-----------------------------------------------------------
-- ENTITY BUILD/DESTROY EVENT ROUTING
-- CRITICAL: Ghost tracking requires NO filters (monitors all entities)
-- Combinator events use filters for performance
-----------------------------------------------------------

--- Unified handler for all entity build events
--- Routes to ghost tracking OR combinator creation based on entity type
--- @param event EventData Event data with entity and optional tags
local function on_entity_built(event)
    local entity = event.entity
    if not entity or not entity.valid then return end

    -- Route to appropriate handler based on entity type
    if entity.type == "entity-ghost" then
        -- Track ALL ghosts (no filter - this runs on every ghost built)
        gc_control.on_ghost_built(event)
    elseif entity.name == GHOST_COMBINATOR then
        -- Handle combinator creation
        gc_control.on_combinator_built(event)
    end
end

--- Unified handler for all entity removal events
--- Routes to ghost tracking OR combinator cleanup based on entity type
--- @param event EventData Event data with entity
local function on_entity_removed(event)
    local entity = event.entity
    if not entity or not entity.valid then return end

    -- Route to appropriate handler based on entity type
    if entity.type == "entity-ghost" then
        -- Track ALL ghost removals (no filter - runs on every ghost removed)
        gc_control.on_ghost_removed(event)
    elseif entity.name == GHOST_COMBINATOR then
        -- Handle combinator destruction
        gc_control.on_combinator_removed(event)
    end
end

-- Register build events WITHOUT filters to catch both ghosts and combinators
-- The handlers do internal type checking for performance
script.on_event(defines.events.on_built_entity, on_entity_built)
script.on_event(defines.events.on_robot_built_entity, on_entity_built)
script.on_event(defines.events.script_raised_built, on_entity_built)
script.on_event(defines.events.script_raised_revive, on_entity_built)

-- Register destroy events WITHOUT filters to catch both ghosts and combinators
script.on_event(defines.events.on_player_mined_entity, on_entity_removed)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed)
script.on_event(defines.events.on_entity_died, on_entity_removed)
script.on_event(defines.events.script_raised_destroy, on_entity_removed)

-----------------------------------------------------------
-- COMBINATOR-SPECIFIC EVENTS (WITH FILTERS)
-- These only apply to the ghost-combinator entity itself
-----------------------------------------------------------

-- Combinator event filter
local combinator_filter = {
    {filter = "name", name = GHOST_COMBINATOR},
    {filter = "ghost_name", name = GHOST_COMBINATOR}
}

-- Blueprint and copy-paste events for combinators only
script.on_event(defines.events.on_player_setup_blueprint, function(event)
    gc_control.on_player_setup_blueprint(event)
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
    local source = event.source
    local destination = event.destination

    if not source or not source.valid then return end
    if not destination or not destination.valid then return end

    -- Only handle if one of them is our combinator
    if entity_lib.is_type(source, GHOST_COMBINATOR) or
       entity_lib.is_type(destination, GHOST_COMBINATOR) then
        gc_control.on_entity_settings_pasted(event)
    end
end, combinator_filter)

script.on_event(defines.events.on_entity_cloned, function(event)
    local source = event.source
    local destination = event.destination

    if not source or not source.valid then return end
    if not destination or not destination.valid then return end

    -- Only handle if one of them is our combinator
    if entity_lib.is_type(source, GHOST_COMBINATOR) or
       entity_lib.is_type(destination, GHOST_COMBINATOR) then
        gc_control.on_entity_cloned(event)
    end
end, combinator_filter)

-----------------------------------------------------------
-- GUI EVENT ROUTING
-----------------------------------------------------------

-- Handle GUI opened events - let the GUI module decide if it's relevant
script.on_event(defines.events.on_gui_opened, function(event)
    gc_gui.on_gui_opened(event)
end)

-- Handle GUI closed events - let the GUI module decide if it's relevant
script.on_event(defines.events.on_gui_closed, function(event)
    gc_gui.on_gui_closed(event)
end)

-- Handle all GUI clicks - let the GUI module decide if it's relevant
script.on_event(defines.events.on_gui_click, function(event)
    gc_gui.on_gui_click(event)
end)

-- Handle all checkbox state changes - let the GUI module decide if it's relevant
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    gc_gui.on_gui_checked_state_changed(event)
end)

-----------------------------------------------------------
-- PERIODIC UPDATES
-----------------------------------------------------------

-- Every tick: Update combinator outputs if ghost counts changed
-- CRITICAL: This must be fast! Only processes combinators on surfaces with changes
script.on_event(defines.events.on_tick, function(event)
    gc_control.on_tick(event)
end)

-- Every 5 seconds (300 ticks): Compact ghost slot assignments
-- Removes zero-count ghosts and compresses slot IDs to avoid gaps
script.on_nth_tick(300, function(event)
    gc_control.compact_ghost_slots(event)
end)

log("[ghost-combinator] control.lua loaded")
