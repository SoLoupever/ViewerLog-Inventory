local addonName, ns = ...

-- API publique des objets, posée sur _G.ViewerLogAPI. Absente si le module
-- n'est pas installé : les consommateurs testent sa présence.

local pub = ns.vl

function ns.GetBags(charName, realmName)
    local d = pub.GetCharacter(charName, realmName)
    return d and d.bags
end

function ns.GetBank(charName, realmName)
    local d = pub.GetCharacter(charName, realmName)
    return d and d.bank
end

function ns.GetWarbandBank()
    return ns.GetStore().warbandBank
end

-- { count, expiresAt } — expiresAt en epoch (précision jour, cf. scanner
-- Mail.lua) ; nil si aucun courrier connu. Consommé par ViewerLog_Reminder.
function ns.GetMailInfo(charName, realmName)
    local d = pub.GetCharacter(charName, realmName)
    if not d or not d.mailExpiresAt then return nil end
    return { count = d.mail and #d.mail or 0, expiresAt = d.mailExpiresAt }
end

-- Infos de possession pour un itemID (index pré-construit, sans rebuild).
function ns.GetInventoryInfo(itemID)
    return ns.tooltipIndex[itemID]
end

function ns.RefreshIndex()
    ns.InvalidateIndexAll()
end

-- Scan manuel (/vl scan).
function ns.ScanItems()
    ns.ScanBags("MANUAL")
    ns.ScanBank()
    ns.ScanWarbandBank()
end

pub.GetBags             = ns.GetBags
pub.GetBank             = ns.GetBank
pub.GetWarbandBank      = ns.GetWarbandBank
pub.GetMailInfo         = ns.GetMailInfo
pub.GetInventoryInfo    = ns.GetInventoryInfo
pub.GetTooltipEntry     = ns.GetTooltipEntry
pub.RefreshIndex        = ns.RefreshIndex
pub.InvalidateIndex     = ns.InvalidateIndex
pub.RegisterIndexSource = ns.RegisterIndexSource
pub.ScanItems           = ns.ScanItems
