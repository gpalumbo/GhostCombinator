-- Mission Control Mod - GUI Entity Utilities
-- This module provides common entity-related GUI helper functions
-- These are pure utility functions that can be used by any GUI module

local gui_entity = {}

--- Get power status for an entity
--- Uses Factorio 2.0 entity.status API for accurate status reporting.
--- Entities without a status property (e.g., constant combinators that don't
--- consume power) are treated as "Working" when valid.
--- @param entity LuaEntity|nil The entity to check
--- @return table Status information with sprite and text fields
function gui_entity.get_power_status(entity)
    if not entity or not entity.valid then
        return {
            sprite = "utility/status_not_working",
            text = {"entity-status.disabled"}
        }
    end

    local status = entity.status

    -- Entities without a status property (e.g., constant combinators) are always working
    if not status then
        return {
            sprite = "utility/status_working",
            text = {"entity-status.working"}
        }
    end

    -- Map defines.entity_status to display
    if status == defines.entity_status.working
        or status == defines.entity_status.normal then
        return {
            sprite = "utility/status_working",
            text = {"entity-status.working"}
        }
    elseif status == defines.entity_status.low_power then
        return {
            sprite = "utility/status_yellow",
            text = {"entity-status.low-power"}
        }
    elseif status == defines.entity_status.no_power then
        return {
            sprite = "utility/status_not_working",
            text = {"entity-status.no-power"}
        }
    elseif status == defines.entity_status.disabled_by_control_behavior
        or status == defines.entity_status.disabled_by_script
        or status == defines.entity_status.disabled then
        return {
            sprite = "utility/status_not_working",
            text = {"entity-status.disabled"}
        }
    elseif status == defines.entity_status.marked_for_deconstruction then
        return {
            sprite = "utility/status_yellow",
            text = {"entity-status.marked-for-deconstruction"}
        }
    else
        -- Default: treat any unhandled status as working
        return {
            sprite = "utility/status_working",
            text = {"entity-status.working"}
        }
    end
end

return gui_entity