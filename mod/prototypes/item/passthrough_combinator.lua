-- Passthrough Combinator Item Prototype
-- Factorio 2.0 API

data:extend({
    {
        type = "item",
        name = "passthrough-combinator",
        -- Using base arithmetic combinator icon (can be replaced with custom graphics later)
        icon = "__base__/graphics/icons/arithmetic-combinator.png",
        icon_size = 64,
        -- Place in circuit network category
        subgroup = "circuit-network",
        order = "c[combinators]-d[passthrough-combinator]",
        -- Link to entity prototype
        place_result = "passthrough-combinator",
        -- Stack size and rocket capacity
        stack_size = 50
    }
})

log("[mission-control] prototypes/item/passthrough_combinator.lua loaded")
