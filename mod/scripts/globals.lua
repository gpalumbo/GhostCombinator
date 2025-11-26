-- Ghost Combinator Mod - Global Storage Management
-- Central aggregator for all entity storage modules and shared state
-- CRITICAL: Uses Factorio 2.0 APIs - storage NOT global!
--
-- This module:
-- 1. Aggregates entity-specific storage modules (ghost_combinator/storage.lua, etc.)
-- 2. Manages shared state (player GUI states)
-- 3. Provides unified init_storage() for all storage tables

local entity_lib = require("lib.entity_lib")

-- Import entity-specific storage modules
local gc_storage = require("scripts.ghost_combinator.storage")

local globals = {}

--------------------------------------------------------------------------------
-- Storage Initialization
--------------------------------------------------------------------------------

--- Initialize all storage tables on mod init/configuration change
--- Called during on_init and on_configuration_changed events
function globals.init_storage()
    -- Initialize entity-specific storage
    gc_storage.init_storage()

    -- Initialize shared storage (minimal - used only for GUI compatibility)
    storage.player_gui_states = storage.player_gui_states or {}
end

--------------------------------------------------------------------------------
-- Player GUI State Management (shared across all entities)
--------------------------------------------------------------------------------

--- Set player GUI state (which entity is open and what type)
--- Stores entity reference, not unit_number, for validity checking
--- @param player_index number The player index
--- @param entity LuaEntity The entity being viewed
--- @param gui_type string The type of GUI opened (e.g., "ghost_combinator")
function globals.set_player_gui_entity(player_index, entity, gui_type)
    if not player_index then
        game.print("[ERROR] set_player_gui_entity called with nil player_index")
        return
    end

    if not storage.player_gui_states then
        globals.init_storage()
    end

    if not entity or not entity.valid then
        -- Clear the GUI state
        storage.player_gui_states[player_index] = nil
        return
    end

    local is_ghost = entity_lib.is_ghost(entity)

    storage.player_gui_states[player_index] = {
        open_entity = entity,  -- Store entity reference, not unit_number
        gui_type = gui_type or "unknown",
        is_ghost = is_ghost
    }
end

--- Get player GUI state
--- Returns the current GUI state, validating entity is still valid
--- @param player_index number The player index
--- @return table|nil GUI state with open_entity, gui_type, and is_ghost fields
function globals.get_player_gui_state(player_index)
    if not player_index then
        return nil
    end

    if not storage.player_gui_states then
        return nil
    end

    local state = storage.player_gui_states[player_index]
    if not state then
        return nil
    end

    -- Validate entity is still valid
    if not state.open_entity or not state.open_entity.valid then
        -- Entity became invalid, clear state
        storage.player_gui_states[player_index] = nil
        return nil
    end

    return state
end

--- Clear player GUI state
--- Called when GUI is closed
--- @param player_index number The player index
function globals.clear_player_gui_entity(player_index)
    if not player_index then
        return
    end

    if not storage.player_gui_states then
        return
    end

    storage.player_gui_states[player_index] = nil
end

--- Clean up all player GUI states referencing a specific entity
--- Called when an entity is destroyed
--- @param entity LuaEntity The entity being destroyed
--- @param gui_frame_name string|nil Optional GUI frame name to destroy (defaults to checking common names)
function globals.cleanup_player_gui_states_for_entity(entity, gui_frame_name)
    if not entity then
        return
    end

    if not storage.player_gui_states then
        return
    end

    -- Check all player GUI states
    for player_index, state in pairs(storage.player_gui_states) do
        if state.open_entity == entity then
            storage.player_gui_states[player_index] = nil

            -- Also close the player's GUI if still open
            local player = game.get_player(player_index)
            if player and player.valid then
                -- Try the provided frame name, or fall back to known frame names
                local frame_names = gui_frame_name and {gui_frame_name} or {
                    "ghost_combinator_gui"
                    -- Add other GUI frame names here as needed
                }

                for _, frame_name in ipairs(frame_names) do
                    local frame = player.gui.screen[frame_name]
                    if frame and frame.valid then
                        frame.destroy()
                        break
                    end
                end
            end
        end
    end
end

return globals
