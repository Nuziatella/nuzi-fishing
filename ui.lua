local api = require("api")
local Constants = require("nuzi-fishing/constants")
local Shared = require("nuzi-fishing/shared")

local Ui = {
    target_canvas = nil,
    target_icon = nil,
    target_fish_name = nil,
    target_status = nil,
    target_coach = nil,
    target_hint = nil,
    target_timer = nil,
    target_keybind = nil,
    target_glow = nil,
    strength_icon = nil,
    strength_timer = nil,
    marker_rows = {},
    catch_rows = {},
    boat_row = nil,
    session_window = nil,
    session_labels = {},
    settings_window = nil,
    settings_controls = {},
    on_settings_changed = nil
}

local SETTINGS_ROWS = {
    { label = "Addon", key = "enabled" },
    { label = "Target HUD", key = "show_target" },
    { label = "Fish Name", key = "show_fish_name" },
    { label = "Status Text", key = "show_status_text" },
    { label = "Coach", key = "show_coach" },
    { label = "Coach Hint", key = "show_coach_hint" },
    { label = "Keybind", key = "show_keybind" },
    { label = "Prompt Sounds", key = "show_prompt_sounds" },
    { label = "Timers", key = "show_timers" },
    { label = "Waiting", key = "show_wait" },
    { label = "Strength", key = "show_strength" },
    { label = "Markers", key = "show_markers" },
    { label = "Auto Catches", key = "show_auto_catches" },
    { label = "Boat", key = "show_boat" },
    { label = "Session", key = "show_session" }
}

local function getAlignLeft()
    if ALIGN_LEFT ~= nil then
        return ALIGN_LEFT
    end
    if ALIGN ~= nil and ALIGN.LEFT ~= nil then
        return ALIGN.LEFT
    end
    return nil
end

local function getAlignCenter()
    if ALIGN_CENTER ~= nil then
        return ALIGN_CENTER
    end
    if ALIGN ~= nil and ALIGN.CENTER ~= nil then
        return ALIGN.CENTER
    end
    return nil
end

local function safeSetText(widget, text)
    if widget == nil or widget.SetText == nil then
        return
    end
    local nextText = tostring(text or "")
    if widget.__nuzi_text ~= nextText then
        widget.__nuzi_text = nextText
        widget:SetText(nextText)
    end
end

local function safeSetVisible(widget, visible)
    if widget == nil or widget.Show == nil then
        return
    end
    local nextVisible = visible and true or false
    if widget.__nuzi_visible ~= nextVisible then
        widget.__nuzi_visible = nextVisible
        widget:Show(nextVisible)
    end
end

local function safeSetIcon(icon, path)
    if icon == nil or type(path) ~= "string" or path == "" then
        return
    end
    if icon.__nuzi_icon_path ~= path then
        icon.__nuzi_icon_path = path
        if F_SLOT ~= nil and F_SLOT.SetIconBackGround ~= nil then
            F_SLOT.SetIconBackGround(icon, path)
        end
    end
end

local function safeSetDrawableVisible(drawable, visible)
    if drawable == nil then
        return
    end
    local nextVisible = visible and true or false
    if drawable.__nuzi_visible ~= nextVisible then
        drawable.__nuzi_visible = nextVisible
        pcall(function()
            if drawable.Show ~= nil then
                drawable:Show(nextVisible)
            elseif drawable.SetVisible ~= nil then
                drawable:SetVisible(nextVisible)
            end
        end)
    end
end

local function safeSetDrawableColor(drawable, color)
    if drawable == nil or type(color) ~= "table" then
        return
    end
    local key = table.concat({
        tostring(color[1] or ""),
        tostring(color[2] or ""),
        tostring(color[3] or ""),
        tostring(color[4] or "")
    }, ",")
    if drawable.__nuzi_color_key ~= key then
        drawable.__nuzi_color_key = key
        pcall(function()
            if drawable.SetColor ~= nil then
                drawable:SetColor(color[1], color[2], color[3], color[4])
            end
        end)
    end
