-- Ghost Combinator - Control Module
-- Handles all entity lifecycle events and ghost tracking
-- CRITICAL: Performance-critical ghost tracking - must be FAST!

local gc_storage = require("scripts.ghost_combinator.storage")
local globals = require("scripts.globals")

local control = {}

-- Entity name constant
local GHOST_COMBINATOR = "ghost-combinator"

-- Update interval for combinator slots (every tick for responsiveness)
local UPDATE_INTERVAL = 1

-- Compaction interval (every 10 seconds)
local COMPACT_INTERVAL = 600

-----------------------------------------------------------
-- LOCAL HELPER FUNCTIONS
-----------------------------------------------------------

--- Initialize all slots for a combinator with current ghost data
--- Used when a new combinator is placed to populate it immediately
--- @param combinator LuaEntity The combinator entity
--- @param ghosts table Table of ghost_name -> {count, slot, changed}
--- @return boolean True if initialization succeeded
local function initialize_combinator_slots(combinator, ghosts)
    if not combinator or not combinator.valid then
        return false
    end

    -- Get control behavior
    local cb = combinator.get_control_behavior()
    if not cb then
        log("[ghost_combinator] WARNING: Combinator has no control behavior")
        return false
    end

    -- Get or create section 1
    local section = cb.get_section(1)
    if not section then
        section = cb.add_section("")
        if not section then
            log("[ghost_combinator] WARNING: Could not create section for combinator")
            return false
        end
    end

    -- Write ALL slots (ignore changed flag - this is initialization)
    local slot_count = 0
    for ghost_key, ghost_data in pairs(ghosts) do
        if ghost_data.count > 0 and ghost_data.name then
            -- Use stored entity name and quality
            local filter = {
                value = {
                    type = "item",
                    name = ghost_data.name,
                    quality = ghost_data.quality or "normal"
                },
                min = ghost_data.count
            }
            section.set_slot(ghost_data.slot, filter)
            slot_count = slot_count + 1
        end
    end

    return true, slot_count
end

-----------------------------------------------------------
-- GHOST TRACKING HANDLERS
-- CRITICAL: Called for ALL entity events - must be FAST!
-----------------------------------------------------------

--- Handle ghost entity built
--- CRITICAL: This is called for EVERY entity built - type check MUST be first!
--- @param event EventData Event data containing entity
function control.on_ghost_built(event)
    local entity = event.entity

    -- FAST rejection - type check MUST be first line!
    if not entity or entity.type ~= "entity-ghost" then
        return
    end

    local ghost_name = entity.ghost_name
    local surface_index = entity.surface.index
    local quality_name = entity.quality and entity.quality.name or "normal"

    -- Increment ghost count (track by name + quality)
    gc_storage.increment_ghost(surface_index, ghost_name, quality_name)

    -- Debug logging (can be disabled for production)
    -- log("[ghost_combinator] Ghost built: " .. ghost_name .. " (" .. quality_name .. ") on surface " .. surface_index)
end

--- Handle ghost entity removed (mined, canceled, etc.)
--- CRITICAL: This is called for EVERY entity removed - type check MUST be first!
--- @param event EventData Event data containing entity
function control.on_ghost_removed(event)
    local entity = event.entity

    -- FAST rejection - type check MUST be first line!
    if not entity or entity.type ~= "entity-ghost" then
        return
    end

    local ghost_name = entity.ghost_name
    local surface_index = entity.surface.index
    local quality_name = entity.quality and entity.quality.name or "normal"

    -- Decrement ghost count (track by name + quality)
    gc_storage.decrement_ghost(surface_index, ghost_name, quality_name)

    -- Debug logging (can be disabled for production)
    -- log("[ghost_combinator] Ghost removed: " .. ghost_name .. " (" .. quality_name .. ") on surface " .. surface_index)
end

--- Handle ghost revived (became real entity)
--- This is called when a ghost is built by a robot or player
--- NOTE: script_raised_revive provides both 'entity' (new) and optionally 'ghost' (if it existed)
--- @param event EventData Event data containing entity (and possibly ghost for script_raised_revive)
function control.on_ghost_revived(event)
    -- For script_raised_revive, we get the created entity, not the ghost
    -- The ghost is already destroyed at this point
    -- We need to check if this was previously a ghost (via tags or other means)
    -- For now, we rely on script_raised_built being called instead
    -- This handler is kept for potential future use

    -- Note: In Factorio 2.0, when a ghost is revived:
    -- 1. on_robot_built_entity is called with the new entity
    -- 2. The ghost is automatically removed
    -- So we don't need special handling here - the normal build flow handles it
