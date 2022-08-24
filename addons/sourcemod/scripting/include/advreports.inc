#if defined _advreports_included
#endinput
#endif
#define _advreports_included

#define MSG_LENGTH 192
#define PI 3.1415926535897932384626433832795
#define PLUGIN_AUTHOR "Timid"
#define PLUGIN_VERSION "4.2.0"
#define PREFIX "[SM]"

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++)

#define LoopIngameClients(%1) for(int %1=1;%1<=MaxClients;%1++)\
if (IsClientInGame( % 1))
	
#define LoopIngamePlayers(%1) for(int %1=1;%1<=MaxClients;%1++)\
if (IsClientInGame( % 1) && !IsFakeClient( % 1))
	
#define LoopAlivePlayers(%1) for(int %1=1;%1<=MaxClients;%1++)\
if (IsClientInGame( % 1) && IsPlayerAlive( % 1))
	
stock void HookEvents()
{
	HookEvent("round_start", Event_Round_Start, EventHookMode_Pre);
	HookEvent("round_end", Event_Round_End, EventHookMode_Pre);
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("player_death", Event_Player_Death);
} 