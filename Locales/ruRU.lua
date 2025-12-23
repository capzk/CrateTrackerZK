-- CrateTrackerZK - Russian Localization
-- Translator: ZamestoTV
-- This file contains only translation data, no logic
local LocaleManager = BuildEnv("LocaleManager");
if not LocaleManager or not LocaleManager.RegisterLocale then
    -- 记录加载失败（如果 LocaleManager 已存在但 RegisterLocale 不存在）
    if LocaleManager then
        LocaleManager.failedLocales = LocaleManager.failedLocales or {};
        table.insert(LocaleManager.failedLocales, {
            locale = "ruRU",
            reason = "RegisterLocale function not available"
        });
    end
    return; -- Locales.lua not loaded yet
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

-- Notifications
localeData["TeamNotificationStatus"] = "Уведомления в группу %s";
localeData["AirdropDetected"] = "[%s] Обнаружен воздушный десант военных припасов!!!";
localeData["NoTimeRecord"] = "[%s] Нет записи о времени!!!";
localeData["TimeRemaining"] = "[%s] До воздушного десанта военных припасов: %s!!!";
localeData["Enabled"] = "включены";
localeData["Disabled"] = "выключены";

-- Commands
localeData["UnknownCommand"] = "Неизвестная команда: %s";
localeData["DebugEnabled"] = "Отладочная информация включена";
localeData["DebugDisabled"] = "Отладочная информация выключена";
localeData["DebugUsage"] = "Команда отладки: /ctk debug on|off";
localeData["ClearingData"] = "Очистка всех данных о времени и фазировании...";
localeData["DataCleared"] = "Все данные о времени и фазировании очищены, список карт сохранён";
localeData["DataClearFailedEmpty"] = "Очистка данных не удалась: список карт пуст";
localeData["DataClearFailedModule"] = "Очистка данных не удалась: модуль данных не загружен";
localeData["ClearUsage"] = "Команда очистки: /ctk clear или /ctk reset";
localeData["NotificationModuleNotLoaded"] = "Модуль уведомлений не загружен";
localeData["TeamNotificationStatusPrefix"] = "Статус уведомлений в группу: ";
localeData["TeamUsage1"] = "Команды уведомлений в группу:";
localeData["TeamUsage2"] = "/ctk team on — Включить уведомления в группу";
localeData["TeamUsage3"] = "/ctk team off — Выключить уведомления в группу";
localeData["TeamUsage4"] = "/ctk team status — Просмотреть статус уведомлений в группу";
localeData["HelpTitle"] = "Доступные команды:";
localeData["HelpClear"] = "/ctk clear или /ctk reset — Очистить все данные о времени и фазировании (список карт сохраняется)";
localeData["HelpTeam"] = "/ctk team on|off — Включить/выключить уведомления в группу";
localeData["HelpStatus"] = "/ctk team status — Просмотреть статус уведомлений в группу";
localeData["HelpHelp"] = "/ctk help — Показать эту справку";
localeData["HelpUpdateWarning"] = "Если после обновления возникнут проблемы, полностью удалите папку аддона и установите заново!!";

