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
localeData["FloatingButtonTooltipLine3"] = "ПКМ - открыть настройки";

-- Notifications (Airdrop)
localeData["Enabled"] = "включены";
localeData["Disabled"] = "выключены";
localeData["AirdropDetected"] = "[%s] Обнаружен сброс военных припасов!!!";
localeData["AirdropDetectedManual"] = "[%s] Сброс военных припасов!!!";
localeData["NoTimeRecord"] = "[%s] Нет записи о времени!!!";
localeData["TimeRemaining"] = "[%s] До воздушного десанта военных припасов: %s!!!";
localeData["AutoTeamReportMessage"] = "На [%s] до сброса военных припасов осталось: %s!!";

-- Phase Detection Alerts
localeData["PhaseDetectedFirstTime"] = "[%s] Текущая фаза: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "[%s] Текущая фаза изменена на: |cffffff00%s|r";

-- UI
localeData["MapName"] = "Название карты";
localeData["PhaseID"] = "Текущая фаза";
localeData["LastRefresh"] = "Последний";
localeData["NextRefresh"] = "Следующий";
localeData["NotAcquired"] = "---:---";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d мин %02d сек";

-- Menu Items
localeData["MenuHelp"] = "Справка";
localeData["MenuAbout"] = "О аддоне";

-- Settings Panel
localeData["SettingsSectionExpansion"] = "Настройки версии";
localeData["SettingsSectionControl"] = "Управление аддоном";
localeData["SettingsSectionData"] = "Управление данными";
localeData["SettingsSectionUI"] = "Настройки интерфейса";
localeData["SettingsMainPage"] = "Основные настройки";
localeData["SettingsMessages"] = "Настройки сообщений";
localeData["SettingsMapList"] = "Список карт";
localeData["SettingsExpansionVersion"] = "Версия игры";
localeData["SettingsThemeSwitch"] = "Тема";
localeData["SettingsAddonToggle"] = "Переключатель аддона";
localeData["SettingsTeamNotify"] = "Уведомления группы";
localeData["SettingsSoundAlert"] = "Звуковое уведомление";
localeData["SettingsAutoReport"] = "Авто-уведомление";
localeData["SettingsAutoReportInterval"] = "Интервал отправки (сек)";
localeData["SettingsClearButton"] = "Очистить локальные данные";
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

localeData["SettingsHelpText"] = [[
Руководство по использованию

1. Таймер обратного отсчета на главном окне поддерживает отправку сообщений по клику мышью:
   ЛКМ: отправляет сообщение "[Карта] War Supplies airdrop in: Время"
   ПКМ: отправляет сообщение "Current [Карта] War Supplies airdrop in: Время"

2. Параметры страницы настроек сообщений:
   Настройки сообщений: управляют ручной и автоматической отправкой сообщений
   Уведомления группы: при включении сообщение отправляется в группу, рейд или чат подземелья
   Звуковое уведомление: при включении воспроизводится звук при обнаружении сброса
   Авто-уведомление: при включении автоматически отправляет ближайший таймер сброса через заданный интервал
   Интервал отправки (сек): задает интервал автоматической отправки сообщений
]];

-- Register this locale
LocaleManager.RegisterLocale("ruRU", localeData);
