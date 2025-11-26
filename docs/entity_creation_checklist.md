# New Entity Type Creation Checklist

Based on the Logistics Chooser Combinator implementation.

---

## 1. PROTOTYPE DEFINITION (mod/prototypes/entity/)

### Required Prototype Fields
- [ ] **type**: Set to appropriate entity type (e.g., "constant-combinator", "container", etc.)
- [ ] **name**: Unique entity name (e.g., "logistics-chooser-combinator")
- [ ] **flags**: Include "not-rotatable", "placeable-player", "player-creation". Add "hidden" if entity shouldn't appear in selection tools.
- [ ] **minable**: Set result to item name, mining_time determines how long to deconstruct.
- [ ] **max_health**: Base health (scales with quality). Use 150 for combinators.
- [ ] **corpse**: Set to "small-remnants" for small entities.
- [ ] **collision_box**: Defines physical footprint. Use {{-0.35, -0.35}, {0.35, 0.35}} for 1x1 entities.
- [ ] **selection_box**: Visual selection outline, slightly larger than collision_box.

### Circuit Network Fields (if applicable)
- [ ] **circuit_wire_connection_point**: Define connection points for red/green wires using `circuit_connector_definitions`.
- [ ] **circuit_connector_sprites**: Visual sprites for circuit connections.
- [ ] **circuit_wire_max_distance**: Maximum wire reach (default: 9 tiles).

### Power Fields (if applicable)
- [ ] **energy_source**: Set type ("electric", "void", etc.) and usage_priority.
- [ ] **energy_usage_per_tick**: Power consumption (e.g., "1kW").
- [ ] **active_energy_usage**: For entities with active/idle states.

### Graphics
- [ ] **sprites/animation**: Entity appearance (use tinted vanilla sprites or custom graphics).
- [ ] **icon/icon_size**: Icon for inventories (64x64 recommended).
- [ ] **working_visualisations**: Optional animations for active states.

### Other Important Fields
- [ ] **tile_buildability_rules**: Define placement restrictions (land-only, space-only, etc.) using surface rules (gravity, pressure, etc.). Replaces validation.lua approach.
- [ ] **fast_replaceable_group**: Allow upgrading between entity variants.
- [ ] **next_upgrade**: Define upgrade path for quality system.
- [ ] **open_sound/close_sound**: Audio feedback for GUI interactions.

**NOTE ON PLACEMENT**: Entity-item connection works bidirectionally through the **item's `place_result`** field. You do NOT need `item_to_place` or `placeable_by` in the entity prototype if the item has `place_result = "entity-name"`.

---

## 2. ITEM & RECIPE DEFINITIONS

### Item (mod/prototypes/item/)
- [ ] **type**: Usually "item"
- [ ] **name**: Item name (recommend matching entity name for consistency)
- [ ] **stack_size**: How many fit in one inventory slot (50 for combinators)
- [ ] **place_result**: Must match entity name exactly - this links the item to the entity
- [ ] **subgroup**: Category in crafting menu
- [ ] **order**: Sort order within subgroup

### Recipe (mod/prototypes/recipe/)
- [ ] **name**: Recipe name (can match item name)
- [ ] **enabled**: false (unlock via technology)
- [ ] **ingredients**: Crafting materials
- [ ] **results**: Output items
- [ ] **energy_required**: Crafting time in seconds

### Technology (mod/prototypes/technology/)
- [ ] Add recipe unlock to appropriate technology's **effects**

---

## 3. STORAGE ARCHITECTURE

### File Organization
Storage is split into two layers:

1. **Entity-specific storage** (`mod/scripts/[entity]/storage.lua`):
   - Contains all storage functions specific to one entity type
   - Uses short function names: `register()`, `get_data()`, `update_data()`
   - Only accessed by entity's own modules (control.lua, gui.lua)

2. **Central aggregator** (`mod/scripts/globals.lua`):
   - Requires all entity storage modules
   - Re-exports entity functions with prefixed names for backwards compatibility
   - Manages shared state (player GUI states)
   - Provides unified `init_storage()` that initializes all storage tables

### Storage Table Structure
```lua
storage.entity_name_plural = {
    [unit_number] = {
        entity = entity_reference,
        -- Entity-specific data fields
        custom_data = {},
        connected_entities = {},
        -- etc.
    }
}
```

### Required Storage Functions (in entity's storage.lua)
- [ ] **init_storage()**: Initialize entity's storage table
- [ ] **register(entity)**: Create storage entry when entity is built. Initialize all required fields with defaults.
- [ ] **unregister(unit_number)**: Remove storage entry when entity is destroyed. Clean up any dependent data.
- [ ] **get_data(entity_or_unit_number)**: Universal getter accepting entity OR unit_number. Handle ghost entities by reading tags, real entities from storage.

### Configuration Storage Functions (if entity has configuration)
- [ ] **serialize_config(unit_number)**: Convert storage data to blueprint-compatible table for tags/blueprints.
- [ ] **restore_config(entity, config)**: Apply configuration from blueprint tags. Handle both ghost (write tags) and real (write storage).
- [ ] **get_ghost_config(ghost_entity)**: Read configuration from ghost entity tags. Return default config if tags missing.
- [ ] **save_ghost_config(ghost_entity, config)**: Write configuration to ghost entity tags using complete table assignment pattern.

