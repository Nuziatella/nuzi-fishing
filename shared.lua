local api = require("api")
local Constants = require("nuzi-fishing/constants")

local Shared = {
    settings = nil
}

local function pruneUnknown(into, defaults)
    local changed = false
    for key, value in pairs(into) do
        local defaultValue = defaults[key]
        if defaultValue == nil then
            into[key] = nil
            changed = true
        elseif type(value) == "table" and type(defaultValue) == "table" then
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

function Shared.LoadSettings()
    local settings = api.GetSettings(Constants.ADDON_ID) or {}
    local changed = pruneUnknown(settings, Constants.DEFAULT_SETTINGS)
    if copyDefaults(settings, Constants.DEFAULT_SETTINGS) then
        changed = true
    end
    Shared.settings = settings
    if changed then
        api.SaveSettings()
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
    api.SaveSettings()
end

function Shared.ToggleSetting(key)
    local settings = Shared.EnsureSettings()
    settings[key] = not settings[key]
    Shared.SaveSettings()
    return settings[key]
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

return Shared
