--- This file quickly builds a configuration file for the watcher, with default values.


local config_file = [[---@class Watcher.config
---@field watcher_name string The name of this instance of the watcher. This is used to identify the watcher in logs and messages.
---@field log_file string The file to log player activity to.
---@field webhook Watcher.config.Webhook Information about the global webhook to send messages to.
---@field uses_webhook boolean If true, the watcher will send messages to the webhook defined by `webhook`.
---@field global_whitelist string[] A list of player names that are whitelisted globally. If a player is in this list, they don't need to be added to the whitelisted list of each area.
---@field log_data Watcher.config.LoggedCoords[] The coordinates to log player activity for.
---@field player_detectors Watcher.config.PlayerDetector[] The list of player detectors in use, with some small amount of metadata for each.
---@field dimension "minecraft:overworld"|"minecraft:the_nether"|"minecraft:the_end"|string The dimension of the area being logged.
---@field exit_timeout number The "time" (in scans) to wait without detecting a player before considering them to have exited a given area.
---@field detector_range number The range in blocks to check for players around each player detector
---@field detectors_have_range boolean If true, detectors require a range to be set, otherwise a single detector will be able to cover the entire world.
---@field scan_interval number The interval in seconds that the watcher will scan for players in the world. If it takes longer than this to scan, the next scan will occur immediately after the previous scan finishes.

---@class Watcher.config.Webhook The global webhook to send messages to.
---@field url string The URL of the discord webhook to send messages to.
---@field name string The name to use for the webhook.
---@field avatar string The avatar to use for the webhook.

---@class Watcher.config.LoggedCoords The coordinates to log player activity for.
---@field name string The name of the area to log.
---@field whitelist string[] A list of player names that are whitelisted for this area only.
---@field first Watcher.config.Coords.Position The first position of the area to log.
---@field second Watcher.config.Coords.Position The second position of the area to log.

---@class Watcher.config.Coords.Position The position of the area to log.
---@field x number The x coordinate of the position.
---@field y number The y coordinate of the position.
---@field z number The z coordinate of the position.

---@class Watcher.config.PlayerDetector
---@field network_name string The name of the detector on the network.
---@field display_name string The name to display for the detector.
---@field position Watcher.config.Coords.Position? The position of the detector, if supplied.
---@field radius_mode boolean If in radius mode, the detector will log players entering the radius around it.
---@field whitelist string[] A list of player names that are whitelisted for this detector only.
---@field group string? The group this detector belongs to, if any. This is used to group detectors together when in radius mode. Detectors belonging to the same group will not trigger again if a player moved from one detector to another.

---@type Watcher.config
return {
  --##### Metadata about this watcher instance. #####--

  -- The name of this instance of the watcher.
  watcher_name = "%s",

  -- The dimension this watcher is operating in.
  dimension = "%s",

  -- The file to log player activity to.
  log_file = "%s",


  --##### Scanner configuration. #####--


  -- If true, detectors require a range (and cannot just use `getPlayer` without them being in range).
  detectors_have_range = %s,

  -- The range in blocks to check for players around each player detector
  detector_range = %d,

  -- The time (in seconds) between scans for players in the world.
  scan_interval = %d,

  -- The timeout (in scans) to wait without detecting a player in an area or radius before considering them to have exited.
  exit_timeout = %d,

  -- A list of player names that are whitelisted globally. Whitelisted players are not logged.
  global_whitelist = %s,


  --##### Webhook configuration. #####--


  -- If true, the watcher will send messages to the webhook defined by `webhook`.
  uses_webhook = %s,
  webhook = {
    -- The name to use for the webhook.
    name = "%s",

    -- The URL of the discord webhook to send messages to.
    url = "%s",

    -- The avatar to use for the webhook.
    avatar = "%s"
  },


  --##### Areas to log player activity for. #####--


  log_data = %s,


  --##### Player detectors in use. #####--


  player_detectors = %s
}]]

-- Lazy hack to make the output look a bit nicer.
local _print = print
local function print(...)
  _print(" -", ...)
end

local defaults = {
  watcher_name = "Enter Name Here",
  dimension = "minecraft:overworld",
  log_file = "watcher.log",

  detectors_have_range = true,
  detector_range = 32,
  scan_interval = 1,
  exit_timeout = 3,
  global_whitelist = {},

  uses_webhook = false,
  webhook = {
    -- The name to use for the webhook.
    name = "Watcher",

    -- The URL of the discord webhook to send messages to.
    url = "https://...",

    -- The avatar to use for the webhook.
    avatar = "https://..."
  },

  log_data = {
    {
      name = "Example Area",
      first = { x = 0, y = 50, z = 0 },
      second = { x = 50, y = 100, z = 50 },
      whitelist = {},
    },
  },

  player_detectors = {}
}

local copied_keys = {
  "watcher_name",
  "log_file",
  "uses_webhook",
  "webhook",
  "dimension",
  "global_whitelist",
  "exit_timeout",
  "detector_range",
  "detectors_have_range",
  "scan_interval",
  "log_data"
}

local ok, previous_config = pcall(require, "watcher-conf")
if type(previous_config) == "string" then previous_config = nil end ---@diagnostic disable-line: cast-local-type

-- Collect the player detectors on the network.
local player_detectors = { peripheral.find("playerDetector") }
local detectors_config = {}

local alphabetic_names = {
  "Alice",
  "Bob",
  "Charlie",
  "Dave",
  "Eve",
  "Frank",
  "Grace",
  "Heidi",
  "Ivan",
  "Judy",
  "Karl",
  "Liam",
  "Mallory",
  "Nina",
  "Oscar",
  "Peggy",
  "Quentin",
  "Rupert",
  "Sybil",
  "Trent",
  "Uma",
  "Victor",
  "Walter",
  "Xena",
  "Yara",
  "Zara"
}
local name_idx = 1
local function next_name()
  local name = alphabetic_names[name_idx]
  name_idx = name_idx + 1
  if name_idx > #alphabetic_names then
    name_idx = 1
  end
  return name
end

if #player_detectors == 0 then
  player_detectors = {}
else
  -- If we have player detectors, build the configuration for them.
  for _, detector in ipairs(player_detectors) do
    local detector_config = {
      network_name = peripheral.getName(detector),
      display_name = next_name(),
      radius_mode = false,
      whitelist = {}
    }
    table.insert(detectors_config, detector_config)
  end
end

if previous_config then
  print("Found previous configuration, copying over relevant keys...")

  -- We need to copy keys from the previous config, and determine which detectors are in the old config.
  for _, key in ipairs(copied_keys) do
    defaults[key] = previous_config[key]
  end

  print("Checking for previous player detectors...")
  -- If the previous config has player detectors, we need to copy them over.
  local previous_detectors = previous_config.player_detectors or {}
  local previous_detector_names = {}
  for _, detector in ipairs(previous_detectors) do
    previous_detector_names[detector.network_name] = detector
  end

  print("Found", #previous_detectors, "previous player detectors. Finding them in the previous config.")
  -- Find the previous detectors that are still present, and copy the configuration.
  local new_detector_set = {}
  for _, detector in ipairs(detectors_config) do
    local previous_detector = previous_detector_names[detector.network_name]
    if previous_detector then
      -- Copy the display name and radius mode from the previous detector.
      detector.display_name = previous_detector.display_name
      detector.radius_mode = previous_detector.radius_mode
      detector.whitelist = previous_detector.whitelist
      detector.group = previous_detector.group
      detector.position = previous_detector.position
    end
    new_detector_set[detector.network_name] = true
  end

  -- Notify of all previous detectors that were not found in the new configuration.
  for _, previous_detector in pairs(previous_detector_names) do
    if not new_detector_set[previous_detector.network_name] then
      printError("Detector", previous_detector.network_name, "( named", previous_detector.display_name, ") was not found.")
      printError("  -> It will be omitted from the new configuration.")
      print("Warning: Previous detector", previous_detector.network_name, "not found in the new configuration. It will be ignored.")
    end
  end
end

previous_config = previous_config or defaults

local function tab_forward(str, n)
  -- Add n spaces to the beginning of each line in str (except the first line).
  return str:gsub("\n", "\n" .. string.rep(" ", n or 2))
end


local config_str = string.format(
  config_file,
  previous_config.watcher_name or defaults.watcher_name,
  previous_config.dimension or defaults.dimension,
  previous_config.log_file or defaults.log_file,
  previous_config.detectors_have_range or defaults.detectors_have_range,
  previous_config.detector_range or defaults.detector_range,
  previous_config.scan_interval or defaults.scan_interval,
  previous_config.exit_timeout or defaults.exit_timeout,
  tab_forward(textutils.serialize(previous_config.global_whitelist or defaults.global_whitelist)),
  previous_config.uses_webhook or defaults.uses_webhook,
  previous_config.webhook and previous_config.webhook.name or defaults.webhook.name,
  previous_config.webhook and previous_config.webhook.url or defaults.webhook.url,
  previous_config.webhook and previous_config.webhook.avatar or defaults.webhook.avatar,
  tab_forward(textutils.serialize(previous_config.log_data or defaults.log_data)),
  tab_forward(textutils.serialize(detectors_config))
)

if fs.exists("watcher-conf.lua.bak") then
  print("Removing old backup file watcher-conf.lua.bak...")
  fs.delete("watcher-conf.lua.bak")
end

if fs.exists("watcher-conf.lua") then
  print("Backing up old configuration file watcher-conf.lua to watcher-conf.lua.bak...")
  fs.move("watcher-conf.lua", "watcher-conf.lua.bak")
end

print("Creating new configuration file watcher-conf.lua...")
local handle, err = fs.open("watcher-conf.lua", "w")
if not handle then
  error("Failed to open watcher-conf.lua for writing: " .. err)
end
handle.write(config_str)
handle.close()

term.setTextColor(colors.green)
print("Configuration file watcher-conf.lua created successfully.")