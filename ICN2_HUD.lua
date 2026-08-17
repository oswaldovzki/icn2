-- ============================================================
-- ICN2_HUD.lua
-- The Vitality Instrument: a roleplay-first character needs display.
-- ============================================================

ICN2 = ICN2 or {}

local L = setmetatable({}, { __index = function(_, key)
    return ICN2.L and ICN2.L[key] or key
end })

local NEEDS = { "hunger", "thirst", "fatigue" }
local ASSET = "Interface\\AddOns\\ICN2\\assets\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local EPSILON = 0.002

local hudFrame, instrument, readout, content
local needFrames = {}
local actionButtons = {}

local PALETTE = {
    ink       = { 0.012, 0.016, 0.026, 0.98 },
    panel     = { 0.024, 0.032, 0.050, 0.97 },
    panelAlt  = { 0.040, 0.051, 0.075, 0.94 },
    edge      = { 0.25, 0.31, 0.43, 0.95 },
    silver    = { 0.78, 0.84, 0.92, 1 },
    dim       = { 0.42, 0.48, 0.58, 1 },
    orange    = { 1.00, 0.42, 0.12, 1 },
    danger    = { 1.00, 0.18, 0.12, 1 },
    recovery  = { 0.24, 0.92, 0.52, 1 },
}

local NEED_COLOR = {
    hunger  = { 0.98, 0.46, 0.16 },
    thirst  = { 0.20, 0.63, 1.00 },
    fatigue = { 0.73, 0.38, 1.00 },
}

local function setColor(texture, c)
    texture:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
end

local function setText(fontString, c)
    fontString:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

local function label(parent, text, font, c)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetText(text or "")
    if c then setText(fs, c) end
    return fs
end

local function backdrop(frame, bg, edge, edgeSize)
    frame:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = edgeSize or 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
end

local function stripe(parent, point, relative, relPoint, width, height, c)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetPoint(point, relative, relPoint, 0, 0)
    tex:SetSize(width, height)
    setColor(tex, c)
    return tex
end

