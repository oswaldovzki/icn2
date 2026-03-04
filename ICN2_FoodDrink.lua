-- ============================================================
-- ICN2_FoodDrink.lua  (v1.1.2)
-- Hooks WoW's native food/drink buff events via UNIT_AURA.
--
-- How it works:
--   1. When a "eating" or "drinking" aura appears on the player,
--      we record the buff start time and expected duration.
--   2. Every tick we trickle restoration proportionally so the
--      bar visually fills while eating/drinking.
--   3. If the buff expires naturally (≥85% of duration elapsed)
--      → +50% restore to hunger or thirst (v1.1.2: capped at 50%).
--   4. If the buff disappears early (cancelled) →
--      partial credit proportional to time: up to 50% max.
--   5. "Well Fed" aura appearing → hunger AND thirst instantly set
--      to 100%, one-shot, no persistent flag. The buff itself is
--      not tracked further; normal decay resumes immediately.
-- ============================================================

ICN2 = ICN2 or {}

-- ── State ─────────────────────────────────────────────────────────────────────
local foodState  = { active = false, startTime = nil, duration = nil, buffName = nil }
local drinkState = { active = false, startTime = nil, duration = nil, buffName = nil }

-- ── Known aura name fragments (lowercase) ─────────────────────────────────────
local FOOD_AURA_PATTERNS   = { "food", "refreshment", "eating" }
local DRINK_AURA_PATTERNS  = { "drink", "thirst", "drinking", "hydration" }
local WELLFED_PATTERNS     = { "well fed" }
local DRINK_EXTRA_PATTERNS = { "conjured water", "mana tea", "morning glory" }

-- v1.1.2: Full eat/drink session restores exactly 50% of the need bar.
-- Partial cancellation grants a proportional fraction of that 50%.
local FULL_SESSION_RESTORE = 50.0  -- % restored on full uninterrupted session

-- ── Utility: scan unit auras (C_UnitAuras API, TWW / 10.x+) ──────────────────
local function scanAuras(unit, filter)
    local results = {}
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not aura then break end
        table.insert(results, aura)
        i = i + 1
    end
    return results
end

-- ── Check if a name matches any pattern ──────────────────────────────────────
local function matchesAny(name, patterns)
    if not name then return false end
    local lower = name:lower()
    for _, p in ipairs(patterns) do
        if lower:find(p, 1, true) then return true end
    end
    return false
end

-- ── Find a specific aura type on the player ──────────────────────────────────
local function findAura(patterns, extraPatterns)
    local auras = scanAuras("player", "HELPFUL")
    for _, aura in ipairs(auras) do
        if matchesAny(aura.name, patterns) then return aura end
        if extraPatterns and matchesAny(aura.name, extraPatterns) then return aura end
    end
    return nil
end

-- ── Apply restoration on buff end ────────────────────────────────────────────
-- full = true  → player finished eating/drinking naturally → +50%
-- full = false → player was interrupted               → +(50% × fraction)
local function applyRestore(state, need, full)
    if not state.startTime then return end

    local elapsed  = GetTime() - state.startTime
    local duration = state.duration or 30
    local fraction = math.min(1.0, elapsed / math.max(1, duration))
    local amount   = full and FULL_SESSION_RESTORE or (FULL_SESSION_RESTORE * fraction)

    if need == "hunger" then
        ICN2DB.hunger = math.min(100, ICN2DB.hunger + amount)
        ICN2:TriggerEmote("satisfied", "hunger")
    elseif need == "thirst" then
        ICN2DB.thirst = math.min(100, ICN2DB.thirst + amount)
        ICN2:TriggerEmote("satisfied", "thirst")
    end

    ICN2:UpdateHUD()

    if full then
        print(string.format("|cFFFF6600ICN2|r %s restored! (+50%%)",
            need == "hunger" and "|cFF00FF00Hunger|r" or "|cFF4499FFThirst|r"))
    elseif amount >= 1 then
        print(string.format("|cFFFF6600ICN2|r %s partially restored (+%.0f%% — interrupted).",
            need == "hunger" and "|cFF00FF00Hunger|r" or "|cFF4499FFThirst|r",
            amount))
    end
