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

## multiple loggers

The module is a ready-to-use default logger. Use `Logger.new(options)` for
independent instances, with the same dot-call methods as the default logger:

```lua
local network = Logger.new({ Level = Logger.Levels.INFO.Level })
local database = Logger.new({ Separator = " | ", LineNumber = false })

network.info("Connected")
database.warn("Retrying query")
```

Each new logger starts from the built-in defaults, independently of changes to
the default logger or other instances. Options use the configuration fields
below. A `Levels` option merges per-level settings into a fresh level table:

```lua
local network = Logger.new({ Levels = { INFO = { Prefix = "[NETWORK]" } } })
```

## configuration

Set options directly on `Logger` or pass them to `Logger.new(options)`. The
default output is the UTC timestamp, level prefix, caller line, and message
arguments, in that order. Enabling function names inserts the caller's name
before its line number:

```text
[2026-11-07T12:34:56Z] [INFO] connect() :123 Connected
```

| Option | Default | Behavior |
| --- | --- | --- |
| `Level` | `10` | Minimum level to emit. Use `Logger.Levels.INFO.Level`, for example. |
| `Prefix` | `true` | Include the level's prefix. Customize individual prefixes through `Logger.Levels.INFO.Prefix`, etc.; set one to `nil` to omit it. |
| `Timestamp` | `true` | Include the formatted timestamp in brackets. Set to `false` to omit it. |
| `TimestampFormat` | `"!%Y-%m-%dT%H:%M:%SZ"` | An `os.date` string format. The default is ISO 8601 in UTC; a leading `!` selects UTC. |
| `LineNumber` | `true` | Include the caller's line as `:123`, when available. |
| `FunctionName` | `false` | Include the caller's function name as `connect()`, when available. Anonymous or unnamed callers omit this field. |
| `Separator` | `nil` | A string used to join prefixes, lines, and arguments. `nil` preserves native argument forwarding to `print`/`warn`; error messages use a space. An empty string joins without spacing. |
| `Formatter` | `nil` | Optional `function(entry): string` that returns the entire message layout for every level. |
| `Traceback` | `true` | Append the caller's traceback to error messages, after formatting. |
| `Output` | `"console"` | `"console"`, `"file"`, or `"both"`. File output requires the environment's `writefile` function. |
| `FilePath` | `"rolog.log"` | File path passed to `writefile`, relative to the host environment's workspace. Parent directories must already exist. |

```lua
Logger.Timestamp = false
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
`error` always builds a string. When console output is enabled, it raises that
string in a spawned task, so the console error does not stop the calling thread.
`Traceback = false` removes the appended caller trace; Roblox may still display
the spawned task's own error stack.

A custom formatter receives these fields:

| Field | Value |
| --- | --- |
| `Level` | `"DEBUG"`, `"INFO"`, `"WARN"`, or `"ERROR"`. |
| `Prefix` | The configured level prefix, or `nil` when disabled. |
| `Timestamp` | The formatted timestamp without brackets, or `nil` when disabled. |
| `LineNumber` | The caller's line number, or `nil` when disabled or unavailable. |
| `FunctionName` | The caller's name without parentheses, or `nil` when disabled or unavailable. |
| `Message` | Only the message arguments, converted to strings and joined using `Separator` (a space when `nil`). |

```lua
Logger.Timestamp = true
Logger.LineNumber = true
Logger.Separator = " "
Logger.Formatter = function(entry)
	local location = entry.LineNumber and (":" .. entry.LineNumber) or ""
	return entry.Timestamp .. " " .. entry.Level .. location .. " - " .. entry.Message
end

Logger.info("Hello", "World") -- 2026-11-07T12:34:56Z INFO:123 - Hello World
```

The formatter replaces the default prefix/line layout. Filtered messages do not
invoke it. Set `Logger.Formatter = nil` and `Logger.Separator = nil` to restore
native argument forwarding.

## file output

Use file output only in environments that provide `writefile(path, contents)`:

```lua
local fileLogger = Logger.new({
	Output = "file",
	FilePath = "session.log",
	FunctionName = true,
})

local function connect()
	fileLogger.info("Connected")
end
connect()

fileLogger.Output = "both" -- send subsequent logs to the file and console
fileLogger.warn("Retrying")
```

Every emitted message is written immediately with a trailing newline, using the
same formatting options and custom formatter as console output. File output
stringifies values and uses a space when `Separator` is `nil`. Error records
include the caller traceback when `Traceback` is enabled; file-only mode does
not spawn a console error.

Because `writefile` replaces file contents, the logger keeps this module
session's history in memory and rewrites it on every message. **The first write
to each path replaces any existing file.** Choose a new path to keep a previous
session's logs. History grows with the log size. Instances from the same loaded
module that use the same path share this history, and yielding writes to that
path are serialized. Different paths have separate histories. Changing a path
and switching back resumes its history; outside changes to the file are not
read back. Only `writefile` is required from the host's filesystem API.

Default console logging works without `writefile`. Explicit file output raises
a clear error if `writefile` is unavailable or the path is empty. Filesystem
errors propagate to the caller, including for `Logger.error`; failed writes
do not add the failed record to the in-memory history. In `"both"` mode the
file is written before console output. Filtered messages do not write files.

## tests

Install the standalone [Luau CLI](https://github.com/luau-lang/luau/releases), then run:

```sh
python3 tests/run.py
```

You can also pass the path to the CLI: `python3 tests/run.py /path/to/luau`.
The tests use Luau's debug library and mock Roblox output, task scheduling, and
the host's filesystem API. They cover isolated instances, timestamps, caller
names, formatting, filtering, file failures, and concurrent writes.
