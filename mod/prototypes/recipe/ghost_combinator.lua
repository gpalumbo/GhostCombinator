-- Ghost Combinator Recipe Prototype
-- Factorio 2.0 API

data:extend({
    {
        type = "recipe",
        name = "ghost-combinator",
        -- Recipe is disabled by default, unlocked via technology
        enabled = false,
        -- Crafting time (0.5 seconds)
        energy_required = 0.5,
        -- Recipe ingredients: 5x electronic circuits, 5x advanced circuits
        ingredients = {
            {type = "item", name = "electronic-circuit", amount = 5},
            {type = "item", name = "advanced-circuit", amount = 5}
        },
        -- Recipe output
        results = {
            {type = "item", name = "ghost-combinator", amount = 1}
        }
    }
})
