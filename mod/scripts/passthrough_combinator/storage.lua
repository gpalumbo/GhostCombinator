-- Mission Control Mod - Passthrough Combinator Storage
-- Entity-specific storage management for passthrough combinators
-- CRITICAL: Uses Factorio 2.0 APIs - storage NOT global!
--
-- Storage Structure:
-- storage.passthrough_combinators = {
--     [unit_number] = {
--         entity = entity_reference,
--         configured_surfaces = {},  -- Set of surface indices
--     }
-- }

local entity_lib = require("lib.entity_lib")

local pc_storage = {}

-- Entity name constant
local PASSTHROUGH_COMBINATOR = "passthrough-combinator"

--------------------------------------------------------------------------------
-- Format Conversion (Internal Set ↔ Tag Array)
--------------------------------------------------------------------------------
-- INTERNAL FORMAT (storage): {configured_surfaces = {[8]=true, [9]=true}}
-- TAG FORMAT (property tree): {configured_surfaces = {8, 9}}

--- Convert internal config format to tag-compatible format
--- Converts sets to arrays since tags don't support keyed tables
--- @param config table Internal config with set-based configured_surfaces
--- @return table Tag-compatible config with array-based configured_surfaces
local function convert_config_to_tags(config)
    if not config then
        return { configured_surfaces = {} }
    end

    local tag_config = {
        configured_surfaces = {}
    }

    -- Convert set {[index]=true} to array {index, ...}
    if config.configured_surfaces then
        for surface_index, is_configured in pairs(config.configured_surfaces) do
            if is_configured then
                table.insert(tag_config.configured_surfaces, surface_index)
            end
        end
    end

    return tag_config
end

--- Convert tag format to internal config format
--- Converts arrays to sets for faster lookups
--- @param tag_config table Tag config with array-based configured_surfaces
--- @return table Internal config with set-based configured_surfaces
local function convert_config_from_tags(tag_config)
    if not tag_config then
        return { configured_surfaces = {} }
    end

    local config = {
        configured_surfaces = {}
    }

    -- Convert array {index, ...} to set {[index]=true}
    if tag_config.configured_surfaces then
        for _, surface_index in ipairs(tag_config.configured_surfaces) do
            config.configured_surfaces[surface_index] = true
        end
    end

    return config
end

--------------------------------------------------------------------------------
-- Storage Initialization
--------------------------------------------------------------------------------

--- Initialize passthrough combinator storage table
--- Called during on_init and on_configuration_changed events
function pc_storage.init_storage()
    storage.passthrough_combinators = storage.passthrough_combinators or {}
end

--------------------------------------------------------------------------------
-- Entity Registration
--------------------------------------------------------------------------------

--- Register a passthrough combinator entity in storage
--- CRITICAL: Only register real entities, NEVER ghosts!
--- @param entity LuaEntity The combinator entity to register
--- @return table|nil The created data table, or nil if registration failed
function pc_storage.register(entity)
    if not entity or not entity.valid then
        game.print("[ERROR] Attempted to register invalid passthrough combinator")
        return nil
    end

    if entity_lib.is_ghost(entity) then
        game.print("[ERROR] Attempted to register ghost entity - ghosts use entity.tags, not storage!")
        return nil
    end

    if not entity_lib.is_type(entity, PASSTHROUGH_COMBINATOR) then
        game.print("[ERROR] Attempted to register non-passthrough-combinator entity: " .. entity.name)
        return nil
    end

    local unit_number = entity.unit_number
    if not unit_number then
        game.print("[ERROR] Passthrough combinator has no unit_number")
        return nil
    end

    -- Initialize storage if needed
    if not storage.passthrough_combinators then
        pc_storage.init_storage()
    end

    -- Create data structure
    local data = {
        entity = entity,
        configured_surfaces = {}  -- Empty set initially
    }

    storage.passthrough_combinators[unit_number] = data
    return data
end

