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

**executors:**
```lua
local Logger = loadstring(game:HttpGet("https://raw.githubusercontent.com/lain804/rolog/refs/heads/master/rolog.lua"))()

Logger.Level = Logger.Levels.DEBUG.Level

Logger.debug("Hello", "World")
Logger.info("Hello", "World")
Logger.warn("Hello", "World")
Logger.error("Hello", "World")
```

## configuration

Set options directly on `Logger`. The default output remains the level prefix,
caller line, and message arguments, in that order.

| Option | Default | Behavior |
| --- | --- | --- |
| `Level` | `10` | Minimum level to emit. Use `Logger.Levels.INFO.Level`, for example. |
| `Prefix` | `true` | Include the level's prefix. Customize individual prefixes through `Logger.Levels.INFO.Prefix`, etc.; set one to `nil` to omit it. |
| `LineNumber` | `true` | Include the caller's line as `:123`, when available. |
| `Separator` | `nil` | A string used to join prefixes, lines, and arguments. `nil` preserves native argument forwarding to `print`/`warn`; error messages use a space. An empty string joins without spacing. |
| `Formatter` | `nil` | Optional `function(entry): string` that returns the entire message layout for every level. |
| `Traceback` | `true` | Append the caller's traceback to error messages, after formatting. |

```lua
Logger.LineNumber = false
Logger.Separator = " | "
Logger.Levels.INFO.Prefix = "[APP]"
Logger.info("Hello", "World") -- [APP] | Hello | World

Logger.Prefix = false
Logger.info("Hello", "World") -- Hello | World
```

When `Separator` or `Formatter` is set, arguments are converted with `tostring`,
including `nil` and `false`, in their original order. Otherwise, `debug`, `info`,
and `warn` forward the original values, preserving Roblox's object inspection.
`error` always builds a string and raises it in a spawned task, so it does not
stop the calling thread. `Traceback = false` removes the appended caller trace;
Roblox may still display the spawned task's own error stack.

A custom formatter receives these fields:

| Field | Value |
| --- | --- |
| `Level` | `"DEBUG"`, `"INFO"`, `"WARN"`, or `"ERROR"`. |
| `Prefix` | The configured level prefix, or `nil` when disabled. |
| `LineNumber` | The caller's line number, or `nil` when disabled or unavailable. |
| `Message` | Only the message arguments, converted to strings and joined using `Separator` (a space when `nil`). |

```lua
Logger.LineNumber = true
Logger.Separator = " "
Logger.Formatter = function(entry)
	local location = entry.LineNumber and (":" .. entry.LineNumber) or ""
	return entry.Level .. location .. " - " .. entry.Message
end

Logger.info("Hello", "World") -- INFO:123 - Hello World (line number varies)
```

The formatter replaces the default prefix/line layout. Filtered messages do not
invoke it. Set `Logger.Formatter = nil` and `Logger.Separator = nil` to restore
native argument forwarding.

## tests

Install the standalone [Luau CLI](https://github.com/luau-lang/luau/releases), then run:

```sh
python3 tests/run.py
```

You can also pass the path to the CLI: `python3 tests/run.py /path/to/luau`.
The tests use Luau's debug library and mock Roblox output and task scheduling.
