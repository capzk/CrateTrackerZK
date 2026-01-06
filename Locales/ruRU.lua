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
localeData["MapNamesCount"] = "Отсутствующие названия карт: %d";
localeData["AirdropCratesCount"] = "Отсутствующие названия ящиков: %d";

-- Notifications
localeData["TeamNotificationStatus"] = "Уведомления в группу %s";
localeData["AirdropDetected"] = "[%s] Обнаружен воздушный десант военных припасов!!!";  -- Автоматическое сообщение (с ключевым словом "Обнаружен")
localeData["AirdropDetectedManual"] = "[%s] Воздушный десант военных припасов!!!";  -- Ручное уведомление (без ключевого слова "Обнаружен")
localeData["NoTimeRecord"] = "[%s] Нет записи о времени!!!";
localeData["TimeRemaining"] = "[%s] До воздушного десанта военных припасов: %s!!!";
localeData["Enabled"] = "включены";
localeData["Disabled"] = "выключены";

-- Phase Detection Alerts
localeData["PhaseDetectedFirstTime"] = "[%s] Текущий ID фазы: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "[%s] Текущий ID фазы изменён на: |cffffff00%s|r";

-- Invalid Airdrop Alerts
localeData["InvalidAirdropNotification"] = "[%s] Обнаружено недействительное событие воздушного десанта, самолёт с припасами существовал слишком короткое время, признано недействительным событием.";

-- Commands
localeData["UnknownCommand"] = "Неизвестная команда: %s";
localeData["ClearingData"] = "Очистка всех данных о времени и фазировании...";
localeData["DataCleared"] = "Все данные очищены, аддон переинициализирован";
localeData["DataClearFailedModule"] = "Очистка данных не удалась: модуль данных не загружен";
localeData["TeamUsage1"] = "Команды уведомлений в группу:";
localeData["TeamUsage2"] = "/ctk team on — Включить уведомления в группу";
localeData["TeamUsage3"] = "/ctk team off — Выключить уведомления в группу";
localeData["HelpTitle"] = "Доступные команды:";
localeData["HelpClear"] = "/ctk clear или /ctk reset — Очистить все данные и переинициализировать аддон";
localeData["HelpTeam"] = "/ctk team on|off — Включить/выключить уведомления в группу";
localeData["HelpHelp"] = "/ctk help — Показать эту справку";
localeData["HelpUpdateWarning"] = "Если после обновления возникнут проблемы, полностью удалите папку аддона и установите заново!!";

localeData["ErrorTimerManagerNotInitialized"] = "Менеджер таймеров не инициализирован";
localeData["ErrorInvalidMapID"] = "Неверный ID карты: %s";
localeData["ErrorTimerStartFailedMapID"] = "Запуск таймера не удался: ID карты=%s";
localeData["ErrorUpdateRefreshTimeFailed"] = "Не удалось обновить время обновления: ID карты=%s";
localeData["ErrorMapTrackerModuleNotLoaded"] = "Модуль MapTracker не загружен";
localeData["ErrorIconDetectorModuleNotLoaded"] = "Модуль IconDetector не загружен";
localeData["ErrorTimerManagerModuleNotLoaded"] = "Модуль TimerManager не загружен";
localeData["ErrorCannotGetMapData"] = "Не удалось получить данные карты, ID карты=%s";
localeData["TimeFormatError"] = "Ошибка формата времени, введите в формате ЧЧ:ММ:СС или ЧЧММСС";
localeData["TimestampError"] = "Не удалось создать корректную метку времени";
localeData["AddonInitializedSuccess"] = "Аддон успешно инициализирован, приятной игры!";

-- UI
localeData["MainPanelTitle"] = "|cff00ff88[CrateTrackerZK]|r";
localeData["InfoButton"] = "Инфо";
localeData["Map"] = "Карта";
localeData["Phase"] = "Фаза";
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
localeData["InputTimeHint"] = "Введите время последнего обновления (ЧЧ:ММ:СС или ЧЧММСС):";
localeData["Confirm"] = "Подтвердить";
localeData["Cancel"] = "Отмена";
localeData["Return"] = "Назад";
localeData["UIFontSize"] = 15;
localeData["HelpText"] = [[Доступные команды:

/ctk help                Показать доступные команды
/ctk team on/off         Включить или выключить уведомления в группу
/ctk clear               Очистить локальные данные и переинициализировать

Совместное использование времени группы всегда включено и синхронизирует время через групповые уведомления. Убедитесь, что у членов группы включены групповые уведомления.

Чтобы получить текущий ID фазирования, просто наведите курсор на любого NPC. ID фазирования будет автоматически определен и отображен на главной панели.
Если после обновления аддона возникнут проблемы, полностью удалите папку аддона и установите заново.]];

-- Menu Items
localeData["MenuHelp"] = "Справка";
localeData["MenuAbout"] = "О аддоне";

-- Map name translations (using map ID as key)
localeData.MapNames = {
    [2248] = "Остров Дорн",      -- 多恩岛
    [2369] = "Остров Сирен",        -- 海妖岛
    [2371] = "К'ареш",            -- 卡雷什
    [2346] = "Нижняя Шахта",         -- 安德麦
    [2215] = "Тайносводье",        -- 陨圣峪
    [2214] = "Гулкие глубины", -- 喧鸣深窟
    [2255] = "Аз-Кахет",         -- 艾基-卡赫特
};

-- Airdrop crate name translations
localeData.AirdropCrateNames = {
    ["WarSupplyCrate"] = "Ящик с военными припасами",
};

-- Airdrop NPC shouts (placeholder uses enUS lines)
localeData.AirdropShouts = {
    "Ruffious says: I see some valuable resources in the area! Get ready to grab them!",
    "Ruffious says: Looks like there's treasure nearby. And that means treasure hunters. Watch your back.",
    "Ruffious says: There's a cache of resources nearby. Find it before you have to fight over it!",
    "Ruffious says: Opportunity's knocking! If you've got the mettle, there are valuables waiting to be won.",
};

-- Register this locale
LocaleManager.RegisterLocale("ruRU", localeData);