--- Unregister a passthrough combinator from storage
--- Called when entity is destroyed/removed
--- @param unit_number number The unit_number of the entity to unregister
function pc_storage.unregister(unit_number)
    if not unit_number then
        game.print("[ERROR] Attempted to unregister passthrough combinator with nil unit_number")
        return
    end

    if not storage.passthrough_combinators then
        return -- Nothing to unregister
    end

    storage.passthrough_combinators[unit_number] = nil
end

--------------------------------------------------------------------------------
-- Data Access Functions
--------------------------------------------------------------------------------

--- Get passthrough combinator data from storage or ghost tags
--- Handles both entity references and unit_numbers
--- CRITICAL: Ghosts read from entity.tags, real entities from storage
--- @param entity_or_unit_number LuaEntity|number Entity reference or unit_number
--- @return table|nil The entity data, or nil if not found
function pc_storage.get_data(entity_or_unit_number)
    -- Handle nil input
    if not entity_or_unit_number then
        return nil
    end

    -- Determine if we have an entity or a unit_number
    local entity = nil
    local unit_number = nil

    if type(entity_or_unit_number) == "number" then
        unit_number = entity_or_unit_number
    else
        entity = entity_or_unit_number
        if not entity.valid then
            return nil
        end
        unit_number = entity.unit_number
    end

    -- Handle ghost entities - read from tags
    if entity and entity_lib.is_ghost(entity) then
        return pc_storage.get_ghost_config(entity)
    end

    -- Handle real entities - read from storage
    if not storage.passthrough_combinators then
        return nil
    end

    return storage.passthrough_combinators[unit_number]
end

--- Update passthrough combinator data (works for both ghosts and real entities)
--- For ghosts: updates entity.tags
--- For real entities: updates storage entry
--- @param entity LuaEntity The entity to update (can be ghost or real)
--- @param data table The data to set/merge
function pc_storage.update_data(entity, data)
    if not entity or not entity.valid then
        game.print("[ERROR] Attempted to update invalid entity")
        return
    end

    if not data then
        game.print("[ERROR] Attempted to update entity with nil data")
        return
    end

    -- Handle ghost entities - merge with existing config
    if entity_lib.is_ghost(entity) then
        -- Get existing config
        local existing_config = pc_storage.get_ghost_config(entity) or {}

        -- Merge new data into existing config
        for key, value in pairs(data) do
            existing_config[key] = value
        end

        -- Save merged config back to tags
        pc_storage.save_ghost_config(entity, existing_config)
        return
    end

    -- Handle real entities
    local unit_number = entity.unit_number
    if not unit_number then
        game.print("[ERROR] Entity has no unit_number")
        return
    end

    if not storage.passthrough_combinators then
        pc_storage.init_storage()
    end

    -- Get existing data or create new entry
    local existing_data = storage.passthrough_combinators[unit_number]
    if not existing_data then
        existing_data = pc_storage.register(entity)
    end

    -- Merge data (preserve entity reference)
    if existing_data then
        for key, value in pairs(data) do
            if key ~= "entity" then  -- Never overwrite entity reference
                existing_data[key] = value
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Blueprint/Copy-Paste Support
--------------------------------------------------------------------------------

--- Serialize passthrough combinator configuration for blueprints
--- Converts storage data to a blueprint-compatible table
--- Works for both ghost and real entities
--- @param entity LuaEntity The entity to serialize (can be ghost or real)
--- @return table|nil Blueprint-compatible configuration table
function pc_storage.serialize_config(entity)
    if not entity or not entity.valid then
        return nil
    end

    local data = pc_storage.get_data(entity)
    if not data then
        return nil
    end

    -- Create serializable configuration
    local config = {
        configured_surfaces = {}
    }

    -- Convert configured_surfaces set to array for serialization
    if data.configured_surfaces then
        for surface_index, _ in pairs(data.configured_surfaces) do
            table.insert(config.configured_surfaces, surface_index)
        end
    end

    return config
end