end

local function safeAnchor(widget, point, target, relativePoint, x, y)
    if widget == nil then
        return
    end
    local key = tostring(point) .. "|" .. tostring(target) .. "|" .. tostring(relativePoint) .. "|" .. tostring(x) .. "|" .. tostring(y)
    if widget.__nuzi_anchor_key ~= key then
        widget.__nuzi_anchor_key = key
        if widget.RemoveAllAnchors ~= nil then
            widget:RemoveAllAnchors()
        end
        widget:AddAnchor(point, target, relativePoint, x, y)
    end
end

local function applyCommonWindowBehavior(window)
    if window == nil then
        return
    end
    pcall(function()
        window:SetCloseOnEscape(true)
    end)
    pcall(function()
        window:EnableHidingIsRemove(false)
    end)
    pcall(function()
        window:SetUILayer("normal")
    end)
end

local function setLabelStyle(label, fontSize, color)
    if label == nil or label.style == nil then
        return
    end
    if fontSize ~= nil and label.__nuzi_font_size ~= fontSize and label.style.SetFontSize ~= nil then
        label.__nuzi_font_size = fontSize
        label.style:SetFontSize(fontSize)
    end
    if type(color) == "table" and label.style.SetColor ~= nil then
        local key = table.concat({
            tostring(color[1] or ""),
            tostring(color[2] or ""),
            tostring(color[3] or ""),
            tostring(color[4] or "")
        }, ",")
        if label.__nuzi_color_key ~= key then
            label.__nuzi_color_key = key
            label.style:SetColor(color[1], color[2], color[3], color[4] or 1)
        end
    end
end

local function getTimerColor(timeText, defaultColor)
    local seconds = tonumber(string.match(tostring(timeText or ""), "([%d%.]+)s"))
    if seconds ~= nil and seconds <= Constants.WARNING_TIME_SECONDS then
        return { 1, 0.28, 0.18, 1 }
    end
    return defaultColor
end

local function createLabel(id, parent, x, y, width, height, fontSize, alignValue, color)
    local label = api.Interface:CreateWidget("label", id, parent)
    label:AddAnchor("TOPLEFT", x, y)
    label:SetExtent(width, height)
    safeSetText(label, "")
    if label.style ~= nil then
        if label.style.SetFontSize ~= nil then
            label.style:SetFontSize(fontSize or 14)
        end
        if label.style.SetAlign ~= nil and alignValue ~= nil then
            label.style:SetAlign(alignValue)
        end
        if label.style.SetShadow ~= nil then
            label.style:SetShadow(true)
        end
        if color ~= nil and label.style.SetColor ~= nil then
            label.style:SetColor(color[1], color[2], color[3], color[4] or 1)
        end
    end
    return label
end

local function createButton(id, parent, text, x, y, width, height, onClick)
    local button = api.Interface:CreateWidget("button", id, parent)
    button:AddAnchor("TOPLEFT", x, y)
    button:SetExtent(width, height)
    button:SetText(text)
    if api.Interface ~= nil and api.Interface.ApplyButtonSkin ~= nil then
        pcall(function()
            api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
        end)
    end
    if onClick ~= nil and button.SetHandler ~= nil then
        button:SetHandler("OnClick", onClick)
    end
    return button
end

local function createIcon(id, parent)
    local icon = CreateItemIconButton(id, parent)
    icon:Show(true)
    if F_SLOT ~= nil and F_SLOT.ApplySlotSkin ~= nil and SLOT_STYLE ~= nil and icon.back ~= nil then
        local style = SLOT_STYLE.DEFAULT or SLOT_STYLE.BUFF or SLOT_STYLE.ITEM
        if style ~= nil then
            F_SLOT.ApplySlotSkin(icon, icon.back, style)
        end
    end
    return icon
end

