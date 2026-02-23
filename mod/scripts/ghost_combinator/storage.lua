-- Ghost Combinator - Storage Module
-- Manages ghost tracking data per surface and combinator registration
-- CRITICAL: Uses Factorio 2.0 APIs - storage NOT global!
--
-- Storage Structure:
-- storage.ghost_combinator = {
--     [surface_index] = {
--         combinators = { [unit_number] = entity, ... },
--         ghosts = {
--             ["item_name:quality"] = {    -- Key is item_name:quality (not entity_name)
--                 count = N,
--                 slot = M,
--                 changed = true/false,
--                 item_name = "item_name",  -- Item name for signal output (looked up from entity)
--                 quality = "quality_name"  -- Quality for signal
--             },
--         },
--         any_changes = false,
--         next_slot = 1,
--         last_compact_tick = 0,  -- Track when we last compacted slots
--         slot_high_water = 0    -- Highest slot ever assigned (for resync orphan clearing)
--     }
-- }
-- NOTE: Entity names don't always match item names (e.g., "straight-rail" -> "rail")
-- Multiple entity types may map to the same item, so they share a slot.
--
-- storage.ghost_registrations = {
--     [registration_number] = {surface_index, ghost_name, quality_name}
-- }
-- Used to track ghosts registered with register_on_object_destroyed

local circuit_utils = require("lib.circuit_utils")
local signal_utils = require("lib.signal_utils")

local gc_storage = {}

-- Entity name constant
local GHOST_COMBINATOR = "ghost-combinator"

--------------------------------------------------------------------------------
-- Storage Initialization
--------------------------------------------------------------------------------

--- Initialize ghost combinator storage table
--- Called during on_init and on_configuration_changed events
function gc_storage.init_storage()
    storage.ghost_combinator = storage.ghost_combinator or {}
    storage.ghost_registrations = storage.ghost_registrations or {}
end

--------------------------------------------------------------------------------
-- Surface Data Management
--------------------------------------------------------------------------------

--- Get or create surface data table
--- @param surface_index number The surface index
--- @return table Surface data table
function gc_storage.get_surface_data(surface_index)
    if not surface_index then
        game.print("[ERROR] get_surface_data called with nil surface_index")
        return nil
    end

    if not storage.ghost_combinator then
        gc_storage.init_storage()
    end

    -- Create surface data if it doesn't exist
    if not storage.ghost_combinator[surface_index] then
        storage.ghost_combinator[surface_index] = {
            combinators = {},
            ghosts = {},
            any_changes = false,
            next_slot = 1,
            last_compact_tick = 0,
            slot_high_water = 0  -- Highest slot ever assigned (for resync orphan clearing)
        }
    end

    return storage.ghost_combinator[surface_index]
end

--------------------------------------------------------------------------------
-- Combinator Registration
--------------------------------------------------------------------------------

--- Register a ghost combinator entity in storage
--- CRITICAL: Only register real entities, NEVER ghosts!
--- @param entity LuaEntity The combinator entity to register
--- @return boolean True if registration succeeded
function gc_storage.register_combinator(entity)
    if not entity or not entity.valid then
        game.print("[ERROR] Attempted to register invalid ghost combinator")
        return false
    end

    if entity.type == "entity-ghost" then
        game.print("[ERROR] Attempted to register ghost entity - only real entities allowed!")
        return false
    end

    if entity.name ~= GHOST_COMBINATOR then
        game.print("[ERROR] Attempted to register non-ghost-combinator entity: " .. entity.name)
        return false
    end

    local unit_number = entity.unit_number
    if not unit_number then
        game.print("[ERROR] Ghost combinator has no unit_number")
        return false
    end

    local surface_index = entity.surface.index
    local surface_data = gc_storage.get_surface_data(surface_index)

    if not surface_data then
        return false
    end

    -- Register the combinator
    surface_data.combinators[unit_number] = entity

    -- Mark that we need to update this combinator with current ghost data
    surface_data.any_changes = true

    return true
end

--- Unregister a ghost combinator from storage
--- Called when entity is destroyed/removed
--- @param unit_number number The unit_number of the entity to unregister
--- @param surface_index number The surface index
function gc_storage.unregister_combinator(unit_number, surface_index)
    if not unit_number or not surface_index then
        game.print("[ERROR] Attempted to unregister combinator with nil unit_number or surface_index")
        return
    end

    if not storage.ghost_combinator then
        return
    end

    local surface_data = storage.ghost_combinator[surface_index]
    if not surface_data then
        return
    end

    surface_data.combinators[unit_number] = nil
end

--------------------------------------------------------------------------------
-- Ghost Tracking Functions
--------------------------------------------------------------------------------

