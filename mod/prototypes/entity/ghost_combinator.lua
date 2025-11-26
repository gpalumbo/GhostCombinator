-- Ghost Combinator Entity Prototype
-- A combinator that outputs signals based on ghost entity counts on the surface
-- Factorio 2.0 API

local flib_data_util = require("__flib__.data-util")

-- Copy constant combinator as base (1x1 size, read-only output)
local ghost_combinator = flib_data_util.copy_prototype(
    data.raw["constant-combinator"]["constant-combinator"],
    "ghost-combinator"
)

-- Basic properties
ghost_combinator.max_health = 150

-- Energy configuration (1kW electric, secondary-input priority)
-- This combinator consumes power to scan for ghosts on the surface
ghost_combinator.energy_source = {
    type = "electric",
    usage_priority = "secondary-input"
}
ghost_combinator.active_energy_usage = "1kW"

-- Minable configuration
ghost_combinator.minable = {
    mining_time = 0.1,
    result = "ghost-combinator"
}

-- Corpse configuration (reuse constant combinator remnants)
ghost_combinator.corpse = "constant-combinator-remnants"

-- Fast replaceable group
ghost_combinator.fast_replaceable_group = "ghost-combinator"

-- Ensure proper flags for player interaction
ghost_combinator.flags = {
    "placeable-player",
    "player-creation"
}

-- Add to data
data:extend({ghost_combinator})
