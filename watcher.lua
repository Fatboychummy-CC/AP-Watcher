--- Watcher
--- This program watches locations using Advanced Peripherals' Player Detector, logging
--- when players enter and leave the given areas over discord or console.

local conf = require("watcher-conf")

local headers = {
  ["Content-Type"] = "application/json"
}

---@class Watcher.PlayerDetector.PlayerData : Watcher.config.Coords.Position
---@field airSupply number The air supply of the player.
---@field dimension string The dimension the player is in.
---@field eyeHeight number The eye height of the player.
---@field health number The health of the player.
---@field maxHealth number The maximum health of the player.
---@field pitch number The pitch of the player.
---@field respawnAngle number The respawn angle of the player.
---@field respawnDimension string The dimension the player will respawn in.
---@field respawnPosition Watcher.config.Coords.Position? The position the player will respawn at, if set.
---@field x number The x coordinate of the player.
---@field y number The y coordinate of the player.
---@field z number The z coordinate of the player.
---@field yaw number The yaw of the player.



--- Checks if an object is inside a table.
---@param obj any The object to check.
---@param tbl table The table to check against.
---@return boolean in_table True if the object is in the table, false otherwise.
local function in_table(obj, tbl)
  for _, v in ipairs(tbl) do
    if v == obj then
      return true
    end
  end
  return false
end



--- Log that a player has entered or left an area.
---@param webhook_url string The URL of the discord webhook to send messages to.
---@param webhook_name string The name to use for the webhook.
local function send_webhook(webhook_url, webhook_name, webhook_avatar, message)
  local data = {
    username = webhook_name,
    avatar_url = webhook_avatar,
    content = message
  }

  local response, err = http.post(webhook_url, textutils.serializeJSON(data), headers)
  if not response then
    printError("Failed to send webhook:", err or "Unknown error")
    return
  end

  local response_body = response.readAll()
  response.close()

  if response.getResponseCode() ~= 204 then
    printError("Failed to send webhook:", response_body)
  end
end



local function log_to_file(message)
  -- Replace newlines with spaces for file logging
  -- Remove bold formatting
  message = message:gsub("\n", " "):gsub("**", "")

  local file = fs.open(conf.log_file, "a")
  if not file then
    error("Failed to open log file: " .. conf.log_file)
  end

  file.writeLine(("%s - %s"):format(os.date("%Y-%m-%d %H:%M:%S"), message))
  file.close()
end



--- Log a message.
---@param message string The message to log.
local function log_message(message)
  print(message)  -- Print to console for immediate feedback
  log_to_file(message)  -- Log to file
end



--- Log player entering a radius.
---@param player_name string The name of the player.
---@param detector Watcher.config.PlayerDetector The player detector that detected the player.
---@param detector_group string? The group of the detector that detected the player.
local function log_radius_enter(player_name, detector, detector_group)
  local message

  if detector_group then
    message = ("**%s** entered radius of **%s** \n-# %s (%s, %s)"):format(
      player_name,
      detector_group,
      conf.dimension,
      detector.display_name,
      detector.network_name
    )
  else
    message = ("**%s** entered radius of **%s** (%s) \n-# %s"):format(
      player_name,
      detector.display_name,
      detector.network_name,
      conf.dimension
    )
  end

  if conf.uses_webhook then
    send_webhook(
      conf.webhook.url,
      conf.webhook.name,
      conf.webhook.avatar,
      message
    )
  end

  log_message(message)
end



--- Log players leaving a radius.
---@param player_name string The name of the player.
---@param detector_group string The group of the detector that detected the player.
local function log_radius_exit(player_name, detector_group)
  local message = ("**%s** left radius of **%s** \n-# %s"):format(
    player_name,
    detector_group,
    conf.dimension
  )


  if conf.uses_webhook then
    send_webhook(
      conf.webhook.url,
      conf.webhook.name,
      conf.webhook.avatar,
      message
    )
  end

  log_message(message)
end



--- Log players entering a a box area.
---@param location_data Watcher.config.LoggedCoords The coordinates and data of the area being logged.
---@param player_name string The name of the player.
---@param player_data Watcher.PlayerDetector.PlayerData The data of the player.
local function log_box_enter(location_data, player_name,  player_data)
  local message = ("**%s** entered **%s** (%.02f, %.02f, %.02f) \n-# %s"):format(
    player_name,
    location_data.name,
    player_data.x, player_data.y, player_data.z,
    conf.dimension
  )

  if conf.uses_webhook then
    send_webhook(
      conf.webhook.url,
      conf.webhook.name,
      conf.webhook.avatar,
      message
    )
  end

  log_message(message)
