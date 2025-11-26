# My Example Mod 

## Vision Statement
Logistics data from roboports only list items and not construction requests.
This combinator will keep a count of each ghost and create a set of signals of all ghosts on a surface.  

## Core Components

### 1. Technologies

#### Ghost Combinator Technology
- **Name:** 'Ghost Combinator"
- **Cost:** 500x each science pack (automation, logistic, chemical, production, utility)
- **Prerequisites:** Logistic system, Production science pack
- **Unlocks:** Ghost Combinator
- **Icon:** constant combinator

### 2. Receiver Combinator

**Entity Specifications:**
- **Size:** 2x1 combinator
- **Recipe:** 5x electronic circuits , 5x advanced circuits
- **Placement:** no restrictions
- **Health:** 150 (same as arithmetic combinator, scales with quality)
- **Power:** 1kW 
- **Circuit Connections:** i2 terminals (red out, green out)
- **Graphics:** Constant Combinator with single red led on display
- **Stack Size:** 50
- **Rocket Capacity:** 50

**Configuration UI:**
- Readonly signal out grid

**Signal Behavior:**
- Output signals based on running statistics of ghost count on the smae surface

**Implementation Critical:**
```lua
-- Start registering ghosts immediatly before the technology is researched
-- Persist state across save/load
```

## Critical Implementation Warnings

### MUST Handle:
1. **Entity lifecycle events** - Cleanup when entities destroyed
2. **Save/Load** - Properly serialize global state
3. **Multiplayer** - Ensure signal sync across players
4. **Quality scaling** - Apply quality bonuses to health/power

## Architecture Notes

### Global State Structure
For each surface maintain a list of ghost combinators and active_ghosts.  Each entity type will have a slot id to update the slot in the constant combinator.
Every 5-10 seconds we will run a process to remove entity names that are at zero and compress the slot numbers to avoid gaps long term
```lua
sotrage.<modname> = {
  ghost_combinator_data= {
    [surface_id] = {
      ghost_combinators = {
        entity
      }
      any_changes = true/false
      active_ghosts = {
        entity_name -> slot_id,count,changed
      }
    }
  },
```

### Performance Optimizations
we will register every ghost in on_built() and update the data structure.  we will limit redundant checks and ensure speed of the update is critical.
We will update the combinator slots every tick not every ghost.  we will use the changed flag on the active ghosts dictionary to limit the updates for speed, clearing them as needed. (iterate over active ghost keys and if changed iterate over the combinators)

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
