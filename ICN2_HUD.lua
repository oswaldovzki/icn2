-- ============================================================
-- ICN2_HUD.lua
-- On-screen HUD: hunger, thirst, fatigue.
-- Draggable, scalable.
-- ============================================================

ICN2 = ICN2 or {}

local L = setmetatable({}, { __index = function(_, k)
    return ICN2.L and ICN2.L[k] or k
end })

-- ── Module state ──────────────────────────────────────────────────────────────
local hudFrame
local headerFrame
local contentFrame
local chrome = {}
local bars   = {}
local headerBtns = {}

-- ── Layout constants ──────────────────────────────────────────────────────────
local BAR_H       = 20
local BAR_GAP     = 8
local ICON_SIZE   = 24
local NUM_BLOCKS  = 10
local BLOCK_GAP   = 2
local INDICATOR_W = 30
local HEADER_H    = 26
local CHROME_PAD  = 6

local BASE_BAR_W  = (BAR_H + BLOCK_GAP) * NUM_BLOCKS   -- 220px at scale 1.0

local NEED_KEYS = { "hunger", "thirst", "fatigue" }
local ASSETS_PATH = "Interface\\AddOns\\ICN2\\assets\\"

-- ── Default need icons ────────────────────────────────────────────────────────
local NEED_ICONS = {
    hunger  = ASSETS_PATH .. "inc2_hunger-chicken_icon.png",
    thirst  = ASSETS_PATH .. "inc2_thirst_icon.png",
    fatigue = ASSETS_PATH .. "inc2_fatigue_icon.png",
}

-- ── Fallback bar colors ───────────────────────────────────────────────────────
local BLOCK_COLORS = {
    hunger  = { 0.2, 0.9,  0.2 },
    thirst  = { 0.2, 0.5,  1.0 },
    fatigue = { 1.0, 0.85, 0.1 },
}

local DEFAULT_FILL_TEX = "Interface\\TargetingFrame\\UI-StatusBar"

local function MergeTheme(base, override)
    local result = {}
    for k, v in pairs(base) do
        if type(v) == "table" and type(override[k]) == "table" then
            result[k] = MergeTheme(v, override[k])
        else
            result[k] = override[k] ~= nil and override[k] or v
        end
    end
    for k, v in pairs(override or {}) do
        if result[k] == nil then
            result[k] = v
        end
    end
    return result
end

local function normalizeHUDTheme(theme, rawTheme)
    if not theme or not theme.layout then
        return theme
    end

    rawTheme = rawTheme or {}
    if not theme.layout.iconAnchor then
        theme.layout.iconAnchor = { point = "LEFT", relPoint = "LEFT", x = 0, y = 0 }
    end

    if not theme.layout.barAnchor then
        theme.layout.barAnchor = { point = "LEFT", relPoint = "LEFT", x = theme.layout.iconSize + 4, y = 0 }
    elseif not rawTheme.layout or not rawTheme.layout.barAnchor or rawTheme.layout.barAnchor.x == nil then
        theme.layout.barAnchor.x = theme.layout.iconSize + 4
    end

    if not theme.layout.glyphAnchor then
        theme.layout.glyphAnchor = { point = "RIGHT", relPoint = "RIGHT", x = -2, y = 0 }
    end

    return theme
end

ICN2.THEME_BASE = {
    layout = {
        showChrome = true,
        showHeader = true,
        showIcons  = true,
        showBars   = true,
        showGlyphs = true,
        barWidth   = BASE_BAR_W,
        barHeight  = BAR_H,
        iconSize   = ICON_SIZE,
        iconAnchor  = { point = "LEFT", relPoint = "LEFT", x = 0, y = 0 },
        barAnchor   = { point = "LEFT", relPoint = "LEFT", x = ICON_SIZE + 4, y = 0 },
        glyphAnchor = { point = "RIGHT", relPoint = "RIGHT", x = -2, y = 0 },
        
        -- NEW: Header button layout
        headerBtnAnchor = { point = "RIGHT", relPoint = "RIGHT", x = 0, y = -4 },
        headerBtnSize   = 24,
        headerBtnGap    = 4,
    },
    assets = {
        fillTex = DEFAULT_FILL_TEX,
        icons   = NEED_ICONS,
        
        -- NEW: Dynamic texture slots
        rowBG       = nil,
        indicatorBG = nil,
        headerBtns  = {
            btn1 = "loreobject-32x32",
            btn2 = "glues-characterSelect-icon-notify-inProgress-hover",
            btn3 = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
        }
    },
    barColors = BLOCK_COLORS,
}

