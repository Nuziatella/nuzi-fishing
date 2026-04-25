local api = require("api")
local Core = api._NuziCore or require("nuzi-core/core")

local Events = Core.Events
local Log = Core.Log
local Require = Core.Require
local Scheduler = Core.Scheduler

local bootstrapLogger = Log.Create("Nuzi Fishing")
local moduleErrors = {}

local function appendModuleErrors(name, errors)
    if type(errors) ~= "table" or #errors == 0 then
        moduleErrors[#moduleErrors + 1] = string.format("%s: unknown load failure", tostring(name))
        return
    end
    moduleErrors[#moduleErrors + 1] = string.format(
        "%s: %s",
        tostring(name),
        Require.DescribeErrors(errors)
    )
end

local Constants, _, constantErrors = Require.Addon("nuzi-fishing", "constants")
if Constants == nil then
    appendModuleErrors("constants", constantErrors)
end

local logger = Log.Create(Constants ~= nil and Constants.ADDON_NAME or "Nuzi Fishing")
local modules = nil
local failures = nil
if Constants ~= nil then
    modules, failures = Require.AddonSet("nuzi-fishing", {
        "shared",
        "tracker",
        "ui"
    })
else
    modules = {}
    failures = {}
end

for name, failure in pairs(failures or {}) do
    appendModuleErrors(name, failure.errors)
end

local Shared = modules.shared
local Tracker = modules.tracker
local Ui = modules.ui

local addon = {
    name = Constants ~= nil and Constants.ADDON_NAME or "Nuzi Fishing",
    author = Constants ~= nil and Constants.ADDON_AUTHOR or "Nuzi",
    version = Constants ~= nil and Constants.ADDON_VERSION or "2.0.0",
    desc = Constants ~= nil and Constants.ADDON_DESC or "Fishing coach HUD"
}

local TARGETED_UPDATE_INTERVAL_MS = 100
local IDLE_UPDATE_INTERVAL_MS = 250

local updateTicker = Scheduler.CreateTicker({
    interval_ms = Constants ~= nil and Constants.UPDATE_INTERVAL_MS or 16,
    max_elapsed_ms = IDLE_UPDATE_INTERVAL_MS * 4
})
local events = Events.Create({
    logger = logger
})
local bindingEvents = Events.CreateEventWindow({
    id = Constants ~= nil and Constants.EVENT_WINDOW_ID or "nuziFishingEvents",
    logger = logger
})

local function modulesReady()
    return Constants ~= nil and Shared ~= nil and Tracker ~= nil and Ui ~= nil
end

local function logModuleErrors()
    if #moduleErrors == 0 then
        return
    end
    for _, detail in ipairs(moduleErrors) do
        logger:Err("Module load error: " .. tostring(detail))
    end
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
    if not ok then
        logger:Err("Render error: " .. tostring(err))
    end
end

local function onUpdate(dt)
    if not modulesReady() then
        return
    end

    local intervalMs = getUpdateIntervalMs()
    local shouldRun, elapsedMs = updateTicker:Advance(dt, intervalMs)
    if not shouldRun then
        return
    end

    local settings = Shared.EnsureSettings()
    if not settings.enabled then
        Ui.HideHud()
        return
    end

    local ok, err = pcall(function()
        Ui.Render(Tracker.Update(elapsedMs))
    end)
    if not ok then
        logger:Err("Update error: " .. tostring(err))
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

    updateTicker:Reset()
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
        logModuleErrors()
        bootstrapLogger:Err("Failed to load one or more modules.")
        return
    end

    logModuleErrors()
    Shared.LoadSettings()
    updateTicker:Reset()
    Tracker.Reset()
    Ui.Init({
        on_settings_changed = renderNow
    })
    renderNow()
    events:OnSafe("UPDATE", "UPDATE", onUpdate)
    events:OnSafe("UI_RELOADED", "UI_RELOADED", onUiReloaded)
    bindingEvents:OptionalOnSafe("UPDATE_BINDINGS", "UPDATE_BINDINGS", onUpdateBindings)
    logger:Info("Loaded v" .. tostring(addon.version))
end

local function onUnload()
    events:ClearAll()
    bindingEvents:ClearAll()
    updateTicker:Reset()
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
