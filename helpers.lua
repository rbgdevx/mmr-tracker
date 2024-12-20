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
              if tonumber(bracket) then
                -- Handle brackets with specs (e.g., '6' and '8')
                if bracket == "6" or bracket == "8" then
                  -- spec, games
                  for _, games in pairs(bracketData) do
                    -- index, gameInfo
                    for _, game in ipairs(games) do
                      tinsert(allGames, game)
                    end
                  end
                else
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
  end

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
      local changeString = NS.db.global.showMMRDifference and (colorString .. " (" .. valueDifference .. ")") or ""

      -- Add the formatted data
      local displayString = bracketString .. valueString .. changeString
      NS.Interface:AddText(NS.Interface, displayString, index, key, hasData)
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
  if hasAnyBracketData then
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
  end

  -- Update frame visibility and layout
  -- for _, textFrame in pairs(NS.lines) do
  -- 	textFrame:SetAlpha(textFrame.hasData and 1 or (NS.db.global.hideNoResults and 0 or 1))
  -- end

  NS.Interface:UpdateAnchors(NS.Interface, NS.lines)
  NS.SetTextFrameSize(NS.Interface, NS.lines)
  NS.Interface:AddControls(NS.Interface.textFrame)
end

NS.UpdateTable = function()
  local allGames = NS.FlattenAllGames(NS.playerInfo)
  -- if next(MMRTrackerFrame.lastGame) ~= nil then
  -- 	tinsert(allGames, MMRTrackerFrame.lastGame)
  -- 	NS.sortByDate(allGames)
  -- end

  local rows = {}
  for _, _gameInfo in ipairs(allGames) do
    local _bracket = tonumber(_gameInfo.bracket)
    local _preMatchValue = _gameInfo.rating
    local _postMathValue = _gameInfo.rating + _gameInfo.ratingChange
    local _valueChange = _gameInfo.ratingChange
    if _bracket == 6 and NS.db.global.showShuffleRating == false then
      _preMatchValue = _gameInfo.preMatchMMR
      _postMathValue = _gameInfo.postMatchMMR
      _valueChange = _gameInfo.mmrChange
    elseif _bracket == 8 and NS.db.global.showBlitzRating == false then
      _preMatchValue = _gameInfo.preMatchMMR
      _postMathValue = _gameInfo.postMatchMMR
      _valueChange = _gameInfo.mmrChange
    end
    local _positiveChange = _valueChange > 0
    local _colorChangeString = _valueChange == 0 and "|cFFBBBBBB" or (_positiveChange and "|cFF00FF00" or "|cFFFF0000")
    local _valueDifference = _positiveChange and ("+" .. _valueChange) or _valueChange
    local _rbgFaction = _bracket == 3 or _bracket == 8
    local _rbgString = _gameInfo.faction == 0 and ("|cffFF0000" .. FACTION_HORDE) or ("|cff00AAFF" .. FACTION_ALLIANCE)
    local GREEN_TEAM = VICTORY_TEXT_ARENA0:match("^(%w+)")
    local GOLD_TEAM = VICTORY_TEXT_ARENA1:match("^(%w+)")
    local _arenaString = _gameInfo.faction == 0 and ("|cFF90EE90" .. GREEN_TEAM) or ("|cFFCC9900" .. GOLD_TEAM)
    local _shuffleString = "|cFFBBBBBB" .. "-"
    local _factionString = _rbgFaction and _rbgString or (_bracket == 6 and _shuffleString or _arenaString)
    local _classColors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[_gameInfo.classToken]
    -- "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14:14:0:0|t"
    local _winIcon = _gameInfo.winner == _gameInfo.faction and "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"
      or "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14:0:0|t"
    local _roundsWon = _bracket == 6 and _gameInfo.stats["1"].pvpStatValue or 0
    local _roundsWonColor = _roundsWon == 3 and "|cFFBBBBBB" or (_roundsWon > 3 and "|cFF00FF00" or "|cFFFF0000")

    local _specIcon = NS.GetSpecIcon(_gameInfo.classToken, _gameInfo.spec)
    local _specInfo = "|c" .. _classColors.colorStr .. _gameInfo.spec
    if _specIcon and NS.db.global.showSpecIcon then
      -- NS.GetClassIcon(_gameInfo.classToken, 20),
      _specInfo = "|T" .. _specIcon .. ":20:20:0:0|t"
    end

    tinsert(rows, {
      _gameInfo.date,
      _gameInfo.mapName,
      _specInfo,
      NS.TRACKED_BRACKETS[_bracket],
      _factionString,
      _preMatchValue,
      _colorChangeString .. _valueDifference,
      _postMathValue,
      _gameInfo.winner == nil and "-" or (_bracket == 6 and (_roundsWonColor .. _roundsWon .. "/6") or _winIcon),
      _gameInfo.time,
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
