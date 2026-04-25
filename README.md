simple logging library for roblox

usage: 
regular roblox studio environment: create a modulescript paste the script there and require it from another like so
```lua
local Logger = require("path to modulescript")
Logger.debug("Hello", "World")
```
roblox executor environment:
```lua
local Logger = local Logger = loadstring(game:HttpGet("https://raw.githubusercontent.com/lain804/rolog/refs/heads/master/rolog.lua"))()
Logger.debug("Hello", "World")
```
