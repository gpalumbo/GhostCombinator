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
Makefile
docs/
├── spec.md
├── todo.md
├── module_responsibility_matrix.md
mod/
├── info.json
├── changelog.txt
├── thumbnail.png (optional, 144x144)
├── data.lua
├── control.lua         # event registration and routing to entity specific code. command registration
├── lib/                    # Stateless utility libraries
│   ├── circuit_utils.lua
│   ├── gui/                # common gui features
│       ├── gui_entity.lua                  # GUI components usefule for most entities
├── scripts/               # Stateful entity logic
│   ├── globals.lua       # Entity state management, interactions with stoarge encapsualted here
│   ├── network_manager.lua  # Cross-surface coordination
│   └── example_entity/
│       ├── example_entity.lua  # Core functionality
│       ├── gui.lua                  # GUI handling
│       └── control.lua              # Event handling
├── locale/
│   └── en/
│       └── mission-control-tower.cfg
├── prototypes/
│   ├── technology/
│   │   └── technologies.lua  # All technology definitions
│   ├── entity/
│   │   └── example_entity.lua
│   ├── item/
│   │   └── example_entity.lua
│   └── recipe/
│       └── example_entity.lua
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