local function makeCornerMarkers(parent, size, c)
    local marker = {}
    marker.tl = stripe(parent, "TOPLEFT", parent, "TOPLEFT", size, 1, c)
    marker.tl:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    marker.tr = stripe(parent, "TOPRIGHT", parent, "TOPRIGHT", size, 1, c)
    marker.bl = stripe(parent, "BOTTOMLEFT", parent, "BOTTOMLEFT", size, 1, c)
    marker.br = stripe(parent, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", size, 1, c)
    for _, tex in pairs(marker) do tex:SetHeight(1) end
    return marker
end

local function iconButton(parent, texture, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.texture = button:CreateTexture(nil, "ARTWORK")
    button.texture:SetAllPoints()
    button.texture:SetTexture(texture)
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    return button
end

local function applyAnchor(frame, anchor, relative)
    frame:ClearAllPoints()
    frame:SetPoint(anchor.point or "CENTER", relative, anchor.relPoint or anchor.point or "CENTER", anchor.x or 0, anchor.y or 0)
end

local function getThemeId()
    local id = ICN2DB and ICN2DB.settings and ICN2DB.settings.barTheme
    if id == "minimalistV" or id == "minimalistH" then return "minimal" end
    if id == "smooth" or id == "blocky" or id == "vanguard" then return "field" end
    return id == "field" and "field" or "relic"
end

local THEMES = {
    relic = { id = "relic", label = "Relic Instrument", width = 366, height = 174, cardHeight = 94, gap = 7, scale = 1 },
    field = { id = "field", label = "Field Ledger", width = 410, height = 160, cardHeight = 82, gap = 8, scale = 1 },
    minimal = { id = "minimal", label = "Pocket Tokens", width = 246, height = 86, cardHeight = 70, gap = 5, scale = 1.15 },
}

ICN2.HUD_THEMES = {
    relic = { id = "relic", label = "Relic Instrument", mode = "instrument" },
    field = { id = "field", label = "Field Ledger", mode = "instrument" },
    minimal = { id = "minimal", label = "Pocket Tokens", mode = "minimalist" },
    -- Legacy ids remain readable for existing saved variables.
    colorful = { id = "relic", label = "Relic Instrument", mode = "instrument" },
    smooth = { id = "field", label = "Field Ledger", mode = "instrument" },
    blocky = { id = "field", label = "Field Ledger", mode = "instrument" },
    minimalistV = { id = "minimal", label = "Pocket Tokens", mode = "minimalist" },
    minimalistH = { id = "minimal", label = "Pocket Tokens", mode = "minimalist" },
}

ICN2.HUD_THEME_LIST = { ICN2.HUD_THEMES.relic, ICN2.HUD_THEMES.field, ICN2.HUD_THEMES.minimal }

local function selectedColor(key, value)
    local critical = ICN2.THRESHOLDS and ICN2.THRESHOLDS.critical or 20
    local low = ICN2.THRESHOLDS and ICN2.THRESHOLDS.low or 50
    if value <= critical then return PALETTE.danger[1], PALETTE.danger[2], PALETTE.danger[3] end
    if value <= low then return 1.0, 0.62, 0.12 end
    local settings = ICN2DB and ICN2DB.settings
    local palette = settings and settings.colorPalette and ICN2.Palettes and ICN2.Palettes[settings.colorPalette]
    local custom = palette and palette[key]
    local c = custom or NEED_COLOR[key]
    return c[1], c[2], c[3]
end

local function indicatorTexture(rate)
    local name = "ICN2_paused.png"
    if rate >= 0.278 then name = "ICN2_up_3.png"
    elseif rate >= 0.167 then name = "ICN2_up_2.png"
    elseif rate > EPSILON then name = "ICN2_up_1.png"
    elseif rate <= -0.100 then name = "ICN2_down_3.png"
    elseif rate <= -0.050 then name = "ICN2_down_2.png"
    elseif rate < -EPSILON then name = "ICN2_down_1.png" end
    return ASSET .. name
end

local function setLabelMode(data, mode, value, current, maximum)
    data.value:Hide(); data.detail:Hide()
    if mode == "none" then return end
    local percent = string.format("%.0f%%", value)
    local number = string.format("%.0f / %.0f", current, maximum)
    if mode == "number" then data.value:SetText(number); data.value:Show()
    elseif mode == "both" then data.value:SetText(number); data.detail:SetText(percent); data.value:Show(); data.detail:Show()
    else data.value:SetText(percent); data.value:Show() end
end

local function currentSituation()
    local state = ICN2.State or {}
    if state.isResting then return L["DETAILS_SITUATION_RESTING"]
    elseif state.inCombat then return L["DETAILS_SITUATION_COMBAT"]
    elseif state.isMounted then return L["DETAILS_SITUATION_MOUNTED"]
    elseif state.isSwimming then return L["DETAILS_SITUATION_SWIMMING"]
    elseif state.isIndoors then return L["DETAILS_SITUATION_INDOORS"] end
    return L["DETAILS_SITUATION_IDLE"]
end

function ICN2:ApplyHUDAnchor()
    if not hudFrame then return end
    local settings = ICN2DB.settings
    hudFrame:ClearAllPoints()
    if settings.hudAttached and _G.PlayerFrame then
        hudFrame:SetPoint("TOPLEFT", _G.PlayerFrame, "TOPRIGHT", 10, -4)
    else
        local position = settings.hudPosition or { point="CENTER", relPoint="CENTER", x=0, y=0 }
        hudFrame:SetPoint(position.point or "CENTER", UIParent, position.relPoint or "CENTER", position.x or 0, position.y or 0)
    end
end

local function addSignal(data, texture, x, y, size)
    local signal = data.card:CreateTexture(nil, "OVERLAY")
    signal:SetTexture(texture)
    signal:SetSize(size, size)
    signal:SetPoint("BOTTOMRIGHT", data.card, "BOTTOMRIGHT", x, y)
    data.signal = signal
end

local function buildNeedCard(key)
    local card = CreateFrame("Frame", "ICN2NeedCard_" .. key, content, "BackdropTemplate")
    local data = { key = key, card = card }
    data.cardLabel = label(card, L[string.upper(key)], "GameFontHighlightSmall", PALETTE.dim)
    data.cardLabel:SetPoint("TOPLEFT", card, "TOPLEFT", 9, -7)
    data.icon = card:CreateTexture(nil, "ARTWORK")
    data.icon:SetSize(34, 34); data.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -27); data.icon:SetTexCoord(.08,.92,.08,.92)
    data.icon:SetTexture(ASSET .. (key == "hunger" and "ICN2_hunger_chicken.png" or key == "thirst" and "ICN2_thirst.png" or "ICN2_fatigue.png"))
    data.halo = card:CreateTexture(nil, "BORDER")
    data.halo:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    data.halo:SetVertexColor(1,1,1,0.18); data.halo:SetSize(42,42); data.halo:SetPoint("CENTER", data.icon, "CENTER")
    data.fill = CreateFrame("StatusBar", nil, card)
    data.fill:SetPoint("TOPLEFT", card, "TOPLEFT", 51, -29); data.fill:SetPoint("TOPRIGHT", card, "TOPRIGHT", -9, -29); data.fill:SetHeight(14)
    data.fill:SetMinMaxValues(0,100); data.fill:SetValue(100); data.fill:SetStatusBarTexture(WHITE)
    data.track = card:CreateTexture(nil, "BACKGROUND"); data.track:SetAllPoints(data.fill); setColor(data.track, PALETTE.ink)
    data.tick = card:CreateTexture(nil, "ARTWORK"); data.tick:SetSize(1, 14); data.tick:SetPoint("CENTER", data.fill, "CENTER"); setColor(data.tick, PALETTE.edge)
    data.value = label(card, "", "GameFontNormalSmall", PALETTE.silver); data.value:SetPoint("TOPRIGHT", data.fill, "BOTTOMRIGHT", 0, -4)
    data.detail = label(card, "", "GameFontDisableSmall", PALETTE.dim); data.detail:SetPoint("TOPLEFT", data.fill, "BOTTOMLEFT", 0, -4)
    data.rate = label(card, "", "GameFontDisableSmall", PALETTE.dim); data.rate:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 9, 6)
    data.rate:SetWidth(100); data.rate:SetJustifyH("LEFT")
    data.signal = card:CreateTexture(nil, "OVERLAY"); data.signal:SetSize(14,14); data.signal:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 5)
    data.pulse = CreateFrame("Frame", nil, card); data.pulse:SetAllPoints(card); data.pulse:SetScript("OnUpdate", function(self, elapsed)
        if not data.pulsing then return end
        data.pulseTime = (data.pulseTime or 0) + elapsed
        data.signal:SetAlpha(0.45 + 0.55 * (0.5 + 0.5 * math.sin(data.pulseTime * 4)))
    end)
    card:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[string.upper(key)], 1,1,1)
        GameTooltip:AddLine(string.format("%.1f%%", ICN2:GetNeedPercent(key)), 0.8,0.85,0.92)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    needFrames[key] = data
