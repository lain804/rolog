local Logger = {
	Levels = {
		DEBUG = { Level = 10, Prefix = "[DEBUG]" },
		INFO = { Level = 20, Prefix = "[INFO]" },
		WARN = { Level = 30, Prefix = "[WARNING]" },
		ERROR = { Level = 40, Prefix = "[ERROR]" },
	},

	Traceback = true,
	LineNumber = true,
	Prefix = true,
	Separator = nil,
	Formatter = nil,
	Level = 10,
}

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

local function getCallerLine()
	if not Logger.LineNumber then
		return nil
	end

	local callerLine = debug.info(3, "l")
	return callerLine and callerLine > 0 and callerLine or nil
end

local function addPrefixAndLine(args, levelInfo, callerLine)
	if Logger.LineNumber and callerLine then
		prepend(args, ":" .. tostring(callerLine))
	end

	if Logger.Prefix and levelInfo.Prefix then
		prepend(args, levelInfo.Prefix)
	end
end

local function joinArgs(args)
	local parts = {}
	for i = 1, args.n do
		parts[i] = tostring(args[i])
	end
	return table.concat(parts, Logger.Separator or " ")
end

local function formatArgs(args, levelName, levelInfo, callerLine)
	if Logger.Formatter then
		local message = Logger.Formatter({
			Level = levelName,
			Prefix = Logger.Prefix and levelInfo.Prefix or nil,
			LineNumber = callerLine,
			Message = joinArgs(args),
		})
		assert(type(message) == "string", "Logger.Formatter must return a string")
		return table.pack(message)
	end

	addPrefixAndLine(args, levelInfo, callerLine)
	if Logger.Separator ~= nil then
		return table.pack(joinArgs(args))
	end
	return args
end

local function log(levelName, outputFn, callerLine, ...)
	local levelInfo = Logger.Levels[levelName]

	if not shouldLog(levelInfo) then
		return
	end

	local args = formatArgs(table.pack(...), levelName, levelInfo, callerLine)

	outputFn(table.unpack(args, 1, args.n))
end

function Logger.debug(...)
	log("DEBUG", print, getCallerLine(), ...)
end

function Logger.info(...)
	log("INFO", print, getCallerLine(), ...)
end

function Logger.warn(...)
	log("WARN", warn, getCallerLine(), ...)
end

function Logger.error(...)
	local levelInfo = Logger.Levels.ERROR

	if not shouldLog(levelInfo) then
		return
	end

	local args = formatArgs(table.pack(...), "ERROR", levelInfo, getCallerLine())
	local message = joinArgs(args)

	if Logger.Traceback then
		local traceback = debug.traceback(nil, 2)
		message = message .. "\n" .. traceback
	end

	task.spawn(function()
		error(message, 0)
	end)
end

return Logger
