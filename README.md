# AP Watcher

This program leverages Advanced Peripherals to monitor when players enter and leave specific areas in your world. It has the option to log directly to a discord webhook, and logs to a file by default.

# Features
- Monitors player entry and exit in specified cuboid areas.
- Monitors player entry and exit around player detectors.
- Supports logging to a file and sending notifications to a Discord webhook.

# Requirements
- CC:Tweaked
- Advanced Peripherals

# Installation

1. Run `wget run https://raw.githubusercontent.com/Fatboychummy-CC/AP-Watcher/main/installer.lua`.
2. Follow the prompts to install the program.
3. Connect your computer to one or more player detectors.
4. Create the initial config file by running `build_conf.lua`.
5. Edit the config file to change information about the areas you want to monitor, and the detectors you want to use.
6. Run `watcher.lua` to start monitoring.

# Configuration

`build_conf.lua` will generate a configuration file for you to edit, and can be ran even after you have already set up the watcher with your own configuration file. Old values will be preserved, and a backup of the old configuration file will be created, `build_conf.lua.bak`. If you want to reset the configuration file, you can delete the old one and run `build_conf.lua` again.

The generated configuration file will be called `watcher-conf.lua`. The following options are available:

- `watcher_name`: The name of the watcher. Displayed only in Discord upon starting up and erroring.
- `dimension`: The dimension this watcher is in. Appended to logs.
- `log_file`: The file to log to. Defaults to `watcher.log`.
- `detectors_have_range`: By default, AP does not enforce restrictions on player detectors, meaning they can just... See every player at any range, even cross-dimension. If you or your server operator has set up player detectors to have a range, set this to `true` to enable range checking.
- `detector_range`: The range of the player detectors, if `detectors_have_range` is set to `true`. Defaults to 32.
- `scan_interval`: The interval in seconds between scans for player entry and exit. Defaults to 1.
- `exit_timeout`: The time in *scans* (not seconds!) after which a player is considered to have exited an area if they are not detected. Defaults to 3
- `global_whitelist`: A list of players that are never logged as entering or exiting areas. Defaults to an empty list.
- `uses_webhook`: Whether to send notifications to a Discord webhook. Defaults to `false`.
- `webhook`: A table containing the following:
  - `username`: The username to use for the webhook. Defaults to "Watcher".
  - `url`: The URL of the Discord webhook.
  - `avatar_url`: The URL of the avatar to use for the webhook.
- `log_data`: Explained below.
- `player_detectors`: explained below.

## `log_data`
This is a table containing the areas to monitor. Each area is defined by a name and a cuboid, with the following structure:

```lua
{
  name = "Area Name", -- The name of the area, displayed in logs and Discord notifications.
  first = { x = 0, y = 0, z = 0 }, -- First corner of the cuboid.
  second = { x = 10, y = 10, z = 10 }, -- Second corner of the cuboid.
  whitelist = { "player1", "player2" }, -- Per-location whitelist. Needs to be at least an empty table.
}
```

## `player_detectors`
This is a list of player detectors that are monitored, with the following structure for each detector:

```lua
{
  network_name = "...", -- The name of the detector on the wired network.
  display_name = "Detector Name", -- The name to display in logs and Discord notifications.
  whitelist = { "player1", "player2" }, -- Per-detector whitelist. Needs to be at least an empty table.
  radius_mode = false, -- Explained below
  group = "group_name", -- Optional. The group this detector belongs to. If multiple detectors are in the same group, they will be treated as a single detector for logging purposes.
}
```

### `radius_mode`
If `radius_mode` is set to `true`, the detector will contribute to cuboid areas as usual, but will also log players entering and exiting the radius of the detector (with the radius defined by `detector_range`). This can be useful if you don't want to write out cuboid positions, and just want to monitor players around detectors you've preplaced at specific locations.