end

function ICN2:BuildHUD()
    local settings = ICN2DB.settings
    hudFrame = CreateFrame("Frame", "ICN2HUDFrame", UIParent, "BackdropTemplate")
    hudFrame:SetFrameStrata("MEDIUM"); hudFrame:SetClampedToScreen(true); hudFrame:SetMovable(true); hudFrame:EnableMouse(true); hudFrame:RegisterForDrag("LeftButton")
    local position = settings.hudPosition or { point="CENTER", relPoint="CENTER", x=0, y=0 }
    hudFrame:SetPoint(position.point or "CENTER", UIParent, position.relPoint or "CENTER", position.x or 0, position.y or 0)
    self:ApplyHUDAnchor()
    hudFrame:SetScript("OnDragStart", function(self) if not ICN2DB.settings.hudLocked and not ICN2DB.settings.hudAttached then self:StartMoving() end end)
    hudFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ICN2DB.settings.hudPosition = { point=point, relPoint=relPoint, x=x, y=y }; ICN2DB.settings.hudX=x; ICN2DB.settings.hudY=y
    end)
    hudFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(L["TOOLTIP_TITLE"], 1,1,1)
        for _, key in ipairs(NEEDS) do GameTooltip:AddLine(string.format(L["TOOLTIP_"..string.upper(key)], ICN2:GetNeedPercent(key)), 0.8,0.85,0.92) end
        GameTooltip:AddLine(" "); GameTooltip:AddLine(L["TOOLTIP_HINT"], .65,.7,.78); GameTooltip:Show()
    end)
    hudFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    instrument = CreateFrame("Frame", nil, hudFrame, "BackdropTemplate")
    readout = CreateFrame("Frame", nil, hudFrame, "BackdropTemplate")
    content = CreateFrame("Frame", nil, hudFrame)
    for _, key in ipairs(NEEDS) do buildNeedCard(key) end

    local title = label(instrument, "ICN2", "GameFontNormalLarge", PALETTE.orange); title:SetPoint("TOPLEFT", instrument, "TOPLEFT", 12, -8)
    local titleSub = label(instrument, L["HUD_INSTRUMENT"], "GameFontDisableSmall", PALETTE.dim); titleSub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -1)
    actionButtons[1] = iconButton(instrument, ASSET .. "ICN2_details.png", 17); actionButtons[1]:SetScript("OnClick", function() ICN2:PrintDetails() end)
    actionButtons[2] = iconButton(instrument, ASSET .. "ICN2_settings.png", 17); actionButtons[2]:SetScript("OnClick", function() ICN2:ToggleOptions() end)
    actionButtons[3] = CreateFrame("Button", nil, instrument, "SecureActionButtonTemplate"); actionButtons[3]:SetSize(17,17); actionButtons[3]:SetAttribute("type","spell"); actionButtons[3]:SetAttribute("spell",1231411); actionButtons[3]:SetAttribute("useOnKeyDown",false); actionButtons[3]:RegisterForClicks("AnyUp","AnyDown"); actionButtons[3].texture=actionButtons[3]:CreateTexture(nil,"ARTWORK"); actionButtons[3].texture:SetAllPoints(); actionButtons[3].texture:SetTexture(ASSET.."ICN2_quick-rest.png")
    local notice = label(readout, "", "GameFontHighlightSmall", PALETTE.silver); notice:SetPoint("TOPLEFT", readout, "TOPLEFT", 10, -7); notice:SetPoint("TOPRIGHT", readout, "TOPRIGHT", -10, -7); notice:SetJustifyH("RIGHT"); readout.notice=notice
    local situation = label(readout, "", "GameFontDisableSmall", PALETTE.dim); situation:SetPoint("TOPLEFT", notice, "BOTTOMLEFT", 0, -2); situation:SetPoint("TOPRIGHT", readout, "TOPRIGHT", -10, -25); situation:SetJustifyH("RIGHT"); readout.situation=situation
    hudFrame:SetAlpha(settings.hudAlpha or 1); self:ApplyHUDTheme(settings.barTheme or "relic"); self:LockHUD(settings.hudLocked)
    if not settings.hudEnabled then hudFrame:Hide() end
