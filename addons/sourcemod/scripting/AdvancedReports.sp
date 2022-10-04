/*  [CS:GO] Advanced-Reports, Report the bad people :).
 *
 *  Copyright (C) 2021 Mr.Timid // timidexempt@gmail.com
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

/* Change this to enable debug */
#define _DEBUG 											0 // 1 = Minimum Debug 3 = Full Debug
#define _DEBUG_MODE										1 // 1 = Log to File, 2 = Log to Game Logs, 3 = Print to Chat, 4 = Print to Console

#define LOG_FOLDER										"logs"
#define LOG_PREFIX										"advr_"
#define LOG_EXT											"log"

#if _DEBUG
ConVar hCvarLogDebug = null;
#endif

/* Log File */
char ADVR_LogFile[PLATFORM_MAX_PATH];

#include <discord>
#include <sourcemod>
#include <cstrike>
#include <server_redirect>
#include <timid>

Handle gRMenu;

#include <advreports/cmds>
#include <advreports/cvars>

public Plugin myinfo = 
{
	name = "Advanced-Reports", 
	author = PLUGIN_AUTHOR, 
	description = "Advanced-Reports, Report the bad people :)", 
	version = "1.0.2", 
	url = "https://steamcommunity.com/id/MrTimid/"
}

#define ARPREFIX "\x08「\x0EAdvReports\x08」"

/* Global SQL Char */
char gDbName[] = "advancedreports";
char g_sSQLTable[] = "aReports";

static const char g_sMysqlCreate[] = "CREATE TABLE IF NOT EXISTS `aReports` (`Id` int(20) NOT NULL AUTO_INCREMENT, `playername` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL, `steam` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL, `reason` varchar(56) COLLATE utf8mb4_unicode_ci NOT NULL, `reporter` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL, `date` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL, `serverip` varchar(38) COLLATE utf8mb4_unicode_ci NOT NULL, PRIMARY KEY (`Id`), UNIQUE KEY `steam` (`steam`) ) ENGINE = InnoDB AUTO_INCREMENT=0 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;";

public void OnPluginStart()
{
	BuildLogFilePath();
	
	#if _DEBUG
	LogDebug(false, "Adv-Reports Plugin Started!");
	#endif
	
	/* Create Cvars */
	CreateCvars();
	
	char error[255];
	g_aReportsDB = SQL_Connect(gDbName, true, error, sizeof(error));
	
	if (!g_aReportsDB)
	{
		SetFailState("Error connecting to database: \"%s\"", error);
	}
	
	/* SQL_LockDatabase is redundent for SQL_SetCharset */
	if (!SQL_SetCharset(g_aReportsDB, "utf8mb4")) {
		SQL_SetCharset(g_aReportsDB, "utf8");
	}
	SQL_TQuery(g_aReportsDB, SQLErrorCheckCallback, g_sMysqlCreate);
	
	/* Player Commands */
	RegConsoleCmd("sm_calladmin", CMD_PlayerList, "Opens the report player menu!");
	
	/* Admin Commands */
	RegAdminCmd("sm_reports", CMD_Reports, ADMFLAG_SLAY, "Opens the player reports menu.");
	
	/* Cfg File */
	AutoExecConfig(true, "AdvancedReports");
	
	/* load the key values on plugin start */
	ParseKV();
}

public void OnConfigsExecuted()
{
	GetCvarValues();
}

/* Tried making it so players join and have a warning, display warning to player */


/*
public void OnClientPutInServer(int client)
{
	char sQueryReports[1024];
	Format(sQueryReports, sizeof(sQueryReports), "SELECT `playername`, `steam`, `reason`, `reporter` FROM `%s`", g_sSQLTable);
	SQL_TQuery(g_aReportsDB, SQLPlayerReports, sQueryReports, client);
}

public void SQLPlayerReports(Handle owner, Handle hndl, const char[] error, any data)
{
	int client = data;
	
	ReportDetialMenu = CreateMenu(ReportDetialMenuHNDLR);
	while (SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 0, playername, sizeof(playername));
		SQL_FetchString(hndl, 3, reporter, sizeof(reporter));
		
		char title[64];
		Format(title, sizeof(title), "Details: %s", playername);
		SetMenuTitle(ReportDetialMenu, title);
		
		char reporterItem[64];
		Format(reporterItem, sizeof(reporterItem), "Reporter: %s", reporter);
		AddMenuItem(ReportDetialMenu, "x", reporterItem, ITEMDRAW_DISABLED);
	}
	if (client == playername[32])
	{
		DisplayMenu(ReportDetialMenu, client, MENU_TIME_FOREVER);
	}
}

public int ReportDetialMenuHNDLR(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(choice, info, sizeof(info));
			selectedClient = StringToInt(info);
			if (IsClientInGame(selectedClient))
			{
				DisplayMenu(gRMenu, client, MENU_TIME_FOREVER);
			}
		}
		case MenuAction_End: {  }
	}
}
*/

