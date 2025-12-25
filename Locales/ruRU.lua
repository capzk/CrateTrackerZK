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

-- General
localeData["AddonLoaded"] = "Аддон загружен, приятной игры!";
localeData["HelpCommandHint"] = "Используйте |cffffcc00/ctk help|r для просмотра справки";
localeData["CrateTrackerZK"] = "CrateTrackerZK";

-- Floating Button
localeData["FloatingButtonTooltipTitle"] = "CrateTrackerZK";
localeData["FloatingButtonTooltipLine1"] = "Клик — открыть/закрыть панель отслеживания";
localeData["FloatingButtonTooltipLine2"] = "Перетащите, чтобы переместить кнопку";

-- Phase Detection
localeData["NoInstanceAcquiredHint"] = "ID фазы не получен. Наведите курсор на любого НПС, чтобы получить текущий ID фазы";
localeData["CurrentInstanceID"] = "Текущий ID фазы: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "ID фазы карты [|cffffcc00%s|r] изменён на: |cffffff00%s|r";

-- Message Prefix
localeData["Prefix"] = "|cff00ff88[CrateTrackerZK]|r ";

-- Errors/Hints
localeData["CommandModuleNotLoaded"] = "Модуль команд не загружен, пожалуйста, перезагрузите аддон";
localeData["LocalizationWarning"] = "Предупреждение";
localeData["LocalizationCritical"] = "Критично";
localeData["LocalizationMissingTranslation"] = "[Локализация %s] Отсутствует перевод: %s.%s";
localeData["LocalizationFallbackWarning"] = "Предупреждение: Файл локализации для %s не найден, используется %s";
localeData["LocalizationNoLocaleError"] = "Ошибка: Не найден доступный файл локализации";
localeData["LocalizationMissingTranslationsWarning"] = "Предупреждение: Найдено %d отсутствующих критических переводов (%s)";
localeData["LocalizationMissingMapNames"] = "Отсутствующие названия карт: %s";
localeData["LocalizationMissingCrateNames"] = "Отсутствующие названия ящиков с припасами: %s";
localeData["LocalizationFailedLocalesWarning"] = "Предупреждение: %d файлов локализации не удалось загрузить";
localeData["MapNamesCount"] = "Названия карт: %d";
localeData["AirdropCratesCount"] = "Ящики с припасами: %d";

-- Notifications
localeData["TeamNotificationStatus"] = "Уведомления в группу %s";
localeData["AirdropDetected"] = "[%s] Обнаружен воздушный десант военных припасов!!!";
localeData["NoTimeRecord"] = "[%s] Нет записи о времени!!!";
localeData["TimeRemaining"] = "[%s] До воздушного десанта военных припасов: %s!!!";
localeData["Enabled"] = "включены";
localeData["Disabled"] = "выключены";

-- Commands
localeData["UnknownCommand"] = "Неизвестная команда: %s";
localeData["ClearingData"] = "Очистка всех данных о времени и фазировании...";
localeData["DataCleared"] = "Все данные о времени и фазировании очищены, список карт сохранён";
localeData["DataClearFailedEmpty"] = "Очистка данных не удалась: список карт пуст";
localeData["DataClearFailedModule"] = "Очистка данных не удалась: модуль данных не загружен";
localeData["ClearUsage"] = "Команда очистки: /ctk clear или /ctk reset";
localeData["NotificationModuleNotLoaded"] = "Модуль уведомлений не загружен";
localeData["TeamUsage1"] = "Команды уведомлений в группу:";
localeData["TeamUsage2"] = "/ctk team on — Включить уведомления в группу";
localeData["TeamUsage3"] = "/ctk team off — Выключить уведомления в группу";
localeData["HelpTitle"] = "Доступные команды:";
localeData["HelpClear"] = "/ctk clear или /ctk reset — Очистить все данные о времени и фазировании (список карт сохраняется)";
localeData["HelpTeam"] = "/ctk team on|off — Включить/выключить уведомления в группу";
localeData["HelpHelp"] = "/ctk help — Показать эту справку";
localeData["HelpUpdateWarning"] = "Если после обновления возникнут проблемы, полностью удалите папку аддона и установите заново!!";

localeData["ErrorTimerManagerNotInitialized"] = "Менеджер таймеров не инициализирован";
localeData["ErrorInvalidMapID"] = "Неверный ID карты:";
localeData["ErrorTimerStartFailedMapID"] = "Запуск таймера не удался: ID карты=";
localeData["ErrorInvalidMapIDList"] = "Неверный список ID карт";
localeData["ErrorMapNotFound"] = "Карта не найдена:";
localeData["ErrorInvalidSourceParam"] = "Неверный параметр источника обнаружения";

-- UI
localeData["MainPanelTitle"] = "|cff00ff88[CrateTrackerZK]|r";
localeData["InfoButton"] = "Инфо";
localeData["AnnouncementButton"] = "Анонс";
localeData["IntroButton"] = "Введение";
localeData["Map"] = "Карта";
localeData["Phase"] = "Фаза";
localeData["LastRefresh"] = "Последнее обновление";
localeData["NextRefresh"] = "Следующее обновление";
localeData["Operation"] = "Операция";
localeData["Refresh"] = "Обновить";
localeData["Notify"] = "Уведомить";
localeData["NotAcquired"] = "Не получено";
localeData["NoRecord"] = "Нет записи";
localeData["MinuteSecond"] = "%dм%02dс";
localeData["InputTimeHint"] = "Введите время последнего обновления (ЧЧ:ММ:СС или ЧЧММСС):";
localeData["Confirm"] = "Подтвердить";
localeData["Cancel"] = "Отмена";
localeData["TimeFormatError"] = "Ошибка формата времени, введите в формате ЧЧ:ММ:СС или ЧЧММСС";
localeData["TimestampError"] = "Не удалось создать корректную метку времени";
localeData["InfoModuleNotLoaded"] = "Модуль информации не загружен";
localeData["DataModuleNotLoaded"] = "Модуль данных не загружен";
localeData["TimerManagerNotInitialized"] = "Менеджер таймеров не инициализирован";
localeData["Return"] = "Назад";
localeData["UIFontSize"] = 15;

-- Menu Items
localeData["MenuHelp"] = "Справка";
localeData["MenuAbout"] = "О аддоне";
localeData["MenuSettings"] = "Настройки";

-- Map name translations (using map ID as key)
localeData.MapNames = {
    [2248] = "Isle of Dorn",      -- 多恩岛
    [2369] = "Siren Isle",        -- 海妖岛
    [2371] = "K'aresh",            -- 卡雷什
    [2346] = "Undermine",         -- 安德麦
    [2215] = "Hallowfall",        -- 陨圣峪
    [2214] = "The Ringing Deeps", -- 喧鸣深窟
    [2255] = "Azj-Kahet",         -- 艾基-卡赫特
};

-- Airdrop crate name translations
localeData.AirdropCrateNames = {
    ["WarSupplyCrate"] = "Ящик с военными припасами",
};

-- Register this locale
LocaleManager.RegisterLocale("ruRU", localeData);