-- ═══ SECTION 1 — Theme descriptors ═════════════════════════════════════════════
ICN2.HUD_THEMES = {

    colorful = {
        id    = "colorful",
        label = "Colorful (Default)",
        mode  = "smooth",
        layout = {
            iconSize = 16,
        },
        chrome = {
            bgCenter      = { 0.03, 0.03, 0.03, 0.25 },
            cornerTL      = nil, cornerTR = nil,
            cornerBL      = nil, cornerBR = nil,
            edgeTop       = nil, edgeBottom = nil,
            edgeLeft      = nil, edgeRight  = nil,
            titleStrip    = nil,
            cornerSize    = 6, edgeThickness = 2,
        },
        bar = {
            overlay = ASSETS_PATH .. "inc2_hunger_overlay-bar.png",
            bg      = ASSETS_PATH .. "icn2-bg-hunger-bar.png",
            fills   = {
                hunger  = ASSETS_PATH .. "inc2_hunger_barfill.png",
                thirst  = ASSETS_PATH .. "inc2_thirst_barfill.png",
                fatigue = ASSETS_PATH .. "inc2_sleep_barfill.png",
            },
        },
        barColors = nil,
    },

    minimalist = {
        id    = "minimalist",
        label = "Minimalist",
        mode  = "smooth",
        layout = {
            showChrome = false,
            showHeader = false,
            showBars   = false,
            showGlyphs = false,
            iconSize   = 64,
            iconAnchor = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
        },
    },

    smooth = {
        id    = "smooth",
        label = "Smooth",
        mode  = "smooth",
        chrome = {
            bgCenter      = { 0.05, 0.05, 0.05, 0.88 },
            cornerTL      = nil, cornerTR = nil,
            cornerBL      = nil, cornerBR = nil,
            edgeTop       = nil, edgeBottom = nil,
            edgeLeft      = nil, edgeRight  = nil,
            titleStrip    = nil,
            cornerSize    = 8, edgeThickness = 4,
        },
        bar = {
            bg      = { 0.12, 0.12, 0.12, 0.9 },
            fill    = DEFAULT_FILL_TEX,
            overlay = nil,
        },
        barColors = nil,
    },

    blocky = {
        id    = "blocky",
        label = "Blocky",
        mode  = "blocky",
        chrome = {
            bgCenter      = { 0.05, 0.05, 0.05, 0.88 },
            cornerTL      = nil, cornerTR = nil,
            cornerBL      = nil, cornerBR = nil,
            edgeTop       = nil, edgeBottom = nil,
            edgeLeft      = nil, edgeRight  = nil,
            titleStrip    = nil,
            cornerSize    = 8, edgeThickness = 4,
        },
        bar = {
            bg      = { 0.12, 0.12, 0.12, 0.9 },
            fill    = DEFAULT_FILL_TEX,
            overlay = nil,
        },
        barColors = nil,
    },

    folk = {
        id    = "folk",
        label = "Folk  |cFF888888(WIP)|r",
        mode  = "smooth",
        chrome = {
            bgCenter      = { 0.08, 0.05, 0.02, 0.92 },
            cornerTL      = nil, cornerTR = nil,
            cornerBL      = nil, cornerBR = nil,
            edgeTop       = nil, edgeBottom = nil,
            edgeLeft      = nil, edgeRight  = nil,
            titleStrip    = nil,
            cornerSize    = 8, edgeThickness = 4,
        },
        bar = {
            overlay = nil,
            bg      = { 0.10, 0.07, 0.04, 0.95 },
            fill    = DEFAULT_FILL_TEX,
        },
        barColors = {
            hunger  = { 0.85, 0.55, 0.15 },
            thirst  = { 0.30, 0.65, 0.90 },
            fatigue = { 0.70, 0.85, 0.30 },
        },
    },

    necromancer = {
        id    = "necromancer",
        label = "Necromancer",
        mode  = "smooth",
        layout = {
            cornerSize = 64,
            edgeThickness = 16,
            barAnchor = { point = "LEFT", relPoint = "LEFT", x = 40, y = 0 },
        },
        chrome = {
            bgCenter      = ASSETS_PATH .. "necromancer\\necro_parchment_bg.png",
            cornerTL      = ASSETS_PATH .. "necromancer\\necro_corner_TL.png",
            cornerTR      = ASSETS_PATH .. "necromancer\\necro_corner_TR.png",
            cornerBL      = ASSETS_PATH .. "necromancer\\necro_corner_BL.png",
            cornerBR      = ASSETS_PATH .. "necromancer\\necro_corner_BR.png",
            edgeTop       = ASSETS_PATH .. "necromancer\\necro_edge_top.png",
            edgeBottom    = ASSETS_PATH .. "necromancer\\necro_edge_bottom.png",
            edgeLeft      = ASSETS_PATH .. "necromancer\\necro_edge_left.png",
            edgeRight     = ASSETS_PATH .. "necromancer\\necro_edge_right.png",
            titleStrip    = ASSETS_PATH .. "necromancer\\necro_title_strip.png",
            cornerSize    = 64,
            edgeThickness = 16,
        },
        assets = {
            rowBG       = ASSETS_PATH .. "necromancer\\necro_row_metal_wrapper.png",
            indicatorBG = ASSETS_PATH .. "necromancer\\necro_indicator_box.png",
            headerBtns  = {
                btn1 = ASSETS_PATH .. "necromancer\\necro_header_btn_left.png",
                btn2 = ASSETS_PATH .. "necromancer\\necro_header_btn_left.png",
                btn3 = ASSETS_PATH .. "necromancer\\necro_header_btn_left.png",
            },
            icons = {
                hunger  = ASSETS_PATH .. "necromancer\\inc2_hunger-chicken_icon.png",
                thirst  = ASSETS_PATH .. "necromancer\\inc2_thirst_icon.png",
                fatigue = ASSETS_PATH .. "necromancer\\inc2_fatigue_icon.png",
            }
        },
        bar = {
            fill    = ASSETS_PATH .. "necromancer\\inc2_hunger_barfill.png",
            bg      = nil,
            overlay = nil,
        },
        barColors = {
            hunger  = { 0.55, 0.85, 0.30 },
            thirst  = { 0.80, 0.00, 0.00 },
            fatigue = { 0.18, 0.18, 0.18 },
        },
    },

    dastardly = {
        id    = "dastardly",
        label = "Dastardly",
        mode  = "smooth",
        assets = {
            icons = {
                hunger  = ASSETS_PATH .. "dastardly_skull_hunger.png",
                thirst  = ASSETS_PATH .. "dastardly_skull_thirst.png",
                fatigue = ASSETS_PATH .. "dastardly_skull_fatigue.png",
            }
        },
        chrome = {
            bgCenter      = { 0.04, 0.04, 0.04, 0.92 },
            cornerTL      = "UI-Frame-DastardlyDuos-CornerTopLeft",
            cornerTR      = "UI-Frame-DastardlyDuos-CornerTopRight",
            cornerBL      = "UI-Frame-DastardlyDuos-CornerBottomLeft",
            cornerBR      = "UI-Frame-DastardlyDuos-CornerBottomRight",
            edgeTop       = "UI-Frame-DastardlyDuos-Line-Top",
            edgeBottom    = "UI-Frame-DastardlyDuos-Line-Bottom",
            edgeLeft      = nil,
            edgeRight     = nil,
            titleStrip    = "UI-Frame-DastardlyDuos-Line-Top",
            cornerSize    = 16,
            edgeThickness = 8,
        },
        bar = {
            overlay = "UI-Frame-DastardlyDuos-Bar-Frame-gold",
            fill    = DEFAULT_FILL_TEX,
            bg      = { 0.08, 0.06, 0.03, 0.95 },
        },
        barColors = {
            hunger  = { 0.85, 0.55, 0.15 },
            thirst  = { 0.30, 0.65, 0.90 },
            fatigue = { 0.70, 0.85, 0.30 },
        },
    },
}