local function notifySettingsChanged()
    if Ui.on_settings_changed ~= nil then
        Ui.on_settings_changed()
    end
    if Ui.RefreshSettings ~= nil then
        Ui.RefreshSettings()
    end
end

local function toggleSetting(settingKey)
    Shared.ToggleSetting(settingKey)
    notifySettingsChanged()
end

local function createSettingsRow(parent, rowIndex, title, settingKey)
    local top = 56 + ((rowIndex - 1) * 30)
    local label = createLabel("NuziFishingSettingsLabel" .. tostring(rowIndex), parent, 24, top + 4, 160, 24, 14, getAlignLeft())
    safeSetText(label, title)
    local button = createButton(
        "NuziFishingSettingsButton" .. tostring(rowIndex),
        parent,
        "",
        194,
        top,
        92,
        24,
        function()
            toggleSetting(settingKey)
        end
    )
    Ui.settings_controls[settingKey] = button
end

local function createTargetHud()
    if Ui.target_canvas ~= nil then
        return
    end

    local canvas = api.Interface:CreateEmptyWindow("NuziFishingTargetHud")
    canvas:SetExtent(360, 110)
    canvas:Show(false)
    Ui.target_canvas = canvas

    Ui.target_icon = createIcon("NuziFishingTargetIcon", canvas)
    Ui.target_icon:AddAnchor("TOPLEFT", canvas, "TOPLEFT", 0, 20)

    if canvas.CreateColorDrawable ~= nil then
        Ui.target_glow = canvas:CreateColorDrawable(1, 1, 1, 0, "background")
        Ui.target_glow:AddAnchor("TOPLEFT", Ui.target_icon, -4, -4)
        Ui.target_glow:AddAnchor("BOTTOMRIGHT", Ui.target_icon, 4, 4)
        Ui.target_glow:Show(false)
    end

    Ui.target_fish_name = createLabel("NuziFishingFishName", canvas, -60, 0, 160, 20, 15, getAlignCenter(), { 1, 1, 1, 1 })
    Ui.target_status = createLabel("NuziFishingStatus", canvas, 60, 18, 230, 20, 14, getAlignLeft(), { 0.8, 0.9, 1, 1 })
    Ui.target_coach = createLabel("NuziFishingCoach", canvas, 60, 40, 230, 30, 22, getAlignLeft(), { 1, 0.82, 0.25, 1 })
    Ui.target_hint = createLabel("NuziFishingHint", canvas, 60, 68, 260, 20, 13, getAlignLeft(), { 0.9, 0.9, 0.9, 1 })
    Ui.target_keybind = createLabel("NuziFishingKeybind", canvas, 60, 88, 160, 18, 13, getAlignLeft(), { 1, 1, 1, 1 })
    Ui.target_timer = createLabel("NuziFishingTargetTimer", canvas, 226, 88, 72, 18, 16, getAlignLeft(), { 0, 1, 0, 1 })

    Ui.strength_icon = createIcon("NuziFishingStrengthIcon", canvas)
    Ui.strength_icon:AddAnchor("LEFT", Ui.target_icon, "RIGHT", 5, 0)
    Ui.strength_icon:Show(false)
    Ui.strength_timer = createLabel("NuziFishingStrengthTimer", canvas, 310, 88, 72, 18, 16, getAlignLeft(), { 1, 1, 0, 1 })
end

