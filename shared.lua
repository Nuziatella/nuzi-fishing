local api = require("api")
local Core = api._NuziCore or require("nuzi-core/core")
local Constants = require("nuzi-fishing/constants")

local Log = Core.Log
local Runtime = Core.Runtime
local Settings = Core.Settings

local logger = Log.Create(Constants.ADDON_NAME or "Nuzi Fishing")

local Shared = {
    settings = nil
}

local function ensureSessionLog(settings)
    local changed = false

    if type(settings.session_log) ~= "table" then
        settings.session_log = {
            active = false,
            current = {},
            saved = {},
            next_id = 1
        }
        changed = true
    end

    local log = settings.session_log
    if type(log.saved) ~= "table" then
        log.saved = {}
        changed = true
    end
    if type(log.current) ~= "table" then
        log.current = {}
        changed = true
    end

    local active = log.active and true or false
    if log.active ~= active then
        log.active = active
        changed = true
    end

    local nextId = tonumber(log.next_id) or 1
    if log.next_id ~= nextId then
        log.next_id = nextId
        changed = true
    end

    return log, changed
end

local function normalizeHudMode(settings)
    local mode = string.lower(tostring(settings.hud_mode or "full"))
    if mode ~= "compact" then
        mode = "full"
    end
    local changed = settings.hud_mode ~= mode
    settings.hud_mode = mode
    return changed
end

local store = Settings.CreateAddonStore(Constants, {
    read_mode = "serialized_then_flat",
    write_mode = "serialized_then_flat",
    read_raw_text_fallback = true,
    write_mirror_paths = {
        Constants.LEGACY_SETTINGS_FILE_PATH
    },
    prune_unknown = true,
    skip_empty_default_tables = true,
    normalize = function(settings)
        local changed = false
        if normalizeHudMode(settings) then
            changed = true
        end
        local _, sessionChanged = ensureSessionLog(settings)
        if sessionChanged then
            changed = true
        end
        return changed
    end,
    log_name = Constants.ADDON_NAME or "Nuzi Fishing"
})

Shared.store = store
Shared.GetUiNowMs = Runtime.GetUiNowMs

function Shared.GetStore()
    return store
end

function Shared.LoadSettings()
    local settings = store:Load()
    Shared.settings = settings
    return settings
end

function Shared.EnsureSettings()
    local settings = store:Ensure()
    Shared.settings = settings
    return settings
end

function Shared.SaveSettings()
    local settings = Shared.EnsureSettings()
    local ok = store:Save()
    Shared.settings = settings
    if not ok then
        logger:Err("Failed to save settings.")
    end
    return ok
end

function Shared.ToggleSetting(key)
    local settings = Shared.EnsureSettings()
    settings[key] = not settings[key]
    Shared.SaveSettings()
    return settings[key]
end

function Shared.GetSessionLog()
    local settings = Shared.EnsureSettings()
    local log = ensureSessionLog(settings)
    return log
end

function Shared.GetActiveFishingSession()
    local log = Shared.GetSessionLog()
    if not log.active or Runtime.IsEmptyTable(log.current) then
        return nil
    end
    return log.current
end

function Shared.GetSavedFishingSessions()
    local log = Shared.GetSessionLog()
    return log.saved
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

function Shared.StartFishingSession(nowMs)
    local log = Shared.GetSessionLog()
    if log.active and not Runtime.IsEmptyTable(log.current) then
        return log.current
    end
    local id = tonumber(log.next_id) or 1
    log.next_id = id + 1
    log.active = true
    log.current = {
        id = id,
        title = buildSessionLabel(id),
        started_ms = tonumber(nowMs) or Shared.GetUiNowMs(),
        catches = 0,
        fish_counts = {}
    }
    Shared.SaveSettings()
    return log.current
end

function Shared.EndFishingSession(nowMs)
    local log = Shared.GetSessionLog()
    if not log.active or Runtime.IsEmptyTable(log.current) then
        return nil
    end
    local finished = log.current
    local endMs = tonumber(nowMs) or Shared.GetUiNowMs()
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
    if not log.active or Runtime.IsEmptyTable(log.current) then
        return false
    end
    local current = log.current
    current.catches = (tonumber(current.catches) or 0) + 1
    current.last_catch_ms = tonumber(nowMs) or Shared.GetUiNowMs()
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
