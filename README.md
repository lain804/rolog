Lightweight logging utility designed for the Roblox runtime environment.

**Usage**

**Standard Roblox Studio context:**

Create a `ModuleScript` within `ReplicatedFirst` or `ReplicatedStorage`, insert the library source, and require it from another script:

```lua
local Logger = require("path to modulescript")

Logger.level = Logger.LevelsInfo.DEBUG.level

Logger.debug("Hello", "World")
Logger.info("Hello", "World")
Logger.warn("Hello", "World")
Logger.error("Hello", "World")
```

**Executor-based environment:**

Dynamically retrieve and evaluate the source at runtime:

```lua
local Logger = loadstring(game:HttpGet("https://raw.githubusercontent.com/lain804/rolog/refs/heads/master/rolog.lua"))()

Logger.level = Logger.LevelsInfo.DEBUG.level

Logger.debug("Hello", "World")
Logger.info("Hello", "World")
Logger.warn("Hello", "World")
Logger.error("Hello", "World")
```
