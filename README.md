# roblox logger (lua)

lightweight logging utility for the roblox runtime environment.

## usage

**studio:**
```lua
local Logger = require("path to modulescript")

Logger.level = Logger.LevelsInfo.DEBUG.level

Logger.debug("Hello", "World")
Logger.info("Hello", "World")
Logger.warn("Hello", "World")
Logger.error("Hello", "World")
```

**executors:**
```lua
local Logger = loadstring(game:HttpGet("https://raw.githubusercontent.com/lain804/rolog/refs/heads/master/rolog.lua"))()

Logger.level = Logger.LevelsInfo.DEBUG.level

Logger.debug("Hello", "World")
Logger.info("Hello", "World")
Logger.warn("Hello", "World")
Logger.error("Hello", "World")
```
