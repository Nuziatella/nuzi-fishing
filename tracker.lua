local api = require("api")
local Constants = require("nuzi-fishing/constants")
local Shared = require("nuzi-fishing/shared")

local Tracker = {
    marked = {},
    caught = {},
    catch_serial = 0,
    boat_expiration_ms = nil,
    marker_elapsed_ms = Constants.MARKER_SCAN_MS,
    icon_cache = {},
    hotkey_cache = {},
    ui_state = nil,
    last_target_unit_id = nil,
    last_target_health = nil,
    last_action_buff_id = nil
}

local findLatestCaughtForUnit

local function getUnitScreenPosition(unit)
    local x, y, z = nil, nil, nil
    if api.Unit ~= nil and api.Unit.GetUnitScreenNameTagOffset ~= nil then
        pcall(function()
            x, y, z = api.Unit:GetUnitScreenNameTagOffset(unit)
        end)
    end
    if x == nil or y == nil then
        pcall(function()
            x, y, z = api.Unit:GetUnitScreenPosition(unit)
        end)
    end
    return tonumber(x), tonumber(y), tonumber(z)
end

local function getNowMs()
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

local function getBuffIconPath(buffId)
    if Tracker.icon_cache[buffId] ~= nil then
        return Tracker.icon_cache[buffId] ~= false and Tracker.icon_cache[buffId] or nil
    end
    local path = nil
    if api.Ability ~= nil and api.Ability.GetBuffTooltip ~= nil then
        local ok, tooltip = pcall(function()
            return api.Ability:GetBuffTooltip(buffId, 1)
        end)
        if ok and tooltip ~= nil then
            path = tooltip.path
        end
    end
    Tracker.icon_cache[buffId] = path or false
    return path
end

local function getActionHotkey(buffId)
    local buffInfo = Constants.ACTION_BUFF_INFO[buffId]
    if type(buffInfo) ~= "table" or type(buffInfo.hotkey_actions) ~= "table" then
        return nil
    end

    for _, actionName in ipairs(buffInfo.hotkey_actions) do
        if Tracker.hotkey_cache[actionName] ~= nil then
            local cached = Tracker.hotkey_cache[actionName]
            if cached ~= false and cached ~= "" then
                return cached
            end
        else
            local key = nil
            if X2Hotkey ~= nil and X2Hotkey.GetBindingUiEvent ~= nil then
                pcall(function()
                    key = X2Hotkey:GetBindingUiEvent(actionName, 1)
                end)
            end
            if (key == nil or key == "") and X2Hotkey ~= nil and X2Hotkey.GetOptionBindingUiEvent ~= nil then
                pcall(function()
                    key = X2Hotkey:GetOptionBindingUiEvent(actionName, 1)
                end)
            end
            Tracker.hotkey_cache[actionName] = (type(key) == "string" and key ~= "") and key or false
            if type(key) == "string" and key ~= "" then
                return key
            end
        end
    end

    return nil
end

local function playActionSound(buffId)
    local buffInfo = Constants.ACTION_BUFF_INFO[buffId]
    if type(buffInfo) ~= "table" or type(buffInfo.sound_names) ~= "table" then
        return
    end
    if X2Sound ~= nil and X2Sound.PlayUISound ~= nil then
        for _, soundName in ipairs(buffInfo.sound_names) do
            if type(soundName) == "string" and soundName ~= "" then
                local soundId = 0
                pcall(function()
                    soundId = X2Sound:PlayUISound(soundName, true) or 0
                end)
                if tonumber(soundId) == nil or tonumber(soundId) <= 0 then
                    pcall(function()
                        soundId = X2Sound:PlayUISound(soundName) or 0
                    end)
                end
                if tonumber(soundId) ~= nil and tonumber(soundId) > 0 then
                    return
                end
            end
        end
    end
end

local function isTrackedFish(unitInfo)
    return unitInfo ~= nil and Constants.FISH_NAMES[unitInfo.name] == true
end

local function resetMarker(index)
    Tracker.marked[index] = {
        unit_id = nil,
        death_time_ms = nil
    }
