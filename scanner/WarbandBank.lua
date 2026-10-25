local addonName, ns = ...

-- Scanner banque de bataillon (onglets).
-- Debounce queue + OnUpdate identique à Bank.lua / Bags.lua.

local wipe = wipe

-- ContainerIDs via Enum.BagIndex (pas de valeurs hardcodées). La liste est
-- volontairement plus longue que le nombre d'onglets débloquables : un nom
-- n'est retenu que si Enum.BagIndex[name] existe sur ce client, donc un onglet
-- ajouté plus tard par Blizzard est couvert sans faux conteneur.
local WARBAND_CONTAINERS = {}
do
    local tabNames = {
        "AccountBankTab_1", "AccountBankTab_2", "AccountBankTab_3",
        "AccountBankTab_4", "AccountBankTab_5", "AccountBankTab_6",
        "AccountBankTab_7", "AccountBankTab_8", "AccountBankTab_9",
        "AccountBankTab_10",
    }
    for _, name in ipairs(tabNames) do
        local val = Enum and Enum.BagIndex and Enum.BagIndex[name]
        if val then
            WARBAND_CONTAINERS[#WARBAND_CONTAINERS + 1] = val
        end
    end
    -- Enum absent (client < TWW) → table vide, bataillon désactivé.
end

-- Lookup pour identifier un bagID bataillon depuis BAG_UPDATE.
local WARBAND_BAG_SET = {}
for _, bag in ipairs(WARBAND_CONTAINERS) do
    WARBAND_BAG_SET[bag] = true
end

function ns.IsWarbandBag(bagID)
    return WARBAND_BAG_SET[bagID] == true
end

-- ── Debounce (queue + OnUpdate) ────────────────────────────────────
local _pendingWarbandBags = {}
local _scanFrame            = nil   -- frame OnUpdate (créée une fois)
local _scanQueued            = false

local function ExecuteWarbandScan()
    _scanQueued = false
    _scanFrame:SetScript("OnUpdate", nil)

    -- Garde : aucun slot lisible = banque fermée / données pas reçues.
    -- Évaluée au scan réel (frame suivante). Couvre FRAME_HIDE, /vl scan
    -- hors banque, et un scan trop précoce sur FRAME_SHOW.
    local anySlots = false
    for _, bag in ipairs(WARBAND_CONTAINERS) do
        if (C_Container.GetContainerNumSlots(bag) or 0) > 0 then
            anySlots = true
            break
        end
    end
    if not anySlots then
        wipe(_pendingWarbandBags)
        return
    end

    local store = ns.GetStore()
    store.warbandBank = store.warbandBank or {}
    local wb = store.warbandBank

    -- Onglets dirty uniquement ; file vide (appel bare) → scan complet.
    local scanAll = not next(_pendingWarbandBags)
    if scanAll then
        for _, bag in ipairs(WARBAND_CONTAINERS) do _pendingWarbandBags[bag] = true end
    end

    for bag in pairs(_pendingWarbandBags) do
        ns.ScanContainerInto(bag, wb)
    end
    wipe(_pendingWarbandBags)

    ns.InvalidateIndex({ warband = true })

    -- Rafraîchit la tooltip visible (cf. ScanBags).
    if GameTooltip:IsShown() then
        local _, link = GameTooltip:GetItem()
        if link then
            GameTooltip:SetHyperlink(link)
        end
    end
end

local function QueueWarbandScan(bagID)
    if bagID then
        _pendingWarbandBags[bagID] = true
    end
    if not _scanQueued then
        _scanQueued = true
        _scanFrame:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            ExecuteWarbandScan()
        end)
    end
end

-- Crée la frame OnUpdate une seule fois (après PLAYER_LOGIN). Idempotente.
function ns.InitWarbandBankScanner()
    if _scanFrame then return end
    _scanFrame = CreateFrame("Frame", "ViewerLog_WarbandScanFrame")
end

-- ns.ScanWarbandBank()      → scan complet
-- ns.ScanWarbandBank(bagID) → scan partiel de l'onglet modifié (BAG_UPDATE)
function ns.ScanWarbandBank(bagID)
    if not _scanFrame then return end
    if bagID then
        QueueWarbandScan(bagID)
    else
        wipe(_pendingWarbandBags)
        QueueWarbandScan(nil)
    end
end