end

function ICN2:ApplyHUDTheme(themeId)
    if not hudFrame then return end
    local id = themeId
    if not THEMES[id] then id = getThemeId() end
    local theme = THEMES[id] or THEMES.relic
    local s = ICN2DB.settings
    s.barTheme = id
    hudFrame:SetSize(theme.width, theme.height); hudFrame:SetScale((s.hudScale or 1) * theme.scale)
    backdrop(hudFrame, PALETTE.ink, PALETTE.edge, 1)
    backdrop(instrument, PALETTE.panel, PALETTE.edge, 1); backdrop(readout, PALETTE.panelAlt, PALETTE.edge, 1)
    instrument:ClearAllPoints(); instrument:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 8, -8); instrument:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", -8, -8); instrument:SetHeight(42)
    readout:ClearAllPoints(); readout:SetPoint("TOPRIGHT", instrument, "TOPRIGHT", -7, -7); readout:SetSize(170, 28)
    content:ClearAllPoints(); content:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 8, -57); content:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", -8, 8)
    actionButtons[3]:ClearAllPoints(); actionButtons[3]:SetPoint("RIGHT", instrument, "RIGHT", -8, 0); actionButtons[2]:SetPoint("RIGHT", actionButtons[3], "LEFT", -5, 0); actionButtons[1]:SetPoint("RIGHT", actionButtons[2], "LEFT", -5, 0)
    local width = (theme.width - 16 - theme.gap * 2) / 3
    if id == "minimal" then
        instrument:SetHeight(1); instrument:Hide(); readout:Hide(); content:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 5, -5); content:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", -5, 5); width=(theme.width-10-theme.gap*2)/3
    else instrument:Show(); readout:Show() end
    for index,key in ipairs(NEEDS) do
        local data=needFrames[key]; data.card:SetSize(width, theme.cardHeight); data.card:ClearAllPoints(); data.card:SetPoint("TOPLEFT", content, "TOPLEFT", (index-1)*(width+theme.gap), 0); backdrop(data.card, PALETTE.panelAlt, PALETTE.edge, 1)
        if id == "minimal" then data.cardLabel:Hide(); data.icon:SetSize(27,27); data.icon:ClearAllPoints(); data.icon:SetPoint("CENTER", data.card, "CENTER"); data.halo:Hide(); data.fill:SetHeight(7); data.fill:ClearAllPoints(); data.fill:SetPoint("BOTTOMLEFT",data.card,"BOTTOMLEFT",7,7); data.fill:SetPoint("BOTTOMRIGHT",data.card,"BOTTOMRIGHT",-7,7); data.value:SetPoint("TOP",data.fill,"BOTTOM",0,-2); data.detail:Hide(); data.rate:Hide(); data.signal:SetSize(10,10); data.signal:SetPoint("TOPRIGHT",data.card,"TOPRIGHT",-4,-4)
        else data.cardLabel:Show(); data.icon:SetSize(34,34); data.icon:ClearAllPoints(); data.icon:SetPoint("TOPLEFT",data.card,"TOPLEFT",8,-27); data.halo:Show(); data.fill:SetHeight(14); data.fill:ClearAllPoints(); data.fill:SetPoint("TOPLEFT",data.card,"TOPLEFT",51,-29); data.fill:SetPoint("TOPRIGHT",data.card,"TOPRIGHT",-9,-29); data.rate:Show(); data.detail:Show(); data.signal:SetSize(14,14); data.signal:SetPoint("BOTTOMRIGHT",data.card,"BOTTOMRIGHT",-8,5) end
    end
