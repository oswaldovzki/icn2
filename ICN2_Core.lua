-- ============================================================
-- ICN2_Core.lua  (v1.2.0-beta)
-- Core engine: initialization, decay tick, persistence,
-- situational detection, race/class modifiers.
-- ============================================================

ICN2 = ICN2 or {}

-- ── Internal state ────────────────────────────────────────────────────────────
local frame        = CreateFrame("Frame", "ICN2Frame", UIParent)
local tickInterval = 1.0
local elapsed      = 0

local inCombat   = false
local isSwimming = false

-- Rest stance: set by OnPoseUpdate, cleared on combat/mount
local restStance = nil   -- "sit" | "sleep" | "kneel" | nil

-- Last computed net rates (% per second). Positive = gaining, negative = losing.
-- Written by tick(), read by UpdateHUD() for the indicator and by /icn2 details.
ICN2._lastRates   = { hunger = 0, thirst = 0, fatigue = 0 }

-- Last active modifier labels, written by tick() only when /details was requested.
ICN2._lastDetails = nil

-- ── Deep copy utility ─────────────────────────────────────────────────────────
local function deepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = (type(v) == "table") and deepCopy(v) or v
    end
    return copy
end

-- ── Initialize / merge saved variables ───────────────────────────────────────
local function initDB()
    if not ICN2DB then
        ICN2DB = deepCopy(ICN2.DEFAULTS)
        ICN2DB.lastLogout = time()
        return
    end
    for k, v in pairs(ICN2.DEFAULTS) do
        if ICN2DB[k] == nil then
            ICN2DB[k] = (type(v) == "table") and deepCopy(v) or v
        end
    end
    for k, v in pairs(ICN2.DEFAULTS.settings) do
        if ICN2DB.settings[k] == nil then
            ICN2DB.settings[k] = (type(v) == "table") and deepCopy(v) or v
        end
    end
end

-- ── Offline decay ─────────────────────────────────────────────────────────────
local function applyOfflineDecay()
    if not ICN2DB.lastLogout then return end
    if ICN2DB.settings.freezeOfflineNeeds then return end

    local now   = time()
    local delta = math.min(now - ICN2DB.lastLogout, 8 * 3600)
    if delta <= 0 then return end

    local s      = ICN2DB.settings
    local preset = ICN2.PRESETS[s.preset] or 1.0
    local rest   = ICN2.SITUATION_MODIFIERS.resting

    ICN2DB.hunger  = math.max(0, ICN2DB.hunger  - s.decayRates.hunger  * preset * rest.hunger  * delta)
    ICN2DB.thirst  = math.max(0, ICN2DB.thirst  - s.decayRates.thirst  * preset * rest.thirst  * delta)
    ICN2DB.fatigue = math.max(0, ICN2DB.fatigue - s.decayRates.fatigue * preset * rest.fatigue * delta)

    ICN2:UpdateHUD()
end

