-- ============================================================
-- ICN2_Options.lua
-- Focused controls for the Vitality Instrument and decay engine.
-- ============================================================

ICN2 = ICN2 or {}

local L = setmetatable({}, { __index = function(_, key)
    return ICN2.L and ICN2.L[key] or key
end })

local optionsFrame, displayPanel, decayPanel, tabDisplay, tabDecay
local decaySliders = {}
local styleDropdown, labelDropdown

local C = {
    orange = { 1.00, 0.42, 0.12 }, gold = { 1.00, 0.78, 0.24 },
    text = { 0.90, 0.93, 0.98 }, muted = { 0.52, 0.58, 0.68 },
    panel = { 0.018, 0.025, 0.040, 0.98 }, card = { 0.035, 0.046, 0.070, 0.98 },
    edge = { 0.20, 0.27, 0.40 },
}

local function tint(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function makeLabel(parent, text, x, y, font, color, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then fs:SetWidth(width) end
    fs:SetText(text or "")
    if color then tint(fs, color) end
    return fs
end

local function makeCard(parent, title, y, height)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y); card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, y); card:SetHeight(height)
    card:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1, insets={left=1,right=1,top=1,bottom=1} })
    card:SetBackdropColor(C.card[1],C.card[2],C.card[3],1); card:SetBackdropBorderColor(C.edge[1],C.edge[2],C.edge[3],1)
    makeLabel(card, title, 16, -14, "GameFontNormalLarge", C.gold)
    local line=card:CreateTexture(nil,"ARTWORK"); line:SetPoint("TOPLEFT",card,"TOPLEFT",16,-38); line:SetPoint("TOPRIGHT",card,"TOPRIGHT",-16,-38); line:SetHeight(1); line:SetColorTexture(C.orange[1],C.orange[2],C.orange[3],.35)
    return card
end

local function makeCheckbox(parent, text, x, y, getter, setter, width)
    local check=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate"); check:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); check:SetSize(26,26); check.text:SetText(text); check.text:SetTextColor(C.text[1],C.text[2],C.text[3]); check.text:SetWidth(width or 430); check:SetChecked(getter())
    check:SetScript("OnClick",function(self) setter(self:GetChecked()) end); return check
end

local function slider(parent, text, x, y, width, minValue, maxValue, step, getter, setter, decimals)
    local control=CreateFrame("Slider",nil,parent,"OptionsSliderTemplate"); control:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); control:SetWidth(width); control:SetMinMaxValues(minValue,maxValue); control:SetValueStep(step); control:SetObeyStepOnDrag(true); control:SetValue(getter())
    local function display(value) return string.format(decimals==0 and "%.0f" or "%.2f", value) end
    control.Low:SetText(display(minValue)); control.High:SetText(display(maxValue)); control.Text:SetText(text..": "..display(getter())); control.Text:SetTextColor(C.text[1],C.text[2],C.text[3])
    control:SetScript("OnValueChanged",function(self,value) setter(value); self.Text:SetText(text..": "..display(value)) end); return control
end

local function button(parent, text, x, y, width, callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(width or 110,28); b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); b:SetText(text); b:SetScript("OnClick",callback); return b
end

local function dropdown(parent, name, text, x, y, width, values, selected, callback)
    makeLabel(parent,text,x,y+4,"GameFontHighlight",C.muted)
    local menu=CreateFrame("Frame",name,parent,"UIDropDownMenuTemplate"); menu:SetPoint("TOPLEFT",parent,"TOPLEFT",x+118,y+12); UIDropDownMenu_SetWidth(menu,width or 170); UIDropDownMenu_SetText(menu,selected())
    UIDropDownMenu_Initialize(menu,function(_,level)
        for _,item in ipairs(values()) do
            local info=UIDropDownMenu_CreateInfo(); info.text=item.label; info.value=item.id; info.checked=item.id==selected(true)
            info.func=function() callback(item); UIDropDownMenu_SetText(menu,item.label); CloseDropDownMenus() end; UIDropDownMenu_AddButton(info,level)
        end
    end)
    return menu
end

