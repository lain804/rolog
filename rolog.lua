local Logger = {
	Levels = {
		DEBUG = { Level = 10, Prefix = "[DEBUG]" },
		INFO = { Level = 20, Prefix = "[INFO]" },
		WARN = { Level = 30, Prefix = "[WARNING]" },
		ERROR = { Level = 40, Prefix = "[ERROR]" },
	},

	Traceback = true,
	LineNumber = true,
	Level = 10,
}

local function prepend(t, value)
	table.insert(t, 1, value)
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

	if levelInfo.Prefix then
		prepend(args, levelInfo.Prefix)
	end
end

local function log(levelName, outputFn, callerLine, ...)
	local levelInfo = Logger.Levels[levelName]

	if not shouldLog(levelInfo) then
		return
	end

	local args = { ... }
	addPrefixAndLine(args, levelInfo, callerLine)

	outputFn(table.unpack(args))
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

	local args = { ... }
	addPrefixAndLine(args, levelInfo, getCallerLine())

	for i, value in args do
		args[i] = tostring(value)
	end

	local message = table.concat(args, " ")

	if Logger.Traceback then
		local traceback = debug.traceback(nil, 2)
		message = message .. "\n" .. traceback
	end

	task.spawn(function()
		error(message, 0)
	end)
end

return Logger
