local _, NS = ...

local pairs = pairs
local type = type
local next = next
local setmetatable = setmetatable
local getmetatable = getmetatable
local LibStub = LibStub
local tostring = tostring
local ipairs = ipairs
local tonumber = tonumber
local time = time
local date = date

local twipe = table.wipe
local sformat = string.format
local tinsert = table.insert
local mfloor = math.floor
local slower = string.lower

local CompareCalendarTime = C_DateAndTime.CompareCalendarTime

local SharedMedia = LibStub("LibSharedMedia-3.0")
local ScrollingTable = LibStub("ScrollingTable")

NS.UpdateSize = function(frame, text)
  frame:SetWidth(text:GetStringWidth())
  frame:SetHeight(text:GetStringHeight())
end

NS.UpdateFont = function(frame)
  frame:SetFont(SharedMedia:Fetch("font", NS.db.global.fontFamily), NS.db.global.fontSize, "OUTLINE")
end

NS.SetTextFrameSize = function(frame, _lines)
  local maxWidth = 1
  local totalHeight = 1

  for _, textFrame in pairs(_lines) do
    if textFrame and textFrame:GetAlpha() > 0 then
      local textWidth = textFrame:GetStringWidth() -- Get the width of the text
      local textHeight = textFrame:GetStringHeight() -- Get the height of the text

      -- Update maxWidth if current frame is wider
      if textWidth > maxWidth then
        maxWidth = textWidth
      end

      -- Accumulate the height
      totalHeight = totalHeight + textHeight
    end
  end

  -- Set frame size based on calculated dimensions
  frame.textFrame:SetWidth(maxWidth)
  frame.textFrame:SetHeight(totalHeight)
  -- local border = frame.textFrame:CreateTexture(nil, "BACKGROUND")
  -- border:SetAllPoints(frame.textFrame)
  -- border:SetColorTexture(0, 0, 0, 1) -- Black border with full opacity
end

NS.GetSpecIcon = function(classToken, specName)
  local classData = NS.CLASS_INFO[classToken]
  return classData and classData[specName] and classData[specName].specIcon or nil
end

NS.GetClassIcon = function(classToken, size)
  return "|A:classicon-" .. slower(classToken) .. ":" .. size .. ":" .. size .. "|a"
end

NS.DateClean = function(timeRaw)
  return NS.Timezone and date("%I:%M %p %d/%m/%Y", timeRaw + (NS.Timezone * 3600)) or date("%I:%M %p %d/%m/%Y")
end

NS.Round = function(number, idp)
  local multiplier = 10 ^ (idp or 0)
  return mfloor(number * multiplier + 0.5) / multiplier
end

NS.GetUTCTimestamp = function(timezone)
  local d1 = date("*t")
  local d2 = date("!*t")
  d2.isdst = d1.isdst
  local utc = time(d2)
  if timezone then
    local player = time(d1)
    return utc, NS.Round((player - utc) / 3600, 0)
  else
    return utc
  end
end

-- Helper function to convert date strings into sortable values
local function parseDate(dateString)
  local hour, minute, ampm, day, month, year = dateString:match("(%d+):(%d+) (%a+) (%d+)/(%d+)/(%d+)")
  hour = tonumber(hour)
  minute = tonumber(minute)
  day = tonumber(day)
  month = tonumber(month)
  year = tonumber(year)

  -- Convert 12-hour time to 24-hour time
  if ampm == "PM" and hour ~= 12 then
    hour = hour + 12
  elseif ampm == "AM" and hour == 12 then
    hour = 0
  end

  -- Create a table to represent the date and time
  return {
    year = year,
    month = month,
    monthDay = day,
    weekday = 1, -- Dummy value, not used for sorting
    hour = hour,
    minute = minute, -- Fixed field name
  }
end

local function checkCutOffTime(gameTime, cutOffTime)
  local isBeforeYear = gameTime.year < cutOffTime.year
  local isBeforeMonth = gameTime.month < cutOffTime.month
  local isBeforeDay = gameTime.monthDay < cutOffTime.monthDay
  local isBeforeHour = gameTime.hour < cutOffTime.hour
  local isBeforeMinute = gameTime.minute < cutOffTime.minute

  local isSameYear = gameTime.year == cutOffTime.year
  local isSameMonth = gameTime.month == cutOffTime.month
  local isSameDay = gameTime.monthDay == cutOffTime.monthDay
  local isSameHour = gameTime.hour == cutOffTime.hour
  -- local isSameMinute = gameTime.minute == cutOffTime.minute

  return isBeforeYear
    or (isSameYear and isBeforeMonth)
    or (isSameYear and isSameMonth and isBeforeDay)
    or (isSameYear and isSameMonth and isSameDay and isBeforeHour)
    or (isSameYear and isSameMonth and isSameDay and isSameHour and isBeforeMinute)