end

-----------------------------------------------------------
-- COMBINATOR LIFECYCLE HANDLERS
-- These handle the ghost combinator entity itself
-----------------------------------------------------------

--- Shared handler for combinator build events
--- @param event EventData Event data containing entity
function control.on_combinator_built(event)
    local entity = event.entity

    if not entity or not entity.valid then
        return
    end

    -- Skip ghosts
    if entity.type == "entity-ghost" then
        return
    end

    -- Only handle our entity
    if entity.name ~= GHOST_COMBINATOR then
        return
    end

    -- Register the combinator
    local success = gc_storage.register_combinator(entity)

    if success then
        log("[ghost_combinator] Combinator built: " .. entity.unit_number .. " on surface " .. entity.surface.index)

        -- Initialize combinator with current ghost data
        local surface_index = entity.surface.index
        local surface_data = gc_storage.get_surface_data(surface_index)
        if surface_data and surface_data.ghosts then
            local success, slot_count = initialize_combinator_slots(entity, surface_data.ghosts)
            if success then
                log("[ghost_combinator] Initialized combinator " .. entity.unit_number .. " with " .. (slot_count or 0) .. " ghost types")
            end
        end
    end
end

--- Shared handler for combinator removal events
--- @param event EventData Event data containing entity
function control.on_combinator_removed(event)
    local entity = event.entity

    if not entity or not entity.valid then
        return
    end

    -- Only handle our entity (including ghosts for cleanup)
    if entity.name ~= GHOST_COMBINATOR and not (entity.type == "entity-ghost" and entity.ghost_name == GHOST_COMBINATOR) then
        return
    end

    -- Skip ghost destruction
    if entity.type == "entity-ghost" then
        return
    end

    local unit_number = entity.unit_number
    local surface_index = entity.surface.index

    if not unit_number then
        return
    end

    -- Close any open GUIs for this entity
    globals.cleanup_player_gui_states_for_entity(entity, "ghost_combinator_gui")

    -- Unregister from storage
    gc_storage.unregister_combinator(unit_number, surface_index)

    log("[ghost_combinator] Combinator removed: " .. unit_number .. " from surface " .. surface_index)
end

-----------------------------------------------------------
-- TICK HANDLERS
-- Update combinator slots and perform compaction
-----------------------------------------------------------

--- Update combinator slots for surfaces with changes
--- Called every tick to ensure responsive updates
--- @param event EventData.on_tick
function control.on_tick(event)
    if not storage.ghost_combinator then
        return
    end

    -- Process each surface that has changes
    for surface_index, surface_data in pairs(storage.ghost_combinator) do
        if surface_data.any_changes then
            control.update_surface_combinators(surface_index, surface_data)
            gc_storage.clear_changes_flag(surface_index)
        end
    end
end

--- Update all combinators on a surface with current ghost data
--- Only updates slots that have changed
--- @param surface_index number The surface index
--- @param surface_data table The surface data table
function control.update_surface_combinators(surface_index, surface_data)
    -- Get all combinators on this surface
    local combinators = surface_data.combinators

    if not combinators then
        return
    end

    local updated_count = 0

    -- Update each combinator
    for unit_number, combinator in pairs(combinators) do
        if combinator and combinator.valid then
            local success = control.update_combinator_slots(combinator, surface_data.ghosts)
            if success then
                updated_count = updated_count + 1
            end
        else
            -- Combinator became invalid, remove it
            surface_data.combinators[unit_number] = nil
        end
    end

    -- Clear changed flags on all ghost entries
    for ghost_key, _ in pairs(surface_data.ghosts) do
        gc_storage.clear_ghost_changed(surface_index, ghost_key)
    end

    if updated_count > 0 then
        log("[ghost_combinator] Updated " .. updated_count .. " combinators on surface " .. surface_index)
    end
end

