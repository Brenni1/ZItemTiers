local version = 1.3
if type(ZBLogger_VERSION) == "number" and ZBLogger_VERSION >= version then return end

print("ZBLogger v" .. tostring(version) .. " init")
ZBLogger_VERSION = version

ZBLogger = {} -- intentionally not using 'ZBLogger = ZBLogger or {}' to avoid cross-version method pollution

ZBLogger.DEBUG = 1
ZBLogger.INFO  = 2
ZBLogger.WARN  = 3
ZBLogger.ERROR = 4

ZBLogger.DEFAULT_LEVEL = ZBLogger.INFO

local prefix_tbl = {
    [ZBLogger.DEBUG] = "[d] ",
    [ZBLogger.INFO]  = "[.] ",
    [ZBLogger.WARN]  = "[?] ",
    [ZBLogger.ERROR] = "[!] ",
}

local function try_serialize(obj)
    if type(serialize) ~= "function" then
        return tostring(obj) -- serialize not available, fallback to simple tostring
    end
    local serialized = serialize(obj)
    if type(serialized) ~= "string" or #serialized > 100 then
        return tostring(obj) -- fallback to simple tostring if serialization is too long
    end
    return serialized
end

function ZBLogger:print(level, fmt, ...)
    if self.level > level then return end

    local prefix = prefix_tbl[level] or prefix_tbl[ZBLogger.WARN]
    if self.id then
        prefix = prefix .. "[" .. self.id .. "] "
    end

    -- add syntax sugar: "%s" prints table contents / function names / boolean values / etc
    local args = { ... }
    for i = 1, select('#', ...) do -- select() handles nils in varargs
        local arg = select(i, ...)
        local arg_type = type(arg)
        if arg_type == "number" or arg_type == "string" then
            -- do nothing
        elseif arg_type == "function" and ZombieBuddy and ZombieBuddy.getCallableInfo then
            local cinfo = ZombieBuddy.getCallableInfo(arg)
            if cinfo and cinfo.name then
                args[i] = "function " .. tostring(cinfo.name) .. "()"
            else
                args[i] = try_serialize(arg)
            end
        elseif instanceof(arg, "IsoGridSquare") then
            local sq = arg
            args[i] = string.format("IsoGridSquare(%d, %d, %d)", sq:getX(), sq:getY(), sq:getZ())
        else
            args[i] = try_serialize(arg)
        end
    end

    local success = pcall(function()
        print(prefix .. string.format(fmt, unpack(args)))
    end)
    if not success then
        print("prefix: ", prefix, "fmt:", fmt, "args: ", serialize(args))
    end
end

function ZBLogger:debug(...) self:print(ZBLogger.DEBUG, ...) end
function ZBLogger:info(...)  self:print(ZBLogger.INFO,  ...) end
function ZBLogger:warn(...)  self:print(ZBLogger.WARN,  ...) end
function ZBLogger:error(...) self:print(ZBLogger.ERROR, ...) end

local _loggers = {}

function ZBLogger.new(id, level)
    local logger = _loggers[id]
    if logger then
        if level and level < logger.level then
            logger.level = level -- only update level if it's more verbose than the existing one
        end
        return logger
    end

    logger = {}
    logger.id    = id
    logger.level = level or ZBLogger.DEFAULT_LEVEL
    setmetatable(logger, { __index = ZBLogger })
    _loggers[id] = logger

    return logger
end