local function biasValue(key)
    local settings=ICN2DB.settings
    if settings.preset=="custom" then return math.floor(((settings.customDecayBias and settings.customDecayBias[key]) or 1)+.5) end
    return math.floor(ICN2:PresetMultiplierToBiasDisplay(ICN2.PRESETS[settings.preset] or 1)+.5)
end

local function refreshDecay()
    local settings=ICN2DB.settings; local custom=settings.preset=="custom"; local preset=ICN2.PRESETS[settings.preset] or 1
    for _,row in ipairs(decaySliders) do
        local bias=biasValue(row.key); local multiplier=custom and ICN2:DecayBiasToMultiplier((settings.customDecayBias and settings.customDecayBias[row.key]) or 1) or preset
        row.control:SetValue(bias); row.control.Text:SetText(string.format("%s: %d  (×%.2f%s)",row.title,bias,multiplier,custom and "" or "  preset")); if custom then row.control:Enable() else row.control:Disable() end
    end
end

local function makeBias(parent, key, title, y)
    local max=ICN2.CUSTOM_DECAY_MULTIPLIER_MAX or 30
    local control=CreateFrame("Slider",nil,parent,"OptionsSliderTemplate"); control:SetPoint("TOPLEFT",parent,"TOPLEFT",20,y); control:SetWidth(440); control:SetMinMaxValues(0,max); control:SetValueStep(1); control:SetObeyStepOnDrag(true); control.Low:SetText("0"); control.High:SetText(tostring(max)); control:SetValue(biasValue(key))
    control:SetScript("OnValueChanged",function(self,value)
        value=math.floor(value+.5); if ICN2DB.settings.preset~="custom" then self:SetValue(biasValue(key)); return end
        ICN2DB.settings.customDecayBias=ICN2DB.settings.customDecayBias or {hunger=1,thirst=1,fatigue=1}; ICN2DB.settings.customDecayBias[key]=value; self.Text:SetText(string.format("%s: %d  (×%.2f)",title,value,ICN2:DecayBiasToMultiplier(value)))
    end)
    control.Text:SetText(title); control.Text:SetTextColor(C.text[1],C.text[2],C.text[3]); table.insert(decaySliders,{key=key,title=title,control=control}); return control
end

local function selectTab(which)
    local display=which==1; displayPanel:SetShown(display); decayPanel:SetShown(not display); tabDisplay:SetAlpha(display and 1 or .55); tabDecay:SetAlpha(display and .55 or 1); if not display then refreshDecay() end
end

local function themeOptions()
    local list={}; for _,theme in ipairs(ICN2.HUD_THEME_LIST or {}) do table.insert(list,{id=theme.id,label=theme.label}) end; return list
end

local function selectedTheme(raw)
    local id=ICN2DB.settings.barTheme or "relic"; if raw then return id end; for _,item in ipairs(themeOptions()) do if item.id==id then return item.label end end; return id
end

local function labelOptions()
    return {{id="none",label=L["LABEL_NONE"]},{id="percentage",label=L["LABEL_PERCENTAGE"]},{id="number",label=L["LABEL_NUMBER"]},{id="both",label=L["LABEL_BOTH"]}}
end

local function selectedLabel(raw)
    local id=ICN2DB.settings.barLabelMode or "percentage"; if raw then return id end; for _,item in ipairs(labelOptions()) do if item.id==id then return item.label end end; return id
end

