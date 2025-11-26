# Mission Control Mod - Development TODO

## Current Status
Ghost Combinator implementation complete and ready for testing.

## Completed Features

### Ghost Combinator (v0.1.0)
- [x] Entity prototype (1x1 constant combinator base, 1kW power)
- [x] Item and recipe definitions
- [x] Technology unlock (500x science packs)
- [x] Ghost tracking logic (increment/decrement on build/remove)
- [x] Combinator signal output via LuaLogisticSection API
- [x] Read-only GUI displaying ghost counts
- [x] Per-surface tracking (independent ghost lists per surface)
- [x] Slot compaction (every 5 seconds, removes zero-count entries)
- [x] Locale strings (EN)

## Pending / Future Work
- [ ] Custom graphics (currently using base constant-combinator placeholder)
- [ ] Integration testing with blueprints
- [ ] Performance profiling with large ghost counts
- [ ] Multi-surface testing (Nauvis, Vulcanus, platforms)

## Entity-Specific TODOs
- See: docs/ghost_combinator_todo.md (if detailed tracking needed)

## Known Limitations
1. **Bootstrap Problem**: Ghosts placed before mod installation are not tracked
2. **Signal Type**: Uses "item" signal type - entities without matching item names may show placeholder icon
