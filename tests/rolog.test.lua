return function(createLogger)
	local function equal(actual, expected)
		assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end

	local function setup()
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
		return createLogger(environment), calls, environment
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

	print("All logger tests passed")
end
