public Action CMD_PlayerList(int client, int args)
{
	Menu plMenu = new Menu(PlayerMenuHNDLR);
	plMenu.SetTitle("Player(s):");
	LoopIngamePlayers(x)
	{
		char info[32];
		IntToString(x, info, sizeof(info));
		char name[MAX_NAME_LENGTH + 5];
		Format(name, sizeof(name), "%N", x);
		plMenu.AddItem(info, name);
	}
	plMenu.Display(client, MENU_TIME_FOREVER);
}

public Action Menu_gReason(int client, int args)
{
	DisplayMenu(gRMenu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action CMD_Reports(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	DumbDB(client);
	return Plugin_Handled;
}

