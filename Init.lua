local addonName, ns = ...

-- Init Items : événements du jeu → scanners d'objets.
-- Frame propre ; partage uniquement _G.ViewerLogAPI avec le noyau.

local frame = CreateFrame("Frame", "ViewerLog_Items_EventFrame")

-- bagID valides pour charData.bags (sacs perso). Banque : ns.BANK_BAG_SET.
local VALID_BAGS = { [0]=true,[1]=true,[2]=true,[3]=true,[4]=true,[5]=true }

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("BAG_UPDATE")             -- bagID précis → routage sac/banque/bataillon
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED") -- onglets banque TWW
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
frame:RegisterEvent("MAIL_SHOW")
frame:RegisterEvent("MAIL_INBOX_UPDATE")
frame:RegisterEvent("MAIL_CLOSED")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:RegisterEvent("OWNED_AUCTIONS_UPDATED")
frame:RegisterEvent("AUCTION_CANCELED")
frame:RegisterEvent("AUCTION_HOUSE_AUCTION_CREATED")

-- ── États "ouvert" ─────────────────────────────────────────────────
-- Hors banque / courrier / HV, les données ne sont pas lisibles : un scan
-- écraserait l'existant.
local _bankOpen        = false
local _warbandBankOpen = false
local _mailOpen        = false
local _auctionOpen     = false

-- Nettoyage : une fois par session (ENTERING_WORLD fire à chaque écran de
-- chargement).
local _sessionReady = false

-- Retire les bagID mal indexés (anciennes versions rangeaient de la banque
-- dans charData.bags).
local function CleanupBagIDs()
    ns.vl.ForEachCharacter(function(_, _, charData)
        if charData.bags then
            for bag in pairs(charData.bags) do
                if not VALID_BAGS[bag] then charData.bags[bag] = nil end
            end
        end
        if charData.bank then
            for bag in pairs(charData.bank) do
                if not ns.BANK_BAG_SET[bag] then charData.bank[bag] = nil end
            end
        end
    end)
end

-- Suppression d'un personnage : l'index doit être reconstruit.
ns.vl.RegisterCallback("CHARACTER_DELETED", function()
    ns.InvalidateIndex({ chars = true })
end)

frame:SetScript("OnEvent", function(self, event, ...)

    if event == "PLAYER_LOGIN" then
        -- Un Init idempotent par scanner (crée sa frame OnUpdate).
        ns.InitBagScanner()
        ns.InitBankScanner()
        ns.InitWarbandBankScanner()
        ns.InitMailScanner()

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- PLAYER_LEAVING_WORLD fire à chaque écran de chargement : reset du
        -- flag avant ScanBags pour un scan normal.
        ns._isLoggingOut = false

        if not _sessionReady then
            _sessionReady = true
            CleanupBagIDs()
        end
        ns.ScanBags("ENTERING_WORLD")

    elseif event == "PLAYER_LOGOUT"
        or event == "PLAYER_LEAVING_WORLD" then
        ns._isLoggingOut = true
        ns.ScanBags("LOGOUT")

    -- bagID exact → bon scanner (chacun a son debounce interne).
    elseif event == "BAG_UPDATE" then
        local bagID = ...
        if not ns._isLoggingOut then
            if ns.IsWarbandBag(bagID) then
                if _warbandBankOpen then ns.ScanWarbandBank(bagID) end
            elseif ns.IsBankBag(bagID) then
                if _bankOpen then ns.ScanBank(bagID) end
            else
                ns.ScanBags("BAG_UPDATE", bagID)
            end
        end

    -- Ouverture du banquier (perso + bataillon simultanés en TWW).
    elseif event == "BANKFRAME_OPENED" then
        _bankOpen = true
        ns.ScanBank()
        if C_Bank and C_Bank.FetchBankLockedReason and
           C_Bank.FetchBankLockedReason(Enum.BankType.Account) == nil then
            _warbandBankOpen = true
            C_Timer.After(1.0, function()
                if _warbandBankOpen then ns.ScanWarbandBank() end
            end)
        end

    elseif event == "BANKFRAME_CLOSED" then
        _bankOpen = false
        ns.ScanBank()
        _warbandBankOpen = false

    -- BAG_UPDATE ne couvre pas toujours les onglets CharacterBankTab.
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if _bankOpen and not ns._isLoggingOut then ns.ScanBank() end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local iType = ...
        if iType == Enum.PlayerInteractionType.AccountBank then
            _warbandBankOpen = true
            -- Données différées après FRAME_SHOW : timer de secours.
            -- ScanWarbandBank sort seul si les slots ne sont pas dispo.
            C_Timer.After(1.0, function()
                if _warbandBankOpen then ns.ScanWarbandBank() end
            end)
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local iType = ...
        if iType == Enum.PlayerInteractionType.AccountBank then
            _warbandBankOpen = false
        end

    -- Courrier : MAIL_INBOX_UPDATE arrive en rafale (debounce dans le scanner).
    elseif event == "MAIL_SHOW" then
        _mailOpen = true
        ns.ScanMail()

    elseif event == "MAIL_INBOX_UPDATE" then
        if _mailOpen and not ns._isLoggingOut then ns.ScanMail() end

    elseif event == "MAIL_CLOSED" then
        _mailOpen = false

    -- Enchères : HV ouvert → on demande la liste, OWNED_AUCTIONS_UPDATED la livre.
    elseif event == "AUCTION_HOUSE_SHOW" then
        _auctionOpen = true
        ns.QueryAuctions()

    elseif event == "AUCTION_HOUSE_CLOSED" then
        _auctionOpen = false

    elseif event == "OWNED_AUCTIONS_UPDATED" then
        if _auctionOpen and not ns._isLoggingOut then ns.ScanAuctions() end

    elseif event == "AUCTION_CANCELED"
        or event == "AUCTION_HOUSE_AUCTION_CREATED" then
        if _auctionOpen then ns.QueryAuctions() end
    end
end)