--- Increment ghost count for a specific ghost type and quality
--- CRITICAL: This is called for EVERY ghost built - must be FAST!
--- @param surface_index number The surface index
--- @param ghost_name string The ghost entity name
--- @param quality_name string The quality name (e.g., "normal", "uncommon", "rare", "epic", "legendary")
function gc_storage.increment_ghost(surface_index, ghost_name, quality_name)
    if not surface_index or not ghost_name then
        return
    end

    quality_name = quality_name or "normal"

    local surface_data = gc_storage.get_surface_data(surface_index)
    if not surface_data then
        return
    end

    -- Look up the item name that places this entity
    -- Entity names don't always match item names (e.g., "straight-rail" -> "rail")
    -- Multiple entity types may map to the same item (e.g., straight-rail, curved-rail -> rail)
    local item_name = signal_utils.get_item_name_for_entity(ghost_name)

    -- Use "item_name:quality" as key so entities sharing an item are combined
    local ghost_key = item_name .. ":" .. quality_name
    local ghost_entry = surface_data.ghosts[ghost_key]

    if ghost_entry then
        -- Increment existing ghost
        ghost_entry.count = ghost_entry.count + 1
        ghost_entry.changed = true
    else
        -- New ghost type - assign next available slot
        local slot = surface_data.next_slot
        surface_data.ghosts[ghost_key] = {
            count = 1,
            slot = slot,
            changed = true,
            item_name = item_name,  -- Store item name for signal output
            quality = quality_name  -- Store quality for signal
        }
        surface_data.next_slot = slot + 1

        -- Track highest slot ever assigned (for resync orphan clearing)
        if slot > (surface_data.slot_high_water or 0) then
            surface_data.slot_high_water = slot
        end
    end

    surface_data.any_changes = true
end

--- Decrement ghost count for a specific ghost type and quality
--- CRITICAL: This is called for EVERY ghost removed - must be FAST!
--- @param surface_index number The surface index
--- @param ghost_name string The ghost entity name
--- @param quality_name string The quality name
function gc_storage.decrement_ghost(surface_index, ghost_name, quality_name)
    if not surface_index or not ghost_name then
        return
    end

    quality_name = quality_name or "normal"

    local surface_data = gc_storage.get_surface_data(surface_index)
    if not surface_data then
        return
    end

    -- Look up the item name that places this entity (must match increment_ghost)
    local item_name = signal_utils.get_item_name_for_entity(ghost_name)

    -- Use "item_name:quality" as key (must match increment_ghost)
    local ghost_key = item_name .. ":" .. quality_name
    local ghost_entry = surface_data.ghosts[ghost_key]

    if ghost_entry then
        ghost_entry.count = math.max(0, ghost_entry.count - 1)
        ghost_entry.changed = true
        surface_data.any_changes = true
    end
end

--- Get all ghost counts for a surface (for GUI display)
--- @param surface_index number The surface index
--- @return table|nil Table of ghost_name -> {count, slot} or nil
function gc_storage.get_ghost_counts(surface_index)
    if not surface_index then
        return nil
    end

    local surface_data = storage.ghost_combinator and storage.ghost_combinator[surface_index]
    if not surface_data then
        return {}
    end

    return surface_data.ghosts
end

--- Get all combinators for a surface
--- @param surface_index number The surface index
--- @return table|nil Table of unit_number -> entity or nil
function gc_storage.get_combinators(surface_index)
    if not surface_index then
        return nil
    end

    local surface_data = storage.ghost_combinator and storage.ghost_combinator[surface_index]
    if not surface_data then
        return {}
    end

    return surface_data.combinators
end

--- Check if surface has pending changes
--- @param surface_index number The surface index
--- @return boolean True if there are pending changes
function gc_storage.has_changes(surface_index)
    if not surface_index then
        return false
    end

    local surface_data = storage.ghost_combinator and storage.ghost_combinator[surface_index]
    if not surface_data then
        return false
    end

    return surface_data.any_changes
end

--- Clear the any_changes flag for a surface
--- @param surface_index number The surface index
function gc_storage.clear_changes_flag(surface_index)
    if not surface_index then
        return
    end

    local surface_data = storage.ghost_combinator and storage.ghost_combinator[surface_index]
    if surface_data then
        surface_data.any_changes = false
    end
end

--- Clear the changed flag for a specific ghost entry
--- @param surface_index number The surface index
--- @param ghost_key string The ghost key ("entity_name:quality")
function gc_storage.clear_ghost_changed(surface_index, ghost_key)
    if not surface_index or not ghost_key then
        return
    end

    local surface_data = storage.ghost_combinator and storage.ghost_combinator[surface_index]
    if not surface_data then
        return
    end

    local ghost_entry = surface_data.ghosts[ghost_key]
    if ghost_entry then
        ghost_entry.changed = false
    end
end

