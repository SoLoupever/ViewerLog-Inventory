local addonName, ns = ...

-- ViewerLog_Tooltip : infobulle d'objet.
-- Addon séparé dépendant de ViewerLog : le désactiver (section Dépendances
-- du panneau, ou liste d'addons) coupe entièrement le hook, sans /reload
-- côté cœur. Lit l'index de possession via l'API publique _G.ViewerLogAPI
-- (pas d'accès au ns interne de ViewerLog), y compris pour les options
-- d'affichage (icônes / guilde / bataillon / royaume) via GetSetting.

local VL = _G.ViewerLogAPI
if not VL then return end   -- ViewerLog absent : rien à injecter.

local L = VL.L

-- ── Icônes ───────────────────────────────────────────────────────

local ICON = {
    HORDE    = "|TInterface\\Icons\\PVPCurrency-Honor-Horde:14:14:0:0|t",
    ALLIANCE = "|TInterface\\Icons\\PVPCurrency-Honor-Alliance:14:14:0:0|t",
    WARBAND  = "|T6124644:14:14:0:0|t",
    GUILD    = "|TInterface\\Icons\\Achievement_GuildPerk_MobileBanking:14:14:0:0|t",
}

-- ── Cache couleurs de classe ──────────────────────────────────────

local classHex = {}
local function GetClassHex(class)
    if not classHex[class] then
        local c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
               or { r = 0.8, g = 0.8, b = 0.8 }
        classHex[class] = string.format("FF%02x%02x%02x",
            math.floor(c.r * 255 + 0.5),
            math.floor(c.g * 255 + 0.5),
            math.floor(c.b * 255 + 0.5))
    end
    return classHex[class]
end

-- ── Injection dans l'infobulle ────────────────────────────────────

local function AppendInfo(tooltip, itemID)
    if not itemID then return end

    -- Désactivation "douce" via la case du menu ViewerLog (addon reste chargé).
    if VL.GetSetting("disableTooltip") then return end
    if VL.GetSetting("tooltipOnShift") and not IsShiftKeyDown() then return end

    local entry = VL.GetTooltipEntry(itemID)
    if not entry then return end

    local showIcons  = not VL.GetSetting("hideTooltipIcons")
    local showGuild  = not VL.GetSetting("hideGuildTooltip")
    local showRealm  = not VL.GetSetting("hideRealmTooltip")
    local showWarband = not VL.GetSetting("hideWarbandTooltip")

    local hasChars   = next(entry.chars)       ~= nil
    local hasWarband = (entry.warbandCount     or 0) > 0 and showWarband
    local guildInfo  = entry.sources and entry.sources.guild
    local guildTotal = guildInfo and guildInfo.total or 0
    local hasGuild   = guildTotal > 0 and showGuild
    if not hasChars and not hasWarband and not hasGuild then return end

    -- Total pré-calculé (affiché dans l'en-tête "Owned by").
    local preTotal = 0
    for _, ce in pairs(entry.chars) do
        preTotal = preTotal + (ce.bagCount or 0) + (ce.bankCount or 0) + (ce.mailCount or 0) + (ce.auctionCount or 0)
    end
    if hasWarband then preTotal = preTotal + entry.warbandCount end
    if hasGuild   then preTotal = preTotal + guildTotal end

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(
        L("TT_OWNED_BY"),
        string.format("|cffb266ff%s :|r  |cffffffff%d|r", L("TT_TOTAL"), preTotal),
        1, 0.80, 0, 1, 1, 1)

    local grandTotal = 0

    -- ── Personnages ───────────────────────────────────────────
    for _, ce in pairs(entry.chars) do
        local total = (ce.bagCount or 0) + (ce.bankCount or 0) + (ce.mailCount or 0) + (ce.auctionCount or 0)
        if total > 0 then
            grandTotal = grandTotal + total
            local hex  = GetClassHex(ce.class or "WARRIOR")

            local factionIcon = ""
            if showIcons then
                if     ce.faction == "Horde"    then factionIcon = ICON.HORDE   .. " "
                elseif ce.faction == "Alliance" then factionIcon = ICON.ALLIANCE .. " "
                end
            end

            local left
            if showRealm then
                left = string.format("%s|c%s%s|r |c%s(%s)|r",
                    factionIcon, hex, ce.char, hex, ce.realm)
            else
                left = string.format("%s|c%s%s|r", factionIcon, hex, ce.char)
            end

            local parts = {}
            if (ce.bagCount  or 0) > 0 then
                parts[#parts+1] = string.format("|cffffffff%d :|r |cffa335ee%s|r", ce.bagCount,  L("TT_BAG"))
            end
            if (ce.bankCount or 0) > 0 then
                parts[#parts+1] = string.format("|cffffffff%d :|r |cffa335ee%s|r", ce.bankCount, L("TT_BANK"))
            end
            if (ce.mailCount or 0) > 0 then
                parts[#parts+1] = string.format("|cffffffff%d :|r |cffa335ee%s|r", ce.mailCount, L("TT_MAIL"))
            end
            if (ce.auctionCount or 0) > 0 then
                parts[#parts+1] = string.format("|cffffffff%d :|r |cffa335ee%s|r", ce.auctionCount, L("TT_AUCTION"))
            end

            tooltip:AddDoubleLine(left, table.concat(parts, "  |cff444444·|r  "),
                1, 1, 1, 1, 1, 1)
        end
    end

    -- ── Bataillon ─────────────────────────────────────────────
    if hasWarband then
        grandTotal = grandTotal + entry.warbandCount
        local left  = (showIcons and ICON.WARBAND .. " " or "") ..
                      "|cffd4af37" .. L("TT_WARBAND") .. "|r"
        local right = string.format("|cffffffff%d|r", entry.warbandCount)
        tooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
    end

    -- ── Guildes ───────────────────────────────────────────────
    if hasGuild then
        grandTotal = grandTotal + guildTotal
        if guildInfo.labels then
            for gName, gCount in pairs(guildInfo.labels) do
                local left  = (showIcons and ICON.GUILD .. " " or "") ..
                              "|cff40c0ff" .. L("TT_GUILD") .. " " .. gName .. "|r"
                local right = string.format("|cffffffff%d|r", gCount)
                tooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
            end
        end
    end
end

-- ── Enregistrement du hook ────────────────────────────────────────
-- Toujours enregistré tant que l'addon est chargé. Deux niveaux d'arrêt :
-- masquage doux via le réglage disableTooltip (testé dans AppendInfo),
-- ou déchargement complet en désactivant l'addon (section Dépendances).

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,
        function(tooltip, data)
            if data and data.id then AppendInfo(tooltip, data.id) end
        end)
else
    -- Compatibilité versions antérieures.
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        local _, link = tooltip:GetItem()
        if link then
            AppendInfo(tooltip, tonumber(link:match("item:(%d+)")))
        end
    end)
end
