-- ============================================================
-- ICN2_State.lua
-- World-sensing module. Its only job is answering: "What is the player currently doing?"
--
-- ICN2.State is the single source of truth for all condition flags. Every field is a plain fact about the player
-- No gameplay math lives here.
-- ============================================================

ICN2 = ICN2 or {}

-- ── State table ───────────────────────────────────────────────────────────────
-- All fields default to their safest / most conservative value.
-- inCombat is the only field written by an event rather than UpdateState().
ICN2.State = {
    inCombat    = false, -- set by PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED events for zero-latency response
    isSwimming  = false, -- IsSubmerged()
    isSitting   = false, -- set by sit/stand hooks; cleared by movement/action events
    isResting   = false, -- IsResting() — inn, city, garrison, etc.
    isFlying    = false, -- IsFlying()
    isMounted   = false, -- IsMounted()
    isIndoors   = false, -- IsIndoors()
    nearCampfire = false,-- player has a Cozy Fire / campfire buff
    inHousing   = false, -- player is in a housing zone/plot
    inInstance  = false, -- IsInInstance() — dungeon, raid, BG, arena (aura scanning disabled)
}

-- Sitting is not represented reliably by a player aura.  It is therefore an
-- input/event-driven state rather than something reconstructed during the
-- normal state scan below.
function ICN2:SetSitting(value)
    local newValue = value and true or false
    if ICN2.State.isSitting ~= newValue then
        ICN2.State.isSitting = newValue
        print("|cFFFF6600ICN2|r sitting state: " .. (newValue and "true" or "false"))
    end
end

function ICN2:ClearSitting()
    self:SetSitting(false)
end

-- Install these after PLAYER_LOGIN.  Some of the protected Blizzard action
-- functions are not guaranteed to be available while addon files are loading.
-- The guard also prevents duplicate hooks after an addon reload/init path.
function ICN2:InitSittingHooks()
    if self._sittingHooksInitialized then return end
    self._sittingHooksInitialized = true

    -- Keyboard sit/stand action.  This is a toggle, so mirror the toggle.
    if type(SitStandOrDescendStart) == "function" then
        hooksecurefunc("SitStandOrDescendStart", function()
            ICN2:SetSitting(not ICN2.State.isSitting)
        end)
    end

    -- Built-in /sit and /stand commands are emotes, not addon slash commands.
    if type(DoEmote) == "function" then
        hooksecurefunc("DoEmote", function(emote)
            emote = string.upper(tostring(emote))
            if emote == "SIT" then
                ICN2:SetSitting(true)
            elseif emote == "STAND" then
                ICN2:SetSitting(false)
            end
        end)
    end

    -- Retail clients may route built-in slash emotes through the C namespace
    -- instead of the legacy DoEmote() function.
    if C_ChatInfo and type(C_ChatInfo.PerformEmote) == "function" then
        hooksecurefunc(C_ChatInfo, "PerformEmote", function(emote)
            emote = string.upper(tostring(emote))
            if emote == "SIT" then
                ICN2:SetSitting(true)
            elseif emote == "STAND" then
                ICN2:SetSitting(false)
            end
        end)
    end

    -- On some clients the built-in slash handlers are created after the
    -- addon files load and do not route through DoEmote in an observable way.
    -- Hook the handlers directly when they are available after login.
    if SlashCmdList then
        if type(SlashCmdList.SIT) == "function" then
            hooksecurefunc(SlashCmdList, "SIT", function()
                ICN2:SetSitting(true)
            end)
        end
        if type(SlashCmdList.STAND) == "function" then
            hooksecurefunc(SlashCmdList, "STAND", function()
                ICN2:SetSitting(false)
            end)
        end
    end
end

-- ── UpdateState ───────────────────────────────────────────────────────────────
function ICN2:UpdateState()
    local s = ICN2.State

    -- inCombat is NOT set here. It's set immediately by PLAYER_REGEN_* events in Core for zero-latency response.
    s.isSwimming = (IsSubmerged and IsSubmerged()) and true or false
    s.isResting  = IsResting()  and true or false
    s.isFlying   = IsFlying()   and true or false
    s.isMounted  = IsMounted()  and true or false
    s.isIndoors  = IsIndoors()  and true or false

    -- ── Instance detection ────────────────────────────────────────────────────
    -- Detect dungeons, raids, battlegrounds, arenas (all have tainted auras).
    -- This prevents "secret string" errors that occur when scanning encounter buffs.
    local inInst, instType = IsInInstance()
    s.inInstance = inInst and (instType == "party" or instType == "raid" 
                              or instType == "pvp" or instType == "arena")

    -- ── Instance mode: skip aura scanning ─────────────────────────────────────
    if s.inInstance then
        s.nearCampfire = false
        s.inHousing    = false
        return  -- Exit early — no aura scanning in instances
    end

    if ICN2._auraAccessBlocked then
        s.nearCampfire = false
        s.inHousing    = false
        return
    end

    -- ── Aura-based detection ──────────────────────────────────────────────
    -- Two guards before the scan:
    --   1. s.inCombat
    --   2. UnitAffectingCombat. Covers the rare window where encounter auras
    --      arrive via UNIT_AURA before PLAYER_REGEN_DISABLED fires.
    -- inHousing is intentionally NOT cleared on combat; the zone is unchanged.
    if s.inCombat or UnitAffectingCombat("player") then
        s.nearCampfire = false
        return
    end

    local campfireFound = false

    -- Read from the shared aura cache maintained by ICN2_FoodDrink.lua.
    -- No aura scan here — the cache is already current when UpdateState() is called
    -- because UNIT_AURA patches it before the tick reads it.
    for _, aura in pairs(ICN2._auraCache or {}) do
        local ok, lower = pcall(function()
            return aura.name and string.lower(aura.name) or ""
        end)
        if ok then
            if not campfireFound then
                for _, p in ipairs(ICN2.CAMPFIRE_PATTERNS) do
                    if lower:find(p, 1, true) then campfireFound = true; break end
                end
            end
        end
        if campfireFound then break end
    end

    s.nearCampfire = campfireFound

    -- Housing: campfire buff is the primary signal. Map ID is a belt-and-suspenders fallback.
    local mapID = C_Map.GetBestMapForUnit("player")
    s.inHousing = campfireFound or (mapID ~= nil and ICN2.HOUSING_MAP_IDS[mapID] == true)
end
