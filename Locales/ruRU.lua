-- CrateTrackerZK - Russian Localization
-- Translator: ZamestoTV
-- This file contains only translation data, no logic
local LocaleManager = BuildEnv("LocaleManager");
if not LocaleManager or not LocaleManager.RegisterLocale then
    if LocaleManager then
        LocaleManager.failedLocales = LocaleManager.failedLocales or {};
        table.insert(LocaleManager.failedLocales, {
            locale = "ruRU",
            reason = "RegisterLocale function not available"
        });
    end
    return;
end

local localeData = {};

-- Floating Button
localeData["FloatingButtonTooltipLine1"] = "Клик — открыть/закрыть панель отслеживания";
localeData["FloatingButtonTooltipLine2"] = "Перетащите, чтобы переместить кнопку";

-- Notifications (Airdrop)
localeData["TeamNotificationStatus"] = "Уведомления в группу %s";
localeData["Enabled"] = "включены";
localeData["Disabled"] = "выключены";
localeData["AirdropDetected"] = "";
localeData["AirdropDetectedManual"] = "";
localeData["NoTimeRecord"] = "[%s] Нет записи о времени!!!";
localeData["TimeRemaining"] = "[%s] До воздушного десанта военных припасов: %s!!!";

-- Phase Detection Alerts
localeData["PhaseDetectedFirstTime"] = "[%s] Текущий ID фазы: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "[%s] Текущий ID фазы изменён на: |cffffff00%s|r";

-- Commands
localeData["UnknownCommand"] = "Неизвестная команда: %s";
localeData["DataCleared"] = "Все данные очищены, аддон переинициализирован";
localeData["TeamUsage1"] = "Команды уведомлений в группу:";
localeData["TeamUsage2"] = "/ctk team on — Включить уведомления в группу";
localeData["TeamUsage3"] = "/ctk team off — Выключить уведомления в группу";

-- UI
localeData["MapName"] = "Название карты";
localeData["PhaseID"] = "ID фазы";
localeData["LastRefresh"] = "Последний";
localeData["NextRefresh"] = "Следующий";
localeData["Operation"] = "Действия";
localeData["Refresh"] = "Обновить";
localeData["Notify"] = "Уведомить";
localeData["Delete"] = "Удалить";
localeData["Restore"] = "Восстановить";
localeData["NotAcquired"] = "N/A";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%dм%02dс";

-- Menu Items
localeData["MenuHelp"] = "Справка";
localeData["MenuAbout"] = "О аддоне";


-- Airdrop NPC shouts (placeholder uses enUS lines)
localeData.AirdropShouts = {
    "Ruffious says: I see some valuable resources in the area! Get ready to grab them!",
    "Ruffious says: Looks like there's treasure nearby. And that means treasure hunters. Watch your back.",
    "Ruffious says: There's a cache of resources nearby. Find it before you have to fight over it!",
    "Ruffious says: Opportunity's knocking! If you've got the mettle, there are valuables waiting to be won.",
};

-- Register this locale
LocaleManager.RegisterLocale("ruRU", localeData);
