# Advanced Reports

Advanced Reports is a SourceMod player-reporting plugin. Players can report another player from an in-game menu, reports are stored in MySQL, and administrators can review and act on reports from a second menu.

This release targets and is compiled with **SourceMod 1.12.0.7041**.

## Features

- Race-safe per-client player, reason, report, and admin menus
- Asynchronous MySQL queries with escaped player-controlled values
- One current report per Steam ID; a new report updates the existing record
- Working kick, permanent-ban, report deletion, and optional server-redirect actions
- Optional Discord webhook notifications through SteamWorks
- Reproducible build script and GitHub compile check pinned to SourceMod 1.12.0.7041

## Requirements

- A Source server running SourceMod 1.12
- A MySQL entry named `advancedreports` in `addons/sourcemod/configs/databases.cfg`
- Optional: [SteamWorks](https://github.com/KyleSanderson/SteamWorks) for Discord notifications
- Optional: a compatible `server_redirect.smx` providing the `RedirectClient` native, such as the [GAMMA CASE Server Redirect source](https://github.com/EvanIMK/BHOP-Server/blob/master/SERVER/addons/sourcemod/scripting/server_redirect.sp), for the **Go to reported server** action

Example database entry:

```text
"advancedreports"
{
    "driver"    "mysql"
    "host"      "127.0.0.1"
    "database"  "advancedreports"
    "user"      "source"
    "pass"      "change-me"
    "port"      "3306"
}
```

The plugin creates and updates the `aReports` table automatically. The database user therefore needs `CREATE`, `ALTER`, `SELECT`, `INSERT`, `UPDATE`, and `DELETE` permissions for this table.

## Installation

Copy the repository's `addons/sourcemod` directory into the server's game directory. At minimum, install:

- `addons/sourcemod/plugins/AdvancedReports.smx`
- `addons/sourcemod/configs/advreport/advreasons.cfg`

Start or restart the server, then edit the generated file at `cfg/sourcemod/AdvancedReports.cfg` if needed.

## Commands

- `sm_calladmin` — opens the player report menu
- `sm_reports` — opens the report administration menu; requires the slay flag

The kick and ban actions also check the administrator's kick and ban flags. These checks can be overridden with `sm_advreports_kick` and `sm_advreports_ban` in `admin_overrides.cfg`.

## ConVars

- `sm_advreports_discord` — enables Discord notifications (`0` by default)
- `sm_advreports_webhook` — Discord webhook URL; blank by default and protected from normal ConVar display
- `sm_advreports_server_address` — public `IP:port` used in reports and redirects; when blank, the plugin derives it from `hostip` and `hostport`
- `sm_advreports_cooldown` — seconds each player must wait between reports (`60` by default)

Never commit a real Discord webhook URL. Treat it like a password and configure it only on the game server.

## Building

Run the PowerShell build script from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

The script downloads the exact SourceMod 1.12.0.7041 compiler and a pinned SteamWorks include into the ignored `.build` directory. It fails on compiler errors or warnings and writes the verified binary to `addons/sourcemod/plugins/AdvancedReports.smx`.

To use an existing SourceMod 1.12.0.7041 installation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 `
    -CompilerRoot "C:\path\to\sourcemod-1.12.0-git7041"
```

## Version history

| Version | Changes |
| --- | --- |
| 4.3.0 | SourceMod 1.12.0.7041 compatibility, full compile/runtime cleanup, safe SQL, fixed admin actions, optional integrations, and reproducible builds |
| 4.2.2 | Include-file fixes and general maintenance |
| 4.2.0 | Initial GitHub release |
