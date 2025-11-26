-- Mission Control Mod - Ghost Combinator GUI
-- This module handles the GUI for ghost combinator entity
-- Shows read-only ghost counts as circuit signals

local flib_gui = require("__flib__.gui")
local gui_entity = require("lib.gui.gui_entity")
local entity_lib = require("lib.entity_lib")
local globals = require("scripts.globals")
local gc_storage = require("scripts.ghost_combinator.storage")

local gui = {}

-- Entity name constant
local GHOST_COMBINATOR = "ghost-combinator"

-- GUI element names
local GUI_FRAME_NAME = "ghost_combinator_gui"

--- Get ghost data for a surface
--- @param surface_index number The surface index
--- @return table|nil Ghost data for the surface
local function get_ghost_data(surface_index)
    if not storage.ghost_combinator then
        return nil
    end

    return storage.ghost_combinator[surface_index]
end

--- Convert entity name to sprite path for GUI display
--- Tries item sprite first, then entity sprite
--- @param entity_name string The entity name
--- @return string Sprite path
local function entity_name_to_sprite(entity_name)
    -- Try item sprite first (most entities have item representations)
    local item_proto = game.item_prototypes[entity_name]
    if item_proto then
        return "item/" .. entity_name
    end

    -- Fall back to entity sprite
    local entity_proto = game.entity_prototypes[entity_name]
    if entity_proto then
        return "entity/" .. entity_name
    end

    -- Ultimate fallback - use virtual signal sprite
    return "virtual-signal/signal-unknown"
end

--- Create signal grid display for ghost counts
--- @param parent LuaGuiElement Parent element to add grid to
--- @param entity LuaEntity The ghost combinator entity
local function create_signal_grid(parent, entity)
    if not entity or not entity.valid then
        return
    end

    local surface_index = entity.surface.index
    local ghost_data = get_ghost_data(surface_index)

    -- Create scroll pane for signals
    local scroll = parent.add{
        type = "scroll-pane",
        style = "flib_naked_scroll_pane_no_padding"
    }
    scroll.style.maximal_height = 300
    scroll.style.minimal_width = 400
    scroll.style.horizontally_stretchable = true

    -- Create table grid with 10 columns (matches vanilla constant combinator)
    local signal_table = scroll.add{
        type = "table",
        name = "ghost_signal_grid",
        column_count = 10
    }
    signal_table.style.horizontal_spacing = 0
    signal_table.style.vertical_spacing = 0
    signal_table.style.cell_padding = 0

    -- Count signals added
    local signal_count = 0

    -- Add signal buttons for non-zero ghost counts
    if ghost_data and ghost_data.ghosts then
        -- Sort ghost names for consistent display
        local sorted_ghosts = {}
        for ghost_name, _ in pairs(ghost_data.ghosts) do
            table.insert(sorted_ghosts, ghost_name)
        end
        table.sort(sorted_ghosts)

        -- Add signals
        for _, ghost_name in ipairs(sorted_ghosts) do
            local ghost_info = ghost_data.ghosts[ghost_name]
            if ghost_info and ghost_info.count > 0 then
                local sprite_path = entity_name_to_sprite(ghost_name)

                signal_table.add{
                    type = "sprite-button",
                    sprite = sprite_path,
                    number = ghost_info.count,
                    style = "slot_button",
                    enabled = false, -- Read-only
                    tooltip = {"", "[entity=", ghost_name, "] ", ghost_info.count}
                }

                signal_count = signal_count + 1
            end
        end
    end

    -- If no signals, show message
    if signal_count == 0 then
        scroll.clear()
        local no_signal_label = scroll.add{
            type = "label",
            caption = {"", "No ghosts on this surface"}
        }
        no_signal_label.style.font_color = {r = 0.6, g = 0.6, b = 0.6}
        no_signal_label.style.top_margin = 8
        no_signal_label.style.left_margin = 8
    end

    return scroll
end