local function createTimerRows()
    if #Ui.marker_rows == 0 then
        for markerIndex = 1, Constants.MARKER_COUNT do
            local canvas = api.Interface:CreateEmptyWindow("NuziFishingMarkerRow" .. tostring(markerIndex))
            canvas:SetExtent(56, 64)
            canvas:Show(false)
            local icon = createIcon("NuziFishingMarkerIcon" .. tostring(markerIndex), canvas)
            icon:AddAnchor("TOPLEFT", canvas, "TOPLEFT", 0, 0)
            local label = createLabel("NuziFishingMarkerLabel" .. tostring(markerIndex), canvas, -8, -20, 72, 18, 14, getAlignCenter(), { 1, 1, 1, 1 })
            local time = createLabel("NuziFishingMarkerTime" .. tostring(markerIndex), canvas, -8, 46, 72, 20, 18, getAlignCenter(), { 1, 0.5, 0, 1 })
            Ui.marker_rows[markerIndex] = { canvas = canvas, icon = icon, marker_label = label, time_label = time }
        end
    end

    if #Ui.catch_rows == 0 then
        for index = 1, Constants.AUTO_CATCH_COUNT do
            local canvas = api.Interface:CreateEmptyWindow("NuziFishingCatchRow" .. tostring(index))
            canvas:SetExtent(56, 64)
            canvas:Show(false)
            local icon = createIcon("NuziFishingCatchIcon" .. tostring(index), canvas)
            icon:AddAnchor("TOPLEFT", canvas, "TOPLEFT", 0, 0)
            local label = createLabel("NuziFishingCatchLabel" .. tostring(index), canvas, -8, -20, 72, 18, 14, getAlignCenter(), { 1, 0.85, 0.85, 1 })
            local time = createLabel("NuziFishingCatchTime" .. tostring(index), canvas, -8, 46, 72, 20, 18, getAlignCenter(), { 1, 0.3, 0.3, 1 })
            Ui.catch_rows[index] = { canvas = canvas, icon = icon, marker_label = label, time_label = time }
        end
    end
end

local function createBoatRow()
    if Ui.boat_row ~= nil then
        return
    end

    local canvas = api.Interface:CreateEmptyWindow("NuziFishingBoatRow")
    canvas:SetExtent(56, 64)
    canvas:Show(false)
    local icon = createIcon("NuziFishingBoatIcon", canvas)
    icon:AddAnchor("TOPLEFT", canvas, "TOPLEFT", 0, 0)
    local label = createLabel("NuziFishingBoatLabel", canvas, -8, -20, 72, 18, 14, getAlignCenter(), { 0.3, 0.6, 1, 1 })
    local time = createLabel("NuziFishingBoatTime", canvas, -8, 46, 72, 20, 18, getAlignCenter(), { 0.3, 0.6, 1, 1 })
    safeSetText(label, "Boat")
    Ui.boat_row = { canvas = canvas, icon = icon, marker_label = label, time_label = time }
end

local function createSessionWindow()
    if Ui.session_window ~= nil then
        return
    end

    local window = api.Interface:CreateEmptyWindow("NuziFishingSession")
    window:SetExtent(170, 76)
    window:Show(false)
    Ui.session_window = window
    Ui.session_labels.elapsed = createLabel("NuziFishingSessionElapsed", window, 0, 0, 160, 18, 14, getAlignLeft(), { 1, 1, 1, 1 })
    Ui.session_labels.catches = createLabel("NuziFishingSessionCatches", window, 0, 18, 160, 18, 14, getAlignLeft(), { 1, 0.9, 0.5, 1 })
    Ui.session_labels.active = createLabel("NuziFishingSessionActive", window, 0, 36, 160, 18, 14, getAlignLeft(), { 1, 0.8, 0.8, 1 })
    Ui.session_labels.marked = createLabel("NuziFishingSessionMarked", window, 0, 54, 160, 18, 14, getAlignLeft(), { 1, 0.7, 0.4, 1 })
end