### Universal Update Function (for GUI operations)
- [ ] **update_data(entity, data)**: Write complete configuration to entity. Handle both ghost (write to tags) and real (write to storage). This is the cleanest approach - GUI gets data, modifies it, and writes it back in one operation.

**ALTERNATIVE**: Individual universal functions (add/update/remove for each data type) create bloat. Prefer the single update function that writes complete config.

---

## 4. ENTITY LIFECYCLE EVENTS (registered in mod/control.lua dispatcher and touts to functions in mod/scripts/[entity]/control.lua)

If you have multiple entity types, Register a method in the main control.lua that routes to the handler for the specific entity type.  Routing needs to account for ghosts as well as regular entities.

### Build Events 
- [ ] **on_built_entity**: Player-placed entity. Check event.tags for blueprint configuration. Skip ghosts (they use tags not storage).
- [ ] **on_robot_built_entity**: Robot-placed entity. Check event.tags for blueprint data. Check ghost_tags_cache for revived ghosts.
- [ ] **on_space_platform_built_entity**: Space platform auto-placed entity (e.g., from cargo landing pad). Check event.tags and ghost_tags_cache.
- [ ] **script_raised_built**: Mod/script created entity. Use event.tags if provided.
- [ ] **script_raised_revive**: Ghost revived by script. Check event.tags and ghost_tags_cache.

**Shared handler pattern:**
```lua
function on_built(entity, player, tags)
    if entity.type == "entity-ghost" then
        if tags then save_ghost_config(entity, tags.config) end
        return -- Don't register ghosts
    end

    register_entity(entity)
    if tags and tags.config then
        restore_config(entity, tags.config)
    end
    update_connections(entity.unit_number)
end
```

### Destroy Events (can share handler)
- [ ] **on_player_mined_entity**: Player mined/deconstructed.
- [ ] **on_robot_mined_entity**: Robot deconstructed.
- [ ] **on_space_platform_mined_entity**: Space platform deconstructed entity (e.g., to send back via cargo landing pad).
- [ ] **on_entity_died**: Entity destroyed (damage, combat, etc.).
- [ ] **script_raised_destroy**: Script/mod destroyed entity.

**Shared handler pattern:**
```lua
function on_removed(entity)
    if not entity.valid or entity.name ~= "entity-name" then return end

    cleanup_entity_data(unit_number)
    unregister_entity(unit_number)
    close_any_open_guis(unit_number)
end
```

### Periodic Updates
- [ ] **on_nth_tick(N)**: Processing interval (15 ticks = 250ms, 90 ticks = 1.5s). Update entity logic, evaluate conditions, process connections.

### Lifecycle Initialization
- [ ] **on_init()**: Mod first loaded. Initialize any required storage structures.
- [ ] **on_configuration_changed()**: Mod updated. Run migrations, migrate old data formats.

---

## 5. BLUEPRINT & COPY SUPPORT (mod/control.lua)

### Blueprint Creation
- [ ] **on_player_setup_blueprint**: Call `event.mapping.get()` (NO parameters!) to get the complete mapping table. Then iterate `for blueprint_index, real_entity in pairs(mapping)`. For each entity, call serialize_config(entity), then blueprint.set_blueprint_entity_tag(blueprint_index, "config_key", config).

**CRITICAL GOTCHA**: `event.mapping.get(blueprint_index)` does NOT work (returns nil)! You MUST call `event.mapping.get()` without parameters to get the entire mapping table, then iterate through it.

### Copy/Paste Settings
- [ ] **on_entity_settings_pasted**: Check source.name and destination.name match. Serialize source config, restore to destination using restore_config(destination, config).

### Entity Cloning
- [ ] **on_entity_cloned**: Editor/mod cloning. Serialize source config, register destination entity (cloning creates NEW entity), restore config to destination.

---

## 6. GUI SYSTEM (mod/scripts/[entity]/gui.lua)

### GUI State Management
- [ ] **set_player_gui_entity(player_index, entity, gui_type)**: Store entity reference (NOT unit_number) in storage.player_gui_states. Set is_ghost flag.
- [ ] **get_player_gui_state(player_index)**: Retrieve GUI state. Returns {open_entity = entity_reference, gui_type = string, is_ghost = boolean}.
- [ ] **clear_player_gui_entity(player_index)**: Remove GUI state when closing.

### Helper Function
```lua
local function get_data_from_player(player)
    local gui_state = get_player_gui_state(player.index)
    if not gui_state or not gui_state.open_entity.valid then return nil, nil end

    local entity = gui_state.open_entity
    local data = get_entity_data(entity) -- Universal function handles ghost/real
    return data, entity
end
```

