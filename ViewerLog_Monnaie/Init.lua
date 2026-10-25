local addonName, ns = ...

-- Init ViewerLog_Monnaie : dépendance optionnelle de ViewerLog.
-- Écoute CURRENCY_DISPLAY_UPDATE et l'or ; déclenche scanner/Currency.lua et Gold.lua.
-- ns et event frame propres, flag logout local → dépendance autonome ;
-- partage seulement ViewerLogAPI.

local frame = CreateFrame("Frame", "ViewerLog_Monnaie_EventFrame")
local _isLoggingOut = false

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("ACCOUNT_MONEY")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        _isLoggingOut = false
        ns.ScanGold()
        -- Scan initial différé : garantit des données même pour un
        -- personnage qui ne gagne aucune monnaie cette session.
        C_Timer.After(5, function() ns.ScanCurrencies() end)

    elseif event == "PLAYER_LOGOUT"
        or event == "PLAYER_LEAVING_WORLD" then
        _isLoggingOut = true
        ns.ScanGold(true)
        ns.ScanCurrencies()

    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        -- Peut se déclencher en rafale (plusieurs monnaies gagnées
        -- d'un coup) ; le debounce de 1.5 s interne à Currency.lua
        -- absorbe la rafale.
        if not _isLoggingOut then
            ns.ScanCurrencies(true)
        end

    elseif event == "PLAYER_MONEY" then
        ns.ScanGold()

    elseif event == "ACCOUNT_MONEY" then
        ns.UpdateWarbandGold()

    -- Banque de bataillon ouverte : rafraîchit l'or déposé.
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local iType = ...
        if iType == Enum.PlayerInteractionType.AccountBank then
            C_Timer.After(1.0, ns.UpdateWarbandGold)
        end
    end
end)

-- ── Exposition sur l'API partagée ───────────────────────────────────
-- _G.ViewerLogAPI existe déjà (core chargé avant, via RequiredDeps).
-- ScanCurrencies / GetCurrencies sont définies entièrement ici : le core
-- ignore les monnaies, désinstaller ce dossier retire la fonctionnalité.
if _G.ViewerLogAPI then
    _G.ViewerLogAPI.ScanCurrencies = ns.ScanCurrencies
    _G.ViewerLogAPI.GetCurrencies  = ns.GetCurrencies
    _G.ViewerLogAPI.GetGold        = ns.GetGold
    _G.ViewerLogAPI.GetWarbandGold = ns.GetWarbandGold
end