public int PlayerMenuHNDLR(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(choice, info, sizeof(info));
			selectedClient = StringToInt(info);
			if (IsClientInGame(selectedClient))
			{
				DisplayMenu(gRMenu, client, MENU_TIME_FOREVER);
			}
		}
		case MenuAction_End: {  }
	}
	return 0;
}

public void ParseKV()
{
	/* find the path */
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/advreport/advreasons.cfg");
	
	if (!FileExists(path))
	{
		SetFailState("Configuration file %s is not found", path);
	}
	
	kv = CreateKeyValues("advreasons");
	FileToKeyValues(kv, path);
	
	if (!KvGotoFirstSubKey(kv))
	{
		SetFailState("Unable to find config section in file %s", path);
		return;
	}
	
	/* Report Menu */
	gRMenu = CreateMenu(MenuHandler1);
	int cmdNum = 0;
	char cmdCMD[32];
	
	do {
		KvGetString(kv, "reason", gCmdName, sizeof(gCmdName));
		
		SetMenuTitle(gRMenu, "Report Reason");
		AddMenuItem(gRMenu, cmdCMD, gCmdName);
		Format(g_CmdResponse[cmdNum], sizeof(gCmdName), gCmdName);
		cmdNum++;
	} while (KvGotoNextKey(kv));
	CloseHandle(kv);
}

public int MenuHandler1(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[256];
			
			menu.GetItem(choice, info, sizeof(info));
			Format(gBuffer, sizeof(gBuffer), "%s", g_CmdResponse[choice]);
			/* Item = GetMenuSelectionPosition(); PrintToChat(client, "\x08[\x03ARDebug\x08] Player = %N | Reason = %s", selectedClient, gBuffer); */
			
			PrintToChat(client, "%s Your report has been submited!", ARPREFIX);
			
			
			/* Get report client id */
			GetClientAuthId(selectedClient, AuthId_Steam2, gAuth, sizeof(gAuth));
			strcopy(gSelectedClientSteam[selectedClient], sizeof(gSelectedClientSteam[]), gAuth);
			
			/* Get reporter client id */
			GetClientAuthId(client, AuthId_Steam2, gClientAuth, sizeof(gClientAuth));
			strcopy(gClientSteam[client], sizeof(gClientSteam[]), gClientAuth);
			
			FormatTime(gDate, sizeof(gDate), "%m/%d/%Y - %I:%M:%S", GetTime());
			FormatEx(gReporterID, sizeof(gReporterID), "**%N** \n(%s)", client, gClientAuth);
			FormatEx(gTargetID, sizeof(gTargetID), "**%N** \n(%s)", selectedClient, gAuth);
			FormatEx(gReason, sizeof(gReason), "\n%s", gBuffer);
			
			/* Find Ip send to table */
			Handle cvar = FindConVar("hostip");
			int hostip = GetConVarInt(cvar);
			
			FormatEx(gServerIp, sizeof(gServerIp), "%u.%u.%u.%u", 
				(hostip >> 24) & 0x000000FF, (hostip >> 16) & 0x000000FF, (hostip >> 8) & 0x000000FF, hostip & 0x000000FF);
			cvar = FindConVar("hostport");
			
			GetConVarString(cvar, gServerPort, sizeof(gServerPort));
			
			Format(gServerIpA, sizeof(gServerIpA), "%s:%s", gServerIp, gServerPort);
			
			
			/* Insert into table */
			SQLAddPlayerReport(client);
			
			/* Update table if new report occurs (On same client) */
			SQLUpdatePlayerReport(client);
			
			/* Discord Callback */
			DiscordWebhookCallBack();
			
		}
		case MenuAction_End: {  }
	}
	return 0;
}

public void SQLAddPlayerReport(int client)
{
	char addReportQuery[4096];
	FormatEx(addReportQuery, sizeof(addReportQuery), "INSERT IGNORE INTO `%s` (`Id`, `playername`, `steam`, `reason`, `reporter`, `date`, `serverip`) VALUES (NULL, '%N', '%s', '%s', '%N', '%s', '%s');", g_sSQLTable, selectedClient, gAuth, gBuffer, client, gDate, gServerIpA);
	SQL_TQuery(g_aReportsDB, SQLErrorCheckCallback, addReportQuery);
}

