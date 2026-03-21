local api = require("api")
local Constants = require("nuzi-fishing/constants")
local Shared = require("nuzi-fishing/shared")

local Ui = {
    target_canvas = nil,
    target_bg = nil,
    target_icon = nil,
    target_icon_mask = nil,
    target_icon_text = nil,
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
    session_title = nil,
    session_labels = {},
    session_buttons = {},
    session_fish_labels = {},
    session_history_rows = {},
    settings_window = nil,
    settings_controls = {},
    on_settings_changed = nil
}

local HELPER_SCALE_OPTIONS = { 0.8, 1.0, 1.2, 1.4, 1.6 }

local SETTINGS_ROWS = {
    { label = "Addon", key = "enabled" },
    { label = "Target HUD", key = "show_target" },
    { label = "HUD Size", key = "helper_scale", kind = "cycle" },
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

local function roundNumber(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function scaleValue(value, scale)
    return roundNumber((tonumber(value) or 0) * (tonumber(scale) or 1))
end

local function safeSetExtent(widget, width, height)
    if widget == nil or widget.SetExtent == nil then
        return
    end
    pcall(function()
        widget:SetExtent(roundNumber(width), roundNumber(height))
    end)
end

local function normalizeHelperScale(value)
    local number = tonumber(value) or 1
    local closest = HELPER_SCALE_OPTIONS[1]
    local bestDiff = math.abs(number - closest)
    for _, candidate in ipairs(HELPER_SCALE_OPTIONS) do
        local diff = math.abs(number - candidate)
        if diff < bestDiff then
            closest = candidate
            bestDiff = diff
        end
    end
    return closest
end

local function getHelperScale()
    local settings = Shared.EnsureSettings()
    local scale = normalizeHelperScale(settings.helper_scale)
    settings.helper_scale = scale
    return scale
end

local function scaledFontSize(baseSize)
    local scaled = scaleValue(baseSize, getHelperScale())
    if scaled < 10 then
        scaled = 10
    end
    return scaled
end

local function getHelperScaleLabel()
    return string.format("%d%%", roundNumber(getHelperScale() * 100))
end

local function safeSetText(widget, text)
    if widget == nil or widget.SetText == nil then
        return
    end
    local nextText = tostring(text or "")
    if widget.__nuzi_text ~= nextText then
        widget.__nuzi_text = nextText
        pcall(function()
            widget:SetText(nextText)
        end)
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
    if widget == nil or widget.AddAnchor == nil then
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

local function safeAddAnchor(widget, anchorPoint, anchorTarget, anchorRelativePoint, anchorX, anchorY)
    if widget == nil or widget.AddAnchor == nil then
        return
    end
    pcall(function()
        if anchorY == nil and type(anchorRelativePoint) ~= "string" then
            widget:AddAnchor(anchorPoint, anchorTarget, anchorRelativePoint, anchorX)
        else
            widget:AddAnchor(anchorPoint, anchorTarget, anchorRelativePoint, anchorX, anchorY)
        end
    end)
end

local function safeCreateWidget(kind, id, parent)
    if api.Interface == nil or api.Interface.CreateWidget == nil or parent == nil then
        return nil
    end
    local ok, widget = pcall(function()
        return api.Interface:CreateWidget(kind, id, parent)
    end)
    if ok then
        return widget
    end
    return nil
end

local function safeCreateEmptyWindow(id)
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    local ok, window = pcall(function()
        return api.Interface:CreateEmptyWindow(id)
    end)
    if ok then
        return window
    end
    return nil
end

local function safeCreateWindow(id, title, width, height)
    if api.Interface == nil or api.Interface.CreateWindow == nil then
        return nil
    end
    local ok, window = pcall(function()
        return api.Interface:CreateWindow(id, title, width, height)
    end)
    if ok then
        return window
    end
    return nil
end

local function safeCreateColorDrawable(parent, red, green, blue, alpha, layer)
    if parent == nil or parent.CreateColorDrawable == nil then
        return nil
    end
    local ok, drawable = pcall(function()
        return parent:CreateColorDrawable(red, green, blue, alpha, layer)
    end)
    if ok then
        return drawable
    end
    return nil
end

local function getTargetHudPosition()
    local settings = Shared.EnsureSettings()
    return tonumber(settings.target_hud_x) or 760, tonumber(settings.target_hud_y) or 360
end

local function applyTargetHudPosition()
    if Ui.target_canvas == nil then
        return
    end
    local x, y = getTargetHudPosition()
    safeAnchor(Ui.target_canvas, "TOPLEFT", "UIParent", "TOPLEFT", math.floor(x), math.floor(y))
end

local function getSessionPosition()
    local settings = Shared.EnsureSettings()
    return tonumber(settings.session_x) or 30, tonumber(settings.session_y) or 260
end

local function applySessionPosition()
    if Ui.session_window == nil then
        return
    end
    local x, y = getSessionPosition()
    safeAnchor(Ui.session_window, "TOPLEFT", "UIParent", "TOPLEFT", math.floor(x), math.floor(y))
end

local function enableTargetHudDrag(canvas)
    if canvas == nil then
        return
    end
    if canvas.RegisterForDrag ~= nil then
        canvas:RegisterForDrag("LeftButton")
    end
    if canvas.EnableDrag ~= nil then
        canvas:EnableDrag(true)
    end
    if canvas.SetHandler ~= nil then
        canvas:SetHandler("OnDragStart", function(self)
            if self.StartMoving ~= nil then
                self:StartMoving()
            end
        end)
        canvas:SetHandler("OnDragStop", function(self)
            if self.StopMovingOrSizing ~= nil then
                self:StopMovingOrSizing()
            end
            if self.GetOffset ~= nil then
                local ok, x, y = pcall(function()
                    return self:GetOffset()
                end)
                if ok then
                    local settings = Shared.EnsureSettings()
                    settings.target_hud_x = tonumber(x) or settings.target_hud_x
                    settings.target_hud_y = tonumber(y) or settings.target_hud_y
                    Shared.SaveSettings()
                    applyTargetHudPosition()
                end
            end
        end)
    end
end

local function attachTargetDrag(widget)
    if widget == nil or widget.SetHandler == nil then
        return
    end
    if widget.RegisterForDrag ~= nil then
        widget:RegisterForDrag("LeftButton")
    end
    if widget.EnableDrag ~= nil then
        widget:EnableDrag(true)
    end
    widget:SetHandler("OnDragStart", function()
        if Ui.target_canvas ~= nil and Ui.target_canvas.StartMoving ~= nil then
            Ui.target_canvas:StartMoving()
        end
    end)
    widget:SetHandler("OnDragStop", function()
        if Ui.target_canvas ~= nil and Ui.target_canvas.StopMovingOrSizing ~= nil then
            Ui.target_canvas:StopMovingOrSizing()
        end
        if Ui.target_canvas ~= nil and Ui.target_canvas.GetOffset ~= nil then
            local ok, x, y = pcall(function()
                return Ui.target_canvas:GetOffset()
            end)
            if ok then
                local settings = Shared.EnsureSettings()
                settings.target_hud_x = tonumber(x) or settings.target_hud_x
                settings.target_hud_y = tonumber(y) or settings.target_hud_y
                Shared.SaveSettings()
                applyTargetHudPosition()
            end
        end
    end)
end

local function enableSessionDrag(window)
    if window == nil then
        return
    end
    if window.RegisterForDrag ~= nil then
        window:RegisterForDrag("LeftButton")
    end
    if window.EnableDrag ~= nil then
        window:EnableDrag(true)
    end
    if window.SetHandler ~= nil then
        window:SetHandler("OnDragStart", function(self)
            if self.StartMoving ~= nil then
                self:StartMoving()
            end
        end)
        window:SetHandler("OnDragStop", function(self)
            if self.StopMovingOrSizing ~= nil then
                self:StopMovingOrSizing()
            end
            if self.GetOffset ~= nil then
                local ok, x, y = pcall(function()
                    return self:GetOffset()
                end)
                if ok then
                    local settings = Shared.EnsureSettings()
                    settings.session_x = tonumber(x) or settings.session_x
                    settings.session_y = tonumber(y) or settings.session_y
                    Shared.SaveSettings()
                    applySessionPosition()
                end
            end
        end)
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

local function applyHelperScale()
    local scale = getHelperScale()

    safeSetExtent(Ui.target_canvas, 420 * scale, 132 * scale)
    safeAnchor(Ui.target_icon, "TOPLEFT", Ui.target_canvas, "TOPLEFT", scaleValue(12, scale), scaleValue(34, scale))
    safeSetExtent(Ui.target_icon, 44 * scale, 44 * scale)
    safeAnchor(Ui.target_icon_mask, "TOPLEFT", Ui.target_icon, "TOPLEFT", scaleValue(1, scale), scaleValue(1, scale))
    safeAnchor(Ui.target_icon_mask, "BOTTOMRIGHT", Ui.target_icon, "BOTTOMRIGHT", scaleValue(-1, scale), scaleValue(-1, scale))
    safeAnchor(Ui.target_glow, "TOPLEFT", Ui.target_icon, "TOPLEFT", scaleValue(-4, scale), scaleValue(-4, scale))
    safeAnchor(Ui.target_glow, "BOTTOMRIGHT", Ui.target_icon, "BOTTOMRIGHT", scaleValue(4, scale), scaleValue(4, scale))

    safeAnchor(Ui.target_icon_text, "TOPLEFT", Ui.target_canvas, "TOPLEFT", scaleValue(6, scale), scaleValue(52, scale))
    safeSetExtent(Ui.target_icon_text, 60 * scale, 18 * scale)
    setLabelStyle(Ui.target_icon_text, scaledFontSize(16), nil)

    safeAnchor(Ui.target_fish_name, "TOPLEFT", Ui.target_canvas, "TOPLEFT", scaleValue(12, scale), scaleValue(6, scale))
    safeSetExtent(Ui.target_fish_name, 260 * scale, 20 * scale)
    setLabelStyle(Ui.target_fish_name, scaledFontSize(16), nil)

    safeAnchor(Ui.target_status, "TOPLEFT", Ui.target_canvas, "TOPLEFT", scaleValue(70, scale), scaleValue(34, scale))
    safeSetExtent(Ui.target_status, 220 * scale, 18 * scale)
    setLabelStyle(Ui.target_status, scaledFontSize(13), nil)

    safeAnchor(Ui.target_coach, "TOPLEFT", Ui.target_canvas, "TOPLEFT", scaleValue(70, scale), scaleValue(52, scale))
    safeSetExtent(Ui.target_coach, 240 * scale, 28 * scale)

    safeAnchor(Ui.target_hint, "TOPLEFT", Ui.target_canvas, "TOPLEFT", scaleValue(70, scale), scaleValue(82, scale))
    safeSetExtent(Ui.target_hint, 290 * scale, 18 * scale)
    setLabelStyle(Ui.target_hint, scaledFontSize(13), nil)

    safeAnchor(Ui.target_keybind, "TOPLEFT", Ui.target_canvas, "TOPLEFT", scaleValue(70, scale), scaleValue(102, scale))
    safeSetExtent(Ui.target_keybind, 210 * scale, 18 * scale)
    setLabelStyle(Ui.target_keybind, scaledFontSize(13), nil)

    safeAnchor(Ui.target_timer, "TOPLEFT", Ui.target_canvas, "TOPLEFT", scaleValue(-4, scale), scaleValue(94, scale))
    safeSetExtent(Ui.target_timer, 72 * scale, 18 * scale)

    safeAnchor(Ui.strength_icon, "TOPLEFT", Ui.target_canvas, "TOPLEFT", scaleValue(360, scale), scaleValue(34, scale))
    safeSetExtent(Ui.strength_icon, 44 * scale, 44 * scale)

    safeAnchor(Ui.strength_timer, "TOPLEFT", Ui.target_canvas, "TOPLEFT", scaleValue(346, scale), scaleValue(102, scale))
    safeSetExtent(Ui.strength_timer, 70 * scale, 18 * scale)
    setLabelStyle(Ui.strength_timer, scaledFontSize(16), nil)

    for _, row in ipairs(Ui.marker_rows) do
        safeSetExtent(row.canvas, 56 * scale, 64 * scale)
        safeAnchor(row.icon, "TOPLEFT", row.canvas, "TOPLEFT", 0, 0)
        safeSetExtent(row.icon, 44 * scale, 44 * scale)
        safeAnchor(row.marker_label, "TOPLEFT", row.canvas, "TOPLEFT", scaleValue(-8, scale), scaleValue(-20, scale))
        safeSetExtent(row.marker_label, 72 * scale, 18 * scale)
        setLabelStyle(row.marker_label, scaledFontSize(14), nil)
        safeAnchor(row.time_label, "TOPLEFT", row.canvas, "TOPLEFT", scaleValue(-8, scale), scaleValue(46, scale))
        safeSetExtent(row.time_label, 72 * scale, 20 * scale)
    end

    for _, row in ipairs(Ui.catch_rows) do
        safeSetExtent(row.canvas, 56 * scale, 64 * scale)
        safeAnchor(row.icon, "TOPLEFT", row.canvas, "TOPLEFT", 0, 0)
        safeSetExtent(row.icon, 44 * scale, 44 * scale)
        safeAnchor(row.marker_label, "TOPLEFT", row.canvas, "TOPLEFT", scaleValue(-8, scale), scaleValue(-20, scale))
        safeSetExtent(row.marker_label, 72 * scale, 18 * scale)
        setLabelStyle(row.marker_label, scaledFontSize(14), nil)
        safeAnchor(row.time_label, "TOPLEFT", row.canvas, "TOPLEFT", scaleValue(-8, scale), scaleValue(46, scale))
        safeSetExtent(row.time_label, 72 * scale, 20 * scale)
    end

    if Ui.boat_row ~= nil then
        safeSetExtent(Ui.boat_row.canvas, 56 * scale, 64 * scale)
        safeAnchor(Ui.boat_row.icon, "TOPLEFT", Ui.boat_row.canvas, "TOPLEFT", 0, 0)
        safeSetExtent(Ui.boat_row.icon, 44 * scale, 44 * scale)
        safeAnchor(Ui.boat_row.marker_label, "TOPLEFT", Ui.boat_row.canvas, "TOPLEFT", scaleValue(-8, scale), scaleValue(-20, scale))
        safeSetExtent(Ui.boat_row.marker_label, 72 * scale, 18 * scale)
        setLabelStyle(Ui.boat_row.marker_label, scaledFontSize(14), nil)
        safeAnchor(Ui.boat_row.time_label, "TOPLEFT", Ui.boat_row.canvas, "TOPLEFT", scaleValue(-8, scale), scaleValue(46, scale))
        safeSetExtent(Ui.boat_row.time_label, 72 * scale, 20 * scale)
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
    local label = safeCreateWidget("label", id, parent)
    if label == nil then
        return nil
    end
    safeAnchor(label, "TOPLEFT", parent, "TOPLEFT", x, y)
    safeSetExtent(label, width, height)
    safeSetText(label, "")
    if label.style ~= nil then
        if label.style.SetFontSize ~= nil then
            pcall(function()
                label.style:SetFontSize(fontSize or 14)
            end)
        end
        if label.style.SetAlign ~= nil and alignValue ~= nil then
            pcall(function()
                label.style:SetAlign(alignValue)
            end)
        end
        if label.style.SetShadow ~= nil then
            pcall(function()
                label.style:SetShadow(true)
            end)
        end
        if color ~= nil and label.style.SetColor ~= nil then
            pcall(function()
                label.style:SetColor(color[1], color[2], color[3], color[4] or 1)
            end)
        end
    end
    return label
end

local function createButton(id, parent, text, x, y, width, height, onClick)
    local button = safeCreateWidget("button", id, parent)
    if button == nil then
        return nil
    end
    safeAnchor(button, "TOPLEFT", parent, "TOPLEFT", x, y)
    safeSetExtent(button, width, height)
    safeSetText(button, text)
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
    if type(CreateItemIconButton) ~= "function" or parent == nil then
        return nil
    end
    local ok, icon = pcall(function()
        return CreateItemIconButton(id, parent)
    end)
    if not ok or icon == nil then
        return nil
    end
    safeSetVisible(icon, true)
    if F_SLOT ~= nil and F_SLOT.ApplySlotSkin ~= nil and SLOT_STYLE ~= nil and icon.back ~= nil then
        local style = SLOT_STYLE.DEFAULT or SLOT_STYLE.BUFF or SLOT_STYLE.ITEM
        if style ~= nil then
            pcall(function()
                F_SLOT.ApplySlotSkin(icon, icon.back, style)
            end)
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

local function cycleHelperScale()
    local settings = Shared.EnsureSettings()
    local current = normalizeHelperScale(settings.helper_scale)
    local index = 1
    for optionIndex, optionValue in ipairs(HELPER_SCALE_OPTIONS) do
        if optionValue == current then
            index = optionIndex
            break
        end
    end
    index = index + 1
    if index > #HELPER_SCALE_OPTIONS then
        index = 1
    end
    settings.helper_scale = HELPER_SCALE_OPTIONS[index]
    Shared.SaveSettings()
    applyHelperScale()
    notifySettingsChanged()
end

local function startFishingSession()
    Shared.StartFishingSession(Shared.GetUiNowMs())
    notifySettingsChanged()
end

local function endFishingSession()
    Shared.EndFishingSession(Shared.GetUiNowMs())
    notifySettingsChanged()
end

local function deleteFishingSession(sessionId)
    if sessionId == nil then
        return
    end
    Shared.DeleteFishingSession(sessionId)
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
            if settingKey == "helper_scale" then
                cycleHelperScale()
            else
                toggleSetting(settingKey)
            end
        end
    )
    Ui.settings_controls[settingKey] = button
end

local function createTargetHud()
    if Ui.target_canvas ~= nil then
        return
    end

    local canvas = safeCreateEmptyWindow("NuziFishingTargetHud")
    if canvas == nil then
        return
    end
    safeSetExtent(canvas, 420, 132)
    safeSetVisible(canvas, false)
    Ui.target_canvas = canvas
    applyTargetHudPosition()
    enableTargetHudDrag(canvas)
    Ui.target_bg = safeCreateColorDrawable(canvas, 0.04, 0.04, 0.04, 0.72, "background")
    safeAddAnchor(Ui.target_bg, "TOPLEFT", canvas, "TOPLEFT", -10, -6)
    safeAddAnchor(Ui.target_bg, "BOTTOMRIGHT", canvas, "BOTTOMRIGHT", 10, 6)

    Ui.target_icon = createIcon("NuziFishingTargetIcon", canvas)
    safeAnchor(Ui.target_icon, "TOPLEFT", canvas, "TOPLEFT", 12, 34)

    Ui.target_icon_mask = safeCreateColorDrawable(canvas, 0.08, 0.18, 0.24, 0.88, "overlay")
    safeAnchor(Ui.target_icon_mask, "TOPLEFT", Ui.target_icon, "TOPLEFT", 1, 1)
    safeAnchor(Ui.target_icon_mask, "BOTTOMRIGHT", Ui.target_icon, "BOTTOMRIGHT", -1, -1)
    safeSetDrawableVisible(Ui.target_icon_mask, false)
    Ui.target_icon_text = createLabel("NuziFishingIconText", canvas, 6, 52, 60, 18, 16, getAlignCenter(), { 0.82, 0.98, 1, 1 })
    safeSetVisible(Ui.target_icon_text, false)

    Ui.target_glow = safeCreateColorDrawable(canvas, 1, 1, 1, 0, "background")
    safeAnchor(Ui.target_glow, "TOPLEFT", Ui.target_icon, "TOPLEFT", -4, -4)
    safeAnchor(Ui.target_glow, "BOTTOMRIGHT", Ui.target_icon, "BOTTOMRIGHT", 4, 4)
    safeSetDrawableVisible(Ui.target_glow, false)

    Ui.target_fish_name = createLabel("NuziFishingFishName", canvas, 12, 6, 260, 20, 16, getAlignLeft(), { 1, 1, 1, 1 })
    Ui.target_status = createLabel("NuziFishingStatus", canvas, 70, 34, 220, 18, 13, getAlignLeft(), { 0.8, 0.9, 1, 1 })
    Ui.target_coach = createLabel("NuziFishingCoach", canvas, 70, 52, 240, 28, 24, getAlignLeft(), { 1, 0.82, 0.25, 1 })
    Ui.target_hint = createLabel("NuziFishingHint", canvas, 70, 82, 290, 18, 13, getAlignLeft(), { 0.9, 0.9, 0.9, 1 })
    Ui.target_keybind = createLabel("NuziFishingKeybind", canvas, 70, 102, 210, 18, 13, getAlignLeft(), { 1, 1, 1, 1 })
    Ui.target_timer = createLabel("NuziFishingTargetTimer", canvas, -4, 94, 72, 18, 16, getAlignCenter(), { 0, 1, 0, 1 })

    Ui.strength_icon = createIcon("NuziFishingStrengthIcon", canvas)
    safeAnchor(Ui.strength_icon, "TOPLEFT", canvas, "TOPLEFT", 360, 34)
    safeSetVisible(Ui.strength_icon, false)
    Ui.strength_timer = createLabel("NuziFishingStrengthTimer", canvas, 346, 102, 70, 18, 16, getAlignLeft(), { 1, 1, 0, 1 })

    attachTargetDrag(canvas)
    attachTargetDrag(Ui.target_icon)
    attachTargetDrag(Ui.target_fish_name)
    attachTargetDrag(Ui.target_status)
    attachTargetDrag(Ui.target_coach)
    attachTargetDrag(Ui.target_hint)
    attachTargetDrag(Ui.target_keybind)
    attachTargetDrag(Ui.target_timer)
    attachTargetDrag(Ui.strength_icon)
    attachTargetDrag(Ui.strength_timer)
end

local function createTimerRows()
    if #Ui.marker_rows == 0 then
        for markerIndex = 1, Constants.MARKER_COUNT do
            local canvas = safeCreateEmptyWindow("NuziFishingMarkerRow" .. tostring(markerIndex))
            if canvas ~= nil then
                safeSetExtent(canvas, 56, 64)
                safeSetVisible(canvas, false)
                local icon = createIcon("NuziFishingMarkerIcon" .. tostring(markerIndex), canvas)
                safeAnchor(icon, "TOPLEFT", canvas, "TOPLEFT", 0, 0)
                local label = createLabel("NuziFishingMarkerLabel" .. tostring(markerIndex), canvas, -8, -20, 72, 18, 14, getAlignCenter(), { 1, 1, 1, 1 })
                local time = createLabel("NuziFishingMarkerTime" .. tostring(markerIndex), canvas, -8, 46, 72, 20, 18, getAlignCenter(), { 1, 0.5, 0, 1 })
                Ui.marker_rows[markerIndex] = { canvas = canvas, icon = icon, marker_label = label, time_label = time }
            end
        end
    end

    if #Ui.catch_rows == 0 then
        for index = 1, Constants.AUTO_CATCH_COUNT do
            local canvas = safeCreateEmptyWindow("NuziFishingCatchRow" .. tostring(index))
            if canvas ~= nil then
                safeSetExtent(canvas, 56, 64)
                safeSetVisible(canvas, false)
                local icon = createIcon("NuziFishingCatchIcon" .. tostring(index), canvas)
                safeAnchor(icon, "TOPLEFT", canvas, "TOPLEFT", 0, 0)
                local label = createLabel("NuziFishingCatchLabel" .. tostring(index), canvas, -8, -20, 72, 18, 14, getAlignCenter(), { 1, 0.85, 0.85, 1 })
                local time = createLabel("NuziFishingCatchTime" .. tostring(index), canvas, -8, 46, 72, 20, 18, getAlignCenter(), { 1, 0.3, 0.3, 1 })
                Ui.catch_rows[index] = { canvas = canvas, icon = icon, marker_label = label, time_label = time }
            end
        end
    end
end

local function createBoatRow()
    if Ui.boat_row ~= nil then
        return
    end

    local canvas = safeCreateEmptyWindow("NuziFishingBoatRow")
    if canvas == nil then
        return
    end
    safeSetExtent(canvas, 56, 64)
    safeSetVisible(canvas, false)
    local icon = createIcon("NuziFishingBoatIcon", canvas)
    safeAnchor(icon, "TOPLEFT", canvas, "TOPLEFT", 0, 0)
    local label = createLabel("NuziFishingBoatLabel", canvas, -8, -20, 72, 18, 14, getAlignCenter(), { 0.3, 0.6, 1, 1 })
    local time = createLabel("NuziFishingBoatTime", canvas, -8, 46, 72, 20, 18, getAlignCenter(), { 0.3, 0.6, 1, 1 })
    safeSetText(label, "Boat")
    Ui.boat_row = { canvas = canvas, icon = icon, marker_label = label, time_label = time }
end

local function createSessionWindow()
    if Ui.session_window ~= nil then
        return
    end

    local window = safeCreateEmptyWindow("NuziFishingSession")
    if window == nil then
        return
    end
    safeSetExtent(window, 360, 268)
    safeSetVisible(window, false)
    Ui.session_window = window
    applySessionPosition()
    enableSessionDrag(window)
    local bg = safeCreateColorDrawable(window, 0.05, 0.05, 0.05, 0.78, "background")
    safeAddAnchor(bg, "TOPLEFT", window, "TOPLEFT", -10, -8)
    safeAddAnchor(bg, "BOTTOMRIGHT", window, "BOTTOMRIGHT", 10, 8)
    Ui.session_title = createLabel("NuziFishingSessionTitle", window, 0, 0, 220, 22, 16, getAlignLeft(), { 1, 1, 1, 1 })
    Ui.session_buttons.start = createButton("NuziFishingSessionStart", window, "Start", 234, 0, 54, 24, startFishingSession)
    Ui.session_buttons.finish = createButton("NuziFishingSessionFinish", window, "End", 294, 0, 54, 24, endFishingSession)
    Ui.session_labels.elapsed = createLabel("NuziFishingSessionElapsed", window, 0, 30, 160, 18, 14, getAlignLeft(), { 1, 1, 1, 1 })
    Ui.session_labels.catches = createLabel("NuziFishingSessionCatches", window, 0, 48, 160, 18, 14, getAlignLeft(), { 1, 0.9, 0.5, 1 })
    Ui.session_labels.active = createLabel("NuziFishingSessionActive", window, 170, 30, 160, 18, 14, getAlignLeft(), { 1, 0.8, 0.8, 1 })
    Ui.session_labels.marked = createLabel("NuziFishingSessionMarked", window, 170, 48, 160, 18, 14, getAlignLeft(), { 1, 0.7, 0.4, 1 })
    Ui.session_labels.fish_header = createLabel("NuziFishingSessionFishHeader", window, 0, 76, 160, 18, 13, getAlignLeft(), { 0.8, 0.92, 1, 1 })
    safeSetText(Ui.session_labels.fish_header, "Current Session Fish")
    for index = 1, 4 do
        Ui.session_fish_labels[index] = createLabel(
            "NuziFishingSessionFish" .. tostring(index),
            window,
            0,
            96 + ((index - 1) * 18),
            330,
            18,
            13,
            getAlignLeft(),
            { 0.96, 0.96, 0.96, 1 }
        )
    end
    Ui.session_labels.history_header = createLabel("NuziFishingSessionHistoryHeader", window, 0, 176, 160, 18, 13, getAlignLeft(), { 0.8, 0.92, 1, 1 })
    safeSetText(Ui.session_labels.history_header, "Recent Sessions")
    for index = 1, 4 do
        local rowIndex = index
        local rowY = 198 + ((index - 1) * 34)
        local title = createLabel("NuziFishingSessionHistoryTitle" .. tostring(index), window, 0, rowY, 228, 16, 13, getAlignLeft(), { 1, 1, 1, 1 })
        local detail = createLabel("NuziFishingSessionHistoryDetail" .. tostring(index), window, 0, rowY + 14, 280, 16, 12, getAlignLeft(), { 0.85, 0.85, 0.85, 1 })
        local remove = createButton("NuziFishingSessionDelete" .. tostring(index), window, "X", 314, rowY + 2, 30, 22, function()
            local row = Ui.session_history_rows[rowIndex]
            if row ~= nil then
                deleteFishingSession(row.session_id)
            end
        end)
        Ui.session_history_rows[index] = {
            title = title,
            detail = detail,
            remove = remove,
            session_id = nil
        }
    end
end

local function createSettingsWindow()
    if Ui.settings_window ~= nil then
        return
    end

    local height = 72 + (#SETTINGS_ROWS * 30)
    local window = safeCreateWindow("NuziFishingSettings", Constants.ADDON_NAME, 320, height)
    if window == nil then
        return
    end
    safeAddAnchor(window, "CENTER", "UIParent", 0, 0)
    applyCommonWindowBehavior(window)
    safeSetVisible(window, false)

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
    createSettingsWindow()
    applyHelperScale()
end

function Ui.RefreshSettings()
    local settings = Shared.EnsureSettings()
    applyHelperScale()
    for key, button in pairs(Ui.settings_controls) do
        if button ~= nil and button.SetText ~= nil then
            if key == "helper_scale" then
                button:SetText(getHelperScaleLabel())
            else
                button:SetText(settings[key] and "On" or "Off")
            end
        end
    end
end

function Ui.ToggleSettings()
    createSettingsWindow()
    if Ui.settings_window ~= nil then
        local visible = false
        if Ui.settings_window.IsVisible ~= nil then
            local ok, value = pcall(function()
                return Ui.settings_window:IsVisible()
            end)
            visible = ok and value and true or false
        end
        safeSetVisible(Ui.settings_window, not visible)
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
    local helperScale = getHelperScale()
    local hasPlaceholder = type(target.icon_placeholder_text) == "string" and target.icon_placeholder_text ~= ""
    local hasIcon = type(target.icon_path) == "string" and target.icon_path ~= ""
    local targetVisible = target.visible and (hasIcon or hasPlaceholder)
    safeSetVisible(Ui.target_canvas, targetVisible)
    if targetVisible then
        if hasIcon then
            safeSetIcon(Ui.target_icon, target.icon_path)
        end
        safeSetVisible(Ui.target_icon, hasIcon)
        safeSetDrawableVisible(Ui.target_icon_mask, hasPlaceholder)
        safeSetText(Ui.target_icon_text, hasPlaceholder and target.icon_placeholder_text or "")
        safeSetVisible(Ui.target_icon_text, hasPlaceholder)
        safeSetText(Ui.target_fish_name, target.fish_name or "")
        safeSetText(Ui.target_status, target.status_text or "")
        safeSetText(Ui.target_coach, target.coach_text or "")
        safeSetText(Ui.target_hint, target.coach_hint or "")
        safeSetText(Ui.target_keybind, target.keybind_text or "")
        safeSetText(Ui.target_timer, target.timer_text or "")
        if target.emphasis == "big_reel_in" then
            setLabelStyle(Ui.target_coach, scaledFontSize(24), { 1, 0.92, 0.3, 1 })
            setLabelStyle(Ui.target_timer, scaledFontSize(16), getTimerColor(target.timer_text or "", { 1, 0.82, 0.22, 1 }))
            safeSetDrawableColor(Ui.target_glow, { 0.95, 0.75, 0.1, 0.28 })
            safeSetDrawableVisible(Ui.target_glow, true)
        elseif target.emphasis == "reel_in" then
            setLabelStyle(Ui.target_coach, scaledFontSize(24), { 1, 0.58, 0.18, 1 })
            setLabelStyle(Ui.target_timer, scaledFontSize(16), getTimerColor(target.timer_text or "", { 1, 0.58, 0.18, 1 }))
            safeSetDrawableColor(Ui.target_glow, { 1, 0.45, 0.1, 0.24 })
            safeSetDrawableVisible(Ui.target_glow, true)
        else
            setLabelStyle(Ui.target_coach, scaledFontSize(22), { 0.85, 0.9, 1, 1 })
            setLabelStyle(Ui.target_timer, scaledFontSize(16), getTimerColor(target.timer_text or "", { 0, 1, 0, 1 }))
            safeSetDrawableVisible(Ui.target_glow, false)
        end

        local showStrength = target.strength_visible and type(target.strength_icon_path) == "string" and target.strength_icon_path ~= ""
        safeSetVisible(Ui.strength_icon, showStrength)
        if showStrength then
            safeSetIcon(Ui.strength_icon, target.strength_icon_path)
        end
        safeSetText(Ui.strength_timer, target.strength_timer_text or "")
    else
        safeSetVisible(Ui.target_icon, false)
        safeSetDrawableVisible(Ui.target_icon_mask, false)
        safeSetVisible(Ui.target_icon_text, false)
        safeSetDrawableVisible(Ui.target_glow, false)
    end

    local markers = uiState.markers or {}
    local activeCount = 0
    local rowSpacing = 50 * helperScale
    local rowBaseOffset = -125 * helperScale
    local rowBaseY = 200 * helperScale
    for index = 1, Constants.MARKER_COUNT do
        local row = Ui.marker_rows[index]
        local data = markers[index]
        if row ~= nil and data ~= nil then
            local offsetX = (activeCount * rowSpacing) + rowBaseOffset
            safeAnchor(row.canvas, "TOP", "UIParent", "CENTER", offsetX, rowBaseY)
            safeSetIcon(row.icon, data.icon_path)
            safeSetText(row.time_label, data.timer_text or "")
            safeSetText(row.marker_label, tostring(data.index or index))
            setLabelStyle(row.time_label, scaledFontSize(18), getTimerColor(data.timer_text or "", { 1, 0.5, 0, 1 }))
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
            local offsetX = ((activeCount + catchCount) * rowSpacing) + rowBaseOffset
            safeAnchor(row.canvas, "TOP", "UIParent", "CENTER", offsetX, rowBaseY)
            safeSetIcon(row.icon, data.icon_path)
            safeSetText(row.time_label, data.timer_text or "")
            safeSetText(row.marker_label, tostring(data.serial or index))
            setLabelStyle(row.time_label, scaledFontSize(18), getTimerColor(data.timer_text or "", { 1, 0.3, 0.3, 1 }))
            safeSetVisible(row.canvas, true)
            catchCount = catchCount + 1
        elseif row ~= nil then
            safeSetVisible(row.canvas, false)
        end
    end

    local boat = uiState.boat or {}
    if Ui.boat_row ~= nil then
        if boat.visible and type(boat.icon_path) == "string" and boat.icon_path ~= "" then
            local offsetX = ((activeCount + catchCount) * rowSpacing) + rowBaseOffset
            safeAnchor(Ui.boat_row.canvas, "TOP", "UIParent", "CENTER", offsetX, rowBaseY)
            safeSetIcon(Ui.boat_row.icon, boat.icon_path)
            safeSetText(Ui.boat_row.time_label, boat.timer_text or "")
            setLabelStyle(Ui.boat_row.time_label, scaledFontSize(18), getTimerColor(boat.timer_text or "", { 0.3, 0.6, 1, 1 }))
            safeSetVisible(Ui.boat_row.canvas, true)
        else
            safeSetVisible(Ui.boat_row.canvas, false)
        end
    end

    local session = uiState.session or {}
    if session.visible and Ui.session_window == nil then
        createSessionWindow()
    end
    safeSetVisible(Ui.session_window, session.visible)
    if session.visible then
        safeSetText(Ui.session_title, session.title_text or "")
        safeSetText(Ui.session_labels.elapsed, session.elapsed_text or "")
        safeSetText(Ui.session_labels.catches, session.catches_text or "")
        safeSetText(Ui.session_labels.active, session.active_text or "")
        safeSetText(Ui.session_labels.marked, session.marked_text or "")
        safeSetVisible(Ui.session_buttons.start, not session.has_active)
        safeSetVisible(Ui.session_buttons.finish, session.has_active)
        safeSetVisible(Ui.session_labels.fish_header, session.has_active)
        for index = 1, 4 do
            local fishText = session.fish_lines ~= nil and session.fish_lines[index] or nil
            local label = Ui.session_fish_labels[index]
            if label ~= nil then
                safeSetText(label, fishText or "")
                safeSetVisible(label, fishText ~= nil and fishText ~= "")
            end
        end
        safeSetVisible(Ui.session_labels.history_header, true)
        for index = 1, 4 do
            local row = Ui.session_history_rows[index]
            local item = session.history ~= nil and session.history[index] or nil
            if row ~= nil then
                if item ~= nil then
                    row.session_id = item.id
                    safeSetText(row.title, item.title or "")
                    local detailText = tostring(item.detail or "")
                    if item.fish ~= nil and item.fish ~= "" then
                        detailText = detailText .. " | " .. tostring(item.fish)
                    end
                    safeSetText(row.detail, detailText)
                    safeSetVisible(row.title, true)
                    safeSetVisible(row.detail, true)
                    safeSetVisible(row.remove, true)
                else
                    row.session_id = nil
                    safeSetVisible(row.title, false)
                    safeSetVisible(row.detail, false)
                    safeSetVisible(row.remove, false)
                end
            end
        end
    end
end

function Ui.Unload()
    Ui.HideHud()
    if Ui.settings_window ~= nil then
        safeSetVisible(Ui.settings_window, false)
        Ui.settings_window = nil
    end
    Ui.target_canvas = nil
    Ui.target_bg = nil
    Ui.target_icon = nil
    Ui.target_icon_mask = nil
    Ui.target_icon_text = nil
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
    Ui.session_title = nil
    Ui.session_labels = {}
    Ui.session_buttons = {}
    Ui.session_fish_labels = {}
    Ui.session_history_rows = {}
    Ui.settings_controls = {}
    Ui.on_settings_changed = nil
end

return Ui
