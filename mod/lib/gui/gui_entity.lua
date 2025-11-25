-- Mission Control Mod - GUI Entity Utilities
-- This module provides common entity-related GUI helper functions
-- These are pure utility functions that can be used by any GUI module

local gui_entity = {}

--- Get power status for an entity
--- Returns sprite and text indicating the entity's power/energy state
--- @param entity LuaEntity|nil The entity to check
--- @return table Status information with sprite and text fields
function gui_entity.get_power_status(entity)
    if entity and entity.valid then
        -- Get energy ratio (current / max)
        local energy_ratio = 0
        if entity.electric_buffer_size and entity.electric_buffer_size > 0 then
            energy_ratio = entity.energy / entity.electric_buffer_size
        elseif entity.energy > 0 then
            -- For entities without buffer, just check if they have any energy
            energy_ratio = 1
        end

        if energy_ratio >= 0.5 then
            -- Green: Working (>50% energy)
            return {
                sprite = "utility/status_working",
                text = "Working"
            }
        elseif energy_ratio > 0 then
            -- Yellow: Low Power (1-50% energy)
            return {
                sprite = "utility/status_yellow",
                text = "Low Power"
            }
        else
            -- Red: No Power (0% energy)
            return {
                sprite = "utility/status_not_working",
                text = "No Power"
            }
        end
    end
    return {
        sprite = "utility/bar_gray_pip",
        text = "Unknown"
    }
end

return gui_entity