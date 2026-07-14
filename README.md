# Advanced Reports

Advanced Reports is a SourceMod player-reporting plugin with in-game menus, SQLite or MySQL storage, administrator actions, and optional Discord webhook notifications.

Version **4.4.0** targets and is compiled with **SourceMod 1.12.0.7041**.

## Drag-and-drop installation

For a Linux game server, download [AdvancedReports-4.4.0-sm1.12-linux.zip](dist/AdvancedReports-4.4.0-sm1.12-linux.zip) and extract it directly into the game directory, such as `csgo/`. The archive includes:

- `AdvancedReports.smx`
- The official SteamWorks 1.2.3c Linux extension for Discord webhooks
- Report reasons
- An editable `cfg/sourcemod/AdvancedReports.cfg`
- Installation instructions and third-party notices

The default `storage-local` database uses SourceMod's built-in SQLite support. It requires no database configuration, so reporting works immediately after the plugin loads.

The SteamWorks project's official 1.2.3c release does not provide a Windows DLL. On Windows, install the core files and add a compatible `SteamWorks.ext.dll` separately if Discord notifications are required. Reporting and SQLite storage still work without SteamWorks.

## Commands

Players can open the report menu with any of these chat commands:

- `!report` or `/report`
- `!calladmin` or `/calladmin`

Administrators can use:

- `!reports` or `/reports` — opens saved reports; requires the slay flag

Kick and ban actions also check the administrator's kick and ban flags. Override those checks with `sm_advreports_kick` and `sm_advreports_ban` in `admin_overrides.cfg` if needed.

## Configuration

Edit `cfg/sourcemod/AdvancedReports.cfg`:

- `sm_advreports_database` — SourceMod database entry; defaults to `storage-local` for setup-free SQLite
- `sm_advreports_cooldown` — seconds each player must wait between reports; defaults to `60`
- `sm_advreports_discord` — enables Discord notifications; defaults to `0`
- `sm_advreports_webhook` — private Discord webhook URL
- `sm_advreports_server_address` — public `IP:port`; blank derives it from `hostip` and `hostport`

After editing the database setting, restart the server or reload the plugin.

### Discord webhooks

The Linux package already contains the SteamWorks extension needed to send webhooks. Set:

```text
sm_advreports_discord "1"
sm_advreports_webhook "https://discord.com/api/webhooks/..."
```

Restart the server and run `sm exts list` to confirm SteamWorks is loaded. Never publish a real webhook URL—treat it like a password.

### Optional MySQL storage

Set `sm_advreports_database "advancedreports"` and add this entry to `addons/sourcemod/configs/databases.cfg`:

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

The MySQL user needs `CREATE`, `ALTER`, `SELECT`, `INSERT`, `UPDATE`, and `DELETE` permissions for the automatically managed `aReports` table.

## Features

- Per-client player, reason, report, and administrator menus
- Setup-free SQLite or optional shared MySQL storage
- Asynchronous and escaped database queries
- One current report per Steam ID
- Kick, permanent-ban, report deletion, and optional server redirect actions
- Discord webhook notifications through optional SteamWorks HTTP support
- Player report cooldown
- Reproducible build and package scripts pinned to SourceMod 1.12.0.7041

## Building

Compile the plugin:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

Compile and generate the Linux drag-and-drop package:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Package
```

The build downloads the exact SourceMod compiler and a pinned SourceMod 1.12-compatible SteamWorks include into the ignored `.build` directory. Packaging additionally downloads the official SteamWorks 1.2.3c Linux release, validates its SHA-256 checksum, and creates the ZIP in `dist/`.

To use an existing SourceMod 1.12.0.7041 installation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 `
    -CompilerRoot "C:\path\to\sourcemod-1.12.0-git7041"
```

## Version history

| Version | Changes |
| --- | --- |
| 4.4.0 | Added `!report`, setup-free SQLite, editable cfg, and a Linux drag-and-drop package with the SteamWorks webhook extension |
| 4.3.0 | SourceMod 1.12.0.7041 compatibility, full compile/runtime cleanup, safe SQL, fixed admin actions, optional integrations, and reproducible builds |
| 4.2.2 | Include-file fixes and general maintenance |
| 4.2.0 | Initial GitHub release |