--- Update a single combinator's slots with current ghost data
--- Uses LuaConstantCombinatorControlBehavior and LuaLogisticSection APIs
--- @param combinator LuaEntity The combinator entity
--- @param ghosts table Table of ghost_name -> {count, slot, changed}
--- @return boolean True if update succeeded
function control.update_combinator_slots(combinator, ghosts)
    if not combinator or not combinator.valid then
        return false
    end

    -- Get control behavior
    local cb = combinator.get_control_behavior()
    if not cb then
        log("[ghost_combinator] WARNING: Combinator has no control behavior")
        return false
    end

    -- Get or create section 1
    local section = cb.get_section(1)
    if not section then
        section = cb.add_section("")
        if not section then
            log("[ghost_combinator] WARNING: Could not create section for combinator")
            return false
        end
    end

    -- Update only changed slots
    local updates = 0
    local clears = 0

    for ghost_key, ghost_data in pairs(ghosts) do
        -- Only update if changed
        if ghost_data.changed then
            local slot_index = ghost_data.slot
            local count = ghost_data.count

            if count > 0 then
                -- Get the actual entity name and quality from stored data
                -- ghost_data.name is the entity's ghost_name, ghost_data.quality is its quality
                local entity_name = ghost_data.name
                local quality_name = ghost_data.quality or "normal"

                if not entity_name then
                    -- Skip if no name stored (shouldn't happen, but safety check)
                    log("[ghost_combinator] WARNING: No entity name stored for ghost entry")
                else
                    -- Set slot with ghost item signal
                    -- LogisticFilter format: {value = SignalFilter, min = count}
                    -- CRITICAL: Must specify quality explicitly to avoid "non-trivial filter" error
                    local filter = {
                        value = {
                            type = "item",
                            name = entity_name,
                            quality = quality_name
                        },
                        min = count
                    }

                    section.set_slot(slot_index, filter)
                end
                updates = updates + 1
            else
                -- Clear slot if count is zero
                section.clear_slot(slot_index)
                clears = clears + 1
            end
        end
    end

    if updates > 0 or clears > 0 then
        log("[ghost_combinator] Updated combinator " .. combinator.unit_number .. ": " .. updates .. " set, " .. clears .. " cleared")
    end

    return true
end

--- Periodic slot compaction
--- Called every COMPACT_INTERVAL ticks to remove zero-count entries
--- Also clears orphaned slots from combinators after compaction
--- @param event EventData.on_nth_tick
function control.compact_ghost_slots(event)
    if not storage.ghost_combinator then
        return
    end

    local current_tick = event.tick

    -- Compact each surface
    for surface_index, surface_data in pairs(storage.ghost_combinator) do
        local removed_count, old_max_slot, new_max_slot = gc_storage.compact_slots(surface_index, current_tick)

        -- If slots were removed, clear orphaned slots from all combinators
        if removed_count > 0 and old_max_slot > new_max_slot then
            for unit_number, combinator in pairs(surface_data.combinators) do
                if combinator.valid then
                    local cb = combinator.get_control_behavior()
                    if cb and cb.valid then
                        local section = cb.get_section(1)
                        if section then
                            -- Clear slots from new_max+1 to old_max
                            for slot_idx = new_max_slot + 1, old_max_slot do
                                section.clear_slot(slot_idx)
                            end
                        end
                    end
                else
                    -- Clean up invalid combinator reference
                    surface_data.combinators[unit_number] = nil
                end
            end
        end
    end
end

-----------------------------------------------------------
-- BLUEPRINT AND COPY-PASTE HANDLERS
-- Ghost combinator is read-only, so these are mostly no-ops
-----------------------------------------------------------

--- Handle player setup blueprint event
--- Ghost combinator has no configuration to save to blueprints
--- @param event EventData.on_player_setup_blueprint
function control.on_player_setup_blueprint(event)
    -- Ghost combinator is read-only, no config to save
    -- This is a no-op, but we keep it for consistency
end

--- Handle entity settings pasted event
--- Ghost combinator has no settings to paste
--- @param event EventData.on_entity_settings_pasted
function control.on_entity_settings_pasted(event)
    -- Ghost combinator is read-only, no settings to paste
    -- This is a no-op, but we keep it for consistency
end

--- Handle entity cloned event
--- Ghost combinator has no configuration to clone
--- @param event EventData.on_entity_cloned
function control.on_entity_cloned(event)
    -- Ghost combinator is read-only, no config to clone
    -- This is a no-op, but we keep it for consistency
end

-----------------------------------------------------------
-- MODULE EXPORTS
-----------------------------------------------------------

return control
