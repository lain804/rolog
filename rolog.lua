local Logger = (function() local Logger = {
	LevelsInfo = {
		DEBUG = { level = 10, prefix = "[DEBUG]" },
		INFO = { level = 20, prefix = "[INFO]" },
		WARN = { level = 30, prefix = "[WARNING]" },
		ERROR = { level = 40, prefix = "[ERROR]" },
	},

	traceback = true,
	lineNumber = true,
	level = 10,
}

local function prepend(t, value)
	table.insert(t, 1, value)
end

local function shouldLog(levelInfo)
	return Logger.level <= levelInfo.level
end

local function addPrefixAndLine(args, levelInfo, stackLevel)
	if Logger.lineNumber then
		local line = debug.getinfo(stackLevel, "l").currentline
		prepend(args, ":" .. tostring(line))
	end

	if levelInfo.prefix then
		prepend(args, levelInfo.prefix)
	end
end

local function log(levelName, outputFn, stackLevel, ...)
	local levelInfo = Logger.LevelsInfo[levelName]

	if not shouldLog(levelInfo) then
		return
	end

	local args = { ... }
	addPrefixAndLine(args, levelInfo, stackLevel)

	outputFn(table.unpack(args))
end

function Logger.debug(...)
	log("DEBUG", print, 3, ...)
end

function Logger.info(...)
	log("INFO", print, 3, ...)
end

function Logger.warn(...)
	log("WARN", warn, 3, ...)
end

function Logger.error(...)
	local levelInfo = Logger.LevelsInfo.ERROR

	if not shouldLog(levelInfo) then
		return
	end

	local args = { ... }

	if levelInfo.prefix then
		prepend(args, levelInfo.prefix)
	end

	for i, value in args do
		args[i] = tostring(value)
	end

    local message = table.concat(args, " ")

    if Logger.traceback then
        local traceback = debug.traceback(nil, 2)
        message = message .. "\n" .. traceback
    end

    task.spawn(function()
        error(message, 0)
    end)
end

return Logger end)()

Logger.debug("test")