ICN2.HUD_THEME_LIST = {
    ICN2.HUD_THEMES.colorful,
    ICN2.HUD_THEMES.minimalist,
    ICN2.HUD_THEMES.smooth,
    ICN2.HUD_THEMES.blocky,
    ICN2.HUD_THEMES.folk,
    ICN2.HUD_THEMES.necromancer,
    ICN2.HUD_THEMES.dastardly,
}

local function getTheme()
    local id = ICN2DB and ICN2DB.settings and ICN2DB.settings.barTheme or "colorful"
    return ICN2.HUD_THEMES[id] or ICN2.HUD_THEMES.colorful
end

local function getMergedHUDTheme(themeId)
    local rawTheme = ICN2.HUD_THEMES[themeId] or ICN2.HUD_THEMES.colorful
    local merged = MergeTheme(ICN2.THEME_BASE, rawTheme)
    merged = normalizeHUDTheme(merged, rawTheme)
    merged.id = rawTheme.id
    merged.label = rawTheme.label
    merged.mode = rawTheme.mode
    return merged, rawTheme
end

-- Public helper: return theme descriptor by id (used by options UI)
function ICN2:GetHUDTheme(id)
    if not id then return getTheme() end
    return ICN2.HUD_THEMES[id] or getTheme()
end

-- ══ SECTION 2 — Indicator logic ════════════════════════════════════════════════
local IND_FASTER_UP   =  0.278
local IND_FAST_UP     =  0.167
local IND_FAST_DOWN   = -0.050
local IND_FASTER_DOWN = -0.100
local STABLE_EPSILON  =  0.002

local INDICATORS = {
    stable = ASSETS_PATH .. "inc2_paused_icon.png",
    up1    = ASSETS_PATH .. "inc2_1up-green_icon.png",
    up2    = ASSETS_PATH .. "inc2_2up-green_icon.png",
    up3    = ASSETS_PATH .. "inc2_3up_green_icon.png",
    down1  = ASSETS_PATH .. "inc2_1down-red_icon.png",
    down2  = ASSETS_PATH .. "inc2_2down-red_icon.png",
    down3  = ASSETS_PATH .. "inc2_3down-red_icon.png",
}

local PULSE_PERIOD = 2.0
local PULSE_MIN    = 0.25
local PULSE_MAX    = 1.0

local function shouldPulse(assetPath)  return assetPath ~= INDICATORS.stable  end

local function getSelectedPalette()
    local paletteId = ICN2DB and ICN2DB.settings and ICN2DB.settings.colorPalette or "Default"
    return ICN2.Palettes and ICN2.Palettes[paletteId]
end

local function getNeedColor(key, val) -- returns r,g,b in 0..1 range
    -- If using custom image assets in colorful theme, don't overlay threshold colors unless critical
    local currentTheme = getTheme().id
    if currentTheme == "colorful" and val > ICN2.THRESHOLDS.critical then
        return 1, 1, 1 -- Keep texture un-tinted so the graphic shows properly
    end

    if val <= ICN2.THRESHOLDS.critical then return 0.9, 0.1, 0.1
    elseif val <= ICN2.THRESHOLDS.low  then return 0.9, 0.6, 0.1
    else
        local paletteId = ICN2DB and ICN2DB.settings and ICN2DB.settings.colorPalette or "Default"
        local palette = (paletteId ~= "Default") and getSelectedPalette() or nil
        local fc = palette and palette[key]
        if fc then
            return fc[1], fc[2], fc[3]
        end

        local theme = getTheme()
        fc = (theme.barColors and theme.barColors[key]) or BLOCK_COLORS[key]
        return fc[1], fc[2], fc[3]
    end
