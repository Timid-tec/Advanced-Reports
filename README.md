# Disable-Radar
A source mod plugin simply made to remove the radar on the top right section in game, With the idea in mind for it to be more reliable for the servers to run with the intention of fewer memory leaks.

# Game Supported
- CS:GO

# ConVars
- sm_disableradar_enabled - Should we show radar on top-left. (0 off, 1 on)

# How to Install
- Donwload DisabledRadar.smx and put into /csgo/addons/sourcemod/plugins

# Updates

| Version | Change-Log          |
| ------- | ------------------ |
| 4.2.0   | Added if (client && GetClientTeam(client) > 1 || GetClientTeam(client) < 1) |