end

-- ── Main aura scan — called on every UNIT_AURA for player ─────────────────────
function ICN2:OnUnitAura()
    local now = GetTime()

    -- ── Food aura ─────────────────────────────────────────────────────────────
    local foodAura = findAura(FOOD_AURA_PATTERNS)
    if foodAura then
        if not foodState.active then
            foodState.active    = true
            foodState.startTime = now
            foodState.duration  = foodAura.duration or 30
            foodState.buffName  = foodAura.name
        end
    else
        if foodState.active then
            local elapsed  = now - (foodState.startTime or now)
            local duration = foodState.duration or 30
            local natural  = (elapsed >= duration * 0.85)
            applyRestore(foodState, "hunger", natural)
            foodState.active    = false
            foodState.startTime = nil
            foodState.duration  = nil
            foodState.buffName  = nil
        end
    end

    -- ── Well Fed aura (v1.1.2: one-shot, no persistent tracking) ─────────────
    -- When Well Fed appears, immediately set both hunger and thirst to 100%.
    -- We do NOT set a persistent flag — the buff can stay on the player for
    -- minutes and we must not keep firing. Instead we record the aura's
    -- instanceID so we only trigger once per unique Well Fed application.
    local wellFedAura = findAura(WELLFED_PATTERNS)
    if wellFedAura then
        local id = wellFedAura.auraInstanceID or 0
        if id ~= ICN2._lastWellFedInstanceID then
            ICN2._lastWellFedInstanceID = id
            ICN2DB.hunger = 100.0
            ICN2DB.thirst = 100.0
            ICN2:UpdateHUD()
            ICN2:TriggerEmote("satisfied", "hunger")
            print("|cFFFF6600ICN2|r |cFF00FF00Well Fed!|r Hunger and Thirst set to 100%%. Decay resumes normally.")
        end
    else
        -- Buff gone — reset so the next application triggers again
        ICN2._lastWellFedInstanceID = nil
    end

    -- ── Drink aura ────────────────────────────────────────────────────────────
    local drinkAura = findAura(DRINK_AURA_PATTERNS, DRINK_EXTRA_PATTERNS)
    if drinkAura then
        if not drinkState.active then
            drinkState.active    = true
            drinkState.startTime = now
            drinkState.duration  = drinkAura.duration or 30
            drinkState.buffName  = drinkAura.name
        end
    else
        if drinkState.active then
            local elapsed  = now - (drinkState.startTime or now)
            local duration = drinkState.duration or 30
            local natural  = (elapsed >= duration * 0.85)
            applyRestore(drinkState, "thirst", natural)
            drinkState.active    = false
            drinkState.startTime = nil
            drinkState.duration  = nil
            drinkState.buffName  = nil
        end
    end
end

-- ── Cancel eating/drinking on combat enter ────────────────────────────────────
function ICN2:OnCombatBreakFoodDrink()
    -- UNIT_AURA fires when WoW cancels the buff on combat enter.
    -- Partial credit is handled there. This hook is kept for future use.
end

-- ── Tick: trickle restoration while buff is active ───────────────────────────
-- Spreads 50% across the full buff duration so the bar visually fills.
-- The final applyRestore() on buff-end accounts for the total correctly:
-- trickle gives a live preview; applyRestore adds the remaining delta.
function ICN2:FoodDrinkTick()
    if foodState.active and foodState.startTime and foodState.duration then
        -- trickle = 50% / duration per second, shown live
        local tickGain = FULL_SESSION_RESTORE / math.max(1, foodState.duration)
        ICN2DB.hunger = math.min(100, ICN2DB.hunger + tickGain)
        ICN2:UpdateHUD()
    end

    if drinkState.active and drinkState.startTime and drinkState.duration then
        local tickGain = FULL_SESSION_RESTORE / math.max(1, drinkState.duration)
        ICN2DB.thirst = math.min(100, ICN2DB.thirst + tickGain)
        ICN2:UpdateHUD()
    end
end

-- ── Status query ─────────────────────────────────────────────────────────────
function ICN2:IsEating()   return foodState.active  end
function ICN2:IsDrinking() return drinkState.active end