end

local function getIndicatorAsset(rate)
    if math.abs(rate) <= STABLE_EPSILON then return INDICATORS.stable, 1, 1, 1
    elseif rate >= IND_FASTER_UP        then return INDICATORS.up3,   1, 1, 1
    elseif rate >= IND_FAST_UP          then return INDICATORS.up2,   1, 1, 1
    elseif rate >  0                    then return INDICATORS.up1,   1, 1, 1
    elseif rate <= IND_FASTER_DOWN      then return INDICATORS.down3, 1, 1, 1
    elseif rate <= IND_FAST_DOWN        then return INDICATORS.down2, 1, 1, 1
    else                                     return INDICATORS.down1, 1, 1, 1
    end
end

local function applyThemePadding(theme)
    if not hudFrame or not headerFrame or not contentFrame then return end

    local c = (theme and theme.chrome) or {}
    local edgeThick = c.edgeThickness or 4
    local contentPad = math.max(CHROME_PAD, edgeThick + 2)

    if theme and theme.layout and theme.layout.showHeader then
        headerFrame:Show()
        headerFrame:ClearAllPoints()
        headerFrame:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", contentPad, -contentPad)
        headerFrame:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", -contentPad, -contentPad)
        contentFrame:ClearAllPoints()
        contentFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
    else
        headerFrame:Hide()
        contentFrame:ClearAllPoints()
        contentFrame:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", contentPad, -contentPad)
    end

    contentFrame:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", -contentPad, contentPad)
end

-- ══ SECTION 3 — Texture slot helper ════════════════════════════════════════════
local function applyTexSlot(tex, value)
    if not tex then return end
    if value == nil then
        tex:Hide()
    elseif type(value) == "string" then
        if string.find(value, "\\") or string.find(value, "/") or string.find(value, "%.png$") or string.find(value, "%.tga$") then
            tex:SetTexture(value)
        else
            tex:SetAtlas(value, true)
        end
        tex:Show()
    elseif type(value) == "table" then
        tex:SetColorTexture(value[1], value[2], value[3], value[4] or 1)
        tex:Show()
    end
end

