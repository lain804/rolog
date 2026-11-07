return function(createLogger)
	local function equal(actual, expected)
		assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end

	local function setup(useDefaults)
		local calls = {}
		local function capture(kind, ...)
			table.insert(calls, { kind = kind, args = table.pack(...) })
		end
		local environment = setmetatable({
			print = function(...) capture("print", ...) end,
			warn = function(...) capture("warn", ...) end,
			task = {
				spawn = function(callback)
					local success, message = pcall(callback)
					assert(not success, "error logs must raise an error in the spawned task")
					capture("error", message)
				end,
			},
		}, { __index = getfenv() })
		local logger = createLogger(environment)
		-- Keep legacy formatting assertions independent of the new default timestamp.
		if not useDefaults then
			logger.Timestamp = false
		end
		return logger, calls, environment
	end

	-- Use the actual Luau debug library: Roblox does not have debug.getinfo.
	for _, method in { "debug", "info", "warn", "error" } do
		local logger, calls = setup()
		logger.Traceback = false
		local expectedLine = debug.info(1, "l") + 1
		logger[method]("hello")
		equal(#calls, 1)
		if method == "error" then
			equal(calls[1].args[1], "[ERROR] :" .. expectedLine .. " hello")
		else
			equal(calls[1].kind, method == "warn" and "warn" or "print")
			equal(calls[1].args[2], ":" .. expectedLine)
		end
	end

	do
		local logger, calls, environment = setup()
		logger.LineNumber = false
		-- Missing debug APIs should not matter when caller lines are disabled.
		environment.debug = {}
		logger.info("hello")
		equal(calls[1].args[1], "[INFO]")
		equal(calls[1].args[2], "hello")
	end

	do
		local logger, calls = setup()
		logger.Level = logger.Levels.WARN.Level
		logger.debug("hidden")
		logger.info("hidden")
		logger.warn("visible")
		logger.error("visible")
		equal(#calls, 2)
		equal(calls[1].kind, "warn")
		equal(calls[2].kind, "error")
		assert(string.find(calls[2].args[1], "\n", 1, true), "traceback should be appended")
	end

	for _, method in { "debug", "info", "warn", "error" } do
		for _, prefix in { true, false } do
			local logger, calls = setup()
			logger.Traceback = false
			logger.LineNumber = false
			if not prefix then
				for _, level in logger.Levels do
					level.Prefix = nil
				end
			end
			logger[method](nil, "middle", nil, false, nil)
			if method == "error" then
				equal(calls[1].args[1], (prefix and "[ERROR] " or "") .. "nil middle nil false nil")
			else
				local offset = prefix and 1 or 0
				equal(calls[1].args.n, 5 + offset)
				equal(calls[1].args[1 + offset], nil)
				equal(calls[1].args[2 + offset], "middle")
				equal(calls[1].args[3 + offset], nil)
				equal(calls[1].args[4 + offset], false)
				equal(calls[1].args[5 + offset], nil)
			end
		end
	end

	for _, method in { "debug", "info", "warn", "error" } do
		local logger, calls = setup()
		logger.Traceback = false
		logger.LineNumber = false
		logger.Prefix = false
		logger[method]()
		equal(calls[1].args.n, method == "error" and 1 or 0)
		if method == "error" then
			equal(calls[1].args[1], "")
		end
	end

	-- Opting into a separator stringifies every value, including nils.
	for _, method in { "debug", "info", "warn", "error" } do
		local logger, calls = setup()
		logger.Traceback = false
		logger.Separator = " | "
		for _, level in logger.Levels do
			level.Prefix = "[APP]"
		end
		local object = setmetatable({}, { __tostring = function() return "object" end })
		local expectedLine = debug.info(1, "l") + 1
		logger[method]("hello", nil, false, 42, object, nil)
		equal(calls[1].args.n, 1)
		equal(calls[1].args[1], "[APP] | :" .. expectedLine .. " | hello | nil | false | 42 | object | nil")

		logger.LineNumber = false
		logger.Prefix = false
		logger.Separator = ""
		logger[method]("hello", "world")
		equal(calls[2].args[1], "helloworld")
		logger[method]()
		equal(calls[3].args[1], "")
	end

	for _, method in { "debug", "info", "warn", "error" } do
		local logger, calls = setup()
		logger.Traceback = false
		logger.Separator = ", "
		local entries = {}
		logger.Formatter = function(entry)
			table.insert(entries, entry)
			return "custom: " .. entry.Message
		end
		local expectedLine = debug.info(1, "l") + 1
		logger[method]("hello", nil, false)
		equal(calls[1].args.n, 1)
		equal(calls[1].args[1], "custom: hello, nil, false")
		equal(entries[1].Level, string.upper(method))
		equal(entries[1].Prefix, logger.Levels[string.upper(method)].Prefix)
		equal(entries[1].LineNumber, expectedLine)

		logger.LineNumber = false
		logger.Prefix = false
		logger.Separator = nil
		logger[method](nil, "end")
		equal(calls[2].args[1], "custom: nil end")
		equal(entries[2].Prefix, nil)
		equal(entries[2].LineNumber, nil)

		logger.Formatter = nil
		logger[method]("plain")
		equal(calls[3].args[1], "plain")
	end

	do
		local logger, calls = setup()
		logger.LineNumber = false
		logger.Formatter = function() return "formatted error" end
		logger.error("hello")
		assert(string.sub(calls[1].args[1], 1, 16) == "formatted error\n", "traceback follows formatting")
		logger.Traceback = false
		logger.error("hello")
		equal(calls[2].args[1], "formatted error")
	end

	do
		local logger, calls, environment = setup()
		environment.debug = { info = function() return -1 end }
		logger.info("hello")
		equal(calls[1].args.n, 2)
		equal(calls[1].args[2], "hello")
	end

	do
		local logger, calls = setup()
		logger.Level = logger.Levels.ERROR.Level + 1
		logger.Formatter = function() error("filtered logs must not be formatted") end
		local object = setmetatable({}, { __tostring = function() error("filtered value must not be converted") end })
		logger.debug(object)
		logger.info(object)
		logger.warn(object)
		logger.error(object)
		equal(#calls, 0)
	end

	do
		local logger, calls = setup()
		logger.LineNumber = false
		logger.Prefix = false
		local object = {}
		logger.info(object, nil)
		equal(calls[1].args[1], object)
		equal(calls[1].args.n, 2)
	end

	do
		local logger = setup()
		logger.Formatter = function() return nil end
		local success, message = pcall(logger.info, "hello")
		equal(success, false)
		assert(string.find(message, "Logger.Formatter must return a string", 1, true))
	end

	do
		local logger, calls = setup()
		logger.Level = 100
		logger.Levels.INFO.Prefix = "[DEFAULT]"
		local options = {
			Level = 20,
			Timestamp = false,
			LineNumber = false,
			Separator = " | ",
			Levels = { INFO = { Prefix = "[FIRST]" } },
		}
		local first = logger.new(options)
		local second = logger.new({ LineNumber = false, Timestamp = false })
		first.info("one")
		second.info("two")
		logger.info("hidden")
		equal(#calls, 2)
		equal(calls[1].args[1], "[FIRST] | one")
		equal(calls[2].args[1], "[INFO]")
		equal(first.Levels.INFO.Level, 20)
		equal(second.Level, 10)
		equal(logger.Levels.INFO.Prefix, "[DEFAULT]")
		first.Levels.INFO.Prefix = "[CHANGED]"
		equal(options.Levels.INFO.Prefix, "[FIRST]")
		equal(second.Levels.INFO.Prefix, "[INFO]")
		equal(first.new().Levels.INFO.Prefix, "[INFO]")
		assert(first ~= second and first.Levels ~= second.Levels)
	end

	for _, method in { "debug", "info", "warn", "error" } do
		local logger, calls, environment = setup(true)
		equal(logger.Timestamp, true)
		equal(logger.new().Timestamp, true)
		logger.Traceback = false
		logger.FunctionName = true
		local dateCalls = 0
		environment.os = {
			date = function(format)
				equal(format, "!%Y-%m-%dT%H:%M:%SZ")
				dateCalls = dateCalls + 1
				return "2026-11-07T12:34:56Z"
			end,
		}
		local function caller()
			local expectedLine = debug.info(1, "l") + 1
			logger[method]("hello")
			return expectedLine
		end
		local line = caller()
		equal(dateCalls, 1)
		if method == "error" then
			equal(calls[1].args[1], "[2026-11-07T12:34:56Z] [ERROR] caller() :" .. line .. " hello")
		else
			equal(calls[1].args[1], "[2026-11-07T12:34:56Z]")
			equal(calls[1].args[2], logger.Levels[string.upper(method)].Prefix)
			equal(calls[1].args[3], "caller()")
			equal(calls[1].args[4], ":" .. line)
			equal(calls[1].args[5], "hello")
		end
		logger.Level = 100
		caller()
		equal(dateCalls, 1)
	end

	do
		local logger, calls, environment = setup(true)
		local formats = {}
		environment.os = {
			date = function(format)
				table.insert(formats, format)
				return "12:34:56"
			end,
		}
		logger.TimestampFormat = "!%H:%M:%S"
		logger.FunctionName = true
		logger.LineNumber = false
		local entries = {}
		logger.Formatter = function(entry)
			table.insert(entries, entry)
			return entry.Message
		end
		local function caller()
			logger.info("hello")
		end
		caller()
		equal(formats[1], "!%H:%M:%S")
		equal(entries[1].Timestamp, "12:34:56")
		equal(entries[1].FunctionName, "caller")
		equal(entries[1].LineNumber, nil)
		logger.Timestamp = false
		logger.FunctionName = false
		environment.debug = {}
		caller()
		equal(#formats, 1)
		equal(entries[2].Timestamp, nil)
		equal(entries[2].FunctionName, nil)
		equal(calls[2].args[1], "hello")
	end

	do
		local logger, calls, environment = setup(true)
		logger.FunctionName = true
		logger.LineNumber = false
		logger.Timestamp = false
		environment.debug = { info = function() return -1, "" end }
		logger.info("anonymous")
		equal(calls[1].args.n, 2)
		equal(calls[1].args[2], "anonymous")
	end

	do
		local logger, calls = setup(true)
		logger.LineNumber = false
		logger.info("real clock")
		assert(string.match(calls[1].args[1], "^%[%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ%]$"))
	end

	for _, output in { "file", "both" } do
		for _, method in { "debug", "info", "warn", "error" } do
			local logger, calls, environment = setup()
			logger.Output = output
			logger.FilePath = "test.log"
			logger.LineNumber = false
			logger.Traceback = false
			logger.Separator = " | "
			local content = "previous session\n"
			local writes = 0
			environment.writefile = function(path, data)
				equal(path, "test.log")
				content = data
				writes = writes + 1
			end
			logger[method]("hello", nil, false, nil)
			local prefix = logger.Levels[string.upper(method)].Prefix
			equal(content, prefix .. " | hello | nil | false | nil\n")
			logger[method]()
			equal(content, prefix .. " | hello | nil | false | nil\n" .. prefix .. "\n")
			equal(writes, 2)
			equal(#calls, output == "file" and 0 or 2)
			if output == "both" then
				equal(calls[1].kind, method == "error" and "error" or (method == "warn" and "warn" or "print"))
				equal(calls[1].args[1], prefix .. " | hello | nil | false | nil")
			end
		end
	end

	do
		local logger, calls, environment = setup()
		local storage = {}
		environment.writefile = function(path, data) storage[path] = data end
		local options = { Output = "file", FilePath = "shared.log", Timestamp = false, LineNumber = false, Prefix = false }
		local first = logger.new(options)
		local second = logger.new(options)
		first.info("first")
		second.warn("second")
		equal(storage["shared.log"], "first\nsecond\n")
		first.FilePath = "other.log"
		first.info("other")
		equal(storage["other.log"], "other\n")
		first.FilePath = "shared.log"
		first.info("third")
		equal(storage["shared.log"], "first\nsecond\nthird\n")
		equal(#calls, 0)
	end

	do
		local logger, calls, environment = setup(true)
		logger.Output = "both"
		logger.FunctionName = true
		environment.os = { date = function() return "timestamp" end }
		local content
		environment.writefile = function(_, data) content = data end
		logger.Formatter = function(entry)
			equal(entry.FunctionName, "caller")
			equal(entry.Timestamp, "timestamp")
			return entry.Timestamp .. " " .. entry.FunctionName .. " " .. entry.Message
		end
		local function caller()
			logger.error("hello")
		end
		caller()
		equal(content, calls[1].args[1] .. "\n")
		assert(string.sub(content, 1, 23) == "timestamp caller hello\n", "file output includes formatted message and traceback")
	end

	do
		local logger, calls, environment = setup()
		logger.Output = "file"
		environment.writefile = false
		local success, message = pcall(logger.info, "hello")
		equal(success, false)
		assert(string.find(message, "File logging requires writefile", 1, true))
		equal(#calls, 0)
		logger.Level = 100
		logger.Timestamp = true
		environment.os = { date = function() error("filtered logs must not read the clock") end }
		logger.debug("hidden")
		logger.info("hidden")
		logger.warn("hidden")
		logger.error("hidden")
		equal(#calls, 0)
	end

	for _, path in { "", false, 123 } do
		local logger, calls, environment = setup()
		logger.Output = "file"
		logger.FilePath = path
		environment.writefile = function() error("invalid paths must not be written") end
		local success, message = pcall(logger.info, "hello")
		equal(success, false)
		assert(string.find(message, "Logger.FilePath must be a non-empty string", 1, true))
		equal(#calls, 0)
	end

	do
		local logger, calls = setup()
		logger.Output = "invalid"
		local success, message = pcall(logger.info, "hello")
		equal(success, false)
		assert(string.find(message, "Logger.Output must be console, file, or both", 1, true))
		equal(#calls, 0)
	end

	do
		local logger, _, environment = setup()
		logger.Output = "file"
		logger.LineNumber = false
		logger.Prefix = false
		local writes = 0
		local content
		environment.writefile = function(_, data)
			writes = writes + 1
			if writes == 2 then error("disk full", 0) end
			content = data
		end
		logger.info("first")
		local success, message = pcall(logger.info, "failed")
		equal(success, false)
		equal(message, "disk full")
		equal(content, "first\n")
		logger.info("retry")
		equal(content, "first\nretry\n")
	end

	-- Some host filesystem functions yield; concurrent loggers must not lose records.
	do
		local logger, calls, environment = setup()
		local content
		environment.writefile = function(_, data)
			if data == "first\n" then coroutine.yield("writing") end
			content = data
		end
		environment.task.wait = function() coroutine.yield("waiting") end
		local options = { Output = "file", Timestamp = false, LineNumber = false, Prefix = false }
		local firstLogger = logger.new(options)
		local secondLogger = logger.new(options)
		local first = coroutine.create(function() firstLogger.info("first") end)
		local second = coroutine.create(function() secondLogger.info("second") end)
		local success, state = coroutine.resume(first)
		equal(success, true)
		equal(state, "writing")
		success, state = coroutine.resume(second)
		equal(success, true)
		equal(state, "waiting")
		-- Configuration changes apply to later calls, not a write already in progress.
		firstLogger.Output = "console"
		equal(coroutine.resume(first), true)
		equal(coroutine.resume(second), true)
		equal(coroutine.status(first), "dead")
		equal(coroutine.status(second), "dead")
		equal(content, "first\nsecond\n")
		equal(#calls, 0)
	end

	print("All logger tests passed")
end
