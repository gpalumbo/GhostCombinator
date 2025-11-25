Creating a FACTORIO mod called mission-control.

Requirements for the mod are @docs/spec.md
Maintain currect activity in @docs/todo.md
Code snippets defined when considering feasibilty options are in @docs/implmentation_hints.md, When planning you need to look at these and take them into consideration.

**🚨 CRITICAL: 🚨**
Ensure proper API usage is strictly adhered to.  
- use @docs\flib_api_reference.md to find premade utilities
- Use Context7 to view "Factorio Lua API"  also use 
- Use https://github.com/wube/factorio-data/blob/master/core/prototypes/utility-sprites.lua
VERY IMPORATANT: ALWAYS MAKE SURE YOU ARE USING 2.0 APIs.  I wastes time and gets everyone upset when you use older apis!

**🚨 CRITICAL: Module Responsibility Matrix 🚨**
Before writing ANY code, consult @docs/module_responsibility_matrix.md
This defines EXACTLY where each function belongs (lib/ vs scripts/, which module).
Use the decision tree to determine correct placement for new functions.

## File Structure
```
docs/
├── spec.md                              # Requirements specification
├── todo.md                              # Development tracking
├── module_responsibility_matrix.md      # Code organization rules
├── passthrough_combinator_todo.md       # Entity-specific todos
mod/
├── info.json                            # Mod metadata
├── data.lua                             # Data stage entry point
├── control.lua                          # Runtime entry - event routing
├── lib/                                 # Stateless utility libraries
│   ├── entity_lib.lua                   # Entity name/ghost utilities
│   ├── circuit_utils.lua                # Circuit network helpers
│   └── gui/                             # Shared GUI components
│       ├── gui_entity.lua               # Entity GUI utilities (power status, etc.)
│       └── gui_circuit_inputs.lua       # Signal grid display
├── scripts/                             # Stateful entity logic
│   ├── globals.lua                      # Central storage aggregator + shared state
│   └── passthrough_combinator/          # Entity-specific module
│       ├── storage.lua                  # Entity storage management
│       ├── control.lua                  # Event handlers
│       └── gui.lua                      # Custom GUI
├── locale/
│   └── en/
│       └── passthrough-combinator.cfg   # Localization strings
└── prototypes/
    ├── technology/
    │   └── technologies.lua             # Technology definitions
    ├── entity/
    │   └── passthrough_combinator.lua   # Entity prototype
    ├── item/
    │   └── passthrough_combinator.lua   # Item prototype
    └── recipe/
        └── passthrough_combinator.lua   # Recipe prototype
└── graphics/
│   ├── entity/
│   │   ├── receiver-combinator/
│   │   │   ├── receiver-combinator-base.png
│   │   │   ├── receiver-combinator-base-hr.png
│   │   │   ├── receiver-combinator-dish.png
│   │   │   ├── receiver-combinator-dish-hr.png
│   │   │   └── ...
│   ├── icons/
│   │   ├── receiver-combinator.png
│   ├── technology/
│   │   ├── mission-control.png
│   └── gui/
│       └── ...        
```

Important Process Rules:
1. All implementation files must go under the mod/ directory and follow the File Structure above.
2. Claude implementaion specs, feature specs, and todos should go under docs/
3. Make/git/precommit hooks and otehr SDLC or development infrastructure may live in the root directory.
4. Plan before you code.  Write out the feature plan to a @docs/<feature>_todo.md and add a line to the @docs/todo.md referencing this new file.

Important Coding rules:
1. Keep code well organized.  Each entity type should have it's own file, and common code should be a shared utility file.
2. .lua/.java/.py Code files should not exceed 750-900 lines.  Break it up into mutliple modules.  (Single JSON ,XML or data files that can't be readily broken apart should be in .json .xml .csv files respectively and imported as such)
3. Utilize in-line documentation heavily, and keep to BEST coding practices.