-- ── Situation multipliers ─────────────────────────────────────────────────────
-- Returns mH, mT, mF plus an optional labels table if collectLabels=true.
local function getSituationMultipliers(collectLabels)
    local mH, mT, mF = 1.0, 1.0, 1.0
    local labels = collectLabels and {} or nil

    if IsResting() then
        local r = ICN2.SITUATION_MODIFIERS.resting
        mH, mT, mF = mH * r.hunger, mT * r.thirst, mF * r.fatigue
        if labels then table.insert(labels, string.format("resting (H×%.2f T×%.2f F×%.2f)", r.hunger, r.thirst, r.fatigue)) end
        -- resting short-circuits everything else
        goto applyCharMods
    end

    if IsMounted() then
        local m = ICN2.SITUATION_MODIFIERS.mounted
        mH, mT, mF = mH * m.hunger, mT * m.thirst, mF * m.fatigue
        if labels then table.insert(labels, string.format("mounted (H×%.2f T×%.2f F×%.2f)", m.hunger, m.thirst, m.fatigue)) end
    end

    if IsFlying() then
        local f = ICN2.SITUATION_MODIFIERS.flying
        mH, mT, mF = mH * f.hunger, mT * f.thirst, mF * f.fatigue
        if labels then table.insert(labels, string.format("flying (H×%.2f T×%.2f F×%.2f)", f.hunger, f.thirst, f.fatigue)) end
    end

    if isSwimming then
        local sw = ICN2.SITUATION_MODIFIERS.swimming
        mH, mT, mF = mH * sw.hunger, mT * sw.thirst, mF * sw.fatigue
        if labels then table.insert(labels, string.format("swimming (H×%.2f T×%.2f F×%.2f)", sw.hunger, sw.thirst, sw.fatigue)) end
    end

    if inCombat then
        local c = ICN2.SITUATION_MODIFIERS.combat
        mH, mT, mF = mH * c.hunger, mT * c.thirst, mF * c.fatigue
        if labels then table.insert(labels, string.format("combat (H×%.2f T×%.2f F×%.2f)", c.hunger, c.thirst, c.fatigue)) end
    end

    if IsIndoors() and not inCombat and not IsMounted() then
        local ind = ICN2.SITUATION_MODIFIERS.indoors
        mH, mT, mF = mH * ind.hunger, mT * ind.thirst, mF * ind.fatigue
        if labels then table.insert(labels, string.format("indoors (H×%.2f T×%.2f F×%.2f)", ind.hunger, ind.thirst, ind.fatigue)) end
    end

    ::applyCharMods::

    local race = select(2, UnitRace("player"))
    local rm   = ICN2.RACE_MODIFIERS[race]
    if rm then
        mH, mT, mF = mH * rm.hunger, mT * rm.thirst, mF * rm.fatigue
        if labels then table.insert(labels, string.format("race:%s (H×%.2f T×%.2f F×%.2f)", race, rm.hunger, rm.thirst, rm.fatigue)) end
    end

    local _, class = UnitClass("player")
    local cm = ICN2.CLASS_MODIFIERS[class]
    if cm then
        mH, mT, mF = mH * cm.hunger, mT * cm.thirst, mF * cm.fatigue
        if labels then table.insert(labels, string.format("class:%s (H×%.2f T×%.2f F×%.2f)", class, cm.hunger, cm.thirst, cm.fatigue)) end
    end

    return mH, mT, mF, labels
end

-- ── Armor fatigue modifier ────────────────────────────────────────────────────
local function getArmorFatigueModifier(collectLabels)
    local itemLink = GetInventoryItemLink("player", 5)
    if not itemLink then
        return ICN2.ARMOR_FATIGUE.CLOTH, collectLabels and "armor:none→CLOTH" or nil
    end

    local itemInfo = C_Item.GetItemInfo(itemLink)
    local subType  = itemInfo and itemInfo.itemSubType or nil

    if subType then
        if subType:find("Plate")   then return ICN2.ARMOR_FATIGUE.PLATE,   collectLabels and string.format("armor:PLATE (F×%.2f)",   ICN2.ARMOR_FATIGUE.PLATE)   or nil end
        if subType:find("Mail")    then return ICN2.ARMOR_FATIGUE.MAIL,    collectLabels and string.format("armor:MAIL (F×%.2f)",    ICN2.ARMOR_FATIGUE.MAIL)    or nil end
        if subType:find("Leather") then return ICN2.ARMOR_FATIGUE.LEATHER, collectLabels and string.format("armor:LEATHER (F×%.2f)", ICN2.ARMOR_FATIGUE.LEATHER) or nil end
    end
    return ICN2.ARMOR_FATIGUE.CLOTH, collectLabels and string.format("armor:CLOTH (F×%.2f)", ICN2.ARMOR_FATIGUE.CLOTH) or nil
end

-- ── Main decay tick ───────────────────────────────────────────────────────────
local function tick()
    local s      = ICN2DB.settings
    local preset = ICN2.PRESETS[s.preset] or 1.0
    local mH, mT, mF = getSituationMultipliers()
    local armorMod   = getArmorFatigueModifier()

    local dH = s.decayRates.hunger  * preset * mH
    local dT = s.decayRates.thirst  * preset * mT
    local dF = s.decayRates.fatigue * preset * mF * armorMod

    local oldHunger  = ICN2DB.hunger
    local oldThirst  = ICN2DB.thirst
    local oldFatigue = ICN2DB.fatigue

    ICN2DB.hunger  = math.max(0, ICN2DB.hunger  - dH)
    ICN2DB.thirst  = math.max(0, ICN2DB.thirst  - dT)
    ICN2DB.fatigue = math.max(0, ICN2DB.fatigue - dF)

    -- Net rate: decay is negative, stance recovery adds positive to fatigue
    local stanceGain = (restStance and ICN2.REST_STANCE_RATES[restStance] or 0)
    ICN2._lastRates = {
        hunger  = -dH,
        thirst  = -dT,
        fatigue = stanceGain - dF,
    }

    ICN2:UpdateHUD()
    ICN2:CheckEmotes(oldHunger, oldThirst, oldFatigue)