local function createSettingsWindow()
    if Ui.settings_window ~= nil then
        return
    end

    local height = 72 + (#SETTINGS_ROWS * 30)
    local window = api.Interface:CreateWindow("NuziFishingSettings", Constants.ADDON_NAME, 320, height)
    window:AddAnchor("CENTER", "UIParent", 0, 0)
    applyCommonWindowBehavior(window)
    window:Show(false)

    for index, row in ipairs(SETTINGS_ROWS) do
        createSettingsRow(window, index, row.label, row.key)
    end

    Ui.settings_window = window
    Ui.RefreshSettings()
end

function Ui.Init(callbacks)
    Ui.on_settings_changed = callbacks ~= nil and callbacks.on_settings_changed or nil
    createTargetHud()
    createTimerRows()
    createBoatRow()
    createSessionWindow()
    createSettingsWindow()
end

function Ui.RefreshSettings()
    local settings = Shared.EnsureSettings()
    for key, button in pairs(Ui.settings_controls) do
        if button ~= nil and button.SetText ~= nil then
            button:SetText(settings[key] and "On" or "Off")
        end
    end
end

function Ui.ToggleSettings()
    createSettingsWindow()
    if Ui.settings_window ~= nil then
        Ui.settings_window:Show(not Ui.settings_window:IsVisible())
        Ui.RefreshSettings()
    end
end

function Ui.HideHud()
    safeSetVisible(Ui.target_canvas, false)
    safeSetVisible(Ui.session_window, false)
    for _, row in ipairs(Ui.marker_rows) do
        safeSetVisible(row.canvas, false)
    end
    for _, row in ipairs(Ui.catch_rows) do
        safeSetVisible(row.canvas, false)
    end
    if Ui.boat_row ~= nil then
        safeSetVisible(Ui.boat_row.canvas, false)
    end
end

function Ui.Render(uiState)
    local settings = Shared.EnsureSettings()
    if not settings.enabled or uiState == nil then
        Ui.HideHud()
        return
    end

    local target = uiState.target or {}
    local targetVisible = target.visible and type(target.icon_path) == "string" and target.icon_path ~= "" and target.x ~= nil and target.y ~= nil
    safeSetVisible(Ui.target_canvas, targetVisible)
    if targetVisible then
        safeAnchor(Ui.target_canvas, "TOP", "UIParent", "TOPLEFT", math.floor(target.x - 42), math.floor(target.y - 28))
        safeSetIcon(Ui.target_icon, target.icon_path)
        safeSetText(Ui.target_fish_name, target.fish_name or "")
        safeSetText(Ui.target_status, target.status_text or "")
        safeSetText(Ui.target_coach, target.coach_text or "")
        safeSetText(Ui.target_hint, target.coach_hint or "")
        safeSetText(Ui.target_keybind, target.keybind_text or "")
        safeSetText(Ui.target_timer, target.timer_text or "")
        if target.emphasis == "big_reel_in" then
            setLabelStyle(Ui.target_coach, 24, { 1, 0.92, 0.3, 1 })
            setLabelStyle(Ui.target_timer, 16, getTimerColor(target.timer_text or "", { 1, 0.82, 0.22, 1 }))
            safeSetDrawableColor(Ui.target_glow, { 0.95, 0.75, 0.1, 0.28 })
            safeSetDrawableVisible(Ui.target_glow, true)
        elseif target.emphasis == "reel_in" then
            setLabelStyle(Ui.target_coach, 24, { 1, 0.58, 0.18, 1 })
            setLabelStyle(Ui.target_timer, 16, getTimerColor(target.timer_text or "", { 1, 0.58, 0.18, 1 }))
            safeSetDrawableColor(Ui.target_glow, { 1, 0.45, 0.1, 0.24 })
            safeSetDrawableVisible(Ui.target_glow, true)
        else
            setLabelStyle(Ui.target_coach, 22, { 0.85, 0.9, 1, 1 })
            setLabelStyle(Ui.target_timer, 16, getTimerColor(target.timer_text or "", { 0, 1, 0, 1 }))
            safeSetDrawableVisible(Ui.target_glow, false)
        end

        local showStrength = target.strength_visible and type(target.strength_icon_path) == "string" and target.strength_icon_path ~= ""
        safeSetVisible(Ui.strength_icon, showStrength)
        if showStrength then
            safeSetIcon(Ui.strength_icon, target.strength_icon_path)
        end
        safeSetText(Ui.strength_timer, target.strength_timer_text or "")
    else
        safeSetDrawableVisible(Ui.target_glow, false)
    end

    local markers = uiState.markers or {}
    local activeCount = 0
    for index = 1, Constants.MARKER_COUNT do
        local row = Ui.marker_rows[index]
        local data = markers[index]
        if row ~= nil and data ~= nil then
            local offsetX = (activeCount * 50) - 125
            safeAnchor(row.canvas, "TOP", "UIParent", "CENTER", offsetX, 200)
            safeSetIcon(row.icon, data.icon_path)
            safeSetText(row.time_label, data.timer_text or "")
            safeSetText(row.marker_label, tostring(data.index or index))
            setLabelStyle(row.time_label, 18, getTimerColor(data.timer_text or "", { 1, 0.5, 0, 1 }))
            safeSetVisible(row.canvas, true)
            activeCount = activeCount + 1
        elseif row ~= nil then
            safeSetVisible(row.canvas, false)
        end
    end

    local catches = uiState.catches or {}
    local catchCount = 0
    for index = 1, Constants.AUTO_CATCH_COUNT do
        local row = Ui.catch_rows[index]
        local data = catches[index]
        if row ~= nil and data ~= nil and type(data.icon_path) == "string" and data.icon_path ~= "" then
            local offsetX = ((activeCount + catchCount) * 50) - 125
            safeAnchor(row.canvas, "TOP", "UIParent", "CENTER", offsetX, 200)
            safeSetIcon(row.icon, data.icon_path)
            safeSetText(row.time_label, data.timer_text or "")
            safeSetText(row.marker_label, tostring(data.serial or index))
            setLabelStyle(row.time_label, 18, getTimerColor(data.timer_text or "", { 1, 0.3, 0.3, 1 }))
            safeSetVisible(row.canvas, true)
            catchCount = catchCount + 1
        elseif row ~= nil then
            safeSetVisible(row.canvas, false)
        end
    end

    local boat = uiState.boat or {}
    if Ui.boat_row ~= nil then
        if boat.visible and type(boat.icon_path) == "string" and boat.icon_path ~= "" then
            local offsetX = ((activeCount + catchCount) * 50) - 125
            safeAnchor(Ui.boat_row.canvas, "TOP", "UIParent", "CENTER", offsetX, 200)
            safeSetIcon(Ui.boat_row.icon, boat.icon_path)
            safeSetText(Ui.boat_row.time_label, boat.timer_text or "")
            setLabelStyle(Ui.boat_row.time_label, 18, getTimerColor(boat.timer_text or "", { 0.3, 0.6, 1, 1 }))
            safeSetVisible(Ui.boat_row.canvas, true)
        else
            safeSetVisible(Ui.boat_row.canvas, false)
        end
    end

    local session = uiState.session or {}
    safeSetVisible(Ui.session_window, session.visible)
    if session.visible then
        safeAnchor(Ui.session_window, "TOPLEFT", "UIParent", "TOPLEFT", 30, 260)
        safeSetText(Ui.session_labels.elapsed, session.elapsed_text or "")
        safeSetText(Ui.session_labels.catches, session.catches_text or "")
        safeSetText(Ui.session_labels.active, session.active_text or "")
        safeSetText(Ui.session_labels.marked, session.marked_text or "")
    end
end

function Ui.Unload()
    Ui.HideHud()
    if Ui.settings_window ~= nil then
        Ui.settings_window:Show(false)
        Ui.settings_window = nil
    end
    Ui.target_canvas = nil
    Ui.target_icon = nil
    Ui.target_fish_name = nil
    Ui.target_status = nil
    Ui.target_coach = nil
    Ui.target_hint = nil
    Ui.target_timer = nil
    Ui.target_keybind = nil
    Ui.target_glow = nil
    Ui.strength_icon = nil
    Ui.strength_timer = nil
    Ui.marker_rows = {}
    Ui.catch_rows = {}
    Ui.boat_row = nil
    Ui.session_window = nil
    Ui.session_labels = {}
    Ui.settings_controls = {}
    Ui.on_settings_changed = nil
end

return Ui
