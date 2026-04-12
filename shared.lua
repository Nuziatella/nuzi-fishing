local api = require("api")
local Constants = require("nuzi-fishing/constants")

local Shared = {
    settings = nil
}

local function readTableFile(path)
    if api.File == nil or api.File.Read == nil then
        return nil
    end
    local ok, value = pcall(function()
        return api.File:Read(path)
    end)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

local function writeTableFile(path, value)
    if api.File == nil or api.File.Write == nil or type(value) ~= "table" then
        return false
    end
    local ok = pcall(function()
        api.File:Write(path, value)
    end)
    return ok
end

local function isEmptyTable(value)
    if type(value) ~= "table" then
        return false
    end
    for _ in pairs(value) do
        return false
    end
    return true
end

local function pruneUnknown(into, defaults)
    local changed = false
    for key, value in pairs(into) do
        local defaultValue = defaults[key]
        if defaultValue == nil then
            into[key] = nil
            changed = true
        elseif type(value) == "table" and type(defaultValue) == "table" and not isEmptyTable(defaultValue) then
            if pruneUnknown(value, defaultValue) then
                changed = true
            end
        end
    end
    return changed
end

local function copyDefaults(into, defaults)
    local changed = false
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(into[key]) ~= "table" then
                into[key] = {}
                changed = true
            end
            if copyDefaults(into[key], value) then
                changed = true
            end
        elseif into[key] == nil then
            into[key] = value
            changed = true
        end
    end
    return changed
end

local function ensureSessionLog(settings)
    if type(settings.session_log) ~= "table" then
        settings.session_log = {
            active = false,
            current = {},
            saved = {},
            next_id = 1
        }
    end
    local log = settings.session_log
    if type(log.saved) ~= "table" then
        log.saved = {}
    end
    if type(log.current) ~= "table" then
        log.current = {}
    end
    log.active = log.active and true or false
    log.next_id = tonumber(log.next_id) or 1
    return log
end

local function getUiNowMs()
    if api.Time ~= nil and api.Time.GetUiMsec ~= nil then
        local ok, value = pcall(function()
            return api.Time:GetUiMsec()
        end)
        if ok and value ~= nil then
            return tonumber(value) or 0
        end
    end
    return 0
end

local function buildSessionLabel(id)
    local timestamp = nil
    if type(os) == "table" and type(os.date) == "function" then
        local ok, value = pcall(function()
            return os.date("%Y-%m-%d %H:%M")
        end)
        if ok and type(value) == "string" then
            timestamp = value
        end
    end
    if timestamp ~= nil and timestamp ~= "" then
        return timestamp
    end
    return "Session " .. tostring(id)
end

function Shared.LoadSettings()
    local settings = readTableFile(Constants.SETTINGS_FILE_PATH)
    local migrated = false
    if type(settings) ~= "table" then
        settings = readTableFile(Constants.LEGACY_SETTINGS_FILE_PATH)
        if type(settings) == "table" then
            migrated = true
        end
    end
    if type(settings) ~= "table" then
        settings = api.GetSettings(Constants.ADDON_ID) or {}
    end
    local changed = pruneUnknown(settings, Constants.DEFAULT_SETTINGS)
    if copyDefaults(settings, Constants.DEFAULT_SETTINGS) then
        changed = true
    end
    ensureSessionLog(settings)
    Shared.settings = settings
    if changed or migrated then
        Shared.SaveSettings()
    end
    return Shared.settings
end

function Shared.EnsureSettings()
    if Shared.settings == nil then
        return Shared.LoadSettings()
    end
    return Shared.settings
end

function Shared.SaveSettings()
    local settings = Shared.EnsureSettings()
    writeTableFile(Constants.SETTINGS_FILE_PATH, settings)
    if api.SaveSettings ~= nil then
        api.SaveSettings()
    end
end

function Shared.ToggleSetting(key)
    local settings = Shared.EnsureSettings()
    settings[key] = not settings[key]
    Shared.SaveSettings()
    return settings[key]