--- Restore passthrough combinator configuration from blueprint
--- Applies configuration to a newly built entity
--- @param entity LuaEntity The entity to configure
--- @param config table Blueprint configuration table
function pc_storage.restore_config(entity, config)
    if not entity or not entity.valid then
        game.print("[ERROR] Attempted to restore config to invalid entity")
        return
    end

    if not config then
        return -- No config to restore
    end

    -- Handle ghost entities
    if entity_lib.is_ghost(entity) then
        pc_storage.save_ghost_config(entity, config)
        return
    end

    -- Handle real entities
    local unit_number = entity.unit_number
    if not unit_number then
        return
    end

    -- Get or create data entry
    local data = storage.passthrough_combinators[unit_number]
    if not data then
        data = pc_storage.register(entity)
    end

    if not data then
        return
    end

    -- Restore configured_surfaces (convert array back to set)
    if config.configured_surfaces then
        data.configured_surfaces = {}
        for _, surface_index in ipairs(config.configured_surfaces) do
            data.configured_surfaces[surface_index] = true
        end
    end
end

--------------------------------------------------------------------------------
-- Ghost Entity Support
--------------------------------------------------------------------------------

--- Get configuration from ghost entity tags
--- Ghosts store their configuration in entity.tags, NOT in storage
--- Tags use array format, converted to internal set format
--- @param ghost_entity LuaEntity The ghost entity
--- @return table|nil Configuration data (in internal set format)
function pc_storage.get_ghost_config(ghost_entity)
    if not ghost_entity or not ghost_entity.valid then
        return nil
    end

    if not entity_lib.is_ghost(ghost_entity) then
        game.print("[ERROR] get_ghost_config called on non-ghost entity")
        return nil
    end

    if not entity_lib.is_type(ghost_entity, PASSTHROUGH_COMBINATOR) then
        return nil
    end

    local tags = ghost_entity.tags
    if not tags or not tags.passthrough_combinator_config then
        -- Return default empty config (internal format)
        return {
            configured_surfaces = {}
        }
    end

    -- Convert from tag format (array) to internal format (set)
    return convert_config_from_tags(tags.passthrough_combinator_config)
end

--- Save configuration to ghost entity tags
--- CRITICAL: Use complete table replacement pattern for tags
--- Converts internal set format to tag-compatible array format
--- @param ghost_entity LuaEntity The ghost entity
--- @param config table Configuration to save (in internal set format)
function pc_storage.save_ghost_config(ghost_entity, config)
    if not ghost_entity or not ghost_entity.valid then
        game.print("[ERROR] Attempted to save config to invalid ghost")
        return
    end

    if not entity_lib.is_ghost(ghost_entity) then
        game.print("[ERROR] save_ghost_config called on non-ghost entity")
        return
    end

    if not entity_lib.is_type(ghost_entity, PASSTHROUGH_COMBINATOR) then
        return
    end

    -- Convert internal format (set) to tag format (array)
    local tag_config = convert_config_to_tags(config)

    -- Use complete table replacement pattern for ghost tags
    local new_tags = ghost_entity.tags or {}
    new_tags.passthrough_combinator_config = tag_config
    ghost_entity.tags = new_tags
end

--------------------------------------------------------------------------------
-- Cleanup Functions
--------------------------------------------------------------------------------

--- Validate and clean up invalid entities from storage
--- Should be called periodically or on load to ensure storage integrity
function pc_storage.validate_and_cleanup()
    if not storage.passthrough_combinators then
        return
    end

    local invalid_units = {}

    -- Find invalid entities
    for unit_number, data in pairs(storage.passthrough_combinators) do
        if not data.entity or not data.entity.valid then
            table.insert(invalid_units, unit_number)
        end
    end

    -- Remove invalid entries
    for _, unit_number in ipairs(invalid_units) do
        storage.passthrough_combinators[unit_number] = nil
    end

    if #invalid_units > 0 then
        game.print("[INFO] Cleaned up " .. #invalid_units .. " invalid passthrough combinator entries")
    end
end

return pc_storage
