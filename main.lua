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
    version = Constants ~= nil and Constants.ADDON_VERSION or "1.4.0",
    desc = Constants ~= nil and Constants.ADDON_DESC or "Fishing coach HUD"
}

local updateElapsedMs = 0
local TARGETED_UPDATE_INTERVAL_MS = 100
local IDLE_UPDATE_INTERVAL_MS = 250

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

local function hasCurrentTarget()
    if api.Unit == nil or api.Unit.GetUnitId == nil then
        return false
    end

    local ok, targetId = pcall(function()
        return api.Unit:GetUnitId("target")
    end)
    return ok and targetId ~= nil
end

local function shouldUseFastUpdate(state)
    if type(state) ~= "table" then
        return false
    end

    local target = type(state.target) == "table" and state.target or nil
    if target == nil then
        return false
    end

    return target.visible
        or target.strength_visible
        or (type(target.icon_path) == "string" and target.icon_path ~= "")
        or (type(target.status_text) == "string" and target.status_text ~= "")
        or (type(target.coach_text) == "string" and target.coach_text ~= "")
        or (type(target.coach_hint) == "string" and target.coach_hint ~= "")
        or (type(target.timer_text) == "string" and target.timer_text ~= "")
end

local function shouldUseTargetedUpdate(state)
    if hasCurrentTarget() then
        return true
    end
    if type(state) ~= "table" then
        return false
    end

    local markers = type(state.markers) == "table" and state.markers or nil
    if markers ~= nil and #markers > 0 then
        return true
    end

    local catches = type(state.catches) == "table" and state.catches or nil
    if catches ~= nil and #catches > 0 then
        return true
    end

    local boat = type(state.boat) == "table" and state.boat or nil
    if boat ~= nil and boat.visible then
        return true
    end

    local session = type(state.session) == "table" and state.session or nil
    if session ~= nil and session.has_active then
        return true
    end

    return false
end

local function getUpdateIntervalMs()
    local state = nil
    if Tracker ~= nil and Tracker.GetUiState ~= nil then
        state = Tracker.GetUiState()
    end

    if shouldUseFastUpdate(state) then
        return Constants.UPDATE_INTERVAL_MS
    end
    if shouldUseTargetedUpdate(state) then
        return TARGETED_UPDATE_INTERVAL_MS
    end
    return IDLE_UPDATE_INTERVAL_MS
end

local function renderNow()
    local ok, err = pcall(function()
        Ui.Render(Tracker.GetUiState())
    end)
    if not ok and api.Log ~= nil and api.Log.Err ~= nil then
        api.Log:Err("[Nuzi Fishing] Render error: " .. tostring(err))
    end
end

local function onUpdate(dt)
    if not modulesReady() then
        return
    end

    updateElapsedMs = updateElapsedMs + normalizeDeltaMs(dt)
    local intervalMs = getUpdateIntervalMs()
    if updateElapsedMs < intervalMs then
        return
    end
    local elapsedMs = updateElapsedMs
    updateElapsedMs = 0

    local settings = Shared.EnsureSettings()
    if not settings.enabled then
        Ui.HideHud()
        return
    end

    local ok, err = pcall(function()
        Ui.Render(Tracker.Update(elapsedMs))
    end)
    if not ok then
        if api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi Fishing] Update error: " .. tostring(err))
        end
        pcall(function()
            Tracker.Reset()
            Ui.HideHud()
        end)
    end
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
