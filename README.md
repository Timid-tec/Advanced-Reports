<p align="center">
  <img src="assets/advanced-reports-banner.svg" alt="Advanced Reports animated banner" width="100%">
</p>

# Advanced Reports

Advanced Reports is a SourceMod player-reporting plugin with in-game menus, SQLite or MySQL storage, administrator actions, and optional Discord webhook notifications.

Version **4.5.0** targets and is compiled with **SourceMod 1.12.0.7041**.

## Drag-and-drop installation

For a Linux game server, download [AdvancedReports-4.5.0-sm1.12-linux.zip](dist/AdvancedReports-4.5.0-sm1.12-linux.zip) and extract it directly into the game directory, such as `csgo/`. The archive includes:

- `AdvancedReports.smx`
- `advanced_reports.sp` source
- The official SteamWorks 1.2.3c Linux extension for Discord webhooks
- Report reasons
- An editable `cfg/sourcemod/AdvancedReports.cfg`
- Installation instructions, changelog, and third-party notices

The default `storage-local` database uses SourceMod's built-in SQLite support. It requires no database configuration, so reporting works immediately after the plugin loads.

The SteamWorks project's official 1.2.3c release does not provide a Windows DLL. On Windows, install the core files and add a compatible `SteamWorks.ext.dll` separately if Discord notifications are required. Reporting and SQLite storage still work without SteamWorks.

## Commands

Players can open the report menu with:

- `!report` or `/report`
- `!calladmin` or `/calladmin`

Administrators can use `!reports` or `/reports` to open saved reports; this requires the slay flag. Kick and ban actions separately check the kick and ban flags. These checks can be customized with `sm_advreports_kick`, `sm_advreports_ban`, and `sm_advreports_immunity` in `admin_overrides.cfg`.

## Configuration

Edit `cfg/sourcemod/AdvancedReports.cfg`:

- `sm_advreports_database` - database entry; defaults to setup-free `storage-local` SQLite
- `sm_advreports_cooldown` - seconds each player waits between reports; defaults to `60`
- `sm_advreports_duplicate_window` - seconds before the same reporter can report the same target again; defaults to `600`
- `sm_advreports_custom_reasons` - enables private chat input for reasons marked `"custom" "1"`; defaults to `1`
- `sm_advreports_notify_admins` - alerts admins with access to `!reports`; defaults to `1`
- `sm_advreports_admin_sound` - notification sound; blank disables it
- `sm_advreports_protect_admins` - hides admins with immunity access from report targets; defaults to `0`
- `sm_advreports_discord` - enables Discord notifications; defaults to `0`
- `sm_advreports_webhook` - private Discord webhook URL
- `sm_advreports_server_address` - public `IP:port`; blank derives it from `hostip` and `hostport`

After changing the database setting, restart the server or reload the plugin.

### Discord webhooks

The Linux package contains the SteamWorks extension needed to send webhooks. Set:

```text
sm_advreports_discord "1"
sm_advreports_webhook "https://discord.com/api/webhooks/..."
```

Restart the server and run `sm exts list` to confirm SteamWorks is loaded. Never publish a real webhook URL; treat it like a password.

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
- Confirmation before every report submission
- Private custom-reason input through chat, with `!cancel` support
- General reporter cooldown plus a separate reporter-target duplicate window
- Optional admin immunity using SourceMod command overrides
- Immediate online-admin chat and sound notifications
- Setup-free SQLite or optional shared MySQL storage
- Asynchronous and escaped database queries
- One current report per Steam ID
- Kick, permanent-ban, report deletion, and optional server redirect actions
- Rich Discord embeds with map, player count, target state, and direct-connect link
- Dedicated audit log at `addons/sourcemod/logs/advancedreports.log`
- Reproducible build and package scripts pinned to SourceMod 1.12.0.7041

## Design inspiration

The 4.5.0 workflow was informed by established open-source report plugins while the implementation here remains native to Advanced Reports:

- [Impact123/CallAdmin](https://github.com/Impact123/CallAdmin) inspired confirmation, custom reasons, immunity, and admin notification concepts.
- [srcdslab/sm-plugin-CallAdmin](https://github.com/srcdslab/sm-plugin-CallAdmin) inspired richer Discord context and audible admin alerts.
- [oppars01/csgo-advanced-report](https://github.com/oppars01/csgo-advanced-report) inspired stronger duplicate-report controls and moderation history concepts.
- [KeidaS/Report-System](https://github.com/KeidaS/Report-System) informed the review of admin ownership and workflow ideas.

Automatic punishment based only on report counts is intentionally not included because coordinated false reports could abuse it.

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
| 4.5.0 | Added submission confirmation, private custom reasons, reporter-target duplicate protection, optional admin immunity, live admin alerts, richer Discord embeds, and report/admin audit logging |
| 4.4.0 | Added `!report`, setup-free SQLite, editable cfg, and a Linux drag-and-drop package with the SteamWorks webhook extension |
| 4.3.0 | SourceMod 1.12.0.7041 compatibility, full compile/runtime cleanup, safe SQL, fixed admin actions, optional integrations, and reproducible builds |
| 4.2.2 | Include-file fixes and general maintenance |
| 4.2.0 | Initial GitHub release |
