-- CrateTrackerZK - Spanish Localization (esMX)
local LocaleManager = BuildEnv("LocaleManager");
if not LocaleManager or not LocaleManager.RegisterLocale then
    if LocaleManager then
        LocaleManager.failedLocales = LocaleManager.failedLocales or {};
        table.insert(LocaleManager.failedLocales, {
            locale = "esMX",
            reason = "RegisterLocale function not available"
        });
    end
    return;
end

local localeData = {};

-- Floating Button
localeData["FloatingButtonTooltipLine3"] = "Clic-derecho para abrir los ajustes";

-- Notifications (Airdrop)
localeData["Enabled"] = "Notificaciones de equipo activadas";
localeData["Disabled"] = "Notificaciones de equipo desactivadas";
localeData["AirdropDetected"] = "[%s]¡Suministros de guerra detectados!!!";
localeData["AirdropDetectedManual"] = "[%s]¡Suministros de guerra!!!";
localeData["NoTimeRecord"] = "[%s]¡Sin registro de tiempo!!!";
localeData["TimeRemaining"] = "[%s]Suministros de guerra en: %s!!!";
localeData["AutoTeamReportMessage"] = "Actual[%s]Suministros de guerra en: %s!!";
localeData["SharedPhaseSyncApplied"] = "Se obtuvo la informacion compartida mas reciente del lanzamiento de suministros para la fase actual en [%s].";
localeData["PhaseTeamAlertMessage"] = "La fase actual en %s cambio: %s ➡ %s";
localeData["UnknownPhaseValue"] = "desconocida";

-- Phase Detection Alerts
localeData["PhaseDetectedFirstTime"] = "[%s] Fase actual: |cffffff00%s|r";
localeData["InstanceChangedTo"] = "[%s] La fase actual cambio a: |cffffff00%s|r";

-- UI
localeData["MapName"] = "Nombre del mapa";
localeData["PhaseID"] = "Fase actual";
localeData["LastRefresh"] = "Ultima actualizacion";
localeData["NextRefresh"] = "Proxima actualizacion";
localeData["NotAcquired"] = "---:---";
localeData["NoRecord"] = "--:--";
localeData["MinuteSecond"] = "%d min %02d seg";

-- Menu Items
localeData["MenuHelp"] = "Ayuda";
localeData["MenuAbout"] = "Acerca de";

-- Settings Panel
localeData["SettingsSectionExpansion"] = "Ajustes de version";
localeData["SettingsSectionControl"] = "Control del Addon";
localeData["SettingsSectionData"] = "Gestion de datos";
localeData["SettingsSectionUI"] = "Ajustes de IU";
localeData["SettingsMainPage"] = "Ajustes principales";
localeData["SettingsMessages"] = "Ajustes de mensajes";
localeData["SettingsMapSelection"] = "Seleccion de mapa";
localeData["SettingsThemeSwitch"] = "Tema";
localeData["SettingsAddonToggle"] = "Alternar Addon";
localeData["SettingsLeaderMode"] = "Modo de lider";
localeData["SettingsLeaderModeTooltip"] = "Cuando esta activado, las notificaciones visibles de suministros y los reportes automaticos en banda preferiran aviso de banda; si no tienes permiso, volveran automaticamente al chat de banda normal.";
localeData["SettingsTeamNotify"] = "Notificaciones de equipo";
localeData["SettingsSoundAlert"] = "Alerta de sonido";
localeData["SettingsAutoReport"] = "Notificar automaticamente";
localeData["SettingsAutoReportInterval"] = "Intervalo de reporte (seg)";
localeData["SettingsClearButton"] = "Borrar datos locales";
localeData["SettingsToggleOn"] = "Activado";
localeData["SettingsToggleOff"] = "Desactivado";
localeData["SettingsClearConfirmText"] = "¿Borrar todos los datos y reiniciar? Esta accion no se puede deshacer.";
localeData["SettingsClearConfirmYes"] = "Confirmar";
localeData["SettingsClearConfirmNo"] = "Cancelar";

-- Airdrop NPC shouts
localeData.AirdropShouts = {
    --11.0
    "Ruffious dice: ¡La oportunidad llama a la puerta! Si tienes agallas, hay objetos de valor esperando a ser ganados.",
    "Ruffious dice: ¡Veo recursos valiosos en la zona! ¡Preparense para tomarlos!",
    "Ruffious dice: Hay un alijo de recursos cerca. ¡Encuentrenlo antes de que tengan que luchar por el!",
    "Ruffious dice: Parece que hay un tesoro cerca. Y eso significa cazadores de tesoros. Vigila tu espalda.",
    --12.0
    "Ziadan dice: Aprovecha la ventaja inicial y obten tu botin.",
    "Ziadan dice: Eso parece un tesoro a lo lejos. ¡No pierdas esta oportunidad!",
    "Vidious dice: ¡Mantente atento a las oportunidades de botin cuando surjan, como ahora!",
    "Vidious dice: Te gustan las mercancias, ¿verdad? Entonces encuentralas.",
};

localeData["SettingsHelpText"] = [[
Guia de uso

La cuenta regresiva de la IU principal admite el envio de mensajes al hacer clic:
Clic izquierdo: envia "[Mapa] Suministros de guerra en: Tiempo"
Clic derecho: envia "Actual [Mapa] Suministros de guerra en: Tiempo"

Opciones de la pagina de Ajustes de Mensajes:
Ajustes de Mensajes: controla el comportamiento del envio de mensajes manual y automatico
Modo de lider: cuando esta activado, las notificaciones visibles de suministros y los reportes automaticos en banda preferiran aviso de banda; sin permiso volveran al chat de banda normal
Notificaciones de equipo: cuando esta activado, los mensajes se envian al chat de grupo o banda
Alerta de sonido: cuando esta activado, se reproduce un sonido al detectar un suministro
Notificar automaticamente: cuando esta activado, envia automaticamente la cuenta regresiva del suministro mas cercano en el intervalo configurado
Intervalo de reporte (seg): establece el intervalo para los mensajes automaticos de cuenta regresiva
]];

-- Register this locale
LocaleManager.RegisterLocale("esMX", localeData);
