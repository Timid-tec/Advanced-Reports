ConVar g_cvDiscordWebEnable;
ConVar g_cvDiscordWebHook;

Menu gMenuHandles[MAXPLAYERS + 1];
Handle gPMenu;
Handle DetailsMenu;
Handle kv;
Handle g_aReportsDB;

int gWebHookEnabled;
int selectedClient;

char gSelectedClientSteam[256];
char gClientSteam[256];
char g_CmdResponse[128][256];
char gCmdName[32];
char gBuffer[256];
char gAuth[32];
char gClientAuth[32];
char gDate[36];
char gReason[56];
char gHostname[64];
char gServerIpA[38];
char gServerIp[32];
char gServerPort[16];
char gWebHook[128];
char gReporterID[128];
char gTargetID[128];
char playername[MAX_NAME_LENGTH + 8];
char steamid[20];
char reporter[36];
char date[36];
char serverIp[38];


void CreateCvars()
{
	g_cvDiscordWebEnable = CreateConVar("sm_advreports_discord", "1", "Should we print to the discord server, reports? (0 off, 1 on)");
	g_cvDiscordWebHook = CreateConVar("sm_advreports_webhook", "https://discord.com/api/webhooks/889719179568091156/TbqmZs5apwYqI-XOrzFxXMv3a7WtpQtRX07Y81dT8dLBJsgdPVhNp11chask4zfKJHRa", "Sets where the webhook should send. (def, https://discord.com/api/webhooks/)");
	
	g_cvDiscordWebEnable.AddChangeHook(OnConVarChanged);
	g_cvDiscordWebHook.AddChangeHook(OnConVarChanged);
}

void GetCvarValues()
{
	gWebHookEnabled = g_cvDiscordWebEnable.BoolValue;
	GetConVarString(g_cvDiscordWebHook, gWebHook, sizeof(gWebHook));
}

public void OnConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvDiscordWebEnable)
	{
		gWebHookEnabled = g_cvDiscordWebEnable.BoolValue;
	}
	if (convar == g_cvDiscordWebHook)
	{
		GetConVarString(g_cvDiscordWebHook, gWebHook, sizeof(gWebHook));
	}
}
