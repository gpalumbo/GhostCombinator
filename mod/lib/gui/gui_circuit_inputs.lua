-- Mission Control Mod - Circuit Input Signal Grid GUI Components
-- This module provides reusable GUI components for displaying circuit input signals

local circuit_utils = require("lib.circuit_utils")

local gui_circuit_inputs = {}

--- Convert SignalID to sprite path for GUI display
--- @param signal_id table SignalID with type and name
--- @return string|nil Sprite path or nil if invalid
local function signal_id_to_sprite(signal_id)
    if not signal_id or not signal_id.name then
        return nil
    end

    -- Map SignalID type to sprite type prefix
    -- IMPORTANT: "virtual" signals use "virtual-signal" sprite prefix!
    local signal_type = signal_id.type or "item"

    local sprite_type_map = {
        virtual = "virtual-signal",  -- Maps "virtual" → "virtual-signal"
        item = "item",
        fluid = "fluid",
        entity = "entity",
        recipe = "recipe",
        quality = "quality",
        ["space-location"] = "space-location",
        ["asteroid-chunk"] = "asteroid-chunk"
    }

    local sprite_prefix = sprite_type_map[signal_type]
    if not sprite_prefix then
        -- Unknown type, default to item
        sprite_prefix = "item"
    end

    return sprite_prefix .. "/" .. signal_id.name
end

--- Create signal grid sub-display for red or green wire signals
--- @param parent LuaGuiElement Parent element to add the scroll pane to
--- @param signals table Array of signal data from API (format: {signal = SignalID, count = int})
--- @param color string Wire color ("red" or "green") for display
--- @param grid_table_name string|nil Optional name for the signal grid table element
--- @return LuaGuiElement The created scroll pane
function gui_circuit_inputs.create_signal_sub_grid(parent, signals, color, grid_table_name)
    -- Create scroll pane for signals
    local scroll = parent.add{
        type = "scroll-pane",
        style = "flib_naked_scroll_pane_no_padding"
    }
    scroll.style.maximal_height = 200
    scroll.style.minimal_width = 300

    -- Create table grid with 10 columns
    local signal_table = scroll.add{
        type = "table",
        name = grid_table_name,
        column_count = 10
    }
    signal_table.style.horizontal_spacing = 0
    signal_table.style.vertical_spacing = 0
    signal_table.style.cell_padding = 0

    -- Add signal buttons
    for _, sig_data in ipairs(signals) do
        -- Validate signal structure (API format uses 'signal' not 'signal_id')
        if not sig_data or not sig_data.signal then
            goto continue
        end

        if not sig_data.signal.name then
            goto continue
        end

        -- Convert SignalID to sprite path
        local sprite_path = signal_id_to_sprite(sig_data.signal)
        if not sprite_path then
            goto continue
        end

        -- Determine color indicator sprite based on wire color
        local slot_style
        local c = sig_data.wire_color or color or "none"
        if c == "red" then
            slot_style = "red_slot"
        elseif c == "green" then
            slot_style = "green_slot"
        else
            slot_style = "slot_button"
        end

        -- Add colored indicator sprite button
        signal_table.add({
            type = "sprite-button",
            sprite = sprite_path,
            number = sig_data.count,
            style = slot_style,
            quality = sig_data.signal.quality,
            tags = { signal_sel = sig_data.signal }
        })

        ::continue::
    end

    -- If no signals, show message
    if #signals == 0 then
        local no_signal_label = scroll.add{
            type = "label",
            caption = {"", "No input signals"}
        }
        no_signal_label.style.font_color = {r = 0.6, g = 0.6, b = 0.6}
    end

    return scroll
end

--- Create complete signal grid display with red and green wire sections
--- @param parent LuaGuiElement Parent element to add signal grid to
--- @param entity LuaEntity The combinator entity to read signals from
--- @param signal_grid_frame LuaGuiElement|nil Optional existing frame to reuse
--- @param frame_name string Name for the signal grid frame element
--- @param connector_type string|nil Optional connector type (defaults to "combinator_input") - unused, kept for API compatibility
--- @return table References to created elements {signal_grid_frame = LuaGuiElement}
function gui_circuit_inputs.create_signal_grid(parent, entity, signal_grid_frame, frame_name, connector_type)
    -- Create frame for signal grid (or reuse existing)
    local grid_frame = signal_grid_frame or parent.add{
        type = "frame",
        name = frame_name,
        direction = "vertical",
        style = "inside_shallow_frame"
    }
    grid_frame.style.padding = 8
    grid_frame.style.horizontally_stretchable = true

    -- Add header label
    local signal_header = grid_frame.add{
        type = "label",
        caption = {"", "[font=default-semibold]Input Signals[/font]"}
    }
    signal_header.style.bottom_margin = 4

    -- Get input signals from entity using raw format (preferred)
    local signals = circuit_utils.get_input_signals_raw(entity)

    -- Create sub-grids for red and green wires
    gui_circuit_inputs.create_signal_sub_grid(grid_frame, signals.red, "red")
    gui_circuit_inputs.create_signal_sub_grid(grid_frame, signals.green, "green")

    return {signal_grid_frame = grid_frame}
end

return gui_circuit_inputs
