# Changelog

## 4.5.0 - 2026-07-15

### Added

- A confirmation menu before every player report is submitted.
- Private custom-reason entry through chat for reason entries marked `"custom" "1"` in `advreasons.cfg`.
- `!cancel` and `/cancel` support while entering a custom reason.
- A reporter-target duplicate window controlled by `sm_advreports_duplicate_window`.
- Optional report-target immunity controlled by `sm_advreports_protect_admins` and the `sm_advreports_immunity` override.
- Online-admin chat alerts controlled by `sm_advreports_notify_admins`.
- Optional admin notification sound controlled by `sm_advreports_admin_sound`.
- Discord embed fields for map, connected player count, and the target's team/alive state.
- Successful report and admin-action logging in `addons/sourcemod/logs/advancedreports.log`.

### Changed

- The default `Other Reason` option now prompts the reporter for a private explanation.
- Report targets and cooldowns are revalidated immediately before database submission.
- Asynchronous report deletion now keeps its original target context, avoiding stale menu state in its callback.
- The release package and plugin version are now 4.5.0.

### Compatibility

- Compiled and warning-checked with SourceMod 1.12.0.7041.
- No database schema change is required when upgrading from 4.4.0.

## 4.4.0

- Added `!report`, setup-free SQLite storage, an editable cfg, and the Linux drag-and-drop package with SteamWorks webhook support.

## 4.3.0

- Added SourceMod 1.12.0.7041 compatibility, escaped asynchronous SQL, repaired admin actions, optional integrations, and reproducible builds.