end

NS.MigrateDB = function(db)
  if db.migrated ~= nil and db.migrated == true then
    return
  end

  local data = db.data
  -- February 24, 2025, 10:05 PM PST
  -- this is the end of the first season for the addon
  local firstSeasonCutOffTime = {
    ["monthDay"] = 24,
    ["weekday"] = 2,
    ["month"] = 2,
    ["year"] = 2025,
    ["hour"] = 22,
    ["minute"] = 5,
  }
  -- March 4, 2025, 3:00 PM PST
  -- this is the end of the first post season for the addon
  local noSeasonCutOffTime = {
    ["monthDay"] = 4,
    ["weekday"] = 3,
    ["month"] = 3,
    ["year"] = 2025,
    ["hour"] = 15,
    ["minute"] = 0,
  }

  -- Iterate over regions
  for region, players in pairs(data) do
    -- Iterate over player names
    for player, playerData in pairs(players) do
      -- Add season to lastGame if it exists and doesn't already have it
      if playerData.lastGame then
        if playerData.lastGame.season == nil then
          if checkCutOffTime(playerData.lastGame.gameTime, firstSeasonCutOffTime) then
            playerData.lastGame.season = 38
          elseif checkCutOffTime(playerData.lastGame.gameTime, noSeasonCutOffTime) then
            playerData.lastGame.season = 0
          else
            playerData.lastGame.season = NS.season
          end
        end
      end
      -- Iterate over brackets
      for bracket, games in pairs(playerData) do
        -- Handle brackets with specs (e.g. '6' and '8')
        if bracket == "8" or bracket == "6" then
          -- spec, games
          for spec, specGames in pairs(games) do
            -- index, gameInfo
            for _, game in ipairs(specGames) do
              if game.season == nil then
                if checkCutOffTime(game.gameTime, firstSeasonCutOffTime) then
                  game.season = 38
                elseif checkCutOffTime(game.gameTime, noSeasonCutOffTime) then
                  game.season = 0
                else
                  game.season = NS.season
                end
              end
            end
          end
        elseif bracket == "0" or bracket == "1" or bracket == "3" then
          -- Handle brackets without specs (e.g. '0', '1', '3')
          -- index, gameInfo
          for _, game in ipairs(games) do
            if game.season == nil then
              if checkCutOffTime(game.gameTime, firstSeasonCutOffTime) then
                game.season = 38
              elseif checkCutOffTime(game.gameTime, noSeasonCutOffTime) then
                game.season = 0
              else
                game.season = NS.season
              end
            end
          end
        end
      end
    end
  end

  -- Replace the old spells table with the updated one
  db.data = data
  db.migrated = true
end

-- Function to filter games by the current season
NS.filterBySeason = function(data)
  local filteredGames = {}

  for _, game in ipairs(data) do
    if game.season == NS.season then
      tinsert(filteredGames, game)
    end
  end

  return filteredGames
end

NS.sortByDate = function(data)
  -- Sort the data table using the parsed date and time
  table.sort(data, function(a, b)
    local dateA = parseDate(a.date)
    local dateB = parseDate(b.date)
    return CompareCalendarTime(dateA, dateB) < 0 -- Newest on top
  end)
end

NS.CustomSort = function(_data, _rowA, _rowB, _sortByColumn)
  local column = _data.cols[_sortByColumn]
  local direction = column.sort or column.defaultsort or ScrollingTable.SORT_ASC
  local rowA = _data.data[_rowA][_sortByColumn]
  local rowB = _data.data[_rowB][_sortByColumn]
  local dateA = parseDate(rowA)
  local dateB = parseDate(rowB)
  if rowA == rowB then
    return false
  else
    if direction == ScrollingTable.SORT_ASC then
      return CompareCalendarTime(dateA, dateB) > 0
    else
      return CompareCalendarTime(dateA, dateB) < 0
    end
  end
end

