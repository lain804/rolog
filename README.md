# roblox logger

Lua logging utility designed for roblox runtime environments.

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

## tests

Install the standalone [Luau CLI](https://github.com/luau-lang/luau/releases), then run:

```sh
python3 tests/run.py
```

You can also pass the path to the CLI: `python3 tests/run.py /path/to/luau`.
The tests use Luau's debug library and mock Roblox output and task scheduling.

**executors:**
```lua
local Logger = loadstring(game:HttpGet("https://raw.githubusercontent.com/lain804/rolog/refs/heads/master/rolog.lua"))()

Logger.Level = Logger.Levels.DEBUG.Level

Logger.debug("Hello", "World")
Logger.info("Hello", "World")
Logger.warn("Hello", "World")
Logger.error("Hello", "World")
```