--- Reset the slot high-water mark after a full resync
--- Called after full_resync_surface writes all slots and clears orphans
--- @param surface_index number The surface index
function gc_storage.reset_slot_high_water(surface_index)
    if not surface_index then
        return
    end

    local surface_data = storage.ghost_combinator and storage.ghost_combinator[surface_index]
    if surface_data then
        surface_data.slot_high_water = math.max(0, (surface_data.next_slot or 1) - 1)
    end
end

--------------------------------------------------------------------------------
-- Slot Compaction
--------------------------------------------------------------------------------

--- Compact ghost slots - remove zero-count entries and reassign slots
--- This is called periodically to prevent slot fragmentation
--- @param surface_index number The surface index
--- @param current_tick number The current game tick
--- @return number removed_count Number of slots removed
--- @return number old_max_slot The maximum slot index before compaction (for clearing orphaned slots)
--- @return number new_max_slot The maximum slot index after compaction
function gc_storage.compact_slots(surface_index, current_tick)
    if not surface_index then
        return 0, 0, 0
    end

    local surface_data = storage.ghost_combinator and storage.ghost_combinator[surface_index]
    if not surface_data then
        return 0, 0, 0
    end

    surface_data.last_compact_tick = current_tick

    -- Track the old maximum slot for clearing orphaned combinator slots
    local old_max_slot = surface_data.next_slot - 1

    -- Find and remove zero-count entries
    local removed_count = 0
    local ghosts_to_remove = {}

    for ghost_name, ghost_entry in pairs(surface_data.ghosts) do
        if ghost_entry.count <= 0 then
            table.insert(ghosts_to_remove, ghost_name)
        end
    end

    -- Remove zero-count entries
    for _, ghost_name in ipairs(ghosts_to_remove) do
        surface_data.ghosts[ghost_name] = nil
        removed_count = removed_count + 1
    end

    -- Reassign slots to eliminate gaps
    if removed_count > 0 then
        local new_slot = 1
        for ghost_name, ghost_entry in pairs(surface_data.ghosts) do
            if ghost_entry.slot ~= new_slot then
                ghost_entry.slot = new_slot
                ghost_entry.changed = true
            end
            new_slot = new_slot + 1
        end

        surface_data.next_slot = new_slot
        surface_data.any_changes = true
    end

    return removed_count, old_max_slot, surface_data.next_slot - 1
end

--------------------------------------------------------------------------------
-- Cleanup Functions
--------------------------------------------------------------------------------

--- Validate and clean up invalid combinators from storage
--- Should be called periodically or on load to ensure storage integrity
--- @param surface_index number|nil Optional surface index to clean (cleans all if nil)
function gc_storage.validate_and_cleanup(surface_index)
    if not storage.ghost_combinator then
        return
    end

    local surfaces_to_check = {}

    if surface_index then
        -- Clean specific surface
        table.insert(surfaces_to_check, surface_index)
    else
        -- Clean all surfaces
        for idx, _ in pairs(storage.ghost_combinator) do
            table.insert(surfaces_to_check, idx)
        end
    end

    for _, idx in ipairs(surfaces_to_check) do
        local surface_data = storage.ghost_combinator[idx]
        if surface_data then
            local invalid_units = {}

            -- Find invalid combinators
            for unit_number, entity in pairs(surface_data.combinators) do
                if not entity or not entity.valid then
                    table.insert(invalid_units, unit_number)
                end
            end

            -- Remove invalid entries
            for _, unit_number in ipairs(invalid_units) do
                surface_data.combinators[unit_number] = nil
            end

        end
    end
end

--------------------------------------------------------------------------------
-- Ghost Registration (for on_object_destroyed tracking)
--------------------------------------------------------------------------------

--- Register a ghost entity for destruction tracking
--- Called when a ghost is built to track when it's destroyed/revived
--- @param registration_number uint64 The registration number from script.register_on_object_destroyed
--- @param surface_index number The surface index
--- @param ghost_name string The ghost entity name
--- @param quality_name string The quality name
function gc_storage.register_ghost_entity(registration_number, surface_index, ghost_name, quality_name)
    if not registration_number then
        return
    end

    if not storage.ghost_registrations then
        storage.ghost_registrations = {}
    end

    storage.ghost_registrations[registration_number] = {
        surface = surface_index,
        name = ghost_name,
        quality = quality_name or "normal"
    }
end

--- Get ghost registration info by registration number
--- @param registration_number uint64 The registration number
--- @return table|nil Ghost info {surface, name, quality} or nil if not found
function gc_storage.get_ghost_registration(registration_number)
    if not registration_number or not storage.ghost_registrations then
        return nil
    end

    return storage.ghost_registrations[registration_number]
end

--- Unregister a ghost entity (after destruction event handled)
--- @param registration_number uint64 The registration number
function gc_storage.unregister_ghost_entity(registration_number)
    if not registration_number or not storage.ghost_registrations then
        return
    end

    storage.ghost_registrations[registration_number] = nil
end

return gc_storage