-- ══  SECTION 4 — Build HUD  ════════════════════════════════════════════════════
function ICN2:BuildHUD()
    local s        = ICN2DB.settings
    local barScale = s.hudBarScale or 1.0
    local barW     = math.floor(BASE_BAR_W * barScale)
    local innerW   = ICON_SIZE + 4 + barW + INDICATOR_W
    local frameW   = innerW + CHROME_PAD * 2 + 8
    local frameH   = HEADER_H + (#NEED_KEYS * (BAR_H + BAR_GAP)) + CHROME_PAD * 2

    -- ── Root frame ────────────────────────────────────────────────────────────
    hudFrame = CreateFrame("Frame", "ICN2HUDFrame", UIParent)
    hudFrame:SetSize(frameW, frameH)
    hudFrame:SetFrameStrata("MEDIUM")
    hudFrame:SetClampedToScreen(true)

    local pos = s.hudPosition
    if pos and pos.point then
        hudFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        hudFrame:SetPoint("CENTER", UIParent, "CENTER", s.hudX or 200, s.hudY or -250)
    end

    hudFrame:EnableMouse(true)
    hudFrame:SetMovable(true)
    hudFrame:RegisterForDrag("LeftButton")
    hudFrame:SetScript("OnDragStart", function(self)
        if not ICN2DB.settings.hudLocked then self:StartMoving() end
    end)
    hudFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ICN2DB.settings.hudPosition = ICN2DB.settings.hudPosition or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
        ICN2DB.settings.hudPosition.point = point
        ICN2DB.settings.hudPosition.relPoint = relPoint
        ICN2DB.settings.hudPosition.x = x
        ICN2DB.settings.hudPosition.y = y
    end)
    hudFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(string.format(L["TOOLTIP_HUNGER"],  ICN2:GetNeedPercent("hunger")),  0.2, 0.8, 0.2)
        GameTooltip:AddLine(string.format(L["TOOLTIP_THIRST"],  ICN2:GetNeedPercent("thirst")),  0.2, 0.5, 1.0)
        GameTooltip:AddLine(string.format(L["TOOLTIP_FATIGUE"], ICN2:GetNeedPercent("fatigue")), 1.0, 0.85, 0.1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["TOOLTIP_HINT"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    hudFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── Nine-slice chrome slots ──────────────────────────────────────────────
    chrome.bgCenter = hudFrame:CreateTexture(nil, "BACKGROUND")
    chrome.bgCenter:SetAllPoints()
    chrome.bgCenter:Hide()

    local cornerAnchors = {
        cornerTL = { "TOPLEFT",     "TOPLEFT"     },
        cornerTR = { "TOPRIGHT",    "TOPRIGHT"    },
        cornerBL = { "BOTTOMLEFT",  "BOTTOMLEFT"  },
        cornerBR = { "BOTTOMRIGHT", "BOTTOMRIGHT" },
    }
    for slot, anchors in pairs(cornerAnchors) do
        local tex = hudFrame:CreateTexture(nil, "BORDER")
        tex:SetPoint(anchors[1], hudFrame, anchors[2], 0, 0)
        tex:Hide()
        chrome[slot] = tex
    end

    chrome.edgeTop = hudFrame:CreateTexture(nil, "BORDER")
    chrome.edgeTop:SetPoint("TOPLEFT",  hudFrame, "TOPLEFT",  0, 0)
    chrome.edgeTop:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", 0, 0)
    chrome.edgeTop:Hide()

    chrome.edgeBottom = hudFrame:CreateTexture(nil, "BORDER")
    chrome.edgeBottom:SetPoint("BOTTOMLEFT",  hudFrame, "BOTTOMLEFT",  0, 0)
    chrome.edgeBottom:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", 0, 0)
    chrome.edgeBottom:Hide()

    chrome.edgeLeft = hudFrame:CreateTexture(nil, "BORDER")
    chrome.edgeLeft:SetPoint("TOPLEFT",    hudFrame, "TOPLEFT",    0, 0)
    chrome.edgeLeft:SetPoint("BOTTOMLEFT", hudFrame, "BOTTOMLEFT", 0, 0)
    chrome.edgeLeft:Hide()

    chrome.edgeRight = hudFrame:CreateTexture(nil, "BORDER")
    chrome.edgeRight:SetPoint("TOPRIGHT",    hudFrame, "TOPRIGHT",    0, 0)
    chrome.edgeRight:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", 0, 0)
    chrome.edgeRight:Hide()

    chrome.titleStrip = hudFrame:CreateTexture(nil, "ARTWORK")
    chrome.titleStrip:SetPoint("TOPLEFT",  hudFrame, "TOPLEFT",  0, 0)
    chrome.titleStrip:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", 0, 0)
    chrome.titleStrip:SetHeight(HEADER_H)
    chrome.titleStrip:Hide()

    -- ── Header ────────────────────────────────────────────────────────────────
    headerFrame = CreateFrame("Frame", nil, hudFrame)
    headerFrame:SetHeight(HEADER_H)

    local title = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", headerFrame, "LEFT", 12, 0)
    title:SetText(L["HUD_TITLE"])

    -- Create 3 dynamic buttons
    for i = 1, 3 do
        local btn = CreateFrame("Button", nil, headerFrame)
        btn.tex = btn:CreateTexture(nil, "ARTWORK")
        btn.tex:SetAllPoints()
        headerBtns[i] = btn
    end

    headerBtns[1]:SetScript("OnClick", function() ICN2:PrintDetails() end)
    headerBtns[2]:SetScript("OnClick", function() ICN2:ToggleOptions() end)
    headerBtns[3]:SetScript("OnClick", function() 
    ICN2:HandleAbilityRecovery(1231411) 
    end)
    headerBtns[3]:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(1231411)
        GameTooltip:Show()
    end)
    headerBtns[3]:SetScript("OnLeave", function() 
        GameTooltip:Hide() 
    end)

    -- ── Content area ──────────────────────────────────────────────────────────
    contentFrame = CreateFrame("Frame", nil, hudFrame)

    -- ── Need rows ─────────────────────────────────────────────────────────────
    for i, key in ipairs(NEED_KEYS) do
        local fc   = BLOCK_COLORS[key]
        local rowY = -((i - 1) * (BAR_H + BAR_GAP)) - 4

        local rowFrame = CreateFrame("Frame", "ICN2Row_" .. key, contentFrame)
        rowFrame:SetSize(innerW, BAR_H)
        rowFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", CHROME_PAD - 2, rowY)

        -- Need icon
        local icon = rowFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
        icon:SetTexture(NEED_ICONS[key])
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        -- Bar container frame
        local barFrame = CreateFrame("Frame", "ICN2BarFrame_" .. key, rowFrame)
        barFrame:SetSize(barW, BAR_H)
        barFrame:SetPoint("LEFT", rowFrame, "LEFT", ICON_SIZE + 4, 0)

        -- Bar background track
        local barBG = barFrame:CreateTexture(nil, "BACKGROUND")
        barBG:SetAllPoints()
        barBG:SetColorTexture(0.12, 0.12, 0.12, 0.9)

        -- Animated fill
        local barFill = CreateFrame("StatusBar", "ICN2BarFill_" .. key, barFrame)
        barFill:SetAllPoints()
        barFill:SetMinMaxValues(0, 100)
        barFill:SetValue(100)
        barFill:SetStatusBarTexture(DEFAULT_FILL_TEX)
        barFill:SetStatusBarColor(fc[1], fc[2], fc[3])

        -- Percentage label
        local barLabelLeft = barFill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        barLabelLeft:SetPoint("LEFT", barFill, "LEFT", 3, 0)
        barLabelLeft:SetText("")
        barLabelLeft:Hide()

        local barLabelRight = barFill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        barLabelRight:SetPoint("RIGHT", barFill, "RIGHT", -3, 0)
        barLabelRight:SetText("")
        barLabelRight:Hide()

        -- Decorative overlay above fill
        local barOverlay = barFrame:CreateTexture(nil, "OVERLAY")
        barOverlay:SetAllPoints()
        barOverlay:Hide()

        -- ── Blocky blocks ──────────────────────────────────────────────────────
        local blockFrames = {}

        for b = 1, NUM_BLOCKS do
            local blockW = (barW - (BLOCK_GAP * (NUM_BLOCKS - 1))) / NUM_BLOCKS
            local bx = (b - 1) * (blockW + BLOCK_GAP)

            local fillTex = barFrame:CreateTexture(nil, "OVERLAY")
            fillTex:SetSize(blockW, BAR_H)
            fillTex:SetPoint("LEFT", barFrame, "LEFT", bx, 0)
            fillTex:SetTexture("Interface\\Buttons\\WHITE8X8")
            fillTex:SetVertexColor(fc[1], fc[2], fc[3], 0.95)
            fillTex:Hide()

            blockFrames[b] = { fill = fillTex }
        end

        -- NEW: Row Background (Wraps Icon and Bar)
        local rowBG = rowFrame:CreateTexture(nil, "BACKGROUND")
        rowBG:SetPoint("TOPLEFT", icon, "TOPLEFT", -4, 4)
        rowBG:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", 4, -4)
        rowBG:Hide()

        -- NEW: Indicator Background
        local indBG = rowFrame:CreateTexture(nil, "BACKGROUND")
        indBG:SetPoint("CENTER", glyphTex, "CENTER", 0, 0)
        indBG:SetSize(32, 32)
        indBG:Hide()

        -- ── Glyph indicator + pulse ────────────────────────────────────────────
        local glyphTex = rowFrame:CreateTexture(nil, "OVERLAY")
        glyphTex:SetSize(16, 16)
        glyphTex:SetPoint("RIGHT", rowFrame, "RIGHT", -2, 0)
        glyphTex:SetAlpha(1.0)

        local pulseFrame   = CreateFrame("Frame", nil, rowFrame)
        local pulseElapsed = 0
        local pulseRunning = false

        pulseFrame:SetScript("OnUpdate", function(_, dt)
            if not pulseRunning then return end
            pulseElapsed = pulseElapsed + dt
            local t = (pulseElapsed % PULSE_PERIOD) / PULSE_PERIOD
            local a = PULSE_MIN + (PULSE_MAX - PULSE_MIN)
                      * (0.5 + 0.5 * math.sin(t * math.pi * 2 - math.pi / 2))
            glyphTex:SetAlpha(a)
        end)

        bars[key] = {
            rowFrame      = rowFrame,
            icon          = icon,
            barFrame      = barFrame,
            barBG         = barBG,
            barFill       = barFill,
            barOverlay    = barOverlay,
            barLabelLeft  = barLabelLeft,
            barLabelRight = barLabelRight,
            blocks        = blockFrames,
            glyphTex      = glyphTex,
            rowBG         = rowBG,
            indBG         = indBG,
            setPulse      = function(active)
                pulseRunning = active
                if not active then
                    pulseElapsed = 0
                    glyphTex:SetAlpha(1.0)
                end
            end,
        }
    end

    -- Apply saved state
    hudFrame:SetAlpha(s.hudAlpha or 1.0)
    hudFrame:SetScale(s.hudScale or 1.0)

    -- Set Colorful as the standard base fallback for initial migration steps
    if not s.barTheme then
        s.barTheme = "colorful"
    end
    ICN2:ApplyHUDTheme(s.barTheme)
    if not s.hudEnabled then hudFrame:Hide() end
end

-- ═══ SECTION 5 — Theme application ══════════════════════════════════════════
function ICN2:ApplyHUDTheme(themeId)
    if not hudFrame then return end

    local theme, rawTheme = getMergedHUDTheme(themeId)
    ICN2DB.settings.barTheme   = theme.id
    ICN2DB.settings.blockyBars = (theme.mode == "blocky")

    local layout      = theme.layout or {}
    local c           = theme.chrome or {}
    local cornerSize  = c.cornerSize    or 8
    local edgeThick   = c.edgeThickness or 4
    local showChrome  = layout.showChrome ~= false
    local showHeader  = layout.showHeader ~= false
    local showIcons   = layout.showIcons  ~= false
    local showBars    = layout.showBars   ~= false
    local showGlyphs  = layout.showGlyphs ~= false
    local iconSize    = layout.iconSize   or ICON_SIZE
    local barScale    = ICN2DB.settings.hudBarScale or 1.0
    local barWidth    = math.floor((layout.barWidth or BASE_BAR_W) * barScale)
    local barHeight   = layout.barHeight  or BAR_H
    local iconAnchor  = layout.iconAnchor or { point = "LEFT", relPoint = "LEFT", x = 0, y = 0 }
    local barAnchor   = layout.barAnchor  or { point = "LEFT", relPoint = "LEFT", x = iconSize + 4, y = 0 }
    local glyphAnchor = layout.glyphAnchor or { point = "RIGHT", relPoint = "RIGHT", x = -2, y = 0 }

    -- Background
    applyTexSlot(chrome.bgCenter, showChrome and c.bgCenter or nil)

    -- Corners
    for _, slot in ipairs({ "cornerTL", "cornerTR", "cornerBL", "cornerBR" }) do
        chrome[slot]:SetSize(cornerSize, cornerSize)
        applyTexSlot(chrome[slot], showChrome and c[slot] or nil)
    end

    -- Edges
    chrome.edgeTop:SetHeight(edgeThick)
    applyTexSlot(chrome.edgeTop, showChrome and c.edgeTop or nil)

    chrome.edgeBottom:SetHeight(edgeThick)
    applyTexSlot(chrome.edgeBottom, showChrome and c.edgeBottom or nil)

    chrome.edgeLeft:SetWidth(edgeThick)
    applyTexSlot(chrome.edgeLeft, showChrome and c.edgeLeft or nil)

    chrome.edgeRight:SetWidth(edgeThick)
    applyTexSlot(chrome.edgeRight, showChrome and c.edgeRight or nil)

    -- Title strip
    applyTexSlot(chrome.titleStrip, showChrome and c.titleStrip or nil)

    applyThemePadding(theme)

    -- Header Buttons
    local hAnchor = layout.headerBtnAnchor
    local bSize = layout.headerBtnSize
    local bGap = layout.headerBtnGap
    
    -- Center the middle button (btn2), then anchor btn1 to its left and btn3 to its right
    headerBtns[2]:SetSize(bSize, bSize)
    headerBtns[2]:ClearAllPoints()
    headerBtns[2]:SetPoint(hAnchor.point, headerFrame, hAnchor.relPoint, hAnchor.x, hAnchor.y)
    applyTexSlot(headerBtns[2].tex, theme.assets.headerBtns.btn2)

    headerBtns[1]:SetSize(bSize, bSize)
    headerBtns[1]:ClearAllPoints()
    headerBtns[1]:SetPoint("RIGHT", headerBtns[2], "LEFT", -bGap, 0)
    applyTexSlot(headerBtns[1].tex, theme.assets.headerBtns.btn1)

    headerBtns[3]:SetSize(bSize, bSize)
    headerBtns[3]:ClearAllPoints()
    headerBtns[3]:SetPoint("LEFT", headerBtns[2], "RIGHT", bGap, 0)
    applyTexSlot(headerBtns[3].tex, theme.assets.headerBtns.btn3)

    -- Per-bar slots
    local barDef     = theme.bar or {}
    local barBGColor = barDef.bg   or { 0.12, 0.12, 0.12, 0.9 }
    local fillTex    = barDef.fill or theme.assets.fillTex or DEFAULT_FILL_TEX

    for i, key in ipairs(NEED_KEYS) do
        local data = bars[key]
        if data then
            local rowWidth = iconSize + 4 + (showBars and barWidth or 0) + (showGlyphs and INDICATOR_W or 0) + 8
            local rowY = -((i - 1) * (barHeight + BAR_GAP)) - 4

            data.rowFrame:SetSize(rowWidth, barHeight)
            data.rowFrame:ClearAllPoints()
            data.rowFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", CHROME_PAD - 2, rowY)

            -- ICONS
            if showIcons then
                data.icon:Show()
                data.icon:SetSize(iconSize, iconSize)
                data.icon:ClearAllPoints()
                data.icon:SetPoint(iconAnchor.point, data.rowFrame, iconAnchor.relPoint, iconAnchor.x, iconAnchor.y)
                data.icon:SetTexture((theme.assets and theme.assets.icons and theme.assets.icons[key]) or NEED_ICONS[key])
                data.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            else
                data.icon:Hide()
            end

            -- BARS
            data.barFrame:SetSize(barWidth, barHeight)
            data.barFrame:ClearAllPoints()
            data.barFrame:SetPoint(barAnchor.point, data.rowFrame, barAnchor.relPoint, barAnchor.x, barAnchor.y)
            if showBars then
                data.barFrame:Show()
                if type(barBGColor) == "string" then
                    if string.find(barBGColor, "\\") then
                        data.barBG:SetTexture(barBGColor)
                    else
                        data.barBG:SetAtlas(barBGColor, true)
                    end
                else
                    data.barBG:SetColorTexture(barBGColor[1], barBGColor[2], barBGColor[3], barBGColor[4] or 1)
                end
                if barDef.fills and barDef.fills[key] then
                    data.barFill:SetStatusBarTexture(barDef.fills[key])
                else
                    data.barFill:SetStatusBarTexture(fillTex)
                end
                if barDef.overlay then
                    if string.find(barDef.overlay, "\\") then
                        data.barOverlay:SetTexture(barDef.overlay)
                    else
                        data.barOverlay:SetAtlas(barDef.overlay, true)
                    end
                    data.barOverlay:Show()
                else
                    data.barOverlay:Hide()
                end
            else
                data.barFrame:Hide()
            end

            -- Block layout updates for blocky mode
            local blockW = (barWidth - (BLOCK_GAP * (NUM_BLOCKS - 1))) / NUM_BLOCKS
            for idx, bf in ipairs(data.blocks) do
                bf.fill:ClearAllPoints()
                bf.fill:SetSize(blockW, barHeight)
                bf.fill:SetPoint("LEFT", data.barFrame, "LEFT", (idx - 1) * (blockW + BLOCK_GAP), 0)
            end

            -- GLYPHS
            if showGlyphs then
                data.glyphTex:Show()
                data.glyphTex:ClearAllPoints()
                data.glyphTex:SetPoint(glyphAnchor.point, data.rowFrame, glyphAnchor.relPoint, glyphAnchor.x, glyphAnchor.y)
            else
                data.glyphTex:Hide()
            end

            -- NEW: Apply Row and Indicator BGs
            if theme.assets.rowBG then
                applyTexSlot(data.rowBG, theme.assets.rowBG)
            else
                data.rowBG:Hide()
            end

            if theme.assets.indicatorBG then
                applyTexSlot(data.indBG, theme.assets.indicatorBG)
            else
                data.indBG:Hide()
            end
        end
    end

    ICN2:ApplyBarMode()
end

-- ── Public entry points ────────────────────────────────────────────────────────
function ICN2:SetBarTheme(themeId)
    ICN2:ApplyHUDTheme(themeId)
    ICN2:UpdateHUD()
end

function ICN2:SetBlockyBars(enabled)
    ICN2:SetBarTheme(enabled and "blocky" or "colorful")
end

-- ══  SECTION 6 — Bar mode  ═════════════════════════════════════════════════════
function ICN2:ApplyBarMode()
    if not hudFrame then return end
    local mode = getTheme().mode

    for _, key in ipairs(NEED_KEYS) do
        local data = bars[key]
        if data then
            if mode == "blocky" then
                data.barFill:Hide()
                data.barBG:Hide()
                data.barLabelLeft:Hide()
                data.barLabelRight:Hide()
                data.barOverlay:Hide()
                for _, bf in ipairs(data.blocks) do
                    bf.fill:Show()
                end
            else
                data.barFill:Show()
                data.barBG:Show()
                for _, bf in ipairs(data.blocks) do
                    bf.fill:Hide()
                end
            end
        end
    end
end

-- ══  SECTION 7 — Update loop  ═══════════════════════════════════════════════════
function ICN2:UpdateHUD()
    if not hudFrame then return end
    if not ICN2DB.settings.hudEnabled then hudFrame:Hide(); return end
    hudFrame:Show()

    local values = {
        hunger  = ICN2:GetNeedPercent("hunger"),
        thirst  = ICN2:GetNeedPercent("thirst"),
        fatigue = ICN2:GetNeedPercent("fatigue"),
    }
    local rates     = ICN2:GetCurrentRates()
    local mode      = getTheme().mode
    local labelMode = ICN2DB.settings.barLabelMode or "percentage"

    for _, key in ipairs(NEED_KEYS) do
        local data = bars[key]
        if data then
            local val     = values[key] or 0
            local r, g, b = getNeedColor(key, val)

            if mode == "blocky" then
                local filled = (val >= 100) and NUM_BLOCKS or math.floor(val / 10)
                for idx = 1, NUM_BLOCKS do
                    local bf = data.blocks[idx]
                    if idx <= filled then
                        bf.fill:SetVertexColor(r, g, b, 0.95)
                        bf.fill:Show()
                    else
                        bf.fill:Hide()
                    end
                end
            else
                data.barFill:SetValue(val)
                data.barFill:SetStatusBarColor(r, g, b)
                local current = ICN2DB[key] or 0
                local maxVal  = ICN2:GetMaxValue(key)
                local pctText = string.format("%.0f%%", val)
                local numText = string.format("%.0f/%.0f", current, maxVal)

                if labelMode == "none" then
                    data.barLabelLeft:Hide()
                    data.barLabelRight:Hide()
                elseif labelMode == "percentage" then
                    data.barLabelLeft:Hide()
                    data.barLabelRight:SetText(pctText)
                    data.barLabelRight:Show()
                elseif labelMode == "number" then
                    data.barLabelLeft:Hide()
                    data.barLabelRight:SetText(numText)
                    data.barLabelRight:Show()
                elseif labelMode == "both" then
                    data.barLabelLeft:SetText(numText)
                    data.barLabelLeft:Show()
                    data.barLabelRight:SetText(pctText)
                    data.barLabelRight:Show()
                end
            end

            local assetPath, ir, ig, ib = getIndicatorAsset(rates[key] or 0)
            data.glyphTex:SetTexture(assetPath)
            data.glyphTex:SetVertexColor(ir, ig, ib)
            data.setPulse(shouldPulse(assetPath))
        end
    end
end

-- ══  SECTION 8 — Resize / Lock  ════════════════════════════════════════════════
function ICN2:ResizeBarLength()
    if not hudFrame then return end

    local barScale = ICN2DB.settings.hudBarScale or 1.0
    local theme, rawTheme = getMergedHUDTheme(getTheme().id)
    local barWidth = math.floor((theme.layout.barWidth or BASE_BAR_W) * barScale)
    local iconSize = theme.layout.iconSize or ICON_SIZE
    local rowHeight = theme.layout.barHeight or BAR_H
    local innerW   = iconSize + 4 + barWidth + INDICATOR_W
    local frameW   = innerW + CHROME_PAD * 2 + 8
    local frameH   = HEADER_H + (#NEED_KEYS * (rowHeight + BAR_GAP)) + CHROME_PAD * 2

    hudFrame:SetSize(frameW, frameH)
    applyThemePadding(theme)

    for i, key in ipairs(NEED_KEYS) do
        local data = bars[key]
        if data then
            local rowWidth = iconSize + 4 + barWidth + INDICATOR_W + 8
            local rowY = -((i - 1) * (rowHeight + BAR_GAP)) - 4
            data.rowFrame:SetSize(rowWidth, rowHeight)
            data.rowFrame:ClearAllPoints()
            data.rowFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", CHROME_PAD - 2, rowY)

            data.barFrame:SetSize(barWidth, rowHeight)
            if theme.mode == "blocky" then
                local blockW = (barWidth - (BLOCK_GAP * (NUM_BLOCKS - 1))) / NUM_BLOCKS
                for i, bf in ipairs(data.blocks) do
                    bf.fill:ClearAllPoints()
                    bf.fill:SetSize(blockW, rowHeight)
                    bf.fill:SetPoint("LEFT", data.barFrame, "LEFT", (i - 1) * (blockW + BLOCK_GAP), 0)
                end
            end
        end
    end
end

function ICN2:LockHUD(locked)
    if hudFrame then hudFrame:EnableMouse(not locked) end
end
