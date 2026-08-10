-- ============================================================
-- ICN2_Minimap.lua
-- LibDataBroker launcher with a native minimap-button fallback.
-- ============================================================

ICN2 = ICN2 or {}

local ICON = "Interface\\AddOns\\ICN2\\assets\\ICN2_LOGO.png"
local TITLE = "|cFFFF6600ICN2|r - Character Needs"
local fallbackButton
local brokerIcon

local function toggleHUD()
    ICN2DB.settings.hudEnabled = not ICN2DB.settings.hudEnabled
    ICN2:UpdateHUD()
    print("|cFFFF6600ICN2|r " .. (ICN2DB.settings.hudEnabled and (ICN2.L.MSG_HUD_ENABLED or "HUD enabled") or (ICN2.L.MSG_HUD_DISABLED or "HUD disabled")))
end

local function onClick(button)
    if button == "RightButton" then
        toggleHUD()
    elseif button == "LeftButton" then
        if IsControlKeyDown() then
            ICN2:OpenDebug()
        else
            ICN2:ToggleOptions()
        end
    end
end

local function showTooltip(tooltip)
    tooltip:AddLine(TITLE)
    tooltip:AddLine(ICN2.L.MINIMAP_LEFT or "Left-click: Options")
    tooltip:AddLine(ICN2.L.MINIMAP_RIGHT or "Right-click: Toggle HUD")
    tooltip:AddLine(ICN2.L.MINIMAP_CTRL_LEFT or "Ctrl-click: Debug")
end

local function buildFallback()
    local button = CreateFrame("Button", "ICN2MinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52, -2)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetNormalTexture(ICON)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(_, mouseButton) onClick(mouseButton) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        showTooltip(GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function ICN2:InitMinimapButton()
    if self._minimapInitialized then return end
    self._minimapInitialized = true
    ICN2DB.minimap = ICN2DB.minimap or { hide = false }
    ICN2DB.minimap.hide = not ICN2DB.settings.minimapButton

    local libStub = _G.LibStub
    local ldb = libStub and libStub("LibDataBroker-1.1", true)
    local dbIcon = libStub and libStub("LibDBIcon-1.0", true)

    if ldb then
        local dataObject = ldb:NewDataObject("ICN2", {
            type = "launcher",
            label = "ICN2",
            icon = ICON,
            OnClick = function(_, button) onClick(button) end,
            OnTooltipShow = showTooltip,
        })
        self._minimapDataObject = dataObject
        if dbIcon then
            dbIcon:Register("ICN2", dataObject, ICN2DB.minimap)
            brokerIcon = dbIcon
        end
    end

    if not brokerIcon then
        fallbackButton = buildFallback()
    end
    self:SetMinimapButtonShown(ICN2DB.settings.minimapButton)
end

function ICN2:SetMinimapButtonShown(shown)
    if ICN2DB.minimap then ICN2DB.minimap.hide = not shown end
    if brokerIcon then
        if shown then brokerIcon:Show("ICN2") else brokerIcon:Hide("ICN2") end
    elseif fallbackButton then
        if shown then fallbackButton:Show() else fallbackButton:Hide() end
    end
end