end

local function rememberCaughtTarget(unitId, nowMs)
    if unitId == nil then
        return nil
    end
    local existing = findLatestCaughtForUnit(unitId)
    if existing ~= nil then
        local remainingMs = Constants.MARKER_TIMER_MS - (nowMs - existing.death_time_ms)
        if remainingMs > 0 then
            return existing
        end
    end

    Tracker.catch_serial = Tracker.catch_serial + 1
    local caught = {
        serial = Tracker.catch_serial,
        unit_id = unitId,
        death_time_ms = nowMs
    }
    table.insert(Tracker.caught, caught)
    while #Tracker.caught > Constants.AUTO_CATCH_COUNT do
        table.remove(Tracker.caught, 1)
    end
    return caught
end

findLatestCaughtForUnit = function(unitId)
    if unitId == nil then
        return nil
    end
    for index = #Tracker.caught, 1, -1 do
        local caught = Tracker.caught[index]
        if caught ~= nil and caught.unit_id == unitId then
            return caught
        end
    end
    return nil
end

local function ensureMarker(index)
    if Tracker.marked[index] == nil then
        resetMarker(index)
    end
    return Tracker.marked[index]
end

local function scanMarkers()
    for markerIndex = 1, Constants.MARKER_COUNT do
        local marker = ensureMarker(markerIndex)
        local unitId = api.Unit:GetOverHeadMarkerUnitId(markerIndex)
        if unitId ~= nil then
            local unitInfo = api.Unit:GetUnitInfoById(unitId)
            if isTrackedFish(unitInfo) then
                if marker.unit_id ~= unitId then
                    marker.unit_id = unitId
                    marker.death_time_ms = nil
                end
            else
                resetMarker(markerIndex)
            end
        else
            resetMarker(markerIndex)
        end
    end
end

local function buildTargetState(nowMs)
    local settings = Shared.EnsureSettings()
    local targetState = {
        visible = false,
        x = nil,
        y = nil,
        icon_path = nil,
        timer_text = "",
        keybind_text = "",
        emphasis = nil,
        strength_visible = false,
        strength_icon_path = nil,
        strength_timer_text = ""
    }

    local targetUnitId = api.Unit:GetUnitId("target")
    if targetUnitId == nil then
        Tracker.last_target_unit_id = nil
        Tracker.last_target_health = nil
        return targetState
    end

    local targetInfo = api.Unit:GetUnitInfoById(targetUnitId)
    if targetInfo == nil then
        Tracker.last_target_unit_id = targetUnitId
        Tracker.last_target_health = nil
        return targetState
    end

    local buffCount = api.Unit:UnitBuffCount("target") or 0
    local actionBuff = nil
    local strengthBuff = nil
    local ownersMarkBuff = nil

    for index = 1, buffCount do
        local buff = api.Unit:UnitBuff("target", index)
        if buff ~= nil then
            if buff.buff_id == Constants.OWNERS_MARK_BUFF_ID then
                ownersMarkBuff = buff
            elseif buff.buff_id == Constants.STRENGTH_CONTEST_BUFF_ID then
                strengthBuff = buff
            elseif Constants.ACTION_BUFF_IDS[buff.buff_id] then
                actionBuff = buff
            end
        end
    end

    if ownersMarkBuff ~= nil then
        local playerId = api.Unit:GetUnitId("player")
        local playerInfo = playerId ~= nil and api.Unit:GetUnitInfoById(playerId) or nil
        if playerInfo ~= nil and targetInfo.owner_name ~= nil and targetInfo.owner_name == playerInfo.name then
            Tracker.boat_expiration_ms = nowMs + (tonumber(ownersMarkBuff.timeLeft) or 0)
        end
    end

    if not isTrackedFish(targetInfo) then
        Tracker.last_action_buff_id = nil
        Tracker.last_target_unit_id = targetUnitId
        Tracker.last_target_health = nil
        return targetState
    end

    local x, y = getUnitScreenPosition("target")
    targetState.x = x
    targetState.y = y

    local fishHealth = api.Unit:UnitHealth("target")
    local currentHealth = tonumber(fishHealth)
    local isNewTarget = Tracker.last_target_unit_id ~= targetUnitId
    local wasAliveBefore = tonumber(Tracker.last_target_health) ~= nil and tonumber(Tracker.last_target_health) > 0
    if fishHealth ~= nil and fishHealth <= 0 then
        Tracker.last_action_buff_id = nil
        local latestCaught = findLatestCaughtForUnit(targetUnitId)
        if isNewTarget or wasAliveBefore or Tracker.last_target_health == nil then
            latestCaught = rememberCaughtTarget(targetUnitId, nowMs)
        end
        targetState.visible = settings.show_target
        targetState.icon_path = getBuffIconPath(Constants.DEAD_FISH_ICON_BUFF_ID)
        if settings.show_timers and latestCaught ~= nil then
            local remainingMs = Constants.MARKER_TIMER_MS - (nowMs - latestCaught.death_time_ms)
            if remainingMs < 0 then
                remainingMs = 0
            end
            targetState.timer_text = Shared.FormatSeconds(remainingMs / 1000, 0)
        end
        for markerIndex = 1, Constants.MARKER_COUNT do
            local marker = ensureMarker(markerIndex)
            if marker.unit_id == targetUnitId and marker.death_time_ms == nil then
                marker.death_time_ms = nowMs
            end
        end
        Tracker.last_target_unit_id = targetUnitId
        Tracker.last_target_health = currentHealth
        return targetState
    end

    if actionBuff ~= nil then
        local buffInfo = Constants.ACTION_BUFF_INFO[actionBuff.buff_id]
        if Tracker.last_action_buff_id ~= actionBuff.buff_id then
            playActionSound(actionBuff.buff_id)
        end
        Tracker.last_action_buff_id = actionBuff.buff_id
        targetState.visible = settings.show_target
        if settings.show_target_buff_icon and actionBuff.path ~= nil then
            targetState.icon_path = actionBuff.path
        else
            targetState.icon_path = getBuffIconPath(actionBuff.buff_id)
        end
        targetState.keybind_text = getActionHotkey(actionBuff.buff_id) or ""
        targetState.emphasis = buffInfo ~= nil and buffInfo.emphasis or nil
        if settings.show_timers then
            targetState.timer_text = Shared.FormatSeconds((tonumber(actionBuff.timeLeft) or 0) / 1000, 1)
        end
    elseif strengthBuff ~= nil then
        Tracker.last_action_buff_id = nil
        targetState.visible = settings.show_target
        targetState.icon_path = getBuffIconPath(Constants.WAITING_ICON_BUFF_ID)
    elseif settings.show_wait then
        Tracker.last_action_buff_id = nil
        targetState.visible = settings.show_target
        targetState.icon_path = getBuffIconPath(Constants.WAITING_ICON_BUFF_ID)
        if settings.show_timers then
            targetState.timer_text = "Waiting"
        end
    else
        Tracker.last_action_buff_id = nil
    end

    if strengthBuff ~= nil then
        targetState.strength_visible = settings.show_strength
        targetState.strength_icon_path = getBuffIconPath(Constants.STRENGTH_CONTEST_BUFF_ID)
        if settings.show_timers then
            targetState.strength_timer_text = Shared.FormatSeconds((tonumber(strengthBuff.timeLeft) or 0) / 1000, 1)
        end
    end

    Tracker.last_target_unit_id = targetUnitId
    Tracker.last_target_health = currentHealth

    return targetState
end

