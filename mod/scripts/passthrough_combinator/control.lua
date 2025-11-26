-- Passthrough Combinator - Control Module
-- Handles all entity lifecycle events for the passthrough combinator
-- CRITICAL: Uses Factorio 2.0 APIs only!

local globals = require("scripts.globals")
local entity_lib = require("lib.entity_lib")
local pc_storage = require("scripts.passthrough_combinator.storage")

local control = {}

-- Entity name constant
local PASSTHROUGH_COMBINATOR = "passthrough-combinator"

-----------------------------------------------------------
-- BUILD EVENT HANDLERS
-- These handle entity creation from various sources
-----------------------------------------------------------

--- Shared handler for all entity build events
--- Handles both real entities and ghosts, with blueprint tag support
--- @param event EventData Event data containing entity and optional tags
function control.on_built(event)
    local entity = event.entity
    local tags = event.tags

    if not entity or not entity.valid then return end

    -- Skip ghosts - they use tags not storage
    if entity_lib.is_ghost(entity) then
        if entity_lib.is_type(entity, PASSTHROUGH_COMBINATOR) then
            if tags and tags.passthrough_combinator_config then
                pc_storage.save_ghost_config(entity, tags.passthrough_combinator_config)
            end
            log("[passthrough_combinator] Ghost placed with blueprint tags")
        end
        return
    end

    -- Only handle our entity
    if entity.name ~= PASSTHROUGH_COMBINATOR then return end

    -- Register the entity in storage
    local state = pc_storage.register(entity)
    if not state then
        log("[passthrough_combinator] ERROR: Failed to register entity")
        return
    end

    -- Restore config from blueprint tags if present
    if tags and tags.passthrough_combinator_config then
        pc_storage.restore_config(entity, tags.passthrough_combinator_config)
        log("[passthrough_combinator] Entity built with blueprint config: " .. entity.unit_number)
    else
        log("[passthrough_combinator] Entity built: " .. entity.unit_number)
    end
end

--- Handle player-built entity
--- Called when a player manually places an entity
--- @param event EventData.on_built_entity
function control.on_built_entity(event)
    control.on_built(event)
end

--- Handle robot-built entity
--- Called when a construction robot builds an entity
--- @param event EventData.on_robot_built_entity
function control.on_robot_built_entity(event)
    control.on_built(event)
end

--- Handle space platform built entity
--- Called when a space platform builds an entity
--- @param event EventData.on_space_platform_built_entity
function control.on_space_platform_built_entity(event)
    control.on_built(event)
end

--- Handle script-raised built event
--- Called when another mod creates an entity via script and raises the event
--- @param event EventData.script_raised_built
function control.script_raised_built(event)
    control.on_built(event)
end

--- Handle script-raised revive event
--- Called when a ghost is revived via script
--- @param event EventData.script_raised_revive
function control.script_raised_revive(event)
    control.on_built(event)
end

-----------------------------------------------------------
-- DESTROY EVENT HANDLERS
-- These handle entity removal from various sources
-----------------------------------------------------------

--- Shared handler for all entity removal events
--- Handles cleanup of storage and player GUIs
--- @param event EventData Event data containing entity
function control.on_removed(event)
    local entity = event.entity
    if not entity or not entity.valid then return end

    if not entity_lib.is_type(entity, PASSTHROUGH_COMBINATOR) then
        return
    end

    -- Handle ghost destruction
    if entity_lib.is_ghost(entity) then
        log("[passthrough_combinator] Ghost destroyed")
        return
    end


    local unit_number = entity.unit_number
    if not unit_number then return end

    -- Close any open GUIs for this entity
    -- This will also close the GUI for all players viewing it
    globals.cleanup_player_gui_states_for_entity(entity)

    -- Unregister from storage
    pc_storage.unregister(unit_number)

    log("[passthrough_combinator] Entity removed: " .. unit_number)
end

--- Handle player-mined entity
--- Called when a player manually mines an entity
--- @param event EventData.on_player_mined_entity
function control.on_player_mined_entity(event)
    control.on_removed(event)
end

--- Handle robot-mined entity
--- Called when a deconstruction robot mines an entity
--- @param event EventData.on_robot_mined_entity
function control.on_robot_mined_entity(event)
    control.on_removed(event)
end

--- Handle space platform mined entity
--- Called when a space platform mines an entity
--- @param event EventData.on_space_platform_mined_entity
function control.on_space_platform_mined_entity(event)
    control.on_removed(event)
end

--- Handle entity died event
--- Called when an entity is destroyed by damage
--- @param event EventData.on_entity_died
function control.on_entity_died(event)
    control.on_removed(event)
end

--- Handle script-raised destroy event
--- Called when another mod destroys an entity via script and raises the event
--- @param event EventData.script_raised_destroy
function control.script_raised_destroy(event)
    control.on_removed(event)
end

-----------------------------------------------------------
-- BLUEPRINT AND COPY-PASTE HANDLERS
-- These handle configuration transfer between entities
-----------------------------------------------------------