### GUI Events (registered in mod/control.lua dispatcher and touts to functions in mod/scripts/[entity]/control.lua)
- [ ] **on_gui_opened**: Check entity.name or entity.ghost_name matches. For real entities, ensure registered in storage. For ghosts, log detection. Close default GUI, call create_gui(player, entity), then set_player_gui_entity().
- [ ] **on_gui_closed**: Check event.element.name matches GUI frame. Call close_gui(player).
- [ ] **on_gui_click**: Handle button clicks. Use get_data_from_player() to get entity and data. Update using universal functions.
- [ ] **on_gui_elem_changed**: Handle signal/item pickers. Update using universal functions.
- [ ] **on_gui_text_changed**: Handle text fields. Parse and validate input, update using universal functions.
- [ ] **on_gui_selection_state_changed**: Handle dropdowns. Update using universal functions.
- [ ] **on_gui_checked_state_changed**: Handle checkboxes. Update using universal functions.
- [ ] **on_gui_switch_state_changed**: Handle switches. Update using universal functions.

**CRITICAL**: All GUI update operations MUST use universal functions (add/update/remove_[entity]_[data]_universal) to handle both ghost tags and real entity storage. 

---

## 7. LOCALE STRINGS (mod/locale/en/)

- [ ] **entity-name.[entity-name]**: Display name
- [ ] **entity-description.[entity-name]**: Tooltip description
- [ ] **item-name.[entity-name]**: Item name (usually same as entity-name)
- [ ] **recipe-name.[entity-name]**: Recipe name
- [ ] **gui.[entity-name]-[element]**: GUI element labels/tooltips

---

## 8. COMMON PITFALLS & CRITICAL NOTES

### Ghost Entity Handling
- **NEVER register ghosts in storage**: Ghosts use entity.tags, not storage tables. Registering creates orphaned entries when ghost → real.
- **Universal functions are mandatory**: All GUI operations must use universal functions that check entity.type == "entity-ghost" and route to tags vs storage.
- **Complete tag assignment**: Use `entity.tags = new_table` pattern, never `entity.tags.field = value` (tags may be nil/read-only).
- **event.tags contains ghost tags in Factorio 2.0+**: When ghosts are revived (on_built_entity, on_robot_built_entity, etc.), event.tags contains the ghost's tags. No caching needed.

### GUI State Storage
- **Store entity reference, not unit_number**: gui_state.open_entity should be entity (works for ghost and real), not unit_number (only works for real).
- **Use universal get function**: get_[entity]_data() should accept entity OR unit_number for backward compatibility.

### Event Handler Organization
- **Centralized dispatch**: Register ALL events in main control.lua with dispatcher pattern. Dispatcher calls appropriate module based on gui_state.gui_type or entity name. Need to account for ghost as well as regular entities

### Blueprint Support
- **Tag key naming**: Use descriptive keys like "chooser_config" not "config". Avoids conflicts if multiple entity types in same blueprint.
- **event.mapping.get() usage**: MUST call `event.mapping.get()` with NO parameters to get the complete mapping table. DO NOT call `event.mapping.get(blueprint_index)` - this returns nil and will silently fail. Correct pattern: `local mapping = event.mapping.get()` then `for bp_index, entity in pairs(mapping) do`.
- **Ghost vs Real entity handling**: serialize_config() must handle both ghosts (read from entity.tags) and real entities (read from storage). Use universal getter function.

### Performance
- **Cache connections**: Don't scan for connected entities every tick. Update cache on periodic interval (90 ticks).
- **Use on_nth_tick not on_tick**: Even 15-tick interval (250ms) is frequent enough for most logic.
- **Edge-triggered logic**: Store last_state and only act on state changes to avoid repeated processing.

---

## 9. TESTING CHECKLIST

- [ ] **Manual placement**: Entity builds correctly, storage initialized
- [ ] **Robot placement**: Construction robots place entity correctly
- [ ] **Ghost placement**: Blueprint ghosts show correct preview, tags stored
- [ ] **Ghost revival**: Robots/players revive ghosts with configuration preserved
- [ ] **GUI interaction**: Open GUI on both real and ghost entities, all controls work
- [ ] **Configuration persistence**: Close/reopen GUI, settings preserved
- [ ] **Blueprint creation**: Create blueprint with configured entity, tags saved
- [ ] **Blueprint placement**: Place blueprint, entities created with correct configuration
- [ ] **Copy/paste settings**: Shift+right-click copy, shift+left-click paste works
- [ ] **Entity cloning**: Editor clone tool preserves configuration
- [ ] **Deconstruction**: Entity removed cleanly, storage cleaned up
- [ ] **Save/load**: Save game, reload, entity state preserved
- [ ] **Multiplayer**: Changes sync correctly between players
- [ ] **Quality upgrades**: Entity upgrades preserve configuration
- [ ] **Mod update migration**: Old saves load correctly after mod update

---

## SUMMARY: MINIMUM REQUIRED IMPLEMENTATION

For a basic entity with no special features:
1. **Prototype**: entity.lua, item.lua, recipe.lua
2. **Storage**: register, unregister, get_data functions
3. **Events**: on_built handler, on_removed handler
4. **Control**: register both handlers in control.lua

For entity with configuration/GUI:
- Add all storage functions (serialize, restore, ghost functions, universal functions)
- Add all GUI events and create_gui/close_gui functions
- Add blueprint support (setup_blueprint, settings_pasted, entity_cloned)