end

function ICN2:SetBarTheme(themeId)
    self:ApplyHUDTheme(themeId); self:UpdateHUD()
end

function ICN2:ResizeBarLength()
    if hudFrame then self:ApplyHUDTheme(ICN2DB.settings.barTheme); self:UpdateHUD() end
end

function ICN2:LockHUD(locked)
    if hudFrame then hudFrame:EnableMouse(not locked) end
end

function ICN2:UpdateHUD()
    if not hudFrame then return end
    local settings=ICN2DB.settings; local inCombat=InCombatLockdown and InCombatLockdown()
    if not settings.hudEnabled then if not inCombat then hudFrame:Hide() end; ICN2._hudPendingShow=false; return end
    if inCombat then ICN2._hudPendingShow=true; return end
    ICN2._hudPendingShow=nil; hudFrame:Show()
    local rates=self:GetCurrentRates(); local labelMode=settings.barLabelMode or "percentage"; local critical=ICN2.THRESHOLDS and ICN2.THRESHOLDS.critical or 20
    local lowest=100; local recovering=false; local fading=false
    for _,key in ipairs(NEEDS) do
        local data=needFrames[key]; local value=self:GetNeedPercent(key) or 0; local current=ICN2DB[key] or 0; local maximum=self:GetMaxValue(key); local rate=rates[key] or 0; local r,g,b=selectedColor(key,value)
        if value<lowest then lowest=value end; if rate>EPSILON then recovering=true elseif rate < -EPSILON then fading=true end
        data.fill:SetValue(value); data.fill:SetStatusBarColor(r,g,b,1); data.fill:SetStatusBarTexture(WHITE); setLabelMode(data,labelMode,value,current,maximum)
        data.rate:SetText(rate>EPSILON and L["HUD_RECOVERING"] or rate < -EPSILON and L["HUD_DECAYING"] or L["HUD_STEADY"]); data.rate:SetTextColor(r,g,b,0.78)
        data.signal:SetTexture(indicatorTexture(rate)); data.signal:SetVertexColor(r,g,b,1); data.pulsing=math.abs(rate)>EPSILON; if not data.pulsing then data.signal:SetAlpha(1) end
    end
    local stateText = lowest <= critical and L["HUD_ATTENTION"] or recovering and L["HUD_RECOVERING"] or fading and L["HUD_IN_MOTION"] or L["HUD_STEADY"]
    readout.notice:SetText(stateText); readout.notice:SetTextColor(lowest <= critical and 1 or recovering and .3 or  .8, lowest <= critical and .25 or recovering and .95 or .85, lowest <= critical and .15 or recovering and .5 or 1)
    readout.situation:SetText(currentSituation())
end
