local api = require("api")

local function loadModule(name)
    local ok, mod = pcall(require, "nuzi-fishing/" .. name)
    if ok then
        return mod
    end
    ok, mod = pcall(require, "nuzi-fishing." .. name)
    if ok then
        return mod
    end
    return nil
end

local Constants = loadModule("constants")
local Shared = loadModule("shared")
local Tracker = loadModule("tracker")
local Ui = loadModule("ui")

local addon = {
    name = Constants ~= nil and Constants.ADDON_NAME or "Nuzi Fishing",
    author = Constants ~= nil and Constants.ADDON_AUTHOR or "Nuzi",
    version = Constants ~= nil and Constants.ADDON_VERSION or "1.2.0",
    desc = Constants ~= nil and Constants.ADDON_DESC or "Sport fishing helper"
}

local updateElapsedMs = 0

local function modulesReady()
    return Constants ~= nil and Shared ~= nil and Tracker ~= nil and Ui ~= nil
end

local function normalizeDeltaMs(dt)
    local value = tonumber(dt) or 0
    if value < 0 then
        value = 0
    end
    if value > 0 and value < 5 then
        value = value * 1000
    end
    return value
end

local function renderNow()
    Ui.Render(Tracker.GetUiState())
end

local function onUpdate(dt)
    if not modulesReady() then
        return
    end

    updateElapsedMs = updateElapsedMs + normalizeDeltaMs(dt)
    if updateElapsedMs < Constants.UPDATE_INTERVAL_MS then
        return
    end
    updateElapsedMs = 0

    local settings = Shared.EnsureSettings()
    if not settings.enabled then
        Ui.HideHud()
        return
    end

    Ui.Render(Tracker.Update(Constants.UPDATE_INTERVAL_MS))
end

local function onUiReloaded()
    if not modulesReady() then
        return
    end

    updateElapsedMs = 0
    Tracker.Reset()
    Ui.Unload()
    Ui.Init({
        on_settings_changed = renderNow
    })
    renderNow()
end

local function onUpdateBindings()
    if Tracker ~= nil and Tracker.InvalidateHotkeys ~= nil then
        Tracker.InvalidateHotkeys()
    end
    renderNow()
end

local function onLoad()
    if not modulesReady() then
        if api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi Fishing] Failed to load one or more modules.")
        end
        return
    end

    Shared.LoadSettings()
    Tracker.Reset()
    Ui.Init({
        on_settings_changed = renderNow
    })
    renderNow()
    api.On("UPDATE", onUpdate)
    api.On("UI_RELOADED", onUiReloaded)
    pcall(function()
        api.On("UPDATE_BINDINGS", onUpdateBindings)
    end)
    if api.Log ~= nil and api.Log.Info ~= nil then
        api.Log:Info("[Nuzi Fishing] Loaded v" .. tostring(addon.version))
    end
end

local function onUnload()
    api.On("UPDATE", function() end)
    api.On("UI_RELOADED", function() end)
    pcall(function()
        api.On("UPDATE_BINDINGS", function() end)
    end)
    if Ui ~= nil then
        Ui.Unload()
    end
    if Tracker ~= nil then
        Tracker.Reset()
    end
end

local function onSettingToggle()
    if Ui ~= nil then
        Ui.ToggleSettings()
    end
end

addon.OnLoad = onLoad
addon.OnUnload = onUnload
addon.OnSettingToggle = onSettingToggle

return addon