--- Create the GUI for a ghost combinator
--- @param player LuaPlayer
--- @param entity LuaEntity The entity to create GUI for
--- @return table|nil Table of created elements, or nil on failure
function gui.create_gui(player, entity)
    if not player or not player.valid then
        log("[ghost_combinator/gui] create_gui: invalid player")
        return nil
    end

    if not entity or not entity.valid then
        log("[ghost_combinator/gui] create_gui: invalid entity")
        return nil
    end

    -- Close existing GUI if open
    gui.close_gui(player)

    log("[ghost_combinator/gui] Creating GUI for entity")

    -- Get power status for entity
    local power_status = gui_entity.get_power_status(entity)

    -- Get surface name for display
    local surface = entity.surface
    local surface_name = surface.name
    if surface.planet then
        surface_name = surface.planet.prototype.localised_name or surface_name
    end

    -- Build GUI structure using flib
    local elems = flib_gui.add(player.gui.screen, {
        type = "frame",
        name = GUI_FRAME_NAME,
        direction = "vertical",
        tags = {
            entity_unit_number = entity.unit_number,
            entity_position = entity.position,
            entity_surface_index = entity.surface.index
        },
        children = {
            -- Titlebar
            {
                type = "flow",
                style = "flib_titlebar_flow",
                drag_target = GUI_FRAME_NAME,
                children = {
                    {
                        type = "label",
                        style = "frame_title",
                        caption = {"", "Ghost Combinator"},
                        ignored_by_interaction = true
                    },
                    { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                    {
                        type = "sprite-button",
                        name = "ghost_close_button",
                        style = "frame_action_button",
                        sprite = "utility/close",
                        hovered_sprite = "utility/close_black",
                        clicked_sprite = "utility/close_black",
                        tooltip = {"", "Close"},
                        tags = { action = "close" }
                    }
                }
            },
            -- Content frame
            {
                type = "frame",
                style = "inside_shallow_frame",
                direction = "vertical",
                children = {
                    -- Status indicator
                    {
                        type = "flow",
                        direction = "horizontal",
                        style_mods = {
                            vertical_align = "center",
                            bottom_margin = 8
                        },
                        children = {
                            {
                                type = "label",
                                caption = {"", "Status: "},
                                style_mods = {
                                    font = "default-semibold",
                                    right_margin = 4
                                }
                            },
                            {
                                type = "sprite",
                                name = "status_sprite",
                                sprite = power_status.sprite,
                                style_mods = {
                                    width = 16,
                                    height = 16,
                                    right_margin = 4
                                }
                            },
                            {
                                type = "label",
                                name = "status_label",
                                caption = power_status.text
                            }
                        }
                    },
                    -- Surface info
                    {
                        type = "flow",
                        direction = "horizontal",
                        style_mods = {
                            bottom_margin = 8
                        },
                        children = {
                            {
                                type = "label",
                                caption = {"", "Surface: "},
                                style_mods = {
                                    font = "default-semibold",
                                    right_margin = 4
                                }
                            },
                            {
                                type = "label",
                                caption = surface_name
                            }
                        }
                    },
                    -- Signal section header
                    {
                        type = "flow",
                        direction = "horizontal",
                        style_mods = {
                            vertical_align = "center",
                            bottom_margin = 4
                        },
                        children = {
                            {
                                type = "label",
                                caption = {"", "Ghost Signals:"},
                                style_mods = {
                                    font = "default-semibold"
                                }
                            },
                            { type = "empty-widget", style = "flib_horizontal_pusher" },
                            {
                                type = "sprite-button",
                                name = "refresh_button",
                                style = "tool_button",
                                sprite = "utility/refresh",
                                tooltip = {"", "Refresh"},
                                tags = { action = "refresh" }
                            }
                        }
                    },
                    -- Signal grid frame
                    {
                        type = "frame",
                        name = "signal_grid_frame",
                        direction = "vertical",
                        style = "inside_shallow_frame",
                        style_mods = {
                            padding = 8
                        }
                        -- Signal grid will be added here
                    }
                }
            }
        }
    })

    -- Add signal grid
    if elems.signal_grid_frame then
        create_signal_grid(elems.signal_grid_frame, entity)
    end

    -- Center the GUI
    if elems[GUI_FRAME_NAME] then
        elems[GUI_FRAME_NAME].force_auto_center()
    end

    -- Make the GUI respond to ESC key by setting it as the player's opened GUI
    player.opened = elems[GUI_FRAME_NAME]

    -- Store GUI state via globals
    globals.set_player_gui_entity(player.index, entity, "ghost_combinator")

    log("[ghost_combinator/gui] GUI created successfully for player " .. player.name)

    return elems
end

--- Close the GUI for a player
--- @param player LuaPlayer
function gui.close_gui(player)
    if not player or not player.valid then
        return
    end

    local frame = player.gui.screen[GUI_FRAME_NAME]
    if frame and frame.valid then
        frame.destroy()
        log("[ghost_combinator/gui] GUI closed for player " .. player.name)
    end

    -- Clear the opened GUI reference
    if player.opened == frame then
        player.opened = nil
    end

    -- Clear player GUI state via globals
    globals.clear_player_gui_entity(player.index)
end

--- Refresh the GUI display
--- @param player LuaPlayer
function gui.refresh_gui(player)
    if not player or not player.valid then
        log("[ghost_combinator/gui] refresh_gui: invalid player")
        return
    end

    local frame = player.gui.screen[GUI_FRAME_NAME]
    if not frame or not frame.valid then
        log("[ghost_combinator/gui] refresh_gui: no GUI open")
        return
    end

    -- Get entity from stored state via globals
    local player_gui_state = globals.get_player_gui_state(player.index)
    if not player_gui_state then
        log("[ghost_combinator/gui] refresh_gui: no valid entity in GUI state")
        gui.close_gui(player)
        return
    end

    local entity = player_gui_state.open_entity

    if not entity or not entity.valid then
        log("[ghost_combinator/gui] refresh_gui: entity invalid")
        gui.close_gui(player)
        return
    end

    -- Recreate the GUI to update signals
    log("[ghost_combinator/gui] Refreshing GUI")
    gui.create_gui(player, entity)
end

--- Get entity from GUI tags (helper for event handlers)
--- @param frame LuaGuiElement The GUI frame
--- @return LuaEntity|nil The entity, or nil if not found/invalid
local function get_entity_from_gui(frame)
    if not frame or not frame.valid or not frame.tags then
        return nil
    end

    local tags = frame.tags
    local surface_index = tags.entity_surface_index
    local position = tags.entity_position

    if not surface_index or not position then
        log("[ghost_combinator/gui] get_entity_from_gui: missing tags")
        return nil
    end

    local surface = game.surfaces[surface_index]
    if not surface then
        log("[ghost_combinator/gui] get_entity_from_gui: invalid surface")
        return nil
    end

    -- Find entity at position
    local entities = surface.find_entities_filtered{
        position = position,
        radius = 0.5,
        name = GHOST_COMBINATOR
    }

    if entities and #entities > 0 then
        return entities[1]
    end

    log("[ghost_combinator/gui] get_entity_from_gui: entity not found at position")
    return nil
end

-- GUI Event Handlers

--- Handle GUI click events
--- @param event EventData.on_gui_click
function gui.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end

    local tags = element.tags
    if not tags or not tags.action then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local action = tags.action

    if action == "close" then
        log("[ghost_combinator/gui] Close button clicked by " .. player.name)
        gui.close_gui(player)
    elseif action == "refresh" then
        log("[ghost_combinator/gui] Refresh button clicked by " .. player.name)
        gui.refresh_gui(player)
    end
end

--- Handle GUI opened event
--- @param event EventData.on_gui_opened
function gui.on_gui_opened(event)
    local entity = event.entity
    if not entity_lib.is_type(entity, GHOST_COMBINATOR) then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    log("[ghost_combinator/gui] GUI opened for entity by " .. player.name)

    -- Close the default entity GUI
    player.opened = nil

    -- Create our custom GUI
    gui.create_gui(player, entity)
end

--- Handle GUI closed event
--- @param event EventData.on_gui_closed
function gui.on_gui_closed(event)
    local element = event.element
    if not element or not element.valid then return end

    -- Check if this is our GUI
    if element.name ~= GUI_FRAME_NAME then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    log("[ghost_combinator/gui] GUI closed by " .. player.name)
    gui.close_gui(player)
end

--- Handle GUI checkbox state changed event (stub - no checkboxes in this GUI)
--- @param event EventData.on_gui_checked_state_changed
function gui.on_gui_checked_state_changed(event)
    -- Ghost combinator GUI has no checkboxes, this is a no-op
    -- Kept for consistency with event registration in control.lua
end

return gui
