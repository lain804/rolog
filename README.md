# roblox logger

lightweight logging utility for the roblox runtime environment.

## usage

**studio:**
```lua
local Logger = require("path to modulescript")

Logger.Level = Logger.Levels.DEBUG.Level

Logger.debug("Hello", "World")
Logger.info("Hello", "World")
Logger.warn("Hello", "World")
Logger.error("Hello", "World")
```

**executors:**
```lua
local Logger = loadstring(game:HttpGet("https://raw.githubusercontent.com/lain804/rolog/refs/heads/master/rolog.lua"))()

Logger.Level = Logger.Levels.DEBUG.Level

Logger.debug("Hello", "World")
Logger.info("Hello", "World")
Logger.warn("Hello", "World")
Logger.error("Hello", "World")
```