public void SQLRemovePlayerReport(int client)
{
	char removePlayerReport[4096];
	FormatEx(removePlayerReport, sizeof(removePlayerReport), "DELETE FROM `%s` WHERE `playername` = '%s'", g_sSQLTable, playername);
	SQL_TQuery(g_aReportsDB, SQLErrorCheckCallback, removePlayerReport);
}

public void SQLUpdatePlayerReport(int client)
{
	char updatePlayerQuery[4096];
	FormatEx(updatePlayerQuery, sizeof(updatePlayerQuery), "UPDATE `%s` SET `reason` = '%s', `reporter` = '%N', `date` = '%s', `serverip` = '%s' WHERE `steam` = '%s'", g_sSQLTable, gBuffer, client, gDate, gServerIpA, gAuth);
	SQL_TQuery(g_aReportsDB, SQLErrorCheckCallback, updatePlayerQuery);
}

/*
public void SQLAddPlayerWarning(int client)
{
	char addWarningQuery[4096];
	Format(addWarningQuery, sizeof(addWarningQuery), "INSERT IGNORE INTO `%s` (`Id")
}
*/

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public void DumbDB(int client)
{
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `playername`, `steam`, `reason`, `reporter` FROM `%s`", g_sSQLTable);
	SQL_TQuery(g_aReportsDB, SQLListPlayerReports, sQuery, client);
}

public void SQLListPlayerReports(Handle owner, Handle hndl, const char[] error, any data)
{
	int client = data;
	gPMenu = CreateMenu(ListPlayerReportsHNDLR);
	SetMenuTitle(gPMenu, "Player Report(s):");
	while (SQL_FetchRow(hndl)) {
		char rSteamid[64];
		char rPlayer[MAX_NAME_LENGTH + 8];
		SQL_FetchString(hndl, 0, rPlayer, sizeof(rPlayer));
		SQL_FetchString(hndl, 1, rSteamid, sizeof(rSteamid));
		
		//PrintToChatAll("\x08[\x03ARDebug\x08] Name \x03\"%s\" \x08was found.", playername);
		//PrintToChatAll("\x08[\x03ARDebug\x08] SteamId \x03\"%s\" \x08was found.", steamid);
		
		AddMenuItem(gPMenu, rSteamid, rPlayer);
	}
	DisplayMenu(gPMenu, client, 60);
}

public int ListPlayerReportsHNDLR(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[20];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		char detailsQuery[512];
		/* Ty Impact <3 */
		FormatEx(detailsQuery, sizeof(detailsQuery), "SELECT `playername`, `steam`, `reason`, `reporter`, `date`, `serverip` FROM `%s` WHERE `steam` = '%s'", g_sSQLTable, cValue);
		SQL_TQuery(g_aReportsDB, SQLDetailsQuery, detailsQuery, client);
	}
	return 0;
}

public void SQLDetailsQuery(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	DetailsMenu = CreateMenu(DetailsMenuHNDLR);
	bool hasData = false;
	while (SQL_FetchRow(hndl) && !hasData)
	{
		char reason[56];
		SQL_FetchString(hndl, 0, playername, sizeof(playername));
		SQL_FetchString(hndl, 1, steamid, sizeof(steamid));
		SQL_FetchString(hndl, 2, reason, sizeof(reason));
		SQL_FetchString(hndl, 3, reporter, sizeof(reporter));
		SQL_FetchString(hndl, 4, date, sizeof(date));
		SQL_FetchString(hndl, 5, serverIp, sizeof(serverIp));
		
		char title[64];
		FormatEx(title, sizeof(title), "Details: %s", playername);
		SetMenuTitle(DetailsMenu, title);
		
		char reporterItem[64];
		FormatEx(reporterItem, sizeof(reporterItem), "Reporter: %s", reporter);
		AddMenuItem(DetailsMenu, "x", reporterItem, ITEMDRAW_DISABLED);
		
		char playeridItem[64];
		FormatEx(playeridItem, sizeof(playeridItem), "Target: %s", playername);
		AddMenuItem(DetailsMenu, "x", playeridItem, ITEMDRAW_DISABLED);
		
		char reasonItem[64];
		FormatEx(reasonItem, sizeof(reasonItem), "Reason: %s", reason);
		AddMenuItem(DetailsMenu, "x", reasonItem, ITEMDRAW_DISABLED);
		
		char dateItem[64];
		FormatEx(dateItem, sizeof(dateItem), "Date: %s", date);
		AddMenuItem(DetailsMenu, "x", dateItem, ITEMDRAW_DISABLED);
		
		char serverIpItem[64];
		FormatEx(serverIpItem, sizeof(serverIpItem), "ServerIP: %s", serverIp);
		AddMenuItem(DetailsMenu, "x", serverIpItem, ITEMDRAW_DISABLED);
		
		char choiceItem[64];
		FormatEx(choiceItem, sizeof(choiceItem), "Report Options");
		AddMenuItem(DetailsMenu, "reportoptions", choiceItem);
		
		hasData = true;
	}
	DisplayMenu(DetailsMenu, client, 60);
}