--- Handle entity settings pasted event
--- Called when player uses copy-paste (Shift+Right Click, Shift+Left Click)
--- @param event EventData.on_entity_settings_pasted
function control.on_entity_settings_pasted(event)
    local source = event.source
    local destination = event.destination

    if not source or not source.valid then return end
    if not destination or not destination.valid then return end

    -- Check if source is our entity
    if not entity_lib.is_type(source, PASSTHROUGH_COMBINATOR) then return end

    -- Check if destination is our entity (can be real entity or ghost)
    if not entity_lib.is_type(destination, PASSTHROUGH_COMBINATOR) then return end

    -- Get source configuration (handles both ghosts and real entities)
    local source_config = pc_storage.serialize_config(source)
    if not source_config then
        log("[passthrough_combinator] WARNING: Could not serialize source config")
        return
    end

    -- Apply to destination (handles both real entities and ghosts)
    pc_storage.restore_config(destination, source_config)

    log("[passthrough_combinator] Settings pasted to entity")
end

--- Handle entity cloned event
--- Called when entities are cloned via editor or other mods
--- @param event EventData.on_entity_cloned
function control.on_entity_cloned(event)
    local source = event.source
    local destination = event.destination

    if not source or not source.valid then return end
    if not destination or not destination.valid then return end

    -- Check if source is our entity
    if not entity_lib.is_type(source, PASSTHROUGH_COMBINATOR) then return end

    -- Check if destination is our entity (can be real entity or ghost)
    if not entity_lib.is_type(destination, PASSTHROUGH_COMBINATOR) then return end

    -- Get source configuration (handles both ghosts and real entities)
    local source_config = pc_storage.serialize_config(source)

    if not source_config then
        log("[passthrough_combinator] WARNING: Could not get source config for cloning")
        return
    end

    -- Apply to destination (handles both real entities and ghosts)
    pc_storage.restore_config(destination, source_config)

    log("[passthrough_combinator] Entity cloned")
end

--- Handle player setup blueprint event
--- Called when player creates a blueprint - we save config to blueprint tags
--- @param event EventData.on_player_setup_blueprint
function control.on_player_setup_blueprint(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    -- Get the blueprint item stack
    local bp = player.blueprint_to_setup
    if not bp or not bp.valid_for_read then
        bp = player.cursor_stack
    end

    if not bp or not bp.valid_for_read then return end

    -- Get blueprint entities
    local entities = bp.get_blueprint_entities()
    if not entities then return end

    -- Get the entity mapping from the event
    -- This maps blueprint entity index to real world entities
    local mapping = event.mapping
    if not mapping then return end

    -- Process each entity in the blueprint
    for bp_index, bp_entity in ipairs(entities) do
        if bp_entity.name == PASSTHROUGH_COMBINATOR then
            -- Get the real entity from the mapping
            -- mapping.get() with no parameters returns the full table
            local mapped_entities = mapping.get()
            local real_entity = mapped_entities[bp_index]

            if real_entity and real_entity.valid then
                local config = pc_storage.serialize_config(real_entity)

                if config then
                    -- Set the tags on the blueprint entity
                    bp.set_blueprint_entity_tags(bp_index, {passthrough_combinator_config = config})
                    log("[passthrough_combinator] Added config to blueprint entity " .. bp_index)
                end
            end
        end
    end
end

-----------------------------------------------------------
-- WIRE CONNECTION HANDLERS (Template)
-- NOTE: Factorio 2.0 doesn't have explicit wire add/remove events
-- Wire changes are detected indirectly or via periodic checks
-----------------------------------------------------------

--- Handle wire connection changes (called from external detection)
--- This is a placeholder for when wire changes need special handling
--- @param entity LuaEntity The entity whose wires changed
function control.on_wire_changed(entity)
    if not entity or not entity.valid then return end
    if entity.name ~= PASSTHROUGH_COMBINATOR then return end

    local unit_number = entity.unit_number
    if not unit_number then return end

    -- Log wire changes for debugging
    -- Actual signal processing happens in the periodic update
    log("[passthrough_combinator] Wire configuration changed for entity: " .. unit_number)

    -- Future enhancement: Could cache wire connections here for optimization
    -- For now, signal processing in on_update will handle all wire states
end

-----------------------------------------------------------
-- PERIODIC UPDATE HANDLER
-- Processes signals for all registered combinators
-----------------------------------------------------------

--- Handle periodic signal processing updates
--- Called every N ticks to process signal passthrough
--- @param event EventData.on_nth_tick
function control.on_update(event)
    -- Get all registered combinators
    local combinators = storage.passthrough_combinators
    if not combinators then return end

    local processed = 0
    local invalid = 0

    -- Process each combinator
    for unit_number, state in pairs(combinators) do
        local entity = state.entity

        if entity and entity.valid then
            -- TODO: Implement custom signal passthrough logic here if needed
            -- For now, the arithmetic-combinator base type handles signal passthrough
            -- via its built-in control behavior (identity operation)

            -- Example of what could be done here:
            -- - Read input signals from red/green networks
            -- - Apply custom transformations
            -- - Write output signals
            -- - Update LED states based on activity

            processed = processed + 1
        else
            -- Entity became invalid, clean it up
            pc_storage.unregister(unit_number)
            invalid = invalid + 1
        end
    end

    -- Log periodic updates (only if there was activity)
    if invalid > 0 then
        log("[passthrough_combinator] Periodic update: processed=" .. processed .. ", cleaned_up=" .. invalid)
    end
end

-----------------------------------------------------------
-- MODULE EXPORTS
-----------------------------------------------------------

return control
