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

	if levelInfo.Prefix then
		prepend(args, levelInfo.Prefix)
	end
end

local function log(levelName, outputFn, callerLine, ...)
	local levelInfo = Logger.Levels[levelName]

	if not shouldLog(levelInfo) then
		return
	end

	local args = table.pack(...)
	addPrefixAndLine(args, levelInfo, callerLine)

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

	local args = table.pack(...)
	addPrefixAndLine(args, levelInfo, getCallerLine())

	for i = 1, args.n do
		args[i] = tostring(args[i])
	end

	local message = table.concat(args, " ", 1, args.n)

	if Logger.Traceback then
		local traceback = debug.traceback(nil, 2)
		message = message .. "\n" .. traceback
	end

	task.spawn(function()
		error(message, 0)
	end)
end

return Logger
