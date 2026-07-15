ADVANCED REPORTS 4.5.0 - SOURCEMOD 1.12 - LINUX
================================================

1. Extract this ZIP directly into your game's directory (for example, csgo/).
2. Edit cfg/sourcemod/AdvancedReports.cfg.
3. Restart the server or load addons/sourcemod/plugins/AdvancedReports.smx.

The matching SourcePawn source is included at
addons/sourcemod/scripting/AdvancedReports.sp.

The default storage-local database uses SourceMod's built-in SQLite support, so
no database setup is required. Reports are available with !reports to admins.

PLAYER COMMANDS
  !report
  /report
  !calladmin
  /calladmin

REPORT WORKFLOW
  Select a player and reason, then confirm the report before it is submitted.
  Choosing Other Reason lets you type a private reason in chat. Type !cancel
  to leave the private reason prompt without sending a report.

ADMIN COMMAND
  !reports

DISCORD WEBHOOKS
  This package includes the official SteamWorks 1.2.3c Linux extension.
  Set these values in cfg/sourcemod/AdvancedReports.cfg:

    sm_advreports_discord "1"
    sm_advreports_webhook "https://discord.com/api/webhooks/..."

  Treat the webhook URL like a password. Do not share or commit it.

VERIFY INSTALLATION
  Run "sm plugins list" and confirm Advanced Reports 4.5.0 is loaded.
  Run "sm exts list" and confirm SteamWorks is loaded for Discord webhooks.

This archive contains SteamWorks.ext.so for Linux. A Windows server needs a
compatible SteamWorks.ext.dll installed separately for Discord notifications.
