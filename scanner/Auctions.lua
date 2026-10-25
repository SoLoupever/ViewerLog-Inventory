local addonName, ns = ...

-- Scanner enchères (hôtel des ventes).
-- Lisible uniquement HV ouvert, après QueryOwnedAuctions : Init.lua
-- tient l'état _auctionOpen et n'appelle ces fonctions que dans ce cas.
-- charData.auctions = { [itemID] = quantité }, réécrit EN ENTIER à chaque
-- scan (ventes / annulations reflétées). Enchères vendues (status Sold)
-- ignorées : l'objet n'est plus possédé.
-- Liste incomplète (HasFullOwnedAuctionResults = false) : pas d'écriture.
-- OWNED_AUCTIONS_UPDATED arrive en rafale : debounce comme les autres scanners.

local ACTIVE = Enum.AuctionStatus.Active

local _scanQueued  = false
local _queryQueued = false

local function ExecuteAuctionScan()
    _scanQueued = false

    if not C_AuctionHouse.HasFullOwnedAuctionResults() then return end

    local charData = ns.GetCurrentCharData()
    if not charData then return end

    local auctions
    for i = 1, C_AuctionHouse.GetNumOwnedAuctions() do
        local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
        if info and info.status == ACTIVE then
            auctions = auctions or {}
            local id = info.itemKey.itemID
            auctions[id] = (auctions[id] or 0) + info.quantity
        end
    end

    charData.auctions = auctions
    ns.InvalidateIndex({ chars = true })

    -- Rafraîchit la tooltip visible (cf. ScanMail).
    if GameTooltip:IsShown() then
        local _, link = GameTooltip:GetItem()
        if link then
            GameTooltip:SetHyperlink(link)
        end
    end
end

-- Appelé sur OWNED_AUCTIONS_UPDATED.
function ns.ScanAuctions()
    if _scanQueued then return end
    _scanQueued = true
    C_Timer.After(0.5, ExecuteAuctionScan)
end

-- Demande la liste au serveur ; la réponse arrive via OWNED_AUCTIONS_UPDATED.
function ns.QueryAuctions()
    if _queryQueued then return end
    _queryQueued = true
    C_Timer.After(0.5, function()
        _queryQueued = false
        C_AuctionHouse.QueryOwnedAuctions({})
    end)
end
