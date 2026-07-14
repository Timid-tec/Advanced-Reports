/*
 * Advanced Reports
 *
 * Copyright (C) 2021-2026 Timid
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

// SteamWorks is optional. The database and menus continue to work without it.
#undef REQUIRE_EXTENSIONS
#include <SteamWorks>

#define PLUGIN_VERSION "4.3.0"
#define DATABASE_CONFIG "advancedreports"
#define REPORT_TABLE "aReports"
#define CHAT_PREFIX "\x08[\x0EAdvReports\x08]\x01"

#define MAX_ADDRESS_LENGTH 128
#define MAX_AUTH_LENGTH 32
#define MAX_QUERY_LENGTH 4096
#define MAX_REASON_LENGTH 256
#define MAX_WEBHOOK_LENGTH 512

static const char MYSQL_CREATE_TABLE[] =
    "CREATE TABLE IF NOT EXISTS `" ... REPORT_TABLE ... "` ("
    ... "`Id` int unsigned NOT NULL AUTO_INCREMENT,"
    ... "`playername` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,"
    ... "`steam` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,"
    ... "`reason` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,"
    ... "`reporter` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,"
    ... "`date` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,"
    ... "`serverip` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,"
    ... "PRIMARY KEY (`Id`), UNIQUE KEY `steam` (`steam`)"
    ... ") ENGINE=InnoDB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;";

static const char MYSQL_MIGRATE_TABLE[] =
    "ALTER TABLE `" ... REPORT_TABLE ... "` "
    ... "MODIFY `playername` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,"
    ... "MODIFY `steam` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,"
    ... "MODIFY `reason` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,"
    ... "MODIFY `reporter` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,"
    ... "MODIFY `serverip` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL;";

public Plugin myinfo =
{
    name = "Advanced Reports",
    author = "Timid",
    description = "In-game player reports with SQL and optional Discord notifications",
    version = PLUGIN_VERSION,
    url = "https://github.com/Timid-tec/Advanced-Reports"
};

// Optional native supplied by server_redirect.smx.
native void RedirectClient(int client, char[] address, any ...);

Database g_Database = null;
bool g_DatabaseReady = false;
ArrayList g_ReportReasons = null;

ConVar g_CvarDiscordEnabled;
ConVar g_CvarDiscordWebhook;
ConVar g_CvarPublicAddress;
ConVar g_CvarReportCooldown;

bool g_DiscordEnabled = false;
char g_DiscordWebhook[MAX_WEBHOOK_LENGTH];
char g_PublicAddress[MAX_ADDRESS_LENGTH];
float g_ReportCooldown = 60.0;
bool g_MissingSteamWorksNoticeShown = false;

int g_SelectedTargetUserId[MAXPLAYERS + 1];
float g_NextReportAllowed[MAXPLAYERS + 1];
char g_AdminTargetName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
char g_AdminTargetAuth[MAXPLAYERS + 1][MAX_AUTH_LENGTH];
char g_AdminServerAddress[MAXPLAYERS + 1][MAX_ADDRESS_LENGTH];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errorMax)
{
    MarkNativeAsOptional("RedirectClient");
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_CvarDiscordEnabled = CreateConVar(
        "sm_advreports_discord",
        "0",
        "Send successful reports to Discord. Requires SteamWorks and a webhook URL.",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );
    g_CvarDiscordWebhook = CreateConVar(
        "sm_advreports_webhook",
        "",
        "Discord webhook URL. Keep this value private.",
        FCVAR_PROTECTED
    );
    g_CvarPublicAddress = CreateConVar(
        "sm_advreports_server_address",
        "",
        "Public server address (IP:port). Leave blank to derive it from hostip and hostport."
    );
    g_CvarReportCooldown = CreateConVar(
        "sm_advreports_cooldown",
        "60.0",
        "Seconds a player must wait between reports. Set to 0 to disable the cooldown.",
        FCVAR_NONE,
        true,
        0.0,
        true,
        3600.0
    );

    g_CvarDiscordEnabled.AddChangeHook(OnSettingsChanged);
    g_CvarDiscordWebhook.AddChangeHook(OnSettingsChanged);
    g_CvarPublicAddress.AddChangeHook(OnSettingsChanged);
    g_CvarReportCooldown.AddChangeHook(OnSettingsChanged);

    RegConsoleCmd("sm_calladmin", Command_ReportPlayer, "Open the player report menu.");
    RegAdminCmd("sm_reports", Command_ViewReports, ADMFLAG_SLAY, "Open the saved reports menu.");

    AutoExecConfig(true, "AdvancedReports");
    LoadReportReasons();
    Database.Connect(OnDatabaseConnected, DATABASE_CONFIG);
}

public void OnConfigsExecuted()
{
    CacheSettings();
}

public void OnClientDisconnect(int client)
{
    g_SelectedTargetUserId[client] = 0;
    g_NextReportAllowed[client] = 0.0;
    g_AdminTargetName[client][0] = '\0';
    g_AdminTargetAuth[client][0] = '\0';
    g_AdminServerAddress[client][0] = '\0';
}

public void OnSettingsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    CacheSettings();
}

void CacheSettings()
{
    g_DiscordEnabled = g_CvarDiscordEnabled.BoolValue;
    g_CvarDiscordWebhook.GetString(g_DiscordWebhook, sizeof(g_DiscordWebhook));
    g_CvarPublicAddress.GetString(g_PublicAddress, sizeof(g_PublicAddress));
    g_ReportCooldown = g_CvarReportCooldown.FloatValue;
    TrimString(g_DiscordWebhook);
    TrimString(g_PublicAddress);

    if (!g_DiscordEnabled || IsSteamWorksHttpAvailable())
    {
        g_MissingSteamWorksNoticeShown = false;
    }
}

void LoadReportReasons()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/advreport/advreasons.cfg");

    KeyValues config = new KeyValues("advreasons");
    if (!config.ImportFromFile(path))
    {
        delete config;
        SetFailState("Unable to read report reasons from %s", path);
        return;
    }

    if (!config.GotoFirstSubKey(false))
    {
        delete config;
        SetFailState("No report reasons were found in %s", path);
        return;
    }

    delete g_ReportReasons;
    g_ReportReasons = new ArrayList(MAX_REASON_LENGTH);

    do
    {
        char reason[MAX_REASON_LENGTH];
        config.GetString("reason", reason, sizeof(reason));
        TrimString(reason);

        if (reason[0] != '\0')
        {
            g_ReportReasons.PushString(reason);
        }
    }
    while (config.GotoNextKey(false));

    delete config;

    if (g_ReportReasons.Length == 0)
    {
        SetFailState("No valid report reasons were found in %s", path);
    }
}

public void OnDatabaseConnected(Database database, const char[] error, any data)
{
    if (database == null)
    {
        SetFailState("Could not connect to database configuration '%s': %s", DATABASE_CONFIG, error);
        return;
    }

    char driver[16];
    database.Driver.GetIdentifier(driver, sizeof(driver));
    if (!StrEqual(driver, "mysql", false))
    {
        delete database;
        SetFailState("Database configuration '%s' must use the MySQL driver (found '%s').", DATABASE_CONFIG, driver);
        return;
    }

    delete g_Database;
    g_Database = database;

    if (!g_Database.SetCharset("utf8mb4") && !g_Database.SetCharset("utf8"))
    {
        LogMessage("Could not set the database charset to utf8mb4 or utf8; continuing with the configured charset.");
    }

    g_Database.Query(OnDatabaseSchemaCreated, MYSQL_CREATE_TABLE);
}

public void OnDatabaseSchemaCreated(Database database, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        SetFailState("Could not create or verify database table '%s': %s", REPORT_TABLE, error);
        return;
    }

    g_Database.Query(OnDatabaseSchemaMigrated, MYSQL_MIGRATE_TABLE);
}

public void OnDatabaseSchemaMigrated(Database database, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        SetFailState("Could not update database table '%s': %s", REPORT_TABLE, error);
        return;
    }

    g_DatabaseReady = true;
}

public Action Command_ReportPlayer(int client, int args)
{
    if (!IsHumanClient(client))
    {
        ReplyToCommand(client, "%s This command can only be used in game.", CHAT_PREFIX);
        return Plugin_Handled;
    }

    if (!g_DatabaseReady)
    {
        PrintToChat(client, "%s The reports database is not ready. Please try again shortly.", CHAT_PREFIX);
        return Plugin_Handled;
    }

    float waitTime = g_NextReportAllowed[client] - GetEngineTime();
    if (waitTime > 0.0)
    {
        PrintToChat(
            client,
            "%s Please wait %d second(s) before submitting another report.",
            CHAT_PREFIX,
            RoundToCeil(waitTime)
        );
        return Plugin_Handled;
    }

    Menu menu = new Menu(MenuHandler_SelectPlayer);
    menu.SetTitle("Select a player to report:");

    int playerCount = 0;
    for (int target = 1; target <= MaxClients; target++)
    {
        if (!IsHumanClient(target) || target == client)
        {
            continue;
        }

        char userId[12];
        char playerName[MAX_NAME_LENGTH];
        IntToString(GetClientUserId(target), userId, sizeof(userId));
        GetClientName(target, playerName, sizeof(playerName));
        menu.AddItem(userId, playerName);
        playerCount++;
    }

    if (playerCount == 0)
    {
        delete menu;
        PrintToChat(client, "%s There are no other players available to report.", CHAT_PREFIX);
        return Plugin_Handled;
    }

    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int MenuHandler_SelectPlayer(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char userId[12];
        menu.GetItem(item, userId, sizeof(userId));

        int target = GetClientOfUserId(StringToInt(userId));
        if (!IsHumanClient(target) || target == client)
        {
            PrintToChat(client, "%s That player is no longer available.", CHAT_PREFIX);
            return 0;
        }

        g_SelectedTargetUserId[client] = GetClientUserId(target);
        ShowReasonMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void ShowReasonMenu(int client)
{
    Menu menu = new Menu(MenuHandler_SelectReason);
    menu.SetTitle("Select a report reason:");
    menu.ExitBackButton = true;

    for (int index = 0; index < g_ReportReasons.Length; index++)
    {
        char itemInfo[12];
        char reason[MAX_REASON_LENGTH];
        IntToString(index, itemInfo, sizeof(itemInfo));
        g_ReportReasons.GetString(index, reason, sizeof(reason));
        menu.AddItem(itemInfo, reason);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SelectReason(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char itemInfo[12];
        menu.GetItem(item, itemInfo, sizeof(itemInfo));
        int reasonIndex = StringToInt(itemInfo);

        if (reasonIndex < 0 || reasonIndex >= g_ReportReasons.Length)
        {
            PrintToChat(client, "%s That report reason is no longer available.", CHAT_PREFIX);
            return 0;
        }

        int target = GetClientOfUserId(g_SelectedTargetUserId[client]);
        if (!IsHumanClient(target) || target == client)
        {
            PrintToChat(client, "%s That player is no longer available.", CHAT_PREFIX);
            return 0;
        }

        char reason[MAX_REASON_LENGTH];
        g_ReportReasons.GetString(reasonIndex, reason, sizeof(reason));
        SubmitPlayerReport(client, target, reason);
    }
    else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
    {
        Command_ReportPlayer(client, 0);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void SubmitPlayerReport(int reporter, int target, const char[] reason)
{
    if (!g_DatabaseReady || g_Database == null)
    {
        PrintToChat(reporter, "%s The reports database is unavailable.", CHAT_PREFIX);
        return;
    }

    float waitTime = g_NextReportAllowed[reporter] - GetEngineTime();
    if (waitTime > 0.0)
    {
        PrintToChat(
            reporter,
            "%s Please wait %d second(s) before submitting another report.",
            CHAT_PREFIX,
            RoundToCeil(waitTime)
        );
        return;
    }

    char reporterName[MAX_NAME_LENGTH];
    char reporterAuth[MAX_AUTH_LENGTH];
    char targetName[MAX_NAME_LENGTH];
    char targetAuth[MAX_AUTH_LENGTH];

    GetClientName(reporter, reporterName, sizeof(reporterName));
    GetClientName(target, targetName, sizeof(targetName));

    if (!GetClientAuthId(reporter, AuthId_Steam2, reporterAuth, sizeof(reporterAuth), true)
        || !GetClientAuthId(target, AuthId_Steam2, targetAuth, sizeof(targetAuth), true))
    {
        PrintToChat(reporter, "%s Steam authentication is not ready. Please try again.", CHAT_PREFIX);
        return;
    }

    char date[36];
    char serverAddress[MAX_ADDRESS_LENGTH];
    char hostname[128];
    FormatTime(date, sizeof(date), "%Y-%m-%d %H:%M:%S", GetTime());
    GetServerAddress(serverAddress, sizeof(serverAddress));

    ConVar hostnameCvar = FindConVar("hostname");
    if (hostnameCvar != null)
    {
        hostnameCvar.GetString(hostname, sizeof(hostname));
    }
    else
    {
        strcopy(hostname, sizeof(hostname), "Unknown server");
    }

    char escapedReporter[(MAX_NAME_LENGTH * 2) + 1];
    char escapedTarget[(MAX_NAME_LENGTH * 2) + 1];
    char escapedTargetAuth[(MAX_AUTH_LENGTH * 2) + 1];
    char escapedReason[(MAX_REASON_LENGTH * 2) + 1];
    char escapedDate[73];
    char escapedAddress[(MAX_ADDRESS_LENGTH * 2) + 1];

    if (!g_Database.Escape(reporterName, escapedReporter, sizeof(escapedReporter))
        || !g_Database.Escape(targetName, escapedTarget, sizeof(escapedTarget))
        || !g_Database.Escape(targetAuth, escapedTargetAuth, sizeof(escapedTargetAuth))
        || !g_Database.Escape(reason, escapedReason, sizeof(escapedReason))
        || !g_Database.Escape(date, escapedDate, sizeof(escapedDate))
        || !g_Database.Escape(serverAddress, escapedAddress, sizeof(escapedAddress)))
    {
        PrintToChat(reporter, "%s The report contained data that could not be saved.", CHAT_PREFIX);
        return;
    }

    char query[MAX_QUERY_LENGTH];
    FormatEx(
        query,
        sizeof(query),
        "INSERT INTO `%s` (`playername`,`steam`,`reason`,`reporter`,`date`,`serverip`) "
        ... "VALUES ('%s','%s','%s','%s','%s','%s') "
        ... "ON DUPLICATE KEY UPDATE `playername`=VALUES(`playername`),`reason`=VALUES(`reason`),"
        ... "`reporter`=VALUES(`reporter`),`date`=VALUES(`date`),`serverip`=VALUES(`serverip`);",
        REPORT_TABLE,
        escapedTarget,
        escapedTargetAuth,
        escapedReason,
        escapedReporter,
        escapedDate,
        escapedAddress
    );

    DataPack reportData = new DataPack();
    reportData.WriteCell(GetClientUserId(reporter));
    reportData.WriteString(reporterName);
    reportData.WriteString(reporterAuth);
    reportData.WriteString(targetName);
    reportData.WriteString(targetAuth);
    reportData.WriteString(reason);
    reportData.WriteString(serverAddress);
    reportData.WriteString(hostname);

    g_NextReportAllowed[reporter] = GetEngineTime() + g_ReportCooldown;
    g_Database.Query(OnPlayerReportSaved, query, reportData);
}

public void OnPlayerReportSaved(Database database, DBResultSet results, const char[] error, DataPack reportData)
{
    reportData.Reset();

    int reporterUserId = reportData.ReadCell();
    char reporterName[MAX_NAME_LENGTH];
    char reporterAuth[MAX_AUTH_LENGTH];
    char targetName[MAX_NAME_LENGTH];
    char targetAuth[MAX_AUTH_LENGTH];
    char reason[MAX_REASON_LENGTH];
    char serverAddress[MAX_ADDRESS_LENGTH];
    char hostname[128];

    reportData.ReadString(reporterName, sizeof(reporterName));
    reportData.ReadString(reporterAuth, sizeof(reporterAuth));
    reportData.ReadString(targetName, sizeof(targetName));
    reportData.ReadString(targetAuth, sizeof(targetAuth));
    reportData.ReadString(reason, sizeof(reason));
    reportData.ReadString(serverAddress, sizeof(serverAddress));
    reportData.ReadString(hostname, sizeof(hostname));
    delete reportData;

    int reporter = GetClientOfUserId(reporterUserId);
    if (results == null)
    {
        LogError("Could not save report for %s (%s): %s", targetName, targetAuth, error);
        if (IsHumanClient(reporter))
        {
            g_NextReportAllowed[reporter] = 0.0;
            PrintToChat(reporter, "%s Your report could not be saved. Please contact an administrator.", CHAT_PREFIX);
        }
        return;
    }

    if (IsHumanClient(reporter))
    {
        PrintToChat(reporter, "%s Your report has been submitted.", CHAT_PREFIX);
    }

    SendDiscordReport(
        reporterName,
        reporterAuth,
        targetName,
        targetAuth,
        reason,
        serverAddress,
        hostname
    );
}

public Action Command_ViewReports(int client, int args)
{
    if (!IsHumanClient(client))
    {
        ReplyToCommand(client, "%s This command can only be used in game.", CHAT_PREFIX);
        return Plugin_Handled;
    }

    ShowReportsMenu(client);
    return Plugin_Handled;
}

void ShowReportsMenu(int client)
{
    if (!g_DatabaseReady || g_Database == null)
    {
        PrintToChat(client, "%s The reports database is not ready.", CHAT_PREFIX);
        return;
    }

    char query[256];
    FormatEx(
        query,
        sizeof(query),
        "SELECT `playername`,`steam` FROM `%s` ORDER BY `Id` DESC;",
        REPORT_TABLE
    );
    g_Database.Query(OnReportsLoaded, query, GetClientUserId(client));
}

public void OnReportsLoaded(Database database, DBResultSet results, const char[] error, any clientUserId)
{
    int client = GetClientOfUserId(clientUserId);
    if (!IsHumanClient(client))
    {
        return;
    }

    if (results == null)
    {
        LogError("Could not load reports: %s", error);
        PrintToChat(client, "%s Reports could not be loaded.", CHAT_PREFIX);
        return;
    }

    Menu menu = new Menu(MenuHandler_Reports);
    menu.SetTitle("Player reports:");

    int reportCount = 0;
    while (results.FetchRow())
    {
        char playerName[MAX_NAME_LENGTH];
        char targetAuth[MAX_AUTH_LENGTH];
        results.FetchString(0, playerName, sizeof(playerName));
        results.FetchString(1, targetAuth, sizeof(targetAuth));
        menu.AddItem(targetAuth, playerName);
        reportCount++;
    }

    if (reportCount == 0)
    {
        delete menu;
        PrintToChat(client, "%s There are no saved reports.", CHAT_PREFIX);
        return;
    }

    menu.Display(client, 60);
}

public int MenuHandler_Reports(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char targetAuth[MAX_AUTH_LENGTH];
        menu.GetItem(item, targetAuth, sizeof(targetAuth));
        ShowReportDetails(client, targetAuth);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void ShowReportDetails(int client, const char[] targetAuth)
{
    if (!g_DatabaseReady || g_Database == null)
    {
        PrintToChat(client, "%s The reports database is unavailable.", CHAT_PREFIX);
        return;
    }

    char escapedAuth[(MAX_AUTH_LENGTH * 2) + 1];
    if (!g_Database.Escape(targetAuth, escapedAuth, sizeof(escapedAuth)))
    {
        PrintToChat(client, "%s The selected report could not be read.", CHAT_PREFIX);
        return;
    }

    char query[512];
    FormatEx(
        query,
        sizeof(query),
        "SELECT `playername`,`steam`,`reason`,`reporter`,`date`,`serverip` "
        ... "FROM `%s` WHERE `steam`='%s' LIMIT 1;",
        REPORT_TABLE,
        escapedAuth
    );
    g_Database.Query(OnReportDetailsLoaded, query, GetClientUserId(client));
}

public void OnReportDetailsLoaded(Database database, DBResultSet results, const char[] error, any clientUserId)
{
    int client = GetClientOfUserId(clientUserId);
    if (!IsHumanClient(client))
    {
        return;
    }

    if (results == null)
    {
        LogError("Could not load report details: %s", error);
        PrintToChat(client, "%s Report details could not be loaded.", CHAT_PREFIX);
        return;
    }

    if (!results.FetchRow())
    {
        PrintToChat(client, "%s That report no longer exists.", CHAT_PREFIX);
        ShowReportsMenu(client);
        return;
    }

    char reason[MAX_REASON_LENGTH];
    char reporterName[MAX_NAME_LENGTH];
    char date[36];
    results.FetchString(0, g_AdminTargetName[client], sizeof(g_AdminTargetName[]));
    results.FetchString(1, g_AdminTargetAuth[client], sizeof(g_AdminTargetAuth[]));
    results.FetchString(2, reason, sizeof(reason));
    results.FetchString(3, reporterName, sizeof(reporterName));
    results.FetchString(4, date, sizeof(date));
    results.FetchString(5, g_AdminServerAddress[client], sizeof(g_AdminServerAddress[]));

    Menu menu = new Menu(MenuHandler_ReportDetails);
    menu.SetTitle("Report: %s", g_AdminTargetName[client]);
    AddDisabledMenuLine(menu, "Reporter: %s", reporterName);
    AddDisabledMenuLine(menu, "Target: %s", g_AdminTargetName[client]);
    AddDisabledMenuLine(menu, "Steam ID: %s", g_AdminTargetAuth[client]);
    AddDisabledMenuLine(menu, "Reason: %s", reason);
    AddDisabledMenuLine(menu, "Date: %s", date);
    AddDisabledMenuLine(menu, "Server: %s", g_AdminServerAddress[client]);
    menu.AddItem("options", "Report options");
    menu.ExitBackButton = true;
    menu.Display(client, 60);
}

void AddDisabledMenuLine(Menu menu, const char[] format, any ...)
{
    char line[256];
    VFormat(line, sizeof(line), format, 3);
    menu.AddItem("disabled", line, ITEMDRAW_DISABLED);
}

public int MenuHandler_ReportDetails(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        ShowReportOptions(client);
    }
    else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
    {
        ShowReportsMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void ShowReportOptions(int client)
{
    Menu menu = new Menu(MenuHandler_ReportOptions);
    menu.SetTitle("Options: %s", g_AdminTargetName[client]);

    bool canRedirect = IsRedirectAvailable() && g_AdminServerAddress[client][0] != '\0';
    bool canKick = CheckCommandAccess(client, "sm_advreports_kick", ADMFLAG_KICK)
        && FindClientByAuth(g_AdminTargetAuth[client]) != 0;
    bool canBan = CheckCommandAccess(client, "sm_advreports_ban", ADMFLAG_BAN);

    menu.AddItem("connect", "Go to reported server", canRedirect ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    menu.AddItem("kick", "Kick player from this server", canKick ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    menu.AddItem("ban", "Permanently ban player", canBan ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    menu.AddItem("delete", "Delete report");
    menu.ExitBackButton = true;
    menu.Display(client, 60);
}

public int MenuHandler_ReportOptions(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char itemInfo[16];
        menu.GetItem(item, itemInfo, sizeof(itemInfo));

        if (StrEqual(itemInfo, "connect"))
        {
            if (IsRedirectAvailable() && g_AdminServerAddress[client][0] != '\0')
            {
                RedirectClient(client, g_AdminServerAddress[client]);
            }
            else
            {
                PrintToChat(client, "%s Server Redirect is not available.", CHAT_PREFIX);
            }
        }
        else if (StrEqual(itemInfo, "kick"))
        {
            KickReportedPlayer(client);
        }
        else if (StrEqual(itemInfo, "ban"))
        {
            ShowActionConfirmation(client, "ban");
        }
        else if (StrEqual(itemInfo, "delete"))
        {
            ShowActionConfirmation(client, "delete");
        }
    }
    else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
    {
        ShowReportDetails(client, g_AdminTargetAuth[client]);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void ShowActionConfirmation(int client, const char[] action)
{
    Menu menu = new Menu(MenuHandler_ConfirmAction);

    if (StrEqual(action, "ban"))
    {
        menu.SetTitle("Permanently ban %s?", g_AdminTargetName[client]);
        menu.AddItem("ban", "Confirm permanent ban");
    }
    else
    {
        menu.SetTitle("Delete report for %s?", g_AdminTargetName[client]);
        menu.AddItem("delete", "Confirm report deletion");
    }

    menu.AddItem("cancel", "Cancel");
    menu.ExitButton = false;
    menu.Display(client, 60);
}

public int MenuHandler_ConfirmAction(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char itemInfo[16];
        menu.GetItem(item, itemInfo, sizeof(itemInfo));

        if (StrEqual(itemInfo, "ban"))
        {
            BanReportedPlayer(client);
        }
        else if (StrEqual(itemInfo, "delete"))
        {
            DeleteSelectedReport(client);
        }
        else
        {
            ShowReportOptions(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void KickReportedPlayer(int client)
{
    if (!CheckCommandAccess(client, "sm_advreports_kick", ADMFLAG_KICK))
    {
        PrintToChat(client, "%s You do not have permission to kick players.", CHAT_PREFIX);
        return;
    }

    int target = FindClientByAuth(g_AdminTargetAuth[client]);
    if (!IsHumanClient(target))
    {
        PrintToChat(client, "%s That player is not on this server.", CHAT_PREFIX);
        return;
    }

    ShowActivity2(client, CHAT_PREFIX, " Kicked %N after reviewing a report.", target);
    KickClient(target, "Kicked after an administrator reviewed a report.");
}

void BanReportedPlayer(int client)
{
    if (!CheckCommandAccess(client, "sm_advreports_ban", ADMFLAG_BAN))
    {
        PrintToChat(client, "%s You do not have permission to ban players.", CHAT_PREFIX);
        return;
    }

    int target = FindClientByAuth(g_AdminTargetAuth[client]);
    bool success;

    if (IsHumanClient(target))
    {
        success = BanClient(
            target,
            0,
            BANFLAG_AUTO,
            "Banned after an administrator reviewed a report.",
            "Banned after an administrator reviewed a report.",
            "sm_advreports_ban",
            client
        );
    }
    else
    {
        success = BanIdentity(
            g_AdminTargetAuth[client],
            0,
            BANFLAG_AUTHID,
            "Banned after an administrator reviewed a report.",
            "sm_advreports_ban",
            client
        );
    }

    if (success)
    {
        ShowActivity2(client, CHAT_PREFIX, " Permanently banned %s (%s).", g_AdminTargetName[client], g_AdminTargetAuth[client]);
    }
    else
    {
        PrintToChat(client, "%s The ban could not be applied.", CHAT_PREFIX);
    }
}

void DeleteSelectedReport(int client)
{
    if (!g_DatabaseReady || g_Database == null)
    {
        PrintToChat(client, "%s The reports database is unavailable.", CHAT_PREFIX);
        return;
    }

    char escapedAuth[(MAX_AUTH_LENGTH * 2) + 1];
    if (!g_Database.Escape(g_AdminTargetAuth[client], escapedAuth, sizeof(escapedAuth)))
    {
        PrintToChat(client, "%s The selected report could not be deleted.", CHAT_PREFIX);
        return;
    }

    char query[256];
    FormatEx(query, sizeof(query), "DELETE FROM `%s` WHERE `steam`='%s';", REPORT_TABLE, escapedAuth);
    g_Database.Query(OnReportDeleted, query, GetClientUserId(client));
}

public void OnReportDeleted(Database database, DBResultSet results, const char[] error, any clientUserId)
{
    int client = GetClientOfUserId(clientUserId);
    if (results == null)
    {
        LogError("Could not delete report: %s", error);
        if (IsHumanClient(client))
        {
            PrintToChat(client, "%s The selected report could not be deleted.", CHAT_PREFIX);
        }
        return;
    }

    if (IsHumanClient(client))
    {
        PrintToChat(client, "%s The report was deleted.", CHAT_PREFIX);
        g_AdminTargetName[client][0] = '\0';
        g_AdminTargetAuth[client][0] = '\0';
        g_AdminServerAddress[client][0] = '\0';
        ShowReportsMenu(client);
    }
}

int FindClientByAuth(const char[] auth)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsHumanClient(client))
        {
            continue;
        }

        char clientAuth[MAX_AUTH_LENGTH];
        if (GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth), true)
            && StrEqual(clientAuth, auth, false))
        {
            return client;
        }
    }

    return 0;
}

bool IsHumanClient(int client)
{
    return client > 0
        && client <= MaxClients
        && IsClientInGame(client)
        && !IsFakeClient(client);
}

bool IsRedirectAvailable()
{
    return GetFeatureStatus(FeatureType_Native, "RedirectClient") == FeatureStatus_Available;
}

void GetServerAddress(char[] address, int addressLength)
{
    if (g_PublicAddress[0] != '\0')
    {
        strcopy(address, addressLength, g_PublicAddress);
        return;
    }

    ConVar hostIpCvar = FindConVar("hostip");
    ConVar hostPortCvar = FindConVar("hostport");
    if (hostIpCvar == null || hostPortCvar == null)
    {
        strcopy(address, addressLength, "unknown");
        return;
    }

    int hostIp = hostIpCvar.IntValue;
    int hostPort = hostPortCvar.IntValue;
    FormatEx(
        address,
        addressLength,
        "%d.%d.%d.%d:%d",
        (hostIp >> 24) & 0xFF,
        (hostIp >> 16) & 0xFF,
        (hostIp >> 8) & 0xFF,
        hostIp & 0xFF,
        hostPort
    );
}

bool IsSteamWorksHttpAvailable()
{
    return GetFeatureStatus(FeatureType_Native, "SteamWorks_CreateHTTPRequest") == FeatureStatus_Available
        && GetFeatureStatus(FeatureType_Native, "SteamWorks_SetHTTPRequestNetworkActivityTimeout") == FeatureStatus_Available
        && GetFeatureStatus(FeatureType_Native, "SteamWorks_SetHTTPCallbacks") == FeatureStatus_Available
        && GetFeatureStatus(FeatureType_Native, "SteamWorks_SetHTTPRequestRawPostBody") == FeatureStatus_Available
        && GetFeatureStatus(FeatureType_Native, "SteamWorks_SendHTTPRequest") == FeatureStatus_Available;
}

bool IsDiscordWebhookUrl(const char[] url)
{
    return StrContains(url, "https://discord.com/api/webhooks/", false) == 0
        || StrContains(url, "https://discordapp.com/api/webhooks/", false) == 0;
}

void SendDiscordReport(
    const char[] reporterName,
    const char[] reporterAuth,
    const char[] targetName,
    const char[] targetAuth,
    const char[] reason,
    const char[] serverAddress,
    const char[] hostname
)
{
    if (!g_DiscordEnabled)
    {
        return;
    }

    if (!IsDiscordWebhookUrl(g_DiscordWebhook))
    {
        LogError("Discord reporting is enabled, but sm_advreports_webhook is empty or invalid.");
        return;
    }

    if (!IsSteamWorksHttpAvailable())
    {
        if (!g_MissingSteamWorksNoticeShown)
        {
            LogMessage("Discord reporting is enabled, but the optional SteamWorks extension is unavailable.");
            g_MissingSteamWorksNoticeShown = true;
        }
        return;
    }

    char reporter[256];
    char target[256];
    char directConnect[192];
    FormatEx(reporter, sizeof(reporter), "%s\n(%s)", reporterName, reporterAuth);
    FormatEx(target, sizeof(target), "%s\n(%s)", targetName, targetAuth);
    FormatEx(directConnect, sizeof(directConnect), "steam://connect/%s", serverAddress);

    char escapedReporter[512];
    char escapedTarget[512];
    char escapedReason[512];
    char escapedDirectConnect[384];
    char escapedHostname[256];
    JsonEscape(reporter, escapedReporter, sizeof(escapedReporter));
    JsonEscape(target, escapedTarget, sizeof(escapedTarget));
    JsonEscape(reason, escapedReason, sizeof(escapedReason));
    JsonEscape(directConnect, escapedDirectConnect, sizeof(escapedDirectConnect));
    JsonEscape(hostname, escapedHostname, sizeof(escapedHostname));

    char payload[4096];
    FormatEx(
        payload,
        sizeof(payload),
        "{\"username\":\"Advanced Reports\",\"embeds\":[{\"title\":\"New report\",\"color\":10494192,"
        ... "\"fields\":[{\"name\":\"Reporter\",\"value\":\"%s\",\"inline\":true},"
        ... "{\"name\":\"Target\",\"value\":\"%s\",\"inline\":true},"
        ... "{\"name\":\"Reason\",\"value\":\"%s\",\"inline\":false},"
        ... "{\"name\":\"Direct connect\",\"value\":\"%s\",\"inline\":false}],"
        ... "\"footer\":{\"text\":\"Server: %s\"}}]}",
        escapedReporter,
        escapedTarget,
        escapedReason,
        escapedDirectConnect,
        escapedHostname
    );

    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, g_DiscordWebhook);
    if (request == null)
    {
        LogError("SteamWorks could not create the Discord webhook request.");
        return;
    }

    bool configured = SteamWorks_SetHTTPRequestNetworkActivityTimeout(request, 15)
        && SteamWorks_SetHTTPRequestRawPostBody(request, "application/json; charset=UTF-8", payload, strlen(payload))
        && SteamWorks_SetHTTPCallbacks(request, OnDiscordRequestCompleted);

    if (!configured || !SteamWorks_SendHTTPRequest(request))
    {
        LogError("SteamWorks could not send the Discord webhook request.");
        delete request;
    }
}

public void OnDiscordRequestCompleted(
    Handle request,
    bool failure,
    bool requestSuccessful,
    EHTTPStatusCode statusCode
)
{
    int status = view_as<int>(statusCode);
    if (failure || !requestSuccessful || status < 200 || status >= 300)
    {
        LogError(
            "Discord webhook request failed (transport failure: %d, request successful: %d, HTTP status: %d).",
            failure,
            requestSuccessful,
            status
        );
    }

    delete request;
}

void JsonEscape(const char[] input, char[] output, int outputLength)
{
    int outputPosition = 0;

    for (int inputPosition = 0; input[inputPosition] != '\0' && outputPosition < outputLength - 1; inputPosition++)
    {
        int character = input[inputPosition];
        int escapedCharacter;
        bool needsEscape = true;

        switch (character)
        {
            case '"': escapedCharacter = '"';
            case '\\': escapedCharacter = '\\';
            case '\n': escapedCharacter = 'n';
            case '\r': escapedCharacter = 'r';
            case '\t': escapedCharacter = 't';
            default: needsEscape = false;
        }

        if (needsEscape)
        {
            if (outputPosition >= outputLength - 2)
            {
                break;
            }

            output[outputPosition++] = '\\';
            output[outputPosition++] = escapedCharacter;
        }
        else if (character >= 0x20 || character < 0)
        {
            output[outputPosition++] = character;
        }
    }

    output[outputPosition] = '\0';
}
