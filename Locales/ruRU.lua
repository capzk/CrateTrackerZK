-- CrateTrackerZK - Russian Localization
-- Translator: ZamestoTV

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
localeData["FloatingButtonTooltipLine3"] = "Правый клик — открыть настройки";

localeData["MiniModeTooltipLine1"] = "ПКМ — уведомить";

-- Notifications (Airdrop)
localeData["Enabled"] = "включены";
localeData["Disabled"] = "выключены";
localeData["AirdropDetected"] = "";
localeData["AirdropDetectedManual"] = "";
localeData["NoTimeRecord"] = "[%s] Нет записи о времени!!!";
localeData["TimeRemaining"] = "[%s] До воздушного десанта военных припасов: %s!!!";
localeData["AutoTeamReportMessage"] = "На [%s] до сброса военных припасов осталось: %s!!";

-- Phase Detection Alerts
localeData["PhaseDetectedFirstTime"] = "[%s] Текущий ID фазы: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "[%s] Текущий ID фазы изменён на: |cffffff00%s|r";

-- UI
localeData["MapName"] = "Название карты";
localeData["PhaseID"] = "Текущая фаза";
localeData["LastRefresh"] = "Последний";
localeData["NextRefresh"] = "Следующий";
localeData["Operation"] = "Действия";
localeData["Notify"] = "Уведомить";
localeData["Delete"] = "Удалить";
localeData["Restore"] = "Восстановить";
localeData["NotAcquired"] = "---:---";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d мин %02d сек";

-- Menu Items
localeData["MenuHelp"] = "Справка";
localeData["MenuAbout"] = "О аддоне";

-- Settings Panel
localeData["SettingsPanelTitle"] = "CrateTrackerZK - Настройки";
localeData["SettingsTabSettings"] = "Настройки";
localeData["SettingsSectionControl"] = "Управление аддоном";
localeData["SettingsSectionData"] = "Управление данными";
localeData["SettingsSectionUI"] = "Настройки интерфейса";
localeData["SettingsMiniModeCollapsedRows"] = "Строк после сворачивания мини-режима";
localeData["SettingsAddonToggle"] = "Переключатель аддона";
localeData["SettingsTeamNotify"] = "Уведомления группы";
localeData["SettingsAutoReport"] = "Авто-уведомление";
localeData["SettingsAutoReportInterval"] = "Интервал отправки (сек)";
localeData["SettingsClearAllData"] = "Очистить все данные";
localeData["SettingsClearButton"] = "Очистить";
localeData["SettingsClearDesc"] = "• Сбросит все записи времени и фаз";
localeData["SettingsUIConfigDesc"] = "• Стиль интерфейса настраивается в UiConfig.lua";
localeData["SettingsReloadDesc"] = "• После изменений выполните /reload";
localeData["SettingsToggleOn"] = "Включено";
localeData["SettingsToggleOff"] = "Выключено";
localeData["SettingsClearConfirmText"] = "Очистить все данные и переинициализировать аддон? Действие необратимо.";
localeData["SettingsClearConfirmYes"] = "Подтвердить";
localeData["SettingsClearConfirmNo"] = "Отмена";


-- Airdrop NPC shouts (optional for shout detection and efficiency; can be omitted or left as default)
localeData.AirdropShouts = {
    "Ruffious says: I see some valuable resources in the area! Get ready to grab them!",
    "Ruffious says: Looks like there's treasure nearby. And that means treasure hunters. Watch your back.",
    "Ruffious says: There's a cache of resources nearby. Find it before you have to fight over it!",
    "Ruffious says: Opportunity's knocking! If you've got the mettle, there are valuables waiting to be won.",
};

-- Register this locale
LocaleManager.RegisterLocale("ruRU", localeData);
