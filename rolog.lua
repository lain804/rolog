local files = {}

local function new(options)
	local Logger = {
		Levels = {
			DEBUG = { Level = 10, Prefix = "[DEBUG]" },
			INFO = { Level = 20, Prefix = "[INFO]" },
			WARN = { Level = 30, Prefix = "[WARNING]" },
			ERROR = { Level = 40, Prefix = "[ERROR]" },
		},

		Traceback = true,
		Timestamp = true,
		TimestampFormat = "!%Y-%m-%dT%H:%M:%SZ",
		LineNumber = true,
		FunctionName = false,
		Prefix = true,
		Separator = nil,
		Formatter = nil,
		Output = "console",
		FilePath = "rolog.log",
		Level = 10,
	}

	if options then
		for option, value in options do
			if option == "Levels" then
				for levelName, settings in value do
					assert(Logger.Levels[levelName], "Unknown log level: " .. tostring(levelName))
					for setting, settingValue in settings do
						Logger.Levels[levelName][setting] = settingValue
					end
				end
			else
				Logger[option] = value
			end
		end
	end

	local function prepend(t, value)
		for i = t.n, 1, -1 do
			t[i + 1] = t[i]
		end
		t[1] = value
		t.n = t.n + 1
	end

	local function shouldLog(levelInfo)
		return Logger.Level <= levelInfo.Level
	end

	local function getCallerInfo()
		if not Logger.LineNumber and not Logger.FunctionName then
			return nil, nil
		end

		local callerLine, callerName = debug.info(3, "ln")
		return Logger.LineNumber and callerLine and callerLine > 0 and callerLine or nil,
			Logger.FunctionName and callerName and callerName ~= "" and callerName or nil
	end

	local function addMetadata(args, levelInfo, callerLine, callerName, timestamp)
		if callerLine then
			prepend(args, ":" .. tostring(callerLine))
		end

		if callerName then
			prepend(args, callerName .. "()")
		end

		if Logger.Prefix and levelInfo.Prefix then
			prepend(args, levelInfo.Prefix)
		end

		if timestamp then
			prepend(args, "[" .. timestamp .. "]")
		end
	end

	local function joinArgs(args)
		local parts = {}
		for i = 1, args.n do
			parts[i] = tostring(args[i])
		end
		return table.concat(parts, Logger.Separator or " ")
	end

	local function formatArgs(args, levelName, levelInfo, callerLine, callerName)
		local timestamp
		if Logger.Timestamp then
			timestamp = os.date(Logger.TimestampFormat)
			assert(type(timestamp) == "string", "Logger.TimestampFormat must produce a string")
		end

		if Logger.Formatter then
			local message = Logger.Formatter({
				Level = levelName,
				Prefix = Logger.Prefix and levelInfo.Prefix or nil,
				Timestamp = timestamp,
				LineNumber = callerLine,
				FunctionName = callerName,
				Message = joinArgs(args),
			})
			assert(type(message) == "string", "Logger.Formatter must return a string")
			return table.pack(message)
		end

		addMetadata(args, levelInfo, callerLine, callerName, timestamp)
		if Logger.Separator ~= nil then
			return table.pack(joinArgs(args))
		end
		return args
	end

	local function writeToFile(message)
		local writer = writefile
		assert(type(writer) == "function", "File logging requires writefile in this environment")
		local path = Logger.FilePath
		assert(type(path) == "string" and path ~= "", "Logger.FilePath must be a non-empty string")

		local file = files[path]
		if not file then
			file = { Content = "", Writing = false }
			files[path] = file
		end

		-- Share history and serialize yielding writes across instances using this path.
		while file.Writing do
			task.wait()
		end
		local content = file.Content .. message .. "\n"
		file.Writing = true
		local success, messageOrError = pcall(writer, path, content)
		if success then
			file.Content = content
		end
		file.Writing = false
		if not success then
			error(messageOrError, 0)
		end
	end

	local function emit(args, outputFn)
		local output = Logger.Output
		assert(output == "console" or output == "file" or output == "both",
			"Logger.Output must be console, file, or both")
		if output ~= "console" then
			writeToFile(joinArgs(args))
		end
		if output ~= "file" then
			outputFn(table.unpack(args, 1, args.n))
		end
	end

	local function log(levelName, outputFn, callerLine, callerName, ...)
		local levelInfo = Logger.Levels[levelName]

		if not shouldLog(levelInfo) then
			return
		end

		local args = formatArgs(table.pack(...), levelName, levelInfo, callerLine, callerName)

		emit(args, outputFn)
	end

	function Logger.debug(...)
		local callerLine, callerName = getCallerInfo()
		log("DEBUG", print, callerLine, callerName, ...)
	end

	function Logger.info(...)
		local callerLine, callerName = getCallerInfo()
		log("INFO", print, callerLine, callerName, ...)
	end

	function Logger.warn(...)
		local callerLine, callerName = getCallerInfo()
		log("WARN", warn, callerLine, callerName, ...)
	end

	function Logger.error(...)
		local levelInfo = Logger.Levels.ERROR

		if not shouldLog(levelInfo) then
			return
		end

		local callerLine, callerName = getCallerInfo()
		local args = formatArgs(table.pack(...), "ERROR", levelInfo, callerLine, callerName)
		local message = joinArgs(args)

		if Logger.Traceback then
			local traceback = debug.traceback(nil, 2)
			message = message .. "\n" .. traceback
		end

		emit(table.pack(message), function(errorMessage)
			task.spawn(function()
				error(errorMessage, 0)
			end)
		end)
	end

	Logger.new = new
	return Logger
end

return new()
