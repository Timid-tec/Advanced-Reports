#if defined _debug_included
#endinput
#endif
#define _debug_included

/* Change this to enable debug */
#define _DEBUG 											0 // 1 = Small Debug, 2 = Minimum, 3 = Full Debug
#define _DEBUG_MODE										1 // 1 = Log to File, 2 = Log to Game Logs, 3 = Print to Chat, 4 = Print to Console

#define LOG_FOLDER										"logs"
#define LOG_PREFIX										"debug_"
#define LOG_EXT											"log"

/* Log File */
char Debug_LogFile[PLATFORM_MAX_PATH];

#if _DEBUG
ConVar hCvarLogDebug = null;
#endif

/* Log Functions */
void BuildLogFilePath() // Build Log File System Path
{
	char sLogPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sLogPath, sizeof(sLogPath), LOG_FOLDER);
	
	if (!DirExists(sLogPath)) // Check if SourceMod Log Folder Exists Otherwise Create One
		CreateDirectory(sLogPath, 511);
	
	char cTime[64];
	FormatTime(cTime, sizeof(cTime), "%Y%m%d");
	
	char sLogFile[PLATFORM_MAX_PATH];
	sLogFile = Debug_LogFile;
	
	BuildPath(Path_SM, Debug_LogFile, sizeof(Debug_LogFile), "%s/%s%s.%s", LOG_FOLDER, LOG_PREFIX, cTime, LOG_EXT);
	
	#if _DEBUG
	LogDebug(false, "BuildLogFilePath - AFK Log Path: %s", Debug_LogFile);
	#endif
	
	if (!StrEqual(Debug_LogFile, sLogFile))
		LogAction(0, -1, "[Debug] Log File: %s", Debug_LogFile);
}

/* Debug Functions */
#if _DEBUG
void LogDebug(bool Translation, char[] text, any:...)/* Debug Log Function */
{
	if (hCvarLogDebug != INVALID_HANDLE)
		if (!GetConVarBool(hCvarLogDebug))
		return;
	
	char message[255];
	if (Translation)
		VFormat(message, sizeof(message), "%T", 2);
	else
		if (strlen(text) > 0)
		VFormat(message, sizeof(message), text, 3);
	else
		return;
	
	#if _DEBUG_MODE == 1
	LogToFile(MS_LogFile, "%s", message);
	#elseif _DEBUG_MODE == 2
	LogToGame("[Debug] %s", message);
	#elseif _DEBUG_MODE == 3
	PrintToChatAll(" \x10[Debug] \x0A%s", message);
	#elseif _DEBUG_MODE == 4
	for (int i = 1; i <= MaxClients; i++)
	if (IsClientInGame(i) && IsClientConnected(i) && !IsClientSourceTV(i) && !IsFakeClient(i))
		PrintToConsole(i, "[Debug] %s", message);
	#endif
}
#endif