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

	print("All logger tests passed")
end