local function buildCaughtStates(nowMs)
    local settings = Shared.EnsureSettings()
    local catches = {}
    if not settings.show_target then
        return catches
    end

    local kept = {}
    for _, caught in ipairs(Tracker.caught) do
        local remainingMs = Constants.MARKER_TIMER_MS - (nowMs - caught.death_time_ms)
        if remainingMs > 0 then
            local isTrackedByMarker = false
            for markerIndex = 1, Constants.MARKER_COUNT do
                local marker = ensureMarker(markerIndex)
                if marker.unit_id == caught.unit_id and marker.death_time_ms ~= nil then
                    isTrackedByMarker = true
                    break
                end
            end
            table.insert(kept, caught)
            if not isTrackedByMarker then
                table.insert(catches, {
                    serial = caught.serial,
                    icon_path = getBuffIconPath(Constants.DEAD_FISH_ICON_BUFF_ID),
                    timer_text = settings.show_timers and Shared.FormatSeconds(remainingMs / 1000, 0) or ""
                })
            end
        end
    end
    Tracker.caught = kept
    return catches
end

local function buildMarkerStates(nowMs)
    local settings = Shared.EnsureSettings()
    local markers = {}
    if not settings.show_markers then
        return markers
    end

    for markerIndex = 1, Constants.MARKER_COUNT do
        local marker = ensureMarker(markerIndex)
        if marker.unit_id ~= nil and marker.death_time_ms ~= nil then
            local remainingMs = Constants.MARKER_TIMER_MS - (nowMs - marker.death_time_ms)
            if remainingMs > 0 then
                table.insert(markers, {
                    index = markerIndex,
                    icon_path = getBuffIconPath(Constants.DEAD_FISH_ICON_BUFF_ID),
                    timer_text = Shared.FormatSeconds(remainingMs / 1000, 0)
                })
            else
                marker.death_time_ms = nil
            end
        end
    end

    return markers
end

local function buildBoatState(nowMs)
    local settings = Shared.EnsureSettings()
    local boatState = {
        visible = false,
        icon_path = nil,
        timer_text = ""
    }

    if not settings.show_boat or Tracker.boat_expiration_ms == nil then
        return boatState
    end

    local remainingMs = Tracker.boat_expiration_ms - nowMs
    if remainingMs <= 0 then
        Tracker.boat_expiration_ms = nil
        return boatState
    end

    boatState.visible = true
    boatState.icon_path = getBuffIconPath(Constants.OWNERS_MARK_BUFF_ID)
    boatState.timer_text = Shared.FormatSeconds(remainingMs / 1000, 0)
    return boatState
end

function Tracker.Reset()
    Tracker.marked = {}
    Tracker.caught = {}
    Tracker.catch_serial = 0
    Tracker.boat_expiration_ms = nil
    Tracker.marker_elapsed_ms = Constants.MARKER_SCAN_MS
    Tracker.hotkey_cache = {}
    Tracker.last_target_unit_id = nil
    Tracker.last_target_health = nil
    Tracker.last_action_buff_id = nil
    Tracker.ui_state = {
        target = {
            visible = false,
            x = nil,
            y = nil,
            icon_path = nil,
            timer_text = "",
            keybind_text = "",
            emphasis = nil,
            strength_visible = false,
            strength_icon_path = nil,
            strength_timer_text = ""
        },
        markers = {},
        catches = {},
        boat = {
            visible = false,
            icon_path = nil,
            timer_text = ""
        }
    }
end

function Tracker.InvalidateHotkeys()
    Tracker.hotkey_cache = {}
end

function Tracker.Update(dt)
    if Tracker.ui_state == nil then
        Tracker.Reset()
    end

    local deltaMs = normalizeDeltaMs(dt)
    Tracker.marker_elapsed_ms = Tracker.marker_elapsed_ms + deltaMs
    if Tracker.marker_elapsed_ms >= Constants.MARKER_SCAN_MS then
        Tracker.marker_elapsed_ms = 0
        scanMarkers()
    end

    local nowMs = getNowMs()
    Tracker.ui_state = {
        target = buildTargetState(nowMs),
        markers = buildMarkerStates(nowMs),
        catches = buildCaughtStates(nowMs),
        boat = buildBoatState(nowMs)
    }
    return Tracker.ui_state
end

function Tracker.GetUiState()
    if Tracker.ui_state == nil then
        Tracker.Reset()
    end
    return Tracker.ui_state
end

Tracker.Reset()

return Tracker