end

function Shared.GetUiNowMs()
    return getUiNowMs()
end

function Shared.GetSessionLog()
    local settings = Shared.EnsureSettings()
    return ensureSessionLog(settings)
end

function Shared.GetActiveFishingSession()
    local log = Shared.GetSessionLog()
    if not log.active or isEmptyTable(log.current) then
        return nil
    end
    return log.current
end

function Shared.GetSavedFishingSessions()
    local log = Shared.GetSessionLog()
    return log.saved
end

function Shared.StartFishingSession(nowMs)
    local log = Shared.GetSessionLog()
    if log.active and not isEmptyTable(log.current) then
        return log.current
    end
    local id = tonumber(log.next_id) or 1
    log.next_id = id + 1
    log.active = true
    log.current = {
        id = id,
        title = buildSessionLabel(id),
        started_ms = tonumber(nowMs) or getUiNowMs(),
        catches = 0,
        fish_counts = {}
    }
    Shared.SaveSettings()
    return log.current
end

function Shared.EndFishingSession(nowMs)
    local log = Shared.GetSessionLog()
    if not log.active or isEmptyTable(log.current) then
        return nil
    end
    local finished = log.current
    local endMs = tonumber(nowMs) or getUiNowMs()
    finished.ended_ms = endMs
    finished.duration_ms = math.max(0, endMs - (tonumber(finished.started_ms) or endMs))
    finished.active = false
    table.insert(log.saved, 1, finished)
    while #log.saved > 12 do
        table.remove(log.saved)
    end
    log.current = {}
    log.active = false
    Shared.SaveSettings()
    return finished
end

function Shared.DeleteFishingSession(sessionId)
    local log = Shared.GetSessionLog()
    local id = tonumber(sessionId)
    if id == nil then
        return false
    end
    for index = #log.saved, 1, -1 do
        local session = log.saved[index]
        if tonumber(session ~= nil and session.id or nil) == id then
            table.remove(log.saved, index)
            Shared.SaveSettings()
            return true
        end
    end
    return false
end

function Shared.RecordFishingCatch(fishName, nowMs)
    local log = Shared.GetSessionLog()
    if not log.active or isEmptyTable(log.current) then
        return false
    end
    local current = log.current
    current.catches = (tonumber(current.catches) or 0) + 1
    current.last_catch_ms = tonumber(nowMs) or getUiNowMs()
    if type(current.fish_counts) ~= "table" then
        current.fish_counts = {}
    end
    local key = tostring(fishName or "Unknown Fish")
    current.fish_counts[key] = (tonumber(current.fish_counts[key]) or 0) + 1
    Shared.SaveSettings()
    return true
end

function Shared.GetFishSizeLabel(maxHealth)
    local health = tonumber(maxHealth)
    if health == nil then
        return ""
    end
    if health < Constants.FRY_MAX_HP then
        return "Fry"
    end
    if health > Constants.GARGANTUAN_MIN_HP then
        return "Gargantuan"
    end
    return ""
end

function Shared.FormatFishCatchName(fishName, maxHealth)
    local baseName = tostring(fishName or "")
    if baseName == "" then
        baseName = "Unknown Fish"
    end
    local sizeLabel = Shared.GetFishSizeLabel(maxHealth)
    if sizeLabel == "" then
        return baseName
    end
    return string.format("%s %s", sizeLabel, baseName)
end

function Shared.FormatSeconds(seconds, decimals)
    local value = tonumber(seconds) or 0
    if value < 0 then
        value = 0
    end
    if decimals == 0 then
        return string.format("%.0fs", value)
    end
    return string.format("%.1fs", value)
end

function Shared.FormatDurationMs(durationMs)
    local totalSeconds = math.max(0, math.floor((tonumber(durationMs) or 0) / 1000))
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return string.format("%02d:%02d", minutes, seconds)
end

return Shared
