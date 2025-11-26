-- Technology Definitions for Mission Control Mod
-- Defines all technologies and their unlocks for the example passthrough combinator
--
-- This file extends the data phase with technology prototypes that gate access
-- to the mod's features behind research progression.
--
-- Factorio 2.0 API Reference: https://lua-api.factorio.com/latest/prototypes/TechnologyPrototype.html

data:extend({
    {
        -- Technology type identifier (Factorio 2.0 prototype type)
        type = "technology",

        -- Internal name used for references and prerequisites
        -- Must match the name used in recipe unlocks and other references
        name = "noop-example",

        -- Technology icon displayed in the research queue
        -- Using base game's arithmetic combinator icon as specified
        -- icon_size MUST be specified when using icon (Factorio 2.0 requirement)
        icon = "__base__/graphics/icons/arithmetic-combinator.png",
        icon_size = 64,  -- Standard icon size for technologies

        -- Technologies that must be researched before this one becomes available
        -- space-science-pack: Ensures player has reached space platform stage
        -- logistic-system: Ensures player has basic logistics infrastructure
        prerequisites = {
            "space-science-pack",
            "logistic-system"
        },

        -- Research cost configuration
        unit = {
            -- Number of research cycles required (1000 cycles)
            count = 1,

            -- Science packs required per research cycle
            -- Each cycle consumes 1 of each pack listed below
            -- Factorio 2.0: Use full science pack names (not abbreviated)
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"military-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1}
            },

            -- Time in ticks for each research cycle (60 ticks = 1 second)
            -- This sets research time to 1 second per cycle
            time = 60
        },

        -- Effects applied when technology is researched
        -- This unlocks the recipe for the passthrough-combinator entity
        effects = {
            {
                type = "unlock-recipe",
                -- Recipe name must match the recipe prototype defined in prototypes/recipe/
                recipe = "passthrough-combinator"
            }
        },

        -- Optional fields not used but available in Factorio 2.0:
        -- order: Controls sort order in technology tree (default: alphabetical)
        -- max_level: For infinite research (default: 1 for finite research)
        -- upgrade: Boolean for whether this is an upgrade tech (default: false)
        -- visible_when_disabled: Whether to show in tree before prerequisites (default: false)
    }
})