public void DiscordWebhookCallBack()
{
	if (gWebHookEnabled)
	{
		char FIP[38];
		
		ConVar hServer = FindConVar("hostname");
		
		FormatEx(FIP, sizeof(FIP), "steam://connect/%s:%s", gServerIp, gServerPort);
		
		char fHostname[164];
		hServer.GetString(gHostname, sizeof(gHostname));
		FormatEx(fHostname, sizeof(fHostname), "Server: %s", gHostname);
		
		DiscordWebHook reportWH = new DiscordWebHook(gWebHook);
		reportWH.SlackMode = true;
		
		reportWH.SetUsername("Advanced-Reports");
		reportWH.SetAvatar("https://cdn.discordapp.com/attachments/814931663305048064/816754054309871647/Discord_gif_tran.gif");
		MessageEmbed Embed = new MessageEmbed();
		Embed.SetColor("#A020F0");
		Embed.SetAuthor("New Report!");
		Embed.AddField("Reporter:", gReporterID, true);
		Embed.AddField("Target:", gTargetID, true);
		Embed.AddField("Reason:", gReason, true);
		Embed.AddField("Direct Connect:", FIP, true);
		Embed.SetFooter(fHostname);
		
		reportWH.Embed(Embed);
		reportWH.Send();
		delete reportWH;
	}
}

public int DetailsMenuHNDLR(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[256];
			menu.GetItem(choice, info, sizeof(info));
			
			if (StrEqual(info, "reportoptions"))
			{
				ReportOptionsMenu(client);
			}
		}
		case MenuAction_Cancel:
		{
			DumbDB(client);
		}
	}
	return 0;
}

public void ReportOptionsMenu(int client)
{
	gMenuHandles[client] = new Menu(ReportOptionsHNDLR, MENU_ACTIONS_ALL);
	gMenuHandles[client].SetTitle("Report Options, %s!", playername);
	gMenuHandles[client].AddItem("gotoserver", "Go to server!");
	gMenuHandles[client].AddItem("ban", "Ban Player!");
	gMenuHandles[client].AddItem("kick", "Kick Player!");
	gMenuHandles[client].ExitButton = true;
	gMenuHandles[client].Display(client, MENU_TIME_FOREVER);
}

public int ReportOptionsHNDLR(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(choice, info, sizeof(info));
			if (StrEqual(info, "gotoserver"))
			{
				RedirectClient(client, serverIp);
			}
		}
		case MenuAction_Cancel:
		{
			DumbDB(client);
		}
	}
	return 0;
}


// Log Functions
void BuildLogFilePath() // Build Log File System Path
{
	char sLogPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sLogPath, sizeof(sLogPath), LOG_FOLDER);
	
	if (!DirExists(sLogPath)) // Check if SourceMod Log Folder Exists Otherwise Create One
		CreateDirectory(sLogPath, 511);
	
	char cTime[64];
	FormatTime(cTime, sizeof(cTime), "%Y%m%d");
	
	char sLogFile[PLATFORM_MAX_PATH];
	sLogFile = ADVR_LogFile;
	
	BuildPath(Path_SM, ADVR_LogFile, sizeof(ADVR_LogFile), "%s/%s%s.%s", LOG_FOLDER, LOG_PREFIX, cTime, LOG_EXT);
	
	#if _DEBUG
	LogDebug(false, "BuildLogFilePath - AFK Log Path: %s", ADVR_LogFile);
	#endif
	
	if (!StrEqual(ADVR_LogFile, sLogFile))
		LogAction(0, -1, "[AdvReports] Log File: %s", ADVR_LogFile);
} 