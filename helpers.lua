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

local sformat = string.format
local tinsert = table.insert
local mfloor = math.floor
local slower = string.lower

local CompareCalendarTime = C_DateAndTime.CompareCalendarTime
local GetSecondsUntilWeeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset

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

  -- Equalize line widths so JustifyH (LEFT/CENTER/RIGHT) takes effect
  for _, textFrame in pairs(_lines) do
    if textFrame and textFrame:GetAlpha() > 0 then
      textFrame:SetWidth(maxWidth)
    end
  end
end

NS.GetSpecIcon = function(classToken, specName)
  local classData = NS.CLASS_INFO[classToken]
  return classData and classData[specName] and classData[specName].specIcon or nil
end

NS.GetClassIcon = function(classToken, size)
  return "|A:classicon-" .. slower(classToken) .. ":" .. size .. ":" .. size .. "|a"
end

NS.DateFormat = function(timeRaw, timeZone, region)
  if region == "US" then
    return timeZone and date("%I:%M %p %m/%d/%y", timeRaw + (timeZone * 3600)) or date("%I:%M %p %m/%d/%y", timeRaw)
  else
    return timeZone and date("%H:%M %d.%m.%y", timeRaw + (timeZone * 3600)) or date("%H:%M %d.%m.%y", timeRaw)
  end
end

-- US Format: 10:05 PM 05/07/25
-- EU Format: 22:05 07.05.25
NS.DateClean = function(timeRaw, timeZone, region)
  if region == "US" then
    return timeZone and date("%I:%M %p %m/%d/%y", timeRaw + (timeZone * 3600)) or date("%I:%M %p %m/%d/%y", timeRaw)
  else
    return timeZone and date("%H:%M %d.%m.%y", timeRaw + (timeZone * 3600)) or date("%H:%M %d.%m.%y", timeRaw)
  end
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
local function parseDate(time, region)
  local hour, minute, ampm, day, month, year

  local dateString = NS.DateFormat(time, NS.Timezone, region)

  if region == "US" then
    hour, minute, ampm, month, day, year = dateString:match("(%d+):(%d+) (%a+) (%d+)/(%d+)/(%d+)")
  else
    hour, minute, day, month, year = dateString:match("(%d+):(%d+) (%d+).(%d+).(%d+)")
    ampm = nil -- Already in 24-hour format
  end

  -- Convert string parts to numbers
  hour = tonumber(hour)
  minute = tonumber(minute)
  day = tonumber(day)
  month = tonumber(month)
  year = tonumber(year) + 2000 -- Add 2000 to convert "YY" to "YYYY"

  -- Convert to 24-hour time if needed
  if ampm == "AM" and hour == 12 then
    hour = 0
  elseif ampm == "PM" and hour ~= 12 then
    hour = hour + 12
  end

  -- Create a table to represent the date and time
  return {
    year = year,
    month = month,
    monthDay = day,
    weekday = 1, -- Dummy value, not used for sorting
    hour = hour,
    minute = minute,
  }
end

-- local function checkCutOffTime(gameTime, cutOffTime)
--   local isBeforeYear = gameTime.year < cutOffTime.year
--   local isBeforeMonth = gameTime.month < cutOffTime.month
--   local isBeforeDay = gameTime.monthDay < cutOffTime.monthDay
--   local isBeforeHour = gameTime.hour < cutOffTime.hour
--   local isBeforeMinute = gameTime.minute < cutOffTime.minute

--   local isSameYear = gameTime.year == cutOffTime.year
--   local isSameMonth = gameTime.month == cutOffTime.month
--   local isSameDay = gameTime.monthDay == cutOffTime.monthDay
--   local isSameHour = gameTime.hour == cutOffTime.hour
--   -- local isSameMinute = gameTime.minute == cutOffTime.minute

--   return isBeforeYear
--     or (isSameYear and isBeforeMonth)
--     or (isSameYear and isSameMonth and isBeforeDay)
--     or (isSameYear and isSameMonth and isSameDay and isBeforeHour)
--     or (isSameYear and isSameMonth and isSameDay and isSameHour and isBeforeMinute)
-- end

-- NS.MigrateDB = function(db)
--   if db.migrated ~= nil and db.migrated == true then
--     return
--   end

--   local data = db.data
--   -- February 24, 2025, 10:05 PM PST
--   -- this is the end of the first season for the addon
--   local firstSeasonCutOffTime = {
--     ["monthDay"] = 24,
--     ["weekday"] = 2,
--     ["month"] = 2,
--     ["year"] = 2025,
--     ["hour"] = 22,
--     ["minute"] = 5,
--   }
--   -- March 4, 2025, 3:00 PM PST
--   -- this is the end of the first post season for the addon
--   local noSeasonCutOffTime = {
--     ["monthDay"] = 4,
--     ["weekday"] = 3,
--     ["month"] = 3,
--     ["year"] = 2025,
--     ["hour"] = 15,
--     ["minute"] = 0,
--   }

--   -- Iterate over regions
--   for region, players in pairs(data) do
--     -- Iterate over player names
--     for player, playerData in pairs(players) do
--       -- Add season to lastGame if it exists and doesn't already have it
--       if playerData.lastGame then
--         if playerData.lastGame.season == nil then
--           if checkCutOffTime(playerData.lastGame.gameTime, firstSeasonCutOffTime) then
--             playerData.lastGame.season = 38
--           elseif checkCutOffTime(playerData.lastGame.gameTime, noSeasonCutOffTime) then
--             playerData.lastGame.season = 0
--           else
--             playerData.lastGame.season = NS.season
--           end
--         end
--       end
--       -- Iterate over brackets
--       for bracket, games in pairs(playerData) do
--         -- Handle brackets with specs (e.g. '6' and '8')
--         if bracket == "8" or bracket == "6" then
--           -- spec, games
--           for spec, specGames in pairs(games) do
--             -- index, gameInfo
--             for _, game in ipairs(specGames) do
--               if game.season == nil then
--                 if checkCutOffTime(game.gameTime, firstSeasonCutOffTime) then
--                   game.season = 38
--                 elseif checkCutOffTime(game.gameTime, noSeasonCutOffTime) then
--                   game.season = 0
--                 else
--                   game.season = NS.season
--                 end
--               end
--             end
--           end
--         elseif bracket == "0" or bracket == "1" or bracket == "3" then
--           -- Handle brackets without specs (e.g. '0', '1', '3')
--           -- index, gameInfo
--           for _, game in ipairs(games) do
--             if game.season == nil then
--               if checkCutOffTime(game.gameTime, firstSeasonCutOffTime) then
--                 game.season = 38
--               elseif checkCutOffTime(game.gameTime, noSeasonCutOffTime) then
--                 game.season = 0
--               else
--                 game.season = NS.season
--               end
--             end
--           end
--         end
--       end
--     end
--   end

--   -- Replace the old spells table with the updated one
--   -- db.data = data
--   db.migrated = true
-- end

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

NS.sortByDate = function(data, region)
  -- Sort the data table using the parsed date and time
  table.sort(data, function(a, b)
    local dateA = parseDate(a.time, region)
    local dateB = parseDate(b.time, region)
    return CompareCalendarTime(dateA, dateB) < 0 -- Newest on top
  end)
end

NS.CustomSort = function(_data, _rowA, _rowB, _sortByColumn)
  local column = _data.cols[_sortByColumn]
  local direction = column.sort or column.defaultsort or ScrollingTable.SORT_ASC
  -- Use secret TIME field for date to normalize between region
  local correctedSortByColumn = _sortByColumn == 1 and 10 or _sortByColumn
  local rowA = _data.data[_rowA][correctedSortByColumn]
  local rowB = _data.data[_rowB][correctedSortByColumn]
  if rowA == rowB then
    return false
  else
    local dateA = parseDate(rowA, NS.playerInfo.region)
    local dateB = parseDate(rowB, NS.playerInfo.region)

    if direction == ScrollingTable.SORT_ASC then
      return CompareCalendarTime(dateA, dateB) > 0
    else
      return CompareCalendarTime(dateA, dateB) < 0
    end
  end
end

-- Utility function to flatten all games into a single array (all regions, all characters)
NS.FlattenAllGames = function()
  local allGames = {}

  if not NS.db or not NS.db.data then
    return allGames
  end

  for region, regionData in pairs(NS.db.data) do
    for charName, playerData in pairs(regionData) do
      if type(playerData) == "table" then
        for bracket, bracketData in pairs(playerData) do
          -- Shuffle and Blitz have an extra spec nesting level
          if bracket == "6" or bracket == "8" then
            for _, games in pairs(bracketData) do
              if type(games) == "table" then
                for _, game in ipairs(games) do
                  game._region = region
                  game._character = charName
                  tinsert(allGames, game)
                end
              end
            end
          elseif bracket == "0" or bracket == "1" or bracket == "3" then
            -- 2v2, 3v3, RBG have games directly at the bracket level
            for _, game in ipairs(bracketData) do
              game._region = region
              game._character = charName
              tinsert(allGames, game)
            end
          end
        end
      end
    end
  end

  NS.sortByDate(allGames, NS.playerInfo.region)

  return allGames
end

-- Determine the tracking type label based on which brackets are enabled
local getTrackingType = function()
  local g = NS.db.global
  local hasRating = g.show2v2
    or g.show3v3
    or g.showRBG
    or (g.showShuffle and g.showShuffleRating)
    or (g.showBlitz and g.showBlitzRating)
  local hasMMR = (g.showShuffle and not g.showShuffleRating) or (g.showBlitz and not g.showBlitzRating)
  if hasMMR and hasRating then
    return "mmr/rating"
  elseif hasMMR then
    return "mmr"
  else
    return "rating"
  end
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
    local noDataStr = sformat("Play a game to start tracking %s", getTrackingType())
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
        -- if preMatchValue < 0 then
        --   preMatchValue = 0
        -- end
        -- if postMathValue < 0 then
        --   postMathValue = 0
        -- end

        local showGainsLosses = NS.db.global.showGainsLosses
        local showMMRDifference = NS.db.global.showMMRDifference
        local includeChange = NS.db.global.includeChange
        local dbColor = NS.db.global.color
        -- convert user color rgb to hex
        local userColorHex =
          sformat("%02X%02X%02X%02X", dbColor.a * 255, dbColor.r * 255, dbColor.g * 255, dbColor.b * 255)

        local bracketString = NS.TRACKED_BRACKETS[bracket] .. " " .. soloLabel .. " "
        local valueString = showMMRDifference and (preMatchValue .. " › " .. postMathValue) or postMathValue
        local positiveChange = valueChange > 0
        local valueDifference = positiveChange and ("+" .. valueChange) or valueChange
        local valueColor = valueChange == 0 and "" or positiveChange and "|cFF00FF00" or "|cFFFF0000"
        local userColor = "|c" .. userColorHex
        local colorString = includeChange and userColor or valueColor
        local changeString = showGainsLosses and (colorString .. " (" .. valueDifference .. ")" .. "|r") or ""

        -- Add the formatted data
        local displayString = bracketString .. valueString .. changeString
        NS.Interface:AddText(NS.Interface, displayString, index, key, hasData)
      else
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
    --   or (bracket == 1 and NS.db.global.show3v3)
    --   or (bracket == 3 and NS.db.global.showRBG)
    --   or (bracket == 6 and NS.db.global.showShuffle)
    --   or (bracket == 8 and NS.db.global.showBlitz)

    -- for _, textFrame in pairs(NS.lines) do
    --   if textFrame.bracket == bracket then
    --     textFrame:SetAlpha(showBracket and 1 or 0)
    --   end
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
    local noDataStr = sformat("Play a game to start tracking %s", getTrackingType())
    NS.Interface:AddText(NS.Interface, noDataStr, 0, "none", false)

    for _, textFrame in pairs(NS.lines) do
      if textFrame.bracket ~= "none" then
        textFrame:SetAlpha(0)
      end
    end
  end

  -- Update frame visibility and layout
  -- for _, textFrame in pairs(NS.lines) do
  --   textFrame:SetAlpha(textFrame.hasData and 1 or (NS.db.global.hideNoResults and 0 or 1))
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
  local allGames = NS.FlattenAllGames()
  -- if next(MMRTrackerFrame.lastGame) ~= nil then
  --   tinsert(allGames, MMRTrackerFrame.lastGame)
  --   NS.sortByDate(allGames, NS.playerInfo.region)
  -- end

  -- if not NS.Timezone then
  --   local _, tz = NS.GetUTCTimestamp(true)
  --   NS.Timezone = tz
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
    local dateString = NS.DateFormat(gameInfo.time, NS.Timezone, NS.playerInfo.region)

    -- Win determination for hidden metadata
    local isWin = nil
    if shuffleBracket then
      -- Shuffle: 4+ rounds = win, 0-2 = loss, 3 = excluded (nil)
      if roundsWon >= 4 then
        isWin = true
      elseif roundsWon <= 2 then
        isWin = false
      end
    elseif gameInfo.winner ~= nil then
      isWin = (gameInfo.winner == gameInfo.faction)
    end

    tinsert(rows, {
      dateString,
      gameInfo.mapName,
      specInfo,
      NS.TRACKED_BRACKETS[bracket],
      bracketString,
      preMatchValue,
      changeColor .. valueDifference .. "|r",
      postMathValue,
      gameInfo.winner == nil and "-" or (shuffleBracket and (roundsWonColor .. roundsWon .. "/6" .. "|r") or winIcon),
      gameInfo.time,
      tonumber(gameInfo.bracket), -- [11] bracket key number
      gameInfo.spec, -- [12] raw spec name
      gameInfo.season or NS.NO_SEASON, -- [13] season number (-1 if nil)
      gameInfo._region, -- [14] region string
      gameInfo._character, -- [15] character name
      gameInfo.rating + gameInfo.ratingChange, -- [16] post-match rating (newRating)
      gameInfo.postMatchMMR, -- [17] post-match MMR
      isWin, -- [18] win boolean (nil = excluded from W-L)
    })
  end

  return rows
end

-- Compute summary stats for the header above the data table
-- Left side (Highest Rating/MMR): bracket tab + character + region + spec (Shuffle/Blitz only)
-- Center + Right (W-L, Streak): full NS.TableFilter
NS.ComputeSummaryStats = function(allRows)
  local highestRating = nil
  local highestRatingNonMMR = nil -- highest rating from 2v2/3v3/RBG only (for "All" tab)
  local highestMMR = nil
  local wins = 0
  local losses = 0
  local streakCount = 0
  local streakType = nil -- "W" or "L" or nil
  local streakDetermined = false

  for _, row in ipairs(allRows) do
    local bracketNum = row[11]
    local rowRegion = row[14]
    local rowChar = row[15]
    local rowSpec = row[12]
    local newRating = row[16]
    local postMatchMMR = row[17]
    local isWin = row[18]

    -- Left side: Highest Rating / MMR (bracket tab + character + region + spec for Shuffle/Blitz)
    local passesLeftFilter = true
    -- Check region
    if NS.filters.region ~= "All" and rowRegion ~= NS.filters.region then
      passesLeftFilter = false
    end
    -- Check character
    if passesLeftFilter and NS.filters.character ~= "All" and rowChar ~= NS.filters.character then
      passesLeftFilter = false
    end
    -- Check bracket tab
    if passesLeftFilter and NS.filters.tab ~= nil and bracketNum ~= NS.filters.tab then
      passesLeftFilter = false
    end
    -- Check spec (only for Shuffle/Blitz rows)
    if passesLeftFilter and (bracketNum == 6 or bracketNum == 8) then
      if NS.filters.spec ~= "All" and rowSpec ~= NS.filters.spec then
        passesLeftFilter = false
      end
    end

    if passesLeftFilter then
      -- Highest Rating (all brackets)
      if newRating and newRating >= 0 then
        if not highestRating or newRating > highestRating then
          highestRating = newRating
        end
        -- Highest Rating from non-MMR brackets only (2v2/3v3/RBG)
        if bracketNum == 0 or bracketNum == 1 or bracketNum == 3 then
          if not highestRatingNonMMR or newRating > highestRatingNonMMR then
            highestRatingNonMMR = newRating
          end
        end
      end
      -- Highest MMR (Shuffle/Blitz only)
      if (bracketNum == 6 or bracketNum == 8) and postMatchMMR and postMatchMMR >= 0 then
        if not highestMMR or postMatchMMR > highestMMR then
          highestMMR = postMatchMMR
        end
      end
    end

    -- Center + Right: W-L and Streak (full filter)
    if NS.TableFilter(nil, row) then
      if isWin == true then
        wins = wins + 1
      elseif isWin == false then
        losses = losses + 1
      end

      -- Streak: walk chronologically (newest first in allRows) until direction changes
      if not streakDetermined and isWin ~= nil then
        if streakType == nil then
          -- First game with a result sets the streak direction
          streakType = isWin and "W" or "L"
          streakCount = 1
        elseif (streakType == "W" and isWin) or (streakType == "L" and not isWin) then
          -- Same direction, extend streak
          streakCount = streakCount + 1
        else
          -- Direction changed, streak is over
          streakDetermined = true
        end
      end
    end
  end

  -- If bracket tab is 2v2/3v3/RBG, MMR is N/A
  if NS.filters.tab == 0 or NS.filters.tab == 1 or NS.filters.tab == 3 then
    highestMMR = nil
  end

  return {
    highestRating = highestRating,
    highestRatingNonMMR = highestRatingNonMMR,
    highestMMR = highestMMR,
    wins = wins,
    losses = losses,
    streakCount = streakCount,
    streakType = streakType,
  }
end

-- ScrollingTable filter function — checks all 6 filter dimensions
NS.TableFilter = function(_, rowdata)
  if NS.filters.region ~= "All" then
    if rowdata[14] ~= NS.filters.region then
      return false
    end
  end
  if NS.filters.character ~= "All" then
    if rowdata[15] ~= NS.filters.character then
      return false
    end
  end
  if NS.filters.tab ~= nil then
    if rowdata[11] ~= NS.filters.tab then
      return false
    end
  end
  if NS.filters.spec ~= "All" then
    if rowdata[12] ~= NS.filters.spec then
      return false
    end
  end
  if NS.filters.map ~= "All" then
    if rowdata[2] ~= NS.filters.map then
      return false
    end
  end
  if not NS.PassesTimeFilter(rowdata[10], rowdata[13]) then
    return false
  end
  return true
end

-- Time helpers
NS.ParseUTCTimestamp = function(month)
  local d1 = date("*t")
  local d2 = date("!*t")
  d2.isdst = d1.isdst
  if month then
    return time(d2) - (86400 * (d2.day - 1)) - (3600 * d2.hour) - (60 * d2.min) - d2.sec
  else
    return time(d2) - (3600 * d2.hour) - (60 * d2.min) - d2.sec
  end
end

NS.GetPreviousWeeklyReset = function()
  return 604800 - GetSecondsUntilWeeklyReset()
end

NS.PassesTimeFilter = function(rawTime, season)
  local mode = NS.filters.time
  if mode == 1 then
    return true
  end -- All
  if mode == 2 then -- Session
    return NS.SessionStart and rawTime >= NS.SessionStart
  end
  if mode == 3 then
    return rawTime >= NS.ParseUTCTimestamp()
  end -- Today
  if mode == 4 then -- Yesterday
    local todayStart = NS.ParseUTCTimestamp()
    return rawTime >= (todayStart - 86400) and rawTime < todayStart
  end
  if mode == 5 then -- This Week
    local utcNow = NS.GetUTCTimestamp()
    return rawTime >= (utcNow - NS.GetPreviousWeeklyReset())
  end
  if mode == 6 then
    return rawTime >= NS.ParseUTCTimestamp(true)
  end -- This Month
  if mode == 7 then -- This Season (use API value if active, otherwise static fallback)
    local currentSeason = NS.season > 0 and NS.season or NS.CURRENT_SEASON
    return season == currentSeason
  end
  if mode == 8 then -- Prev. Season
    local currentSeason = NS.season > 0 and NS.season or NS.CURRENT_SEASON
    return season == (currentSeason - 1)
  end
  if mode == 9 then -- Select Season
    if NS.filters.selectedSeason == "All" then
      return true
    end
    return season == NS.filters.selectedSeason
  end
  if mode == 10 then -- Custom Range
    local from, to = NS.filters.customStart, NS.filters.customEnd
    if from > 0 or to > 0 then
      return rawTime >= from and (to == 0 or rawTime <= to)
    end
    return true
  end
  return true
end

-- Calendar hook for custom date range
NS.CalendarParser = function()
  if NS.CalendarMode == 1 then
    local t = {
      day = CalendarFrame.selectedDay,
      month = CalendarFrame.selectedMonth,
      year = CalendarFrame.selectedYear,
      hour = 0,
    }
    PlaySound(624)
    NS.filters.customStart = time(t) - (NS.Timezone * 3600)
    NS.CalendarMode = 2
  elseif NS.CalendarMode == 2 then
    local t = {
      day = CalendarFrame.selectedDay,
      month = CalendarFrame.selectedMonth,
      year = CalendarFrame.selectedYear,
      hour = 23,
      min = 59,
      sec = 59,
    }
    PlaySound(624)
    NS.filters.customEnd = time(t) - (NS.Timezone * 3600)
    CalendarFrame:Hide()
    NS.RefreshFilters()
  end
end

NS.CalendarCleanup = function()
  NS.CalendarMode = 0
  StaticPopup_Hide("MMRTRACKER_CUSTOMDATE")
end

-- Faceted filter helpers
-- Check if a row passes all filters EXCEPT the excluded one
NS.RowPassesFilters = function(rowdata, exclude)
  if exclude ~= "region" and NS.filters.region ~= "All" then
    if rowdata[14] ~= NS.filters.region then
      return false
    end
  end
  if exclude ~= "character" and NS.filters.character ~= "All" then
    if rowdata[15] ~= NS.filters.character then
      return false
    end
  end
  if exclude ~= "tab" and NS.filters.tab ~= nil then
    if rowdata[11] ~= NS.filters.tab then
      return false
    end
  end
  if exclude ~= "spec" and NS.filters.spec ~= "All" then
    if rowdata[12] ~= NS.filters.spec then
      return false
    end
  end
  if exclude ~= "map" and NS.filters.map ~= "All" then
    if rowdata[2] ~= NS.filters.map then
      return false
    end
  end
  if exclude ~= "time" then
    if not NS.PassesTimeFilter(rowdata[10], rowdata[13]) then
      return false
    end
  end
  return true
end

-- Build faceted dropdown list by scanning all rows with one filter excluded
NS.BuildFacetedList = function(allRows, exclude, fieldIndex)
  local list = { ["All"] = "All" }
  local order = { "All" }
  local seen = {}
  for _, row in ipairs(allRows) do
    if NS.RowPassesFilters(row, exclude) then
      local value = row[fieldIndex]
      if value and value ~= "" and not seen[value] then
        seen[value] = true
        list[value] = value
        tinsert(order, value)
      end
    end
  end
  table.sort(order, function(a, b)
    if a == "All" then
      return true
    end
    if b == "All" then
      return false
    end
    return a < b
  end)
  return list, order
end

NS.BuildRegionList = function(allRows)
  return NS.BuildFacetedList(allRows, "region", 14)
end

NS.BuildCharacterList = function(allRows)
  return NS.BuildFacetedList(allRows, "character", 15)
end

NS.BuildSpecList = function(allRows)
  return NS.BuildFacetedList(allRows, "spec", 12)
end

NS.BuildMapList = function(allRows)
  return NS.BuildFacetedList(allRows, "map", 2)
end

-- Build season dropdown list from data (faceted), using SEASON_NAMES for display labels
NS.BuildSeasonList = function(allRows)
  local list = { ["All"] = "All" }
  local order = { "All" }
  local seen = {}
  for _, row in ipairs(allRows) do
    if NS.RowPassesFilters(row, "time") then
      local season = row[13]
      if season and not seen[season] then
        seen[season] = true
        local label = NS.SEASON_NAMES[season] or ("Season " .. season)
        list[season] = label
        tinsert(order, season)
      end
    end
  end
  -- Sort seasons ascending; Off-Season (0) and No Season (-1) at the end
  -- "All" stays first (not in the numeric sort)
  table.sort(order, function(a, b)
    if a == "All" then
      return true
    end
    if b == "All" then
      return false
    end
    if a <= 0 and b <= 0 then
      return a > b
    end -- 0 before -1
    if a <= 0 then
      return false
    end
    if b <= 0 then
      return true
    end
    return a < b
  end)
  return list, order
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
