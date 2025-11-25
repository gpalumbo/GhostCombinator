# My Example Mod 

## Vision Statement
_Typically a general top level for AI to understand hos the module works together_
This is a template.  We will generate one entity with a simple gui as an example but it won't really do anything over the base entity.  It will be a combinator that passes the signals through. 

## Core Components

### 1. Technologies

#### No-Op Examples Technology
- **Name:** `noop exmaple`
- **Cost:** 1000x each science pack (automation, logistic, military, chemical, production, utility, space)
- **Prerequisites:** Space Science, Logistic system
- **Unlocks:** Passthrough Combinator
- **Icon:** Artimetic combinator with a single red led on the display

### 2. Receiver Combinator

**Entity Specifications:**
- **Size:** 2x1 combinator
- **Recipe:** 5x electronic circuits , 5x advanced circuits
- **Placement:** surface eeds >0 pressure (on planets only)
- **Health:** 150 (same as arithmetic combinator, scales with quality)
- **Power:** 1kW 
- **Circuit Connections:** 4 terminals (red in, red out, green in, green out)
- **Mode:** Always bidirectional 
- **Graphics:** Arithmetic Combinator with single red led on display
- **Stack Size:** 50
- **Rocket Capacity:** 50

**Configuration UI:**
- Title: "Communication Settings"
- Multi-select checkbox list of all discovered planets
- "Select All" / "Clear All" buttons
- Input and output signal grids should be on the bottom of the gui

**Signal Behavior:**
- passes input signals to output signals with no alterations:

**Implementation Critical:**
```lua
-- Use standard combinator prototype as base
-- Persist state across save/load
-- Update GUI layout dynamically when and_or toggled
```

### Key Principles
1. **Preserve wire separation** - Red and green networks never mix
2. **MAX aggregation** - Multiple sources MAX their signals

## Critical Implementation Warnings

### DO NOT Attempt:
1. **Creating real interrupts** - Logistics combinator replaces this need
3. **Direct circuit network manipulation** - Use entity connectors
4. **GUI replacement** - Use companion windows/overlays

### MUST Handle:
1. **Entity lifecycle events** - Cleanup when entities destroyed
2. **Save/Load** - Properly serialize global state
3. **Multiplayer** - Ensure signal sync across players
4. **Quality scaling** - Apply quality bonuses to health/power

## Architecture Notes

### Global State Structure
```lua
sotrage.<modname> = {
  passthrough_receivers = {
    [platform_unit_number] = {
      configured_surfaces = {}, -- surface indices
      entity = entity
    }
  },
```

### Performance Optimizations
1. Use filters when registering events where possible
2. Limit GUI updates to when GUI is open

## Edge Cases & Solutions

| Edge Case | Solution |
|-----------|----------|
*TBD*

## Validation Checklist

### Core Functionality
- [ ] Red/green wire separation preserved through transmission  
- [ ] All entities require appropriate tech unlock

### Entity Behavior
- [ ] Health values scale with quality
- [ ] Power consumption scales with quality
- [ ] Entities can be blueprinted and copy/pasted
- [ ] Rotation works correctly for all entities
- [ ] Circuit connections preserved in blueprints

### UI/UX
- [ ] Surface selector shows all discovered planets
- [ ] LED indicators show active state
- [ ] GUI responsive to changes

### Events & Lifecycle
- [ ] Platform lifecycle events handled
- [ ] Entity destroyed events cleanup global state
- [ ] Save/load preserves all state
- [ ] Multiplayer synchronized properly

## Success Criteria

Players can successfully:
1. Build Passthrough Combinators on the planet
2. Configure receiver combinators to connect to specific planets
5. See clear visual feedback (LEDs, status text) of system state
6. Create blueprints incorporating the new entities
7. Scale up to multiple planets and platforms without issues
8. Use familiar Factorio UI patterns throughout

## Final Notes

- This mod extends vanilla without replacing functionality
- All vanilla platform behaviors remain intact
- Circuit control is optional - players can ignore it entirely
- Focus on intuitive, Factorio-like user experience
- Prioritize stability ond performancever feature complexity
- When in doubt, follow vanilla factorio patterns
