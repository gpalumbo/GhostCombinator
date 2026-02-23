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
local signal_utils = require("lib.signal_utils")

-- Entity name constants
local GHOST_COMBINATOR = "ghost-combinator"

-- Periodic tick intervals (in ticks; 60 ticks = 1 second)
local COMPACT_INTERVAL = 300   -- 5 seconds: remove zero-count ghosts & compress slots
local RESYNC_INTERVAL  = 600   -- 10 seconds: full resync of combinator outputs from storage

-- Register custom input handler for pipette tool on GUI signal buttons
script.on_event("gui-pipette-signal", function(event)
    -- Check if hovering over a signal sprite-button with signal data
    if event.element and event.element.tags and event.element.tags.signal_sel then
        local signal_id = event.element.tags.signal_sel
        local player = game.get_player(event.player_index)

        if not player then return end

        -- Convert signal_id to PipetteID format
        local pipette_id = signal_utils.signal_to_prototype(signal_id)

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
--- Only handles combinator cleanup - ghost tracking uses on_object_destroyed
--- @param event EventData Event data with entity
local function on_entity_removed(event)
    local entity = event.entity
    if not entity or not entity.valid then return end

    -- Only handle combinator destruction here
    -- Ghost tracking is handled by on_object_destroyed which fires for ALL
    -- destruction reasons including revive (ghost built into real entity)
    if entity.name == GHOST_COMBINATOR then
        gc_control.on_combinator_removed(event)
    end
end

-- Register build events WITHOUT filters to catch both ghosts and combinators
-- The handlers do internal type checking for performance
script.on_event(defines.events.on_built_entity, on_entity_built)
script.on_event(defines.events.on_robot_built_entity, on_entity_built)
script.on_event(defines.events.script_raised_built, on_entity_built)
script.on_event(defines.events.script_raised_revive, on_entity_built)

-- Register destroy events for combinator cleanup only
-- Ghost entities are tracked via register_on_object_destroyed instead
script.on_event(defines.events.on_player_mined_entity, on_entity_removed)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed)
script.on_event(defines.events.on_entity_died, on_entity_removed)
script.on_event(defines.events.script_raised_destroy, on_entity_removed)

-- Register on_object_destroyed for ghost tracking
-- This fires when ANY registered object is destroyed, including ghost revives
script.on_event(defines.events.on_object_destroyed, function(event)
    gc_control.on_object_destroyed(event)
end)

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

-- NOTE: on_entity_settings_pasted does NOT support filtering in Factorio 2.0
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
end)

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

-- Compact ghost slot assignments: remove zero-count ghosts and compress slot IDs
script.on_nth_tick(COMPACT_INTERVAL, function(event)
    gc_control.compact_ghost_slots(event)
end)

-- Full resync of combinator slots from storage truth (safety net for desyncs)
script.on_nth_tick(RESYNC_INTERVAL, function(event)
    gc_control.full_resync_all(event)
end)

-----------------------------------------------------------
-- DEBUG COMMANDS
-----------------------------------------------------------

-- /gc-ghost-state - Dumps the ghost_combinator.ghosts data structure
commands.add_command("gc-ghost-state", "Dumps the ghost combinator ghost tracking state", function(command)
    local player = game.get_player(command.player_index)
    if not player then return end

    if not storage.ghost_combinator then
        player.print("[Ghost Combinator] No ghost data (storage.ghost_combinator is nil)")
        return
    end

    -- Build a summary structure (avoid printing entity references directly)
    local summary = {}
    for surface_index, surface_data in pairs(storage.ghost_combinator) do
        local surface = game.surfaces[surface_index]
        local surface_name = surface and surface.name or ("surface_" .. surface_index)

        local combinator_count = 0
        if surface_data.combinators then
            for _ in pairs(surface_data.combinators) do
                combinator_count = combinator_count + 1
            end
        end

        summary[surface_name] = {
            surface_index = surface_index,
            combinator_count = combinator_count,
            next_slot = surface_data.next_slot,
            any_changes = surface_data.any_changes,
            ghosts = surface_data.ghosts or {}
        }
    end

    -- Add registration count
    local reg_count = 0
    if storage.ghost_registrations then
        for _ in pairs(storage.ghost_registrations) do
            reg_count = reg_count + 1
        end
    end
    summary._ghost_registrations_count = reg_count

    player.print("[Ghost Combinator] Ghost State:")
    player.print(serpent.block(summary))
end)

-- /gc-ghost-clear [surface_id] - Clears ghosts on a surface (or all if no surface specified)
commands.add_command("gc-ghost-clear", "Clears ghost tracking data. Usage: /gc-ghost-clear [surface_id]", function(command)
    local player = game.get_player(command.player_index)
    if not player then return end

    if not storage.ghost_combinator then
        player.print("[Ghost Combinator] No ghost data to clear")
        return
    end

    local surface_id = nil
    if command.parameter and command.parameter ~= "" then
        surface_id = tonumber(command.parameter)
        if not surface_id then
            player.print("[Ghost Combinator] Invalid surface_id: " .. command.parameter)
            return
        end
    end

    if surface_id then
        -- Clear specific surface
        local surface_data = storage.ghost_combinator[surface_id]
        if surface_data then
            local old_count = 0
            if surface_data.ghosts then
                for _ in pairs(surface_data.ghosts) do
                    old_count = old_count + 1
                end
            end

            surface_data.ghosts = {}
            surface_data.next_slot = 1
            surface_data.any_changes = true

            -- Also clear ghost registrations for this surface
            local cleared_regs = 0
            if storage.ghost_registrations then
                for reg_num, reg_info in pairs(storage.ghost_registrations) do
                    if reg_info.surface == surface_id then
                        storage.ghost_registrations[reg_num] = nil
                        cleared_regs = cleared_regs + 1
                    end
                end
            end
            player.print("[Ghost Combinator] Cleared " .. old_count .. " ghost entries and " ..
                cleared_regs .. " registrations from surface " .. surface_id)
        else
            player.print("[Ghost Combinator] No data for surface " .. surface_id)
        end
    else
        -- Clear all surfaces
        local total_cleared = 0
        local surfaces_cleared = 0

        for surface_index, surface_data in pairs(storage.ghost_combinator) do
            if surface_data.ghosts then
                for _ in pairs(surface_data.ghosts) do
                    total_cleared = total_cleared + 1
                end
            end
            surface_data.ghosts = {}
            surface_data.next_slot = 1
            surface_data.any_changes = true
            surfaces_cleared = surfaces_cleared + 1
        end

        -- Clear all ghost registrations
        local cleared_regs = 0
        if storage.ghost_registrations then
            for _ in pairs(storage.ghost_registrations) do
                cleared_regs = cleared_regs + 1
            end
            storage.ghost_registrations = {}
        end

        player.print("[Ghost Combinator] Cleared " .. total_cleared .. " ghost entries and " ..
            cleared_regs .. " registrations from " .. surfaces_cleared .. " surfaces")
    end
end)
