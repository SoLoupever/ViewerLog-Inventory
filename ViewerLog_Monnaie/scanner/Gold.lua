local addonName, ns = ...

-- Scanner or : personnage (charData.gold) et bataillon (store du module).

local function GetAPI()
    local api = _G.ViewerLogAPI
    return api and api.GetCurrentCharData and api
end

-- Au logout, on ne réécrit que si > 0 (évite d'écraser par 0).
function ns.ScanGold(isLogout)
    local api = GetAPI()
    local charData = api and api.GetCurrentCharData()
    if not charData then return end

    local gold = GetMoney()
    if not gold then return end
    if gold > 0 or (not isLogout and gold == 0) then
        charData.gold = gold
    end
end

function ns.UpdateWarbandGold()
    local api = GetAPI()
    if not api or not (C_Bank and C_Bank.FetchDepositedMoney) then return end
    api.GetModuleData("monnaie").warbandGold =
        C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
end

-- ── Accesseurs (exposés depuis Init.lua) ──────────────────────────
function ns.GetGold(charName, realmName)
    local api = _G.ViewerLogAPI
    local d = api and api.GetCharacter and api.GetCharacter(charName, realmName)
    return d and d.gold or 0
end

function ns.GetWarbandGold()
    local api = _G.ViewerLogAPI
    local store = api and api.GetModuleData and api.GetModuleData("monnaie")
    return store and store.warbandGold or 0
end