-- Debug Messages
localeData["DebugTimerStarted"] = "Таймер запущен через %s, следующее обновление: %s";
localeData["DebugDetectionSourceManual"] = "Ручной ввод";
localeData["DebugDetectionSourceRefresh"] = "Кнопка обновления";
localeData["DebugDetectionSourceAPI"] = "Интерфейс API";
localeData["DebugDetectionSourceMapIcon"] = "Обнаружение иконки на карте";
localeData["DebugNoRecord"] = "Нет записи";
localeData["DebugCannotGetMapName2"] = "Не удалось получить текущее название карты";
localeData["DebugMapListEmpty"] = "Список карт пуст, пропуск обнаружения иконок на карте";
localeData["DebugMapNotInList"] = "[Обнаружение десанта] Текущая карта не в списке валидных, пропуск обнаружения: %s (Родитель=%s ID карты=%s)";
localeData["DebugMapMatchSuccess"] = "[Обнаружение десанта] Совпадение карты успешно: %s";
localeData["DebugParentMapMatchSuccess"] = "[Обнаружение десанта] Совпадение родительской карты успешно (подзона): %s (Родитель=%s)";
localeData["DebugDetectedMapIconVignette"] = "[Обнаружение десанта] Обнаружена иконка карты (Виньетка): %s (Название ящика с припасами: %s)";
localeData["DebugUpdatedRefreshTime"] = "[Обнаружение десанта] Время обновления изменено: %s следующее обновление=%s";
localeData["DebugUpdateRefreshTimeFailed"] = "[Обнаружение десанта] Изменение времени обновления не удалось: ID карты=%s";
localeData["DebugMapIconNameNotConfigured"] = "[Обнаружение иконки карты] Название ящика с припасами не настроено, пропуск обнаружения";
localeData["DebugAirdropActive"] = "[Обнаружение десанта] Обнаружен ящик, событие десанта активно: %s";
localeData["DebugWaitingForConfirmation"] = "[Обнаружение десанта] Ожидание подтверждения непрерывного обнаружения: %s (интервал=%s секунд)";
localeData["DebugClearedFirstDetectionTime"] = "[Обнаружение десанта] Очищена запись о первом обнаружении (иконка не обнаружена): %s";
localeData["DebugAirdropEnded"] = "[Обнаружение десанта] Иконка не обнаружена, событие десанта завершено: %s";
localeData["DebugFirstDetectionWait"] = "[Обнаружение десанта] Первое обнаружение иконки, ожидание подтверждения непрерывного обнаружения: %s";
localeData["DebugContinuousDetectionConfirmed"] = "[Обнаружение десанта] Непрерывное обнаружение подтверждено, обновление времени и отправка уведомления: %s (интервал=%s секунд)";
localeData["ErrorTimerManagerNotInitialized"] = "Менеджер таймеров не инициализирован";
localeData["ErrorInvalidMapID"] = "Неверный ID карты:";
localeData["ErrorTimerStartFailedMapID"] = "Запуск таймера не удался: ID карты=";
localeData["ErrorInvalidMapIDList"] = "Неверный список ID карт";
localeData["ErrorMapNotFound"] = "Карта не найдена:";
localeData["ErrorInvalidSourceParam"] = "Неверный параметр источника обнаружения";

-- Area Detection Debug Messages
localeData["DebugAreaInvalidInstance"] = "[Валидность области] Область недействительна (подземелье/поле боя/помещение), аддон автоматически приостановлен";
localeData["DebugAreaCannotGetMapID"] = "[Валидность области] Не удалось получить ID карты";
localeData["DebugAreaValid"] = "[Валидность области] Область действительна, аддон включён: %s";
localeData["DebugAreaInvalidNotInList"] = "[Валидность области] Область недействительна (не в списке валидных карт), аддон автоматически приостановлен: %s";

-- Phase Detection Debug Messages
localeData["DebugPhaseDetectionPaused"] = "[Обнаружение фазы] Обнаружение приостановлено, пропуск обнаружения фазы";
localeData["DebugPhaseNoMapID"] = "Не удалось получить текущий ID карты, пропуск обновления информации о фазе";

-- Icon Detection Debug Messages
localeData["DebugIconDetectionStart"] = "[Обнаружение иконки карты] Начало обнаружения, карта=%s, название ящика с припасами=%s";

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
localeData["PluginAnnouncement"] = "|cff00ff88Анонс аддона|r";
localeData["PluginIntro"] = "|cff00ff88Введение в аддон|r";
-- UI Font Size Configuration (numeric type)
localeData["UIFontSize"] = 15;

-- Menu Items
localeData["MenuHelp"] = "Справка";
localeData["MenuAbout"] = "О аддоне";
localeData["MenuSettings"] = "Настройки";

-- ============================================================================
-- 地图名称翻译映射表（使用代号系统，完全语言无关）
-- ============================================================================
-- 格式：[地图代号] = "俄语名称"
-- 注意：添加新语言只需创建新的本地化文件，添加代号到名称的映射即可
-- 注意：以下地图名称需要翻译者根据游戏内实际名称进行翻译
localeData.MapNames = {
    ["MAP_001"] = "Isle of Dorn",           -- 需要翻译
    ["MAP_002"] = "K'aresh",                -- 需要翻译
    ["MAP_003"] = "Hallowfall",             -- 需要翻译
    ["MAP_004"] = "Azj-Kahet",              -- 需要翻译
    ["MAP_005"] = "Undermine",              -- 需要翻译
    ["MAP_006"] = "The Ringing Deeps",      -- 需要翻译
    ["MAP_007"] = "Siren Isle",             -- 需要翻译
};

-- ============================================================================
-- 空投箱子名称本地化
-- ============================================================================
localeData.AirdropCrateNames = {
    ["AIRDROP_CRATE_001"] = "Ящик с военными припасами",
};

-- Help and About Content
localeData["AnnouncementText"] = [[
Автор: capzk
Обратная связь: capzk@itcat.dev


]];

localeData["IntroductionText"] = [[
• /ctk team on — Включить уведомления в группу
• /ctk team off — Выключить уведомления в группу
• /ctk clear — Очистить данные




Спасибо за использование!]];

-- Register this locale
LocaleManager.RegisterLocale("ruRU", localeData);