function ICN2:BuildOptions()
    optionsFrame=CreateFrame("Frame","ICN2OptionsFrame",UIParent,"BasicFrameTemplateWithInset"); optionsFrame:SetSize(700,650); optionsFrame:SetPoint("CENTER"); optionsFrame:SetFrameStrata("HIGH"); optionsFrame:SetMovable(true); optionsFrame:EnableMouse(true); optionsFrame:RegisterForDrag("LeftButton"); optionsFrame:SetScript("OnDragStart",function(self) self:StartMoving() end); optionsFrame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end); optionsFrame:Hide(); optionsFrame.TitleText:SetText(L["OPT_TITLE"])
    local sidebar=CreateFrame("Frame",nil,optionsFrame,"BackdropTemplate"); sidebar:SetPoint("TOPLEFT",optionsFrame,"TOPLEFT",8,-28); sidebar:SetPoint("BOTTOMLEFT",optionsFrame,"BOTTOMLEFT",8,8); sidebar:SetWidth(150); sidebar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); sidebar:SetBackdropColor(C.panel[1],C.panel[2],C.panel[3],1)
    makeLabel(sidebar,"ICN2",18,-24,"GameFontNormalLarge",C.orange); makeLabel(sidebar,"VITALITY",18,-47,"GameFontHighlightSmall",C.muted)
    tabDisplay=button(sidebar,L["OPT_SEC_HUD"],10,-78,130,function() selectTab(1) end); tabDisplay:SetNormalFontObject("GameFontNormal"); tabDisplay:SetHighlightFontObject("GameFontHighlight")
    tabDecay=button(sidebar,L["TAB_DECAY"],10,-124,130,function() selectTab(2) end); tabDecay:SetNormalFontObject("GameFontNormal"); tabDecay:SetHighlightFontObject("GameFontHighlight")
    makeLabel(sidebar,"3.0.1",18,-188,"GameFontDisableSmall",C.muted); makeLabel(sidebar,"Changes apply instantly",18,-211,"GameFontDisableSmall",C.muted,120)
    local content=CreateFrame("Frame",nil,optionsFrame); content:SetPoint("TOPLEFT",sidebar,"TOPRIGHT",12,0); content:SetPoint("BOTTOMRIGHT",optionsFrame,"BOTTOMRIGHT",-14,8)
    local scroll=CreateFrame("ScrollFrame",nil,content,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",content,"TOPLEFT",0,-4); scroll:SetPoint("BOTTOMRIGHT",content,"BOTTOMRIGHT",-16,4)
    local child=CreateFrame("Frame",nil,scroll); child:SetWidth(500); child:SetHeight(950); scroll:SetScrollChild(child)
    displayPanel=CreateFrame("Frame",nil,child); displayPanel:SetAllPoints(child); decayPanel=CreateFrame("Frame",nil,child); decayPanel:SetAllPoints(child); decayPanel:Hide()

    local display=makeCard(displayPanel,L["OPT_SEC_HUD"],-4,350)
    makeCheckbox(display,L["OPT_HUD_ENABLED"],18,-54,function() return ICN2DB.settings.hudEnabled end,function(value) ICN2DB.settings.hudEnabled=value; ICN2:UpdateHUD() end,220)
    makeCheckbox(display,L["OPT_HUD_LOCKED"],18,-84,function() return ICN2DB.settings.hudLocked end,function(value) ICN2DB.settings.hudLocked=value; ICN2:LockHUD(value or ICN2DB.settings.hudAttached) end,220)
    makeCheckbox(display,L["OPT_HUD_ATTACH"],18,-114,function() return ICN2DB.settings.hudAttached end,function(value) ICN2DB.settings.hudAttached=value; ICN2:ApplyHUDAnchor(); ICN2:LockHUD(value or ICN2DB.settings.hudLocked) end,280)
    makeCheckbox(display,L["OPT_MINIMAP_BUTTON"],18,-144,function() return ICN2DB.settings.minimapButton end,function(value) ICN2DB.settings.minimapButton=value; ICN2:SetMinimapButtonShown(value) end,220)
    styleDropdown=dropdown(display,"ICN2ThemeDropdown",L["OPT_HUD_STYLE"],18,-183,190,themeOptions,selectedTheme,function(item) ICN2:SetBarTheme(item.id); UIDropDownMenu_SetText(styleDropdown,item.label) end)
    labelDropdown=dropdown(display,"ICN2LabelDropdown",L["OPT_SEC_LABEL_MODE"],18,-225,190,labelOptions,selectedLabel,function(item) ICN2DB.settings.barLabelMode=item.id; ICN2:UpdateHUD(); UIDropDownMenu_SetText(labelDropdown,item.label) end)
    slider(display,L["OPT_OPACITY"],18,-286,205,.1,1,.05,function() return ICN2DB.settings.hudAlpha end,function(value) ICN2DB.settings.hudAlpha=value; local frame=_G["ICN2HUDFrame"]; if frame then frame:SetAlpha(value) end end,2)
    slider(display,L["OPT_SCALE"],270,-286,190,.5,2,.1,function() return ICN2DB.settings.hudScale end,function(value) ICN2DB.settings.hudScale=value; ICN2:ApplyHUDTheme(ICN2DB.settings.barTheme) end,2)
    button(display,L["OPT_BTN_CENTER"],18,-326,125,function() ICN2DB.settings.hudAttached=false; ICN2DB.settings.hudPosition={point="CENTER",relPoint="CENTER",x=0,y=0}; ICN2:ApplyHUDAnchor() end)

    local roleplay=makeCard(displayPanel,L["OPT_SEC_IMMERSION"],-366,152)
    makeCheckbox(roleplay,L["OPT_FREEZE_OFFLINE"],18,-54,function() return ICN2DB.settings.freezeOfflineNeeds end,function(value) ICN2DB.settings.freezeOfflineNeeds=value end,430)
    makeCheckbox(roleplay,L["OPT_EMOTES_ENABLED"],18,-84,function() return ICN2DB.settings.emotesEnabled end,function(value) ICN2DB.settings.emotesEnabled=value end,250)
    slider(roleplay,L["OPT_EMOTE_CHANCE"],18,-125,205,0,1,.05,function() return ICN2DB.settings.emoteChance end,function(value) ICN2DB.settings.emoteChance=value end,2)
    slider(roleplay,L["OPT_EMOTE_INTERVAL"],270,-125,190,30,600,10,function() return ICN2DB.settings.emoteMinInterval end,function(value) ICN2DB.settings.emoteMinInterval=value end,0)

    local manual=makeCard(displayPanel,L["OPT_SEC_MANUAL_RESTORE"],-528,180)
    button(manual,L["BTN_EAT"],18,-54,100,function() ICN2:Eat(50) end); button(manual,L["BTN_DRINK"],126,-54,100,function() ICN2:Drink(50) end); button(manual,L["BTN_REST"],234,-54,100,function() ICN2:Rest(40) end); button(manual,L["BTN_RESET"],342,-54,100,function() ICN2DB.hunger=ICN2:GetMaxValue("hunger"); ICN2DB.thirst=ICN2:GetMaxValue("thirst"); ICN2DB.fatigue=ICN2:GetMaxValue("fatigue"); ICN2:UpdateHUD() end)
    makeLabel(manual,L["OPT_SEC_MANUAL_DEPLETE"],18,-102,"GameFontNormal",C.gold); button(manual,L["BTN_STARVE"],18,-128,100,function() ICN2DB.hunger=0; ICN2:UpdateHUD() end); button(manual,L["BTN_DEHYDRATE"],126,-128,100,function() ICN2DB.thirst=0; ICN2:UpdateHUD() end); button(manual,L["BTN_EXHAUST"],234,-128,100,function() ICN2DB.fatigue=0; ICN2:UpdateHUD() end)

    local decay=makeCard(decayPanel,L["OPT_SEC_DECAY_PRESET"],-4,500); local presets={"fast","medium","slow","realistic","custom"}
    for i,preset in ipairs(presets) do button(decay,preset:sub(1,1):upper()..preset:sub(2),18+(i-1)*88,-54,82,function() ICN2DB.settings.preset=preset; refreshDecay() end) end
    makeLabel(decay,L["DESC_DECAY_LONG"]:format(ICN2.CUSTOM_DECAY_MULTIPLIER_MAX or 30),18,-96,"GameFontHighlightSmall",C.muted,460); makeLabel(decay,L["OPT_SEC_BIAS"],18,-180,"GameFontNormal",C.gold)
    decaySliders={}; makeBias(decay,"hunger",L["HUNGER"],-210); makeBias(decay,"thirst",L["THIRST"],-280); makeBias(decay,"fatigue",L["FATIGUE"],-350)
    optionsFrame:SetScript("OnShow",function() refreshDecay(); UIDropDownMenu_SetText(styleDropdown,selectedTheme()); UIDropDownMenu_SetText(labelDropdown,selectedLabel()) end); selectTab(1)
end

function ICN2:ToggleOptions()
    if not optionsFrame then self:BuildOptions() end
    if optionsFrame:IsShown() then optionsFrame:Hide() else optionsFrame:Show() end
end
