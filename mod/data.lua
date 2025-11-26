-- Mission Control Mod - Data Stage
-- Loads all prototype definitions

-- Load FLib styles
require("__flib__.data")

-- Load entity prototypes
require("prototypes.entity.passthrough_combinator")

-- Load item prototypes
require("prototypes.item.passthrough_combinator")

-- Load recipe prototypes
require("prototypes.recipe.passthrough_combinator")

-- Load technology prototypes
require("prototypes.technology.technologies")

log("[example-mod] data.lua loaded")

data:extend({
  {
    type = "custom-input",
    name = "gui-pipette-signal",
    key_sequence = "Q",
    linked_game_control = "pipette",  -- Links to the pipette control (default: 'Q' key)
    consuming = "none",  -- Allow the event to pass through if not handled
    action = "lua"
  }
})