end

-- ── Recovery functions ────────────────────────────────────────────────────────
function ICN2:Eat(amount)
    ICN2DB.hunger = math.min(100, ICN2DB.hunger + (amount or 30))
    self:UpdateHUD()
    self:TriggerEmote("satisfied", "hunger")
end

function ICN2:Drink(amount)
    ICN2DB.thirst = math.min(100, ICN2DB.thirst + (amount or 30))
    self:UpdateHUD()
    self:TriggerEmote("satisfied", "thirst")
end

function ICN2:Rest(amount)
    ICN2DB.fatigue = math.min(100, ICN2DB.fatigue + (amount or 20))
    self:UpdateHUD()
    self:TriggerEmote("satisfied", "fatigue")
end

-- ── Event registration ────────────────────────────────────────────────────────
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("UNIT_POSE_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "ICN2" then
            initDB()
            ICN2:BuildHUD()
            ICN2:BuildOptions()
            print("|cFFFF6600ICN2|r loaded. Type |cFFFFFF00/icn2|r for options.")
        end

    elseif event == "PLAYER_LOGIN" then
        applyOfflineDecay()
        ICN2:UpdateHUD()

    elseif event == "PLAYER_LOGOUT" then
        ICN2DB.lastLogout = time()

    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat   = true
        restStance = nil

    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        ICN2:OnCombatBreakFoodDrink()

    elseif event == "PLAYER_UPDATE_RESTING" then
        -- Fires on inn enter/exit; also acts as a standing-up safety net
        if not restStance then return end
        -- If player just left a resting area while seated that's fine; keep stance
        -- But if they stood up the UNIT_POSE_UPDATE will clear it — nothing to do here

    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then ICN2:OnUnitAura() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then ICN2:HandleAbilityRecovery(spellID) end

    elseif event == "UNIT_POSE_UPDATE" then
        local unit, pose = ...
        if unit == "player" then ICN2:OnPoseUpdate(pose) end
    end
end)

-- ── OnUpdate ──────────────────────────────────────────────────────────────────
frame:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed >= tickInterval then
        elapsed = 0
        isSwimming = (IsSubmerged and IsSubmerged()) and true or false
        ICN2:FoodDrinkTick()
        ICN2:RestStanceTick()
        tick()
    end
end)

-- ── Pose → stance mapping ─────────────────────────────────────────────────────
-- UNIT_POSE_UPDATE passes pose as an uppercase string: "STAND", "SIT", "SLEEP", "KNEEL"
function ICN2:OnPoseUpdate(pose)
    if inCombat or IsMounted() then
        restStance = nil
        return
    end
    local poseMap = { SIT = "sit", SLEEP = "sleep", KNEEL = "kneel" }
    restStance = poseMap[pose]   -- nil when STAND
end

-- ── Fatigue recovery tick ─────────────────────────────────────────────────────
function ICN2:RestStanceTick()
    if not restStance then return end
    if inCombat or IsMounted() then return end
    if ICN2:IsEating() or ICN2:IsDrinking() then return end

    local rate = ICN2.REST_STANCE_RATES[restStance]
    if not rate then return end

    ICN2DB.fatigue = math.min(100, ICN2DB.fatigue + rate)
end

-- ── Racial / class ability recovery ──────────────────────────────────────────
local ABILITY_RECOVERY = {
    [20577]  = function() ICN2:Eat(40) end,           -- Cannibalize
    [204065] = function() ICN2:Eat(10) ICN2:Rest(10) end, -- DH soul fragment
    [58984]  = function() ICN2:Rest(5) end,            -- Shadowmeld
}

function ICN2:HandleAbilityRecovery(spellID)
    if ABILITY_RECOVERY[spellID] then ABILITY_RECOVERY[spellID]() end
end

-- ── /icn2 details ─────────────────────────────────────────────────────────────
-- Collects and prints all active modifiers for the current tick.
function ICN2:PrintDetails()
    local s      = ICN2DB.settings
    local preset = ICN2.PRESETS[s.preset] or 1.0
    local mH, mT, mF, situLabels = getSituationMultipliers(true)
    local armorMod, armorLabel   = getArmorFatigueModifier(true)

    local dH = s.decayRates.hunger  * preset * mH
    local dT = s.decayRates.thirst  * preset * mT
    local dF = s.decayRates.fatigue * preset * mF * armorMod
    local stanceGain = (restStance and ICN2.REST_STANCE_RATES[restStance] or 0)

    local P = "|cFFFF6600ICN2|r"
    local sep = "|cFF555555--------------------------------|r"

    print(P .. " |cFFFFFF00Details|r — preset: " .. s.preset .. string.format(" (×%.2f)", preset))
    print(sep)

    -- Hunger
    print(string.format(P .. " |cFF00FF00Hunger|r  %.1f%%  net |cFFFFFFFF%+.4f%%/s|r  (base %.5f × %.3f)",
        ICN2DB.hunger, -dH, s.decayRates.hunger, preset * mH))

    -- Thirst
    print(string.format(P .. " |cFF4499FFThirst|r  %.1f%%  net |cFFFFFFFF%+.4f%%/s|r  (base %.5f × %.3f)",
        ICN2DB.thirst, -dT, s.decayRates.thirst, preset * mT))

    -- Fatigue (net includes stance gain)
    print(string.format(P .. " |cFFFFDD00Fatigue|r %.1f%%  net |cFFFFFFFF%+.4f%%/s|r  (decay %.5f × %.3f, stance %+.4f/s)",
        ICN2DB.fatigue, stanceGain - dF, s.decayRates.fatigue, preset * mF * armorMod, stanceGain))

    print(sep)
    print(P .. " |cFFAAAAAASituation modifiers:|r")
    if #situLabels == 0 then
        print("  |cFF888888none (walking/idle outdoors)|r")
    else
        for _, lbl in ipairs(situLabels) do
            print("  |cFFCCCCCC" .. lbl .. "|r")
        end
    end
    if armorLabel then
        print("  |cFFCCCCCC" .. armorLabel .. "|r")
    end
    if restStance then
        print(string.format("  |cFFCCCCCCstance:%s (+%.4f%%/s fatigue)|r",
            restStance, stanceGain))
    end
    print(sep)
    if ICN2:IsEating() then
        print(P .. " |cFF00FF00Currently eating|r — hunger recovering")
    end
    if ICN2:IsDrinking() then
        print(P .. " |cFF4499FFCurrently drinking|r — thirst recovering")
    end
end

-- ── Slash commands ────────────────────────────────────────────────────────────
SLASH_ICN21 = "/icn2"
SlashCmdList["ICN2"] = function(msg)
    msg = msg:lower():trim()
    if msg == "show" or msg == "" then
        ICN2:ToggleOptions()
    elseif msg == "eat" then
        ICN2:Eat(50); print("|cFFFF6600ICN2|r You eat something. Hunger restored.")
    elseif msg == "drink" then
        ICN2:Drink(50); print("|cFFFF6600ICN2|r You drink something. Thirst restored.")
    elseif msg == "rest" then
        ICN2:Rest(40); print("|cFFFF6600ICN2|r You rest. Fatigue restored.")
    elseif msg == "reset" then
        ICN2DB.hunger = 100; ICN2DB.thirst = 100; ICN2DB.fatigue = 100
        ICN2:UpdateHUD()
        print("|cFFFF6600ICN2|r Needs reset to 100%.")
    elseif msg == "status" then
        print(string.format("|cFFFF6600ICN2|r Hunger: |cFF00FF00%.1f%%|r  Thirst: |cFF4499FF%.1f%%|r  Fatigue: |cFFFFDD00%.1f%%|r",
            ICN2DB.hunger, ICN2DB.thirst, ICN2DB.fatigue))
    elseif msg == "details" then
        ICN2:PrintDetails()
    elseif msg == "hud" then
        ICN2DB.settings.hudEnabled = not ICN2DB.settings.hudEnabled
        ICN2:UpdateHUD()
        print("|cFFFF6600ICN2|r HUD " .. (ICN2DB.settings.hudEnabled and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif msg == "lock" then
        ICN2DB.settings.hudLocked = not ICN2DB.settings.hudLocked
        ICN2:LockHUD(ICN2DB.settings.hudLocked)
        print("|cFFFF6600ICN2|r HUD " .. (ICN2DB.settings.hudLocked and "|cFFFF0000locked|r" or "|cFF00FF00unlocked|r"))
    else
        print("|cFFFF6600ICN2|r Commands: |cFFFFFF00/icn2|r [show|eat|drink|rest|reset|status|details|hud|lock]")
    end
end