-- Utility function to flatten all games into a single array
NS.FlattenAllGames = function(playerInfo)
  local allGames = {}

  -- Ensure the top-level data structure exists
  if NS.db and NS.db.data then
    -- Iterate over regions
    for region, regionData in pairs(NS.db.data) do
      -- Skip regions that don't match the player's region
      if region == playerInfo.region then
        -- Iterate over player names
        for playerName, playerData in pairs(regionData) do
          -- Skip players that don't match the player's name
          if playerName == playerInfo.name then
            -- Iterate over brackets
            for bracket, bracketData in pairs(playerData) do
              -- Handle brackets with specs (e.g., '6' and '8')
              if bracket == "6" or bracket == "8" then
                -- spec, games
                for spec, games in pairs(bracketData) do
                  -- index, gameInfo
                  for index, game in ipairs(games) do
                    tinsert(allGames, game)
                  end
                end
              elseif bracket == "0" or bracket == "1" or bracket == "3" then
                -- Handle brackets without specs (e.g., '0', '1', '3')
                -- index, gameInfo
                for _, game in ipairs(bracketData) do
                  tinsert(allGames, game)
                end
              end
            end
          end
        end
      end
    end
  end

  -- Filter out games that don't match the current season
  allGames = NS.filterBySeason(allGames)

  -- Sort the data table using the parsed date and time
  NS.sortByDate(allGames)

  return allGames
end

-- Helper function to check if data exists
local noDataAvailable = function()
  return not NS.db
    or not NS.db.data
    or next(NS.db.data) == nil
    or not NS.db.data[NS.playerInfo.region]
    or next(NS.db.data[NS.playerInfo.region]) == nil
    or not NS.db.data[NS.playerInfo.region][NS.playerInfo.name]
    or next(NS.db.data[NS.playerInfo.region][NS.playerInfo.name]) == nil
end