end



--- Log players leaving a box area.
---@param location_name string The name of the area.
---@param player_name string The name of the player.
local function log_box_exit(location_name, player_name)
  local message = ("**%s** left **%s** \n-# %s"):format(
    player_name,
    location_name,
    conf.dimension
  )

  if conf.uses_webhook then
    send_webhook(
      conf.webhook.url,
      conf.webhook.name,
      conf.webhook.avatar,
      message
    )
  end

  log_message(message)
end



--- Get all logged areas that contain a given position.
---@param position Watcher.config.Coords.Position The position to test.
---@return Watcher.config.LoggedCoords[] areas The logged area(s) that contain the position.
local function get_areas(position)
  local areas = {}

  for _, area in ipairs(conf.log_data) do
    if area.first.x <= position.x and position.x <= area.second.x and
       area.first.y <= position.y and position.y <= area.second.y and
       area.first.z <= position.z and position.z <= area.second.z then
      -- The position is within the area.
      table.insert(areas, area)
    end
  end

  return areas
end



--- Used to keep track of players that have been detected in an area.
---@type table<string, table<string, table<string, boolean>>>
local alarm_groups = {
  box = {},
  radius = {}
}

--- Used to keep track of players that have been detected in an area, but have since left.
--- The number is the "time" (in scans) remaining before the player is considered "dead" in the area.
---@type table<string, table<string, table<string, number>>>
local alarm_groups_dead = {
  box = {},
  radius = {}
}
--- Test to see if a player is in any area.
--- 
--- This function runs all checks (i.e: whitelists, radius, previous detection, etc) and logs the player activity, and attempts to retrieve player data.
---@param detector Watcher.config.PlayerDetector The player detector that detected the player.
---@return string[] player_names The names of the players that were detected within any areas.
---@return table<string, table<string, table<string, boolean>>> box_groups The groups of boxes that the players were detected in.
local function test_detector(detector)
  local detector_group = detector.group or detector.network_name

  --- Keeps track of the current box groups, so that they can be updated later.
  ---@type table<string, table<string, table<string, boolean>>>
  local groups = {
    box = {},
    radius = {}
  }



  --- Handle players detected in the radius around the detector.
  ---@return string[] player_list
  local function handle_radius()
    if not detector.radius_mode then
      return {}
    end

    local radius = conf.detector_range

    local player_list, err = peripheral.call(detector.network_name, "getPlayersInCubic", radius, radius, radius)
    if not player_list or #player_list == 0 then
      if err then
        printError("Error getting players in radius for detector " .. detector.network_name .. ": " .. tostring(err))
      end
      return {}
    end

    -- Remove players that are whitelisted for this detector.
    for i = #player_list, 1, -1 do
      if in_table(player_list[i], detector.whitelist) then
        table.remove(player_list, i)
      end

      if in_table(player_list[i], conf.global_whitelist) then
        table.remove(player_list, i)
      end
    end

    -- Check if the players are currently in detected in the alarm group.
    for _, player_name in ipairs(player_list) do
      if not alarm_groups.radius[detector_group] then
        alarm_groups.radius[detector_group] = {}
      end
      if not groups.radius[detector_group] then
        groups.radius[detector_group] = {}
      end

      if not alarm_groups.radius[detector_group][player_name] then
        -- Mark the player as detected in this group.
        alarm_groups.radius[detector_group][player_name] = true
        groups.radius[detector_group][player_name] = true

        -- Ensure the player is not in the dead group.
        local was_in_dead = false
        if not alarm_groups_dead.radius[detector_group] then
          alarm_groups_dead.radius[detector_group] = {}
        end
        if alarm_groups_dead.radius[detector_group][player_name] then
          was_in_dead = true
        end
        alarm_groups_dead.radius[detector_group][player_name] = nil

        -- Log the player activity.
        if not was_in_dead then
          log_radius_enter(player_name, detector, detector_group)
        end
      end
    end

    return player_list
  end



  --- Handle players detected in box areas.
  ---@param player_datas table<string, Watcher.PlayerDetector.PlayerData>
  ---@return string[] player_list The players only detected within the box areas.
  local function handle_boxes(player_datas)
    local player_list_dict = {}

    for player_name, player_data in pairs(player_datas) do
      if not in_table(player_name, conf.global_whitelist) then
        local areas = get_areas(player_data)

        if #areas > 0 then
          for _, area in ipairs(areas) do
            if not in_table(player_name, area.whitelist) then
              if not alarm_groups.box[area.name] then
                alarm_groups.box[area.name] = {}
              end
              if not groups.box[area.name] then
                groups.box[area.name] = {}
              end

              if not alarm_groups.box[area.name][player_name] then
                -- Mark the player as detected in this area.
                alarm_groups.box[area.name][player_name] = true
                groups.box[area.name][player_name] = true

                -- Ensure the player is not in the dead group.
                local was_in_dead = false
                if not alarm_groups_dead.box[area.name] then
                  alarm_groups_dead.box[area.name] = {}
                end
                if alarm_groups_dead.box[area.name][player_name] then
                  was_in_dead = true
                end
                alarm_groups_dead.box[area.name][player_name] = nil

                -- Log the player activity.
                if not was_in_dead then
                  log_box_enter(area, player_name, player_data)
                end
              end

              -- Add the player to the list of players detected in boxes.
              player_list_dict[player_name] = true
            end
          end
        end
      end
    end

    local player_list = {}
    for player_name in pairs(player_list_dict) do
      table.insert(player_list, player_name)
    end
    return player_list
  end



  --- Collect player data from a list of player names.
  ---@return table<string, Watcher.PlayerDetector.PlayerData> player_datas
  local function collect_data_from_list(player_list)
    local player_datas = {}
    local p_n = #player_list
    local p_f = {}

    for i, player_name in ipairs(player_list) do
      p_f[i] = function()
        local player_data = peripheral.call(detector.network_name, "getPlayer", player_name)
        if not player_data then
          return
        end

        player_datas[player_name] = player_data
      end
    end

    parallel.waitForAll(table.unpack(p_f, 1, p_n))

    return player_datas
  end

  local detected_dict = {}

  if conf.detectors_have_range then
    local player_list = handle_radius()

    local player_datas = collect_data_from_list(player_list)

    handle_boxes(player_datas)

    for player_name in pairs(player_datas) do
      detected_dict[player_name] = true
    end
  else
    -- Infinite range! Woo!
    -- However, we will still check the radius.
    if detector.radius_mode then
      handle_radius()
    end

    local player_datas = collect_data_from_list(
      peripheral.call(detector.network_name, "getOnlinePlayers")
    )

    local player_list = handle_boxes(player_datas)
    for player_name in pairs(player_list) do
      detected_dict[player_name] = true
    end
  end

  local player_list = {}
  for player_name in pairs(detected_dict) do
    table.insert(player_list, player_name)
  end
  return player_list, groups
