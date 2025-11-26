-- Mission Control Mod - Passthrough Combinator GUI
-- This module handles the GUI for passthrough combinator entity
-- Supports both ghost entities (via tags) and real entities (via storage)

local flib_gui = require("__flib__.gui")
local circuit_utils = require("lib.circuit_utils")
local gui_circuit_inputs = require("lib.gui.gui_circuit_inputs")
local gui_entity = require("lib.gui.gui_entity")
local entity_lib = require("lib.entity_lib")
local globals = require("scripts.globals")
local pc_storage = require("scripts.passthrough_combinator.storage")
local logic = require("scripts.passthrough_combinator.logic")

local gui = {}

-- Entity name constant
local PASSTHROUGH_COMBINATOR = "passthrough-combinator"

-- GUI element names
local GUI_FRAME_NAME = "passthrough_combinator_gui"

--- Get list of discovered planets for current force
--- @param force LuaForce
--- @return table Array of {name=string, surface_index=number, localised_name=LocalisedString}
local function get_discovered_planets(force)
    local planets = {}

    -- Iterate through all surfaces to find planets
    for _, surface in pairs(game.surfaces) do
        -- Check if surface is a planet (has planet property in Factorio 2.0)
        if surface.planet then
            -- Check if the force has discovered this planet
            -- In Factorio 2.0, planets are visible if the force has charted any chunks
            -- or has a platform in orbit, or has landed on the planet
            local is_discovered = false

            -- Check if force has any entities on this surface
            local force_entities = surface.find_entities_filtered { force = force, limit = 1 }
            if force_entities and #force_entities > 0 then
                is_discovered = true
            end

            -- Also check if any player from this force has visited
            for _, player in pairs(force.players) do
                if player.surface == surface then
                    is_discovered = true
                    break
                end
            end

            -- Check if there are any charts for this surface (player has explored it)
            local charted = false
            for _, player in pairs(force.players) do
                if force.is_chunk_charted(surface, { x = 0, y = 0 }) then
                    charted = true
                    break
                end
            end
            if charted then
                is_discovered = true
            end

            -- For template purposes, include all planets (can be filtered later)
            -- In production, you'd want stricter discovery checks
            is_discovered = true -- TEMP: Show all planets for testing

            if is_discovered then
                table.insert(planets, {
                    name = surface.planet.prototype.name,
                    surface_index = surface.index,
                    localised_name = surface.planet.prototype.localised_name or { "", surface.planet.prototype.name }
                })
            end
        end
    end

    -- Sort planets by name for consistent display
    table.sort(planets, function(a, b)
        return a.name < b.name
    end)

    log("[passthrough_combinator/gui] Found " .. #planets .. " discovered planets for force " .. force.name)

    return planets
end

--- Get configured surfaces for entity (handles both ghost and real)
--- Returns array format for GUI iteration convenience
--- @param entity LuaEntity The entity (ghost or real)
--- @return table Array of surface indices that are configured
local function get_configured_surfaces(entity)
    if not entity or not entity.valid then
        log("[passthrough_combinator/gui] get_configured_surfaces: invalid entity")
        return {}
    end

    -- Use pc_storage to get entity data (handles both ghost and real)
    local data = pc_storage.get_data(entity)
    if not data then
        log("[passthrough_combinator/gui] No data found for entity")
        return {}
    end

    local configured_set = data.configured_surfaces or {}

    -- Convert set format {[index]=true} to array format {index, ...}
    -- Storage always uses set format internally (conversion handled in storage.lua)
    local configured_array = {}
    for surface_index, is_configured in pairs(configured_set) do
        if is_configured then
            table.insert(configured_array, surface_index)
        end
    end

    log("[passthrough_combinator/gui] Configured surfaces: " .. serpent.line(configured_array))
    return configured_array
end

--- Set configured surfaces for entity (handles both ghost and real)
--- Converts array format to set format for storage via globals.lua
--- @param entity LuaEntity The entity (ghost or real)
--- @param surface_indices table Array of surface indices
local function set_configured_surfaces(entity, surface_indices)
    if not entity or not entity.valid then
        log("[passthrough_combinator/gui] set_configured_surfaces: invalid entity")
        return
    end

    -- Convert array format {index, index, ...} to set format {[index]=true, ...}
    local configured_set = {}
    for _, surface_index in ipairs(surface_indices or {}) do
        configured_set[surface_index] = true
    end

    -- Use pc_storage to update entity data (handles both ghost and real)
    pc_storage.update_data(entity, {
        configured_surfaces = configured_set
    })

    log("[passthrough_combinator/gui] Updated configured surfaces via globals: " .. serpent.line(surface_indices))
end

--- Create the GUI for a passthrough combinator
--- @param player LuaPlayer
--- @param entity LuaEntity The entity to create GUI for (can be ghost or real)
--- @return table|nil Table of created elements, or nil on failure
function gui.create_gui(player, entity)
    if not player or not player.valid then
        log("[passthrough_combinator/gui] create_gui: invalid player")
        return nil
    end

    if not entity or not entity.valid then
        log("[passthrough_combinator/gui] create_gui: invalid entity")
        return nil
    end

    -- Close existing GUI if open
    gui.close_gui(player)

    local is_ghost = entity_lib.is_ghost(entity)
    log("[passthrough_combinator/gui] Creating GUI for " .. (is_ghost and "ghost" or "real") .. " entity")

    -- Get discovered planets for this force
    local planets = get_discovered_planets(player.force)

    -- Get currently configured surfaces
    local configured_surfaces = get_configured_surfaces(entity)

    -- Build planet checkbox children
    local planet_checkboxes = {}

    if #planets == 0 then
        -- No planets discovered
        table.insert(planet_checkboxes, {
            type = "label",
            caption = { "gui.passthrough-combinator-no-planets" },
            style_mods = {
                font_color = { r = 0.6, g = 0.6, b = 0.6 }
            }
        })
    else
        -- Create checkbox for each planet
        for _, planet_data in ipairs(planets) do
            -- Check if this surface is configured
            local is_checked = false
            for _, surf_idx in ipairs(configured_surfaces) do
                if surf_idx == planet_data.surface_index then
                    is_checked = true
                    break
                end
            end

            table.insert(planet_checkboxes, {
                type = "checkbox",
                name = "planet_checkbox_" .. planet_data.surface_index,
                caption = planet_data.localised_name,
                state = is_checked,
                tags = {
                    action = "planet_checkbox",
                    surface_index = planet_data.surface_index
                }
            })
        end
    end

    -- Get power status for real entities
    local power_status = { sprite = "utility/bar_gray_pip", text = "Ghost" }
    if not is_ghost then
        power_status = gui_entity.get_power_status(entity)
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
                        caption = { "gui.passthrough-combinator-title" },
                        ignored_by_interaction = true
                    },
                    { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                    {
                        type = "sprite-button",
                        name = "passthrough_close_button",
                        style = "frame_action_button",
                        sprite = "utility/close",
                        hovered_sprite = "utility/close_black",
                        clicked_sprite = "utility/close_black",
                        tooltip = { "gui.passthrough-combinator-close" },
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
                    -- Status indicator (for real entities only)
                    {
                        type = "flow",
                        direction = "horizontal",
                        style_mods = {
                            vertical_align = "center",
                            bottom_margin = 8
                        },
                        visible = not is_ghost,
                        children = {
                            {
                                type = "label",
                                caption = { "gui.passthrough-combinator-status" },
                                style_mods = {
                                    font = "default-semibold",
                                    right_margin = 8
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
                    -- Planet selection section
                    {
                        type = "flow",
                        direction = "vertical",
                        style_mods = {
                            bottom_margin = 8
                        },
                        children = {
                            {
                                type = "label",
                                caption = { "gui.passthrough-combinator-planets-header" },
                                style_mods = {
                                    font = "default-semibold",
                                    bottom_margin = 4
                                }
                            },
                            -- Scroll pane for planet list
                            {
                                type = "scroll-pane",
                                name = "planet_scroll_pane",
                                style = "flib_naked_scroll_pane",
                                direction = "vertical",
                                style_mods = {
                                    maximal_height = 200,
                                    minimal_width = 300
                                },
                                children = {
                                    {
                                        type = "flow",
                                        name = "planet_checkboxes_flow",
                                        direction = "vertical",
                                        children = planet_checkboxes
                                    }
                                }
                            },
                            -- Select All / Clear All buttons
                            {
                                type = "flow",
                                direction = "horizontal",
                                style_mods = {
                                    top_margin = 4,
                                    horizontal_spacing = 8
                                },
                                visible = (#planets > 0),
                                children = {
                                    {
                                        type = "button",
                                        name = "select_all_button",
                                        caption = { "gui.passthrough-combinator-select-all" },
                                        style = "button",
                                        tags = { action = "select_all" }
                                    },
                                    {
                                        type = "button",
                                        name = "clear_all_button",
                                        caption = { "gui.passthrough-combinator-clear-all" },
                                        style = "button",
                                        tags = { action = "clear_all" }
                                    }
                                }
                            }
                        }
                    },
                    -- Signal grids section (only for real entities)
                    {
                        type = "flow",
                        name = "signal_section",
                        direction = "vertical",
                        visible = not is_ghost,
                        children = {
                            -- Input signals
                            {
                                type = "frame",
                                name = "input_signals_frame",
                                direction = "vertical",
                                style = "inside_shallow_frame",
                                style_mods = {
                                    padding = 8,
                                    top_margin = 4
                                },
                                children = {
                                    {
                                        type = "label",
                                        caption = { "gui.passthrough-combinator-input-signals" },
                                        style_mods = {
                                            font = "default-semibold",
                                            bottom_margin = 4
                                        }
                                    }
                                    -- Signal grid will be added here dynamically
                                }
                            },
                            -- Output signals
                            {
                                type = "frame",
                                name = "output_signals_frame",
                                direction = "vertical",
                                style = "inside_shallow_frame",
                                style_mods = {
                                    padding = 8,
                                    top_margin = 8
                                },
                                children = {
                                    {
                                        type = "label",
                                        caption = { "gui.passthrough-combinator-output-signals" },
                                        style_mods = {
                                            font = "default-semibold",
                                            bottom_margin = 4
                                        }
                                    }
                                    -- Signal grid will be added here dynamically
                                }
                            }
                        }
                    }
                }
            }
        }
    })

    -- Add signal grids for real entities with connections
    -- Get input signals
    local input_signals = circuit_utils.get_input_signals_raw(entity)

    -- Create input signal grid
    if elems.input_signals_frame then
        -- Add red wire signals
        local red_count = #input_signals.red
        --if red_count > 0 then
            gui_circuit_inputs.create_signal_sub_grid(elems.input_signals_frame, input_signals.red, "red",
                "input_red_grid")
        --end

        -- Add green wire signals
        local green_count = #input_signals.green
        if green_count > 0 then
            gui_circuit_inputs.create_signal_sub_grid(elems.input_signals_frame, input_signals.green, "green",
                "input_green_grid")
        end

        -- If no signals, show message
        if red_count == 0 and green_count == 0 then
            elems.input_signals_frame.add {
                type = "label",
                caption = { "", "No input signals" },
                style_mods = {
                    font_color = { r = 0.6, g = 0.6, b = 0.6 }
                }
            }
        end
    end

    -- Get output signals (passthrough: output = input)
    local output_signals = logic.get_output_signals(entity)

    -- Create output signal grid
    if elems.output_signals_frame then
        -- Add red wire output signals
        local red_count = #output_signals.red
        if red_count > 0 then
            gui_circuit_inputs.create_signal_sub_grid(elems.output_signals_frame, output_signals.red, "red",
                "output_red_grid")
        end

        -- Add green wire output signals
        local green_count = #output_signals.green
        if green_count > 0 then
            gui_circuit_inputs.create_signal_sub_grid(elems.output_signals_frame, output_signals.green, "green",
                "output_green_grid")
        end

        -- If no signals, show message
        if red_count == 0 and green_count == 0 then
            elems.output_signals_frame.add {
                type = "label",
                caption = { "", "No output signals" },
                style_mods = {
                    font_color = { r = 0.6, g = 0.6, b = 0.6 }
                }
            }
        end
    end

    -- Center the GUI
    if elems[GUI_FRAME_NAME] then
        elems[GUI_FRAME_NAME].force_auto_center()
    end

    -- Make the GUI respond to ESC key by setting it as the player's opened GUI
    player.opened = elems[GUI_FRAME_NAME]

    -- Store GUI state via globals
    globals.set_player_gui_entity(player.index, entity, "passthrough_combinator")

    log("[passthrough_combinator/gui] GUI created successfully for player " .. player.name)

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
        log("[passthrough_combinator/gui] GUI closed for player " .. player.name)
    end

    -- Clear the opened GUI reference
    if player.opened == frame then
        player.opened = nil
    end

    -- Clear player GUI state via globals
    globals.clear_player_gui_entity(player.index)
end

--- Refresh the signal grids in the GUI
--- @param player LuaPlayer
function gui.refresh_signals(player)
    if not player or not player.valid then
        log("[passthrough_combinator/gui] refresh_signals: invalid player")
        return
    end

    local frame = player.gui.screen[GUI_FRAME_NAME]
    if not frame or not frame.valid then
        log("[passthrough_combinator/gui] refresh_signals: no GUI open")
        return
    end

    -- Get entity from stored state via globals
    local player_gui_state = globals.get_player_gui_state(player.index)
    if not player_gui_state then
        log("[passthrough_combinator/gui] refresh_signals: no valid entity in GUI state")
        gui.close_gui(player)
        return
    end

    local entity = player_gui_state.open_entity
    local is_ghost = player_gui_state.is_ghost

    -- Can't refresh signals for ghosts
    if is_ghost then
        log("[passthrough_combinator/gui] refresh_signals: cannot refresh for ghost entity")
        return
    end

    -- Find signal section
    local signal_section = frame.children[2] and frame.children[2].signal_section
    if not signal_section or not signal_section.valid then
        log("[passthrough_combinator/gui] refresh_signals: signal_section not found")
        return
    end

    -- Check if entity has circuit connections
    local has_connections = circuit_utils.has_circuit_connections(entity)
    signal_section.visible = has_connections

    if not has_connections then
        log("[passthrough_combinator/gui] refresh_signals: no circuit connections")
        return
    end

    -- Recreate the GUI to update signals
    -- This is simpler than trying to update in place
    log("[passthrough_combinator/gui] Recreating GUI to refresh signals")
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
        log("[passthrough_combinator/gui] get_entity_from_gui: missing tags")
        return nil
    end

    local surface = game.surfaces[surface_index]
    if not surface then
        log("[passthrough_combinator/gui] get_entity_from_gui: invalid surface")
        return nil
    end

    -- Find entity at position
    local entities = surface.find_entities_filtered {
        position = position,
        radius = 0.5,
        name = { "passthrough-combinator", "entity-ghost" }
    }

    if entities and #entities > 0 then
        return entities[1]
    end

    log("[passthrough_combinator/gui] get_entity_from_gui: entity not found at position")
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
        log("[passthrough_combinator/gui] Close button clicked by " .. player.name)
        gui.close_gui(player)
    elseif action == "select_all" then
        log("[passthrough_combinator/gui] Select All clicked by " .. player.name)

        -- Find the GUI frame
        local frame = player.gui.screen[GUI_FRAME_NAME]
        if not frame or not frame.valid then return end

        -- Get entity
        local entity = get_entity_from_gui(frame)
        if not entity or not entity.valid then
            gui.close_gui(player)
            return
        end

        -- Get all planets
        local planets = get_discovered_planets(player.force)
        local all_surface_indices = {}
        for _, planet_data in ipairs(planets) do
            table.insert(all_surface_indices, planet_data.surface_index)
        end

        -- Update entity configuration
        set_configured_surfaces(entity, all_surface_indices)

        -- Recreate GUI to reflect changes
        gui.create_gui(player, entity)
    elseif action == "clear_all" then
        log("[passthrough_combinator/gui] Clear All clicked by " .. player.name)

        -- Find the GUI frame
        local frame = player.gui.screen[GUI_FRAME_NAME]
        if not frame or not frame.valid then return end

        -- Get entity
        local entity = get_entity_from_gui(frame)
        if not entity or not entity.valid then
            gui.close_gui(player)
            return
        end

        -- Clear configuration
        set_configured_surfaces(entity, {})

        -- Recreate GUI to reflect changes
        gui.create_gui(player, entity)
    end
end

--- Handle GUI checked state changed events (checkboxes)
--- @param event EventData.on_gui_checked_state_changed
function gui.on_gui_checked_state_changed(event)
    local element = event.element
    if not element or not element.valid then return end

    local tags = element.tags
    if not tags or not tags.action then return end

    if tags.action ~= "planet_checkbox" then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local surface_index = tags.surface_index
    if not surface_index then
        log("[passthrough_combinator/gui] planet_checkbox: missing surface_index in tags")
        return
    end

    local new_state = element.state

    log("[passthrough_combinator/gui] Planet checkbox changed for surface " ..
        surface_index .. " to " .. tostring(new_state))

    -- Find the GUI frame
    local frame = player.gui.screen[GUI_FRAME_NAME]
    if not frame or not frame.valid then return end

    -- Get entity
    local entity = get_entity_from_gui(frame)
    if not entity or not entity.valid then
        gui.close_gui(player)
        return
    end

    -- Get current configuration
    local configured_surfaces = get_configured_surfaces(entity)

    -- Update configuration based on checkbox state
    if new_state then
        -- Add surface if not already present
        local already_present = false
        for _, surf_idx in ipairs(configured_surfaces) do
            if surf_idx == surface_index then
                already_present = true
                break
            end
        end
        if not already_present then
            table.insert(configured_surfaces, surface_index)
        end
    else
        -- Remove surface
        for i = #configured_surfaces, 1, -1 do
            if configured_surfaces[i] == surface_index then
                table.remove(configured_surfaces, i)
            end
        end
    end

    -- Save updated configuration
    set_configured_surfaces(entity, configured_surfaces)

    log("[passthrough_combinator/gui] Updated configured surfaces: " .. serpent.line(configured_surfaces))
end

--- Handle GUI opened event
--- @param event EventData.on_gui_opened
function gui.on_gui_opened(event)
    local entity = event.entity
    if not entity_lib.is_type(entity, PASSTHROUGH_COMBINATOR) then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    log("[passthrough_combinator/gui] GUI opened for entity by " .. player.name)

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

    log("[passthrough_combinator/gui] GUI closed by " .. player.name)
    gui.close_gui(player)
end

return gui