NS.DisplayBracketData = function()
  -- Early exit if there is no data
  if noDataAvailable() then
    -- local noDataStr = sformat("%s %s, %s", "No data for", NS.playerInfo.name, NS.playerInfo.region)
    local noDataStr = sformat("Play a game to start tracking mmr")
    NS.Interface:AddText(NS.Interface, noDataStr, 0, "none", false)
    return
  end

  local hasAnyBracketData = false
  local hasAnySeasonData = false
  local playerData = NS.db.data[NS.playerInfo.region][NS.playerInfo.name]

  -- Iterate over tracked brackets
  for bracket, _ in pairs(NS.TRACKED_BRACKETS) do
    local bracketKey = tostring(bracket)
    local bracketData = playerData[bracketKey]
    local hasData = bracketData and next(bracketData) ~= nil

    -- Handle brackets with spec-level data (shuffle and blitz)
    if hasData and (bracket == 6 or bracket == 8) then
      hasData = bracketData[NS.playerInfo.spec] and next(bracketData[NS.playerInfo.spec]) ~= nil
    end

    -- Determine display parameters
    local index, key = 0, "none"
    if bracket == 0 then
      index, key = 1, "2v2"
    elseif bracket == 1 then
      index, key = 2, "3v3"
    elseif bracket == 3 then
      index, key = 3, "rbg"
    elseif bracket == 6 then
      index, key = 4, "shuffle"
    elseif bracket == 8 then
      index, key = 5, "blitz"
    end

    if hasData then
      hasAnyBracketData = true

      local gameInfo = (bracket == 6 or bracket == 8) and playerData[bracketKey][NS.playerInfo.spec]
        or playerData[bracketKey]

      if gameInfo[#gameInfo].season ~= nil and gameInfo[#gameInfo].season == NS.season then
        NS.db.global.hideIntro = true
        hasAnySeasonData = true

        -- Format strings for display
        local soloLabel = PVP_RATING
        local preMatchValue = gameInfo[#gameInfo].rating
        local postMathValue = gameInfo[#gameInfo].rating + gameInfo[#gameInfo].ratingChange
        local valueChange = gameInfo[#gameInfo].ratingChange
        if bracket == 6 and NS.db.global.showShuffleRating == false then
          soloLabel = "MMR:"
          preMatchValue = gameInfo[#gameInfo].preMatchMMR
          postMathValue = gameInfo[#gameInfo].postMatchMMR
          valueChange = gameInfo[#gameInfo].mmrChange
        elseif bracket == 8 and NS.db.global.showBlitzRating == false then
          soloLabel = "MMR:"
          preMatchValue = gameInfo[#gameInfo].preMatchMMR
          postMathValue = gameInfo[#gameInfo].postMatchMMR
          valueChange = gameInfo[#gameInfo].mmrChange
        end
        local bracketString = NS.TRACKED_BRACKETS[bracket] .. " " .. soloLabel .. " "
        local valueString = NS.db.global.showMMRDifference and (preMatchValue .. " › " .. postMathValue)
          or postMathValue
        local positiveChange = valueChange > 0
        local valueDifference = positiveChange and ("+" .. valueChange) or valueChange
        local colorString = valueChange == 0 and "" or (positiveChange and "|cFF00FF00" or "|cFFFF0000")
        local changeString = NS.db.global.showMMRDifference and (colorString .. " (" .. valueDifference .. ")" .. "|r")
          or ""

        -- Add the formatted data
        local displayString = bracketString .. valueString .. changeString
        NS.Interface:AddText(NS.Interface, displayString, index, key, hasData)
      else
        NS.db.global.hideIntro = false
        -- Display message if no data for this bracket
        local noDataString = sformat("No %s data yet", NS.TRACKED_BRACKETS[bracket])
        NS.Interface:AddText(NS.Interface, noDataString, index, key, false)
      end
    else
      -- Display message if no data for this bracket
      local noDataString = sformat("No %s data yet", NS.TRACKED_BRACKETS[bracket])
      NS.Interface:AddText(NS.Interface, noDataString, index, key, false)
    end

    -- Handle bracket visibility
    -- local showBracket = (bracket == 0 and NS.db.global.show2v2)
    -- 	or (bracket == 1 and NS.db.global.show3v3)
    -- 	or (bracket == 3 and NS.db.global.showRBG)
    -- 	or (bracket == 6 and NS.db.global.showShuffle)
    -- 	or (bracket == 8 and NS.db.global.showBlitz)

    -- for _, textFrame in pairs(NS.lines) do
    -- 	if textFrame.bracket == bracket then
    -- 		textFrame:SetAlpha(showBracket and 1 or 0)
    -- 	end
    -- end
  end

  -- Handle the case where no data exists at all
  if hasAnyBracketData and hasAnySeasonData then
    for _, textFrame in pairs(NS.lines) do
      if textFrame.bracket == "none" then
        textFrame:SetAlpha(0)
        break
      end
    end
  else
    -- local noDataStr = sformat("%s %s, %s", "No data for", NS.playerInfo.name, NS.playerInfo.region)
    local noDataStr = sformat("Play a game to start tracking mmr")
    NS.Interface:AddText(NS.Interface, noDataStr, 0, "none", false)

    for _, textFrame in pairs(NS.lines) do
      if textFrame.bracket ~= "none" then
        textFrame:SetAlpha(0)
      end
    end
  end

  -- Update frame visibility and layout
  -- for _, textFrame in pairs(NS.lines) do
  -- 	textFrame:SetAlpha(textFrame.hasData and 1 or (NS.db.global.hideNoResults and 0 or 1))
  -- end

  NS.Interface:UpdateAnchors(NS.Interface, NS.lines)
  NS.SetTextFrameSize(NS.Interface, NS.lines)

  if NS.db.global.lock then
    NS.Interface:Lock(NS.Interface.textFrame)
  else
    NS.Interface:Unlock(NS.Interface.textFrame)
  end
end

NS.UpdateTable = function()
  local allGames = NS.FlattenAllGames(NS.playerInfo)
  -- if next(MMRTrackerFrame.lastGame) ~= nil then
  -- 	tinsert(allGames, MMRTrackerFrame.lastGame)
  -- 	NS.sortByDate(allGames)
  -- end

  local rows = {}
  for _, gameInfo in pairs(allGames) do
    local bracket = tonumber(gameInfo.bracket)
    local preMatchValue = gameInfo.rating
    local postMathValue = gameInfo.rating + gameInfo.ratingChange
    local valueChange = gameInfo.ratingChange
    if bracket == 6 and NS.db.global.showShuffleRating == false then
      preMatchValue = gameInfo.preMatchMMR
      postMathValue = gameInfo.postMatchMMR
      valueChange = gameInfo.mmrChange
    elseif bracket == 8 and NS.db.global.showBlitzRating == false then
      preMatchValue = gameInfo.preMatchMMR
      postMathValue = gameInfo.postMatchMMR
      valueChange = gameInfo.mmrChange
    end
    local positiveChange = valueChange > 0
    local changeColor = valueChange == 0 and "|cFFBBBBBB" or (positiveChange and "|cFF00FF00" or "|cFFFF0000")
    local valueDifference = positiveChange and ("+" .. valueChange) or valueChange
    local bgBracket = bracket == 3 or bracket == 8
    local shuffleBracket = bracket == 6
    local bgString = gameInfo.faction == 0 and ("|cffFF0000" .. FACTION_HORDE .. "|r")
      or ("|cff00AAFF" .. FACTION_ALLIANCE .. "|r")
    local GREEN_TEAM = VICTORY_TEXT_ARENA0:match("^(%S+)") or "Green"
    local GOLD_TEAM = VICTORY_TEXT_ARENA1:match("^(%S+)") or "Gold"
    local arenaString = gameInfo.faction == 0 and ("|cFF90EE90" .. GREEN_TEAM .. "|r")
      or ("|cFFCC9900" .. GOLD_TEAM .. "|r")
    -- VICTORY_TEXT_ARENA_WINS
    local shuffleString = "|cFFBBBBBB" .. "-" .. "|r"
    local bracketString = bgBracket and bgString or (shuffleBracket and shuffleString or arenaString)
    local classColors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[gameInfo.classToken]
    -- "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14:14:0:0|t"
    local winIcon = gameInfo.winner == gameInfo.faction and "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"
      or "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14:0:0|t"
    local roundsWon = (shuffleBracket and next(gameInfo.stats) ~= nil) and gameInfo.stats[1].pvpStatValue or 0
    local roundsWonColor = roundsWon == 3 and "|cFFBBBBBB" or (roundsWon > 3 and "|cFF00FF00" or "|cFFFF0000")
    local specIcon = NS.GetSpecIcon(gameInfo.classToken, gameInfo.spec)
    local specInfo = "|c" .. classColors.colorStr .. gameInfo.spec .. "|r"
    if NS.db.global.showSpecIcon and specIcon then
      -- NS.GetClassIcon(_gameInfo.classToken, 20),
      specInfo = "|T" .. specIcon .. ":20:20:0:0|t"
    end
    tinsert(rows, {
      gameInfo.date,
      gameInfo.mapName,
      specInfo,
      NS.TRACKED_BRACKETS[bracket],
      bracketString,
      preMatchValue,
      changeColor .. valueDifference .. "|r",
      postMathValue,
      gameInfo.winner == nil and "-" or (shuffleBracket and (roundsWonColor .. roundsWon .. "/6" .. "|r") or winIcon),
      gameInfo.time,
    })
  end

  return rows
end

-- Copies table values from src to dst if they don't exist in dst
NS.CopyDefaults = function(src, dst)
  if type(src) ~= "table" then
    return {}
  end

  if type(dst) ~= "table" then
    dst = {}
  end

  for k, v in pairs(src) do
    if type(v) == "table" then
      if k == "data" or k == "minimap" then
        if not dst[k] or next(dst[k]) == nil then
          dst[k] = NS.CopyDefaults(v, dst[k])
        end
      else
        dst[k] = NS.CopyDefaults(v, dst[k])
      end
    elseif type(v) ~= type(dst[k]) then
      dst[k] = v
    end
  end

  return dst
end

NS.CopyTable = function(src, dest)
  -- Handle non-tables and previously-seen tables.
  if type(src) ~= "table" then
    return src
  end

  if dest and dest[src] then
    return dest[src]
  end

  -- New table; mark it as seen an copy recursively.
  local s = dest or {}
  local res = {}
  s[src] = res

  for k, v in next, src do
    res[NS.CopyTable(k, s)] = NS.CopyTable(v, s)
  end

  return setmetatable(res, getmetatable(src))
end

-- Cleanup savedvariables by removing table values in src that no longer
-- exists in table dst (default settings)
NS.CleanupDB = function(src, dst)
  for key, value in pairs(src) do
    if dst[key] == nil then
      -- HACK: offsetsXY are not set in DEFAULT_SETTINGS but sat on demand instead to save memory,
      -- which causes nil comparison to always be true here, so always ignore these for now
      if key ~= "version" and key ~= "minimapPos" then
        src[key] = nil
      end
    elseif type(value) == "table" then
      if key ~= "data" and key ~= "minimap" then -- also set on demand
        dst[key] = NS.CleanupDB(value, dst[key])
      end
    end
  end
  return dst
end

-- Pool for reusing tables. (Garbage collector isn't ran in combat unless max garbage is reached, which causes fps drops)
do
  local pool = {}

  NS.NewTable = function()
    local t = next(pool) or {}
    pool[t] = nil -- remove from pool
    return t
  end

  NS.RemoveTable = function(tbl)
    if tbl then
      pool[twipe(tbl)] = true -- add to pool, wipe returns pointer to tbl here
    end
  end

  NS.ReleaseTables = function()
    if next(pool) then
      pool = {}
    end
  end
end