end


--- Check all player detectors to see if they have any activity.
local function check_detectors()
  -- Step 1: Decrement all dead players' timeouts.

  -- a: radius
  for detector_group, players in pairs(alarm_groups_dead.radius) do
    for player_name, timeout in pairs(players) do
      if timeout > 0 then
        alarm_groups_dead.radius[detector_group][player_name] = timeout - 1
      else
        -- The player is dead in this group, remove them and notify that they left.
        alarm_groups_dead.radius[detector_group][player_name] = nil

        log_radius_exit(player_name, detector_group)
      end
    end
  end

  -- b: box
  for area_name, players in pairs(alarm_groups_dead.box) do
    for player_name, timeout in pairs(players) do
      if timeout > 0 then
        alarm_groups_dead.box[area_name][player_name] = timeout - 1
      else
        -- The player is dead in this area, remove them and notify that they left.
        alarm_groups_dead.box[area_name][player_name] = nil

        log_box_exit(area_name, player_name)
      end
    end
  end

  -- Step 2: Check all detectors for activity.
  local player_names = {}
  local player_dict = {}
  local groups = {
    box = {},
    radius = {}
  }

  for _, detector in pairs(conf.player_detectors) do
    local detected_players, dgroups = test_detector(detector)
    if dgroups then
      for group_name, group_players in pairs(dgroups.box) do
        if not groups.box[group_name] then
          groups.box[group_name] = {}
        end

        for player_name in pairs(group_players) do
          groups.box[group_name][player_name] = true
        end
      end

      for group_name, group_players in pairs(dgroups.radius) do
        if not groups.radius[group_name] then
          groups.radius[group_name] = {}
        end

        for player_name in pairs(group_players) do
          groups.radius[group_name][player_name] = true
        end
      end
    end

    for _, player_name in ipairs(detected_players) do
      if not player_dict[player_name] then
        player_dict[player_name] = true
        table.insert(player_names, player_name)
      end
    end
  end

  -- Step 3: check over the box groups, and check for any leavers.

  -- a: Push new ones in.
  for group_name, group_players in pairs(groups.box) do
    if not alarm_groups.box[group_name] then
      alarm_groups.box[group_name] = {}
    end
    if not alarm_groups_dead.box[group_name] then
      alarm_groups_dead.box[group_name] = {}
    end

    for player_name in pairs(group_players) do
      if not alarm_groups.box[group_name][player_name] then
        -- The player is new to this group.
        alarm_groups.box[group_name][player_name] = true

        -- Ensure the player is not in the dead group.
        alarm_groups_dead.box[group_name][player_name] = nil
      end
    end
  end

  -- b: Push the leavers to the dead group.
  for group_name, players in pairs(alarm_groups.box) do
    if not groups.box[group_name] then
      -- The group has no players, so all players in the group have left.
      for player_name in pairs(players) do
        if not alarm_groups_dead.box[group_name][player_name] then
          -- The player is new to the dead group.
          alarm_groups_dead.box[group_name][player_name] = conf.exit_timeout

          if alarm_groups.box[group_name] and alarm_groups.box[group_name][player_name] then
            alarm_groups.box[group_name][player_name] = nil
          end
        end
      end
    else
      -- Check for players that have left the group.
      for player_name in pairs(players) do
        if not groups.box[group_name][player_name] then
          -- The player was not detected.
          alarm_groups.box[group_name][player_name] = nil

          if not alarm_groups_dead.box[group_name][player_name] then
            -- The player is new to the dead group.
            alarm_groups_dead.box[group_name][player_name] = conf.exit_timeout
          end
        end
      end
    end
  end

  -- Step 4: check over the radius groups, and check for any leavers.

  -- a: Push new ones in.
  for group_name, group_players in pairs(alarm_groups.radius) do
    if not alarm_groups.radius[group_name] then
      alarm_groups.radius[group_name] = {}
    end
    if not alarm_groups_dead.radius[group_name] then
      alarm_groups_dead.radius[group_name] = {}
    end

    for player_name in pairs(group_players) do
      if not alarm_groups.radius[group_name][player_name] then
        -- The player is new to this group.
        alarm_groups.radius[group_name][player_name] = true

        -- Ensure the player is not in the dead group.
        alarm_groups_dead.radius[group_name][player_name] = nil
      end
    end
  end

  -- b: Push the leavers to the dead group.
  for group_name, players in pairs(alarm_groups.radius) do
    if not groups.radius[group_name] then
      -- The group has no players, so all players in the group have left.
      for player_name in pairs(players) do
        if not alarm_groups_dead.radius[group_name][player_name] then
          -- The player is new to the dead group.
          alarm_groups_dead.radius[group_name][player_name] = conf.exit_timeout
          if alarm_groups.radius[group_name] and alarm_groups.radius[group_name][player_name] then
            alarm_groups.radius[group_name][player_name] = nil
          end
        end
      end
    else
      -- Check for players that have left the group.
      for player_name in pairs(players) do
        if not groups.radius[group_name][player_name] then
          -- The player was not detected.
          alarm_groups.radius[group_name][player_name] = nil

          if not alarm_groups_dead.radius[group_name][player_name] then
            -- The player is new to the dead group.
            alarm_groups_dead.radius[group_name][player_name] = conf.exit_timeout
          end
        end
      end
    end
  end
