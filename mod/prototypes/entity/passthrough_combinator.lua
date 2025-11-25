-- Passthrough Combinator Entity Prototype
-- A combinator that passes input signals to output without modification
-- Factorio 2.0 API

local flib_data_util = require("__flib__.data-util")

-- Copy arithmetic combinator as base
local passthrough_combinator = flib_data_util.copy_prototype(
    data.raw["arithmetic-combinator"]["arithmetic-combinator"],
    "passthrough-combinator"
)

-- Basic properties
passthrough_combinator.max_health = 150

-- Energy configuration (1kW electric)
passthrough_combinator.energy_source = {
    type = "electric",
    usage_priority = "secondary-input"
}
passthrough_combinator.active_energy_usage = "1kW"

-- Surface placement conditions: Requires pressure > 0 (planets only, not space)
-- In Factorio 2.0, pressure = 0 means space, pressure >= 1 means planets
passthrough_combinator.surface_conditions = {
    {
        property = "pressure",
        min = 1  -- Minimum 1 hPa pressure (any planet, not space)
    }
}

-- Minable configuration
passthrough_combinator.minable = {
    mining_time = 0.1,
    result = "passthrough-combinator"
}

-- Corpse configuration
passthrough_combinator.corpse = "arithmetic-combinator-remnants"

-- Fast replaceable group
passthrough_combinator.fast_replaceable_group = "passthrough-combinator"

-- Ensure proper flags for player interaction
passthrough_combinator.flags = {
    "placeable-player",
    "player-creation"
}

-- Add to data
data:extend({passthrough_combinator})

log("[mission-control] prototypes/entity/passthrough_combinator.lua loaded")