end



--- Main loop
local function main_loop()
  local function timeout()
    sleep(conf.scan_interval)
  end

  if conf.uses_webhook then
    -- Send a startup message to the webhook.
    send_webhook(
      conf.webhook.url,
      conf.webhook.name,
      conf.webhook.avatar,
      "**" .. conf.watcher_name .. " was chunkloaded and is now running.**"
    )
  end

  while true do
    parallel.waitForAll(
      check_detectors,
      timeout
    )

    --[[send_webhook(
      conf.webhook.url,
      conf.webhook.name,
      conf.webhook.avatar,
      "```lua\nalarm_groups = " .. textutils.serialize(alarm_groups) .. "\n\nalarm_groups_dead = " .. textutils.serialize(alarm_groups_dead) .. "\n```"
    )]]

    -- Delay a single tick.
    sleep()
  end
end

local ok, err = pcall(main_loop)

if not ok then
  printError("Watcher encountered an error: " .. tostring(err))
  log_to_file("Error: " .. tostring(err))
  if conf.uses_webhook then
    send_webhook(
      conf.webhook.url,
      conf.webhook.name,
      conf.webhook.avatar,
      "**" .. conf.watcher_name .. " encountered an error:**\n```\n" .. tostring(err) .. "\n```"
    )
  end
end