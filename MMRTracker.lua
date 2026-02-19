local AddonName, NS = ...

local CreateFrame = CreateFrame
local IsInInstance = IsInInstance
local UnitAffectingCombat = UnitAffectingCombat
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitFullName = UnitFullName
local SetBattlefieldScoreFaction = SetBattlefieldScoreFaction
local GetBattlefieldTeamInfo = GetBattlefieldTeamInfo
local tostring = tostring
local GetServerTime = GetServerTime
local next = next
local LibStub = LibStub
local GetCurrentRegion = GetCurrentRegion
local GetInstanceInfo = GetInstanceInfo
local GetBattlefieldStatus = GetBattlefieldStatus
local UnitClass = UnitClass
local GetBattlefieldWinner = GetBattlefieldWinner
local GetCurrentArenaSeason = GetCurrentArenaSeason
local IsArenaSkirmish = IsArenaSkirmish
local GetBattlefieldScore = GetBattlefieldScore
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local GetNumBattlefieldScores = GetNumBattlefieldScores

local tinsert = table.insert
local sformat = string.format

local After = C_Timer.After
local GetActiveMatchBracket = C_PvP.GetActiveMatchBracket
local GetScoreInfoByPlayerGuid = C_PvP.GetScoreInfoByPlayerGuid
local IsRatedMap = C_PvP.IsRatedMap
local GetGameAccountInfoByGUID = C_BattleNet.GetGameAccountInfoByGUID
local GetCurrentCalendarTime = C_DateAndTime.GetCurrentCalendarTime
local GetServerTimeLocal = C_DateAndTime.GetServerTimeLocal
local IsRatedBattleground = C_PvP.IsRatedBattleground
local IsSoloRBG = C_PvP.IsSoloRBG
local IsRatedArena = C_PvP.IsRatedArena
local IsSoloShuffle = C_PvP.IsSoloShuffle
local IsRatedSoloShuffle = C_PvP.IsRatedSoloShuffle
local IsInBrawl = C_PvP.IsInBrawl
local GetActiveMatchDuration = C_PvP.GetActiveMatchDuration
local GetSpecialization = C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo = C_SpecializationInfo.GetSpecializationInfo

local AceGUI = LibStub("AceGUI-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LibDataBroker = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")
local ScrollingTable = LibStub("ScrollingTable")

NS.LDB = LibDataBroker
NS.LDB.Config = LibDataBroker:NewDataObject(AddonName, {
  type = "data source",
  text = AddonName,
  icon = "Interface\\PvPRankBadges\\PvPRank12", -- "Interface\\Icons\\UI_RankedPvP_07_Small",
})
NS.LDB.Icon = LibDBIcon

local MMRTrackerGUI = AceGUI:Create("Frame")
MMRTrackerGUI:SetLayout("Fill")
MMRTrackerGUI:SetWidth(790)
MMRTrackerGUI:SetHeight(625)
MMRTrackerGUI:SetTitle(AddonName)
MMRTrackerGUI:EnableResize(false)
MMRTrackerGUI:Hide()
-- MMRTrackerGUI.statustext:GetParent():Hide()
MMRTrackerGUI:SetStatusText("Viewing all data for all brackets, for your current character, for the current season.")

-- Make sure the window can be closed by pressing the escape button
_G["MMRTRACKER_DATA_TABLE_WINDOW"] = MMRTrackerGUI.frame
tinsert(UISpecialFrames, "MMRTRACKER_DATA_TABLE_WINDOW")

local SimpleGroup = AceGUI:Create("SimpleGroup")
SimpleGroup:SetLayout("Fill")
SimpleGroup:SetFullHeight(true)
SimpleGroup:SetFullWidth(true)
MMRTrackerGUI:AddChild(SimpleGroup)

local mapIDRemap = {
  [968] = 566,
  [998] = 1035,
  [1681] = 2107,
  [2197] = 30,
}

-- Date -- Map -- Spec -- Faction -- PreMatchMMR -- MMRChange -- PostMatchMMR -- Win
local columns = {
  {
    name = "Date",
    width = 130,
    align = "CENTER",
    bgcolor = {
      r = 0.15,
      g = 0.15,
      b = 0.15,
      a = 1.0,
    },
    comparesort = function(_self, _rowA, _rowB, _sortByColumn)
      return NS.CustomSort(_self, _rowA, _rowB, _sortByColumn)
    end,
  },
  {
    name = "Map",
    width = 165,
    align = "CENTER",
  },
  {
    name = "Spec",
    width = 90,
    align = "CENTER",
    bgcolor = {
      r = 0.15,
      g = 0.15,
      b = 0.15,
      a = 1.0,
    },
  },
  {
    name = "Bracket",
    width = 65,
    align = "CENTER",
  },
  {
    name = "Team",
    width = 60,
    align = "CENTER",
    bgcolor = {
      r = 0.15,
      g = 0.15,
      b = 0.15,
      a = 1.0,
    },
  },
  {
    name = "Before",
    width = 65,
    align = "CENTER",
  },
  {
    name = "+/-",
    width = 45,
    align = "CENTER",
    bgcolor = {
      r = 0.15,
      g = 0.15,
      b = 0.15,
      a = 1.0,
    },
  },
  {
    name = "After",
    width = 65,
    align = "CENTER",
  },
  {
    name = "Win",
    width = 35,
    align = "CENTER",
    bgcolor = {
      r = 0.15,
      g = 0.15,
      b = 0.15,
      a = 1.0,
    },
  },
}

local DataTable = ScrollingTable:CreateST(columns, 22, 20, nil, SimpleGroup.frame, nil)
DataTable:EnableSelection(true)
NS.DataTable = DataTable

-- Summary header above the data table
local headerFrame = CreateFrame("Frame", "MMRTrackerHeader", SimpleGroup.frame)
headerFrame:SetHeight(50)
headerFrame:SetPoint("TOPLEFT", SimpleGroup.frame, "TOPLEFT", 10, -3)
headerFrame:SetPoint("TOPRIGHT", SimpleGroup.frame, "TOPRIGHT", -10, -3)

-- Left column: Win Rate
local headerWinRateLabel = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerWinRateLabel:SetPoint("TOP", headerFrame, "TOPLEFT", 150, 0)
headerWinRateLabel:SetText("Win Rate")

local headerWinRateValue = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge2")
headerWinRateValue:SetPoint("TOP", headerWinRateLabel, "BOTTOM", 0, -4)
headerWinRateValue:SetTextColor(1, 1, 1, 1)
headerWinRateValue:SetText("0%")

-- Center column: Win - Loss
local headerWLLabel = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerWLLabel:SetPoint("TOP", headerFrame, "TOP", 0, 0)
headerWLLabel:SetText("W/L")

local headerWLValue = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge3")
headerWLValue:SetPoint("TOP", headerWLLabel, "BOTTOM", 0, -4)
headerWLValue:SetText("0 - 0")

-- Right column: Highest Rating/MMR (changes based on bracket tab)
local headerRightLabel = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerRightLabel:SetPoint("TOP", headerFrame, "TOPRIGHT", -150, 0)
headerRightLabel:SetText("Highest Rating/MMR")

local headerRightValue = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge2")
headerRightValue:SetPoint("TOP", headerRightLabel, "BOTTOM", 0, -4)
headerRightValue:SetTextColor(1, 1, 1, 1)
headerRightValue:SetText("N/A")

NS.headerFrame = headerFrame
NS.headerWinRateValue = headerWinRateValue
NS.headerRightLabel = headerRightLabel
NS.headerRightValue = headerRightValue
NS.headerWLValue = headerWLValue

NS.UpdateSummaryHeader = function()
  if not NS.allRows then
    return
  end

  local stats = NS.ComputeSummaryStats(NS.allRows)

  -- Left: Win Rate
  local total = stats.wins + stats.losses
  if total > 0 then
    local pct = math.floor((stats.wins / total) * 100 + 0.5)
    headerWinRateValue:SetText(pct .. "%")
  else
    headerWinRateValue:SetText("0%")
  end

  -- Center: Win - Loss
  local winsStr = "|cFF00FF00" .. stats.wins .. "|r"
  local lossesStr = "|cFFFF0000" .. stats.losses .. "|r"
  headerWLValue:SetText(winsStr .. " |cFFBBBBBB-|r " .. lossesStr)

  -- Right: depends on bracket tab
  local tab = NS.filters.tab
  if tab == 6 or tab == 8 then
    -- Shuffle or Blitz: show Highest MMR
    headerRightLabel:SetText("Highest MMR")
    headerRightValue:SetFont("Fonts\\FRIZQT__.TTF", 18, "")
    headerRightValue:SetTextColor(1, 1, 1, 1)
    if stats.highestMMR then
      headerRightValue:SetText(stats.highestMMR)
    else
      headerRightValue:SetText("N/A")
    end
  elseif tab == 0 or tab == 1 or tab == 3 then
    -- 2v2, 3v3, RBG: show Highest Rating
    headerRightLabel:SetText("Highest Rating")
    headerRightValue:SetFont("Fonts\\FRIZQT__.TTF", 18, "")
    headerRightValue:SetTextColor(1, 1, 1, 1)
    if stats.highestRating then
      headerRightValue:SetText(stats.highestRating)
    else
      headerRightValue:SetText("N/A")
    end
  else
    -- All tab: show Rating/MMR
    headerRightLabel:SetText("Highest Rating/MMR")
    local ratingStr = stats.highestRatingNonMMR and tostring(stats.highestRatingNonMMR) or "N/A"
    local mmrStr = stats.highestMMR and tostring(stats.highestMMR) or "N/A"
    headerRightValue:SetFont("Fonts\\FRIZQT__.TTF", 18, "")
    headerRightValue:SetTextColor(1, 1, 1, 1)
    headerRightValue:SetText(ratingStr .. " |cFFBBBBBB/|r " .. mmrStr)
  end
end

-- Tabs: All, 2v2, 3v3, Shuffle, Blitz, RBG
local tabFrame = CreateFrame("Frame", "MMRTrackerTabs", MMRTrackerGUI.frame)

for i = 1, 6 do
  local tab = CreateFrame("Button", "MMRTrackerTabsTab" .. i, MMRTrackerGUI.frame, "CharacterFrameTabTemplate")
  tab:SetID(i)
  tab:SetText(NS.TAB_LABELS[i])
  if i == 1 then
    tab:SetPoint("CENTER", MMRTrackerGUI.frame, "BOTTOMLEFT", 55, -10)
  else
    tab:SetPoint("LEFT", _G["MMRTrackerTabsTab" .. (i - 1)], "RIGHT", -15, 0)
  end
  tab:SetScript("OnClick", function(self)
    local id = self:GetID()
    NS.filters.tab = NS.TAB_BRACKETS[id]
    PanelTemplates_SetTab(tabFrame, id)
    NS.RefreshFilters()
  end)
end

PanelTemplates_SetNumTabs(tabFrame, 6)
PanelTemplates_SetTab(tabFrame, 1)

-- Dropdown filters: Region, Character, Spec, Map, Time
local function CreateFilterDropdown(label, width, parent, anchorTo, _, offsetX, offsetY)
  local dropdown = AceGUI:Create("Dropdown")
  dropdown:SetLabel(label)
  dropdown:SetWidth(width)
  dropdown.frame:SetParent(parent)
  dropdown.frame:ClearAllPoints()
  if anchorTo then
    dropdown.frame:SetPoint("LEFT", anchorTo, "RIGHT", offsetX or 2, offsetY or 0)
  else
    dropdown.frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", offsetX or 12, offsetY or 35)
  end
  dropdown.frame:Show()
  return dropdown
end

NS.RegionDropDown = CreateFilterDropdown("Region", 65, MMRTrackerGUI.frame, nil, nil, 21, 42)
NS.CharDropDown = CreateFilterDropdown("Character", 175, MMRTrackerGUI.frame, NS.RegionDropDown.frame)
NS.SpecDropDown = CreateFilterDropdown("Spec", 110, MMRTrackerGUI.frame, NS.CharDropDown.frame)
NS.MapDropDown = CreateFilterDropdown("Map", 170, MMRTrackerGUI.frame, NS.SpecDropDown.frame)
NS.TimeDropDown = CreateFilterDropdown("Time", 120, MMRTrackerGUI.frame, NS.MapDropDown.frame)

-- Season dropdown (hidden by default, shown when "Select Season" is chosen)
NS.SeasonDropDown = CreateFilterDropdown("Season", 100, MMRTrackerGUI.frame, NS.TimeDropDown.frame)
NS.SeasonDropDown.frame:Hide()

NS.RegionDropDown:SetCallback("OnValueChanged", function(_, _, value)
  if NS.refreshing then
    return
  end
  NS.filters.region = value
  NS.RefreshFilters()
end)

NS.CharDropDown:SetCallback("OnValueChanged", function(_, _, value)
  if NS.refreshing then
    return
  end
  NS.filters.character = value
  NS.RefreshFilters()
end)

NS.SpecDropDown:SetCallback("OnValueChanged", function(_, _, value)
  if NS.refreshing then
    return
  end
  NS.filters.spec = value
  NS.RefreshFilters()
end)

NS.MapDropDown:SetCallback("OnValueChanged", function(_, _, value)
  if NS.refreshing then
    return
  end
  NS.filters.map = value
  NS.RefreshFilters()
end)

NS.TimeDropDown:SetCallback("OnValueChanged", function(_, _, value)
  if NS.refreshing then
    return
  end
  NS.filters.time = value
  -- Close calendar UI if leaving Custom Range
  if NS.CalendarMode > 0 and value ~= 10 then
    NS.CalendarMode = 0
    StaticPopup_Hide("MMRTRACKER_CUSTOMDATE")
    if CalendarFrame and CalendarFrame:IsShown() then
      CalendarFrame:Hide()
    end
  end
  if value == 9 then -- Select Season
    NS.filters.selectedSeason = NS.season
    NS.SeasonDropDown.frame:Show()
    NS.RefreshFilters()
    return
  end
  if value == 10 then -- Custom Range
    NS.SeasonDropDown.frame:Hide()
    NS.CalendarMode = 1
    StaticPopup_Show("MMRTRACKER_CUSTOMDATE")
    UIParentLoadAddOn("Blizzard_Calendar")
    CalendarFrame:Show()
    return
  end
  NS.SeasonDropDown.frame:Hide()
  NS.filters.customStart = 0
  NS.filters.customEnd = 0
  NS.RefreshFilters()
end)

NS.SeasonDropDown:SetCallback("OnValueChanged", function(_, _, value)
  if NS.refreshing then
    return
  end
  NS.filters.selectedSeason = value
  NS.RefreshFilters()
end)

-- StaticPopup for custom date picker
StaticPopupDialogs["MMRTRACKER_CUSTOMDATE"] = {
  text = "Select start and end date by clicking it.",
  timeout = 0,
  whileDead = true,
  hideOnEscape = false,
}

-- Master refresh function (faceted)
NS.RefreshFilters = function()
  NS.refreshing = true

  NS.allRows = NS.UpdateTable()
  NS.DataTable:SetData(NS.allRows, true)

  -- Rebuild all dropdown lists using faceted logic
  local regionList, regionOrder = NS.BuildRegionList(NS.allRows)
  NS.RegionDropDown:SetList(regionList, regionOrder)
  if not regionList[NS.filters.region] then
    NS.filters.region = "All"
  end
  NS.RegionDropDown:SetValue(NS.filters.region)

  local charList, charOrder = NS.BuildCharacterList(NS.allRows)
  NS.CharDropDown:SetList(charList, charOrder)
  if not charList[NS.filters.character] then
    NS.filters.character = "All"
  end
  NS.CharDropDown:SetValue(NS.filters.character)

  local specList, specOrder = NS.BuildSpecList(NS.allRows)
  NS.SpecDropDown:SetList(specList, specOrder)
  if not specList[NS.filters.spec] then
    NS.filters.spec = "All"
  end
  NS.SpecDropDown:SetValue(NS.filters.spec)

  local mapList, mapOrder = NS.BuildMapList(NS.allRows)
  NS.MapDropDown:SetList(mapList, mapOrder)
  if not mapList[NS.filters.map] then
    NS.filters.map = "All"
  end
  NS.MapDropDown:SetValue(NS.filters.map)

  -- Rebuild season dropdown when in "Select Season" mode
  if NS.filters.time == 9 then
    local seasonList, seasonOrder = NS.BuildSeasonList(NS.allRows)
    NS.SeasonDropDown:SetList(seasonList, seasonOrder)
    if not seasonList[NS.filters.selectedSeason] then
      -- Selected season no longer in filtered data, pick first available
      NS.filters.selectedSeason = seasonOrder[1] or 0
    end
    NS.SeasonDropDown:SetValue(NS.filters.selectedSeason)
  end

  NS.refreshing = false

  -- Apply filter + force visual refresh
  NS.DataTable:SetFilter(NS.TableFilter)
  NS.DataTable:Hide()
  NS.DataTable:Show()

  -- Update status text and summary header
  NS.UpdateStatusText()
  NS.UpdateSummaryHeader()
end

NS.UpdateStatusText = function()
  local bracket = NS.filters.tab and NS.TRACKED_BRACKETS[NS.filters.tab] or "All Brackets"
  local spec = NS.filters.spec ~= "All" and NS.filters.spec or "All Specs"
  local char = NS.filters.character ~= "All" and NS.filters.character or "All Characters"
  local region = NS.filters.region ~= "All" and NS.filters.region or "All Regions"

  local mode = NS.filters.time
  local timeStr
  if mode == 1 then
    timeStr = "All Time"
  elseif mode == 2 then
    timeStr = "Session"
  elseif mode == 3 then
    timeStr = "Today"
  elseif mode == 4 then
    timeStr = "Yesterday"
  elseif mode == 5 then
    timeStr = "This Week"
  elseif mode == 6 then
    timeStr = "This Month"
  elseif mode == 7 then
    timeStr = "This Season"
  elseif mode == 8 then
    timeStr = "Prev. Season"
  elseif mode == 9 then
    if NS.filters.selectedSeason == "All" then
      timeStr = "All Seasons"
    else
      timeStr = NS.SEASON_NAMES[NS.filters.selectedSeason] or ("Season " .. NS.filters.selectedSeason)
    end
  elseif mode == 10 then
    local s, e = NS.filters.customStart, NS.filters.customEnd
    if s > 0 and e > 0 then
      timeStr = date("%m/%d/%y", s) .. "-" .. date("%m/%d/%y", e)
    elseif s > 0 then
      timeStr = date("%m/%d/%y", s) .. "+"
    else
      timeStr = "Custom Range"
    end
  else
    timeStr = "Unknown"
  end

  MMRTrackerGUI:SetStatusText(sformat("Viewing: %s, %s, %s, %s, %s.", region, char, spec, bracket, timeStr))
end

local MMRTracker = {}
NS.MMRTracker = MMRTracker

local MMRTrackerFrame = CreateFrame("Frame", AddonName .. "Frame")
MMRTrackerFrame:SetScript("OnEvent", function(_, event, ...)
  if MMRTracker[event] then
    MMRTracker[event](MMRTracker, ...)
  end
end)
MMRTrackerFrame.lastGame = {}
MMRTrackerFrame.wasOnLoadingScreen = true
MMRTrackerFrame.instanceName = ""
MMRTrackerFrame.instanceType = nil
MMRTrackerFrame.inArena = false
MMRTrackerFrame.loaded = false
MMRTrackerFrame.wasInInstance = false
MMRTrackerFrame.ratedMap = false
MMRTrackerFrame.inQueue = false
NS.MMRTracker.frame = MMRTrackerFrame

local function GetActualRegion(guid)
  local gameAccountInfo = GetGameAccountInfoByGUID(guid)
  return gameAccountInfo and gameAccountInfo.regionID or GetCurrentRegion()
end

local playerGUID = UnitGUID("player")
local regionID = GetActualRegion(playerGUID)
local regionMatch = NS.REGION_NAME[regionID]
local regionName = regionMatch or "UNKNOWN"
if not regionName then
  print("Unknown Region, Please report to the addon author", "Region ID: " .. regionID)
end
local playerRegion = regionName
local playerName, playerRealm = UnitFullName("player")
local playerFullName = playerName .. (playerRealm and ("-" .. playerRealm) or "")
NS.playerInfo = {
  region = playerRegion,
  guid = playerGUID,
  name = playerFullName,
  spec = "",
}
local playerSpec = GetSpecialization()
if playerSpec then
  local _, playerSpecName = GetSpecializationInfo(playerSpec)
  local _, playerClassFilename = UnitClass("player")
  NS.playerInfo.spec = playerSpecName
  NS.playerInfo.class = playerClassFilename
end

function NS.TrackMMR()
  local TIME = NS.GetUTCTimestamp()

  local hidden = false
  local map = select(8, GetInstanceInfo())
  local isArena = IsActiveBattlefieldArena()
  local isBrawl = IsInBrawl()
  local isSoloShuffle = IsSoloShuffle()
  local isRated = true
  local playerNum = GetNumBattlefieldScores()

  if mapIDRemap[map] then
    map = mapIDRemap[map]
  end

  local gameInfo = {
    mapName = MMRTrackerFrame.instanceName,
    race = "",
    class = "",
    classToken = "",
    spec = "",
    faction = -1,
    serverTime = GetServerTime(),
    gameTime = GetCurrentCalendarTime(),
    localTime = GetServerTimeLocal(),
    time = TIME,
    date = NS.DateClean(TIME, NS.Timezone, NS.playerInfo.region),
    duration = GetActiveMatchDuration(),
    preMatchMMR = 0,
    mmrChange = 0,
    postMatchMMR = 0,
    bracket = -1,
    teamRating = 0,
    previousRating = 0,
    newRating = 0,
    ratingChange = 0,
    rating = 0,
    winner = 0,
    season = GetCurrentArenaSeason(),
    stats = {},
  }

  SetBattlefieldScoreFaction(-1)

  local bracket = GetActiveMatchBracket()
  if bracket then
    gameInfo.bracket = bracket
  end

  -- teamName, oldTeamRating, newTeamRating, teamRating (mmr)
  local _, _, _, teamRating = GetBattlefieldTeamInfo(gameInfo.faction)

  local info = GetScoreInfoByPlayerGuid(NS.playerInfo.guid)
  if info then
    local winner = GetBattlefieldWinner()

    local preMatchMMR = info.prematchMMR
    local mmrChange = info.postmatchMMR - info.prematchMMR
    local postMatchMMR = info.postmatchMMR

    gameInfo.race = info.raceName
    gameInfo.class = info.className
    gameInfo.classToken = info.classToken
    gameInfo.spec = info.talentSpec
    gameInfo.faction = info.faction
    gameInfo.preMatchMMR = preMatchMMR
    gameInfo.mmrChange = mmrChange
    gameInfo.postMatchMMR = postMatchMMR
    gameInfo.teamRating = teamRating
    gameInfo.previousRating = info.rating
    gameInfo.newRating = info.rating + info.ratingChange
    gameInfo.ratingChange = info.ratingChange
    gameInfo.rating = info.rating
    gameInfo.winner = winner
    gameInfo.stats = info.stats
  end

  if MMRTrackerFrame.ratedMap or gameInfo.postMatchMMR > 0 or gameInfo.teamRating > 0 then
    local hasBracket = gameInfo.bracket ~= -1 and NS.TRACKED_BRACKETS[gameInfo.bracket]
    local hasSpec = gameInfo.spec ~= ""

    if hasBracket and hasSpec then
      local bracketKey = tostring(gameInfo.bracket)

      if not NS.db.data[NS.playerInfo.region] then
        NS.db.data[NS.playerInfo.region] = {}
      end
      if not NS.db.data[NS.playerInfo.region][NS.playerInfo.name] then
        NS.db.data[NS.playerInfo.region][NS.playerInfo.name] = {}
      end
      if not NS.db.data[NS.playerInfo.region][NS.playerInfo.name][bracketKey] then
        NS.db.data[NS.playerInfo.region][NS.playerInfo.name][bracketKey] = {}
      end
      if gameInfo.bracket == 6 or gameInfo.bracket == 8 then
        if not NS.db.data[NS.playerInfo.region][NS.playerInfo.name][bracketKey][gameInfo.spec] then
          NS.db.data[NS.playerInfo.region][NS.playerInfo.name][bracketKey][gameInfo.spec] = {}
        end
      end

      local gameTable = {
        mapName = gameInfo.mapName,
        race = gameInfo.race,
        class = gameInfo.class,
        classToken = gameInfo.classToken,
        spec = gameInfo.spec,
        faction = gameInfo.faction,
        serverTime = gameInfo.serverTime,
        gameTime = gameInfo.gameTime,
        localTime = gameInfo.localTime,
        time = gameInfo.time,
        date = gameInfo.date,
        duration = gameInfo.duration,
        preMatchMMR = gameInfo.preMatchMMR,
        mmrChange = gameInfo.mmrChange,
        postMatchMMR = gameInfo.postMatchMMR,
        bracket = bracketKey,
        teamRating = gameInfo.teamRating,
        previousRating = gameInfo.previousRating,
        newRating = gameInfo.newRating,
        ratingChange = gameInfo.ratingChange,
        rating = gameInfo.rating,
        winner = gameInfo.winner,
        season = gameInfo.season,
        stats = gameInfo.stats,
      }

      if gameInfo.bracket == 6 or gameInfo.bracket == 8 then
        tinsert(NS.db.data[NS.playerInfo.region][NS.playerInfo.name][bracketKey][gameInfo.spec], gameTable)
      else
        tinsert(NS.db.data[NS.playerInfo.region][NS.playerInfo.name][bracketKey], gameTable)
      end

      NS.db.data[NS.playerInfo.region][NS.playerInfo.name].lastGame = gameTable
      MMRTrackerFrame.lastGame = gameTable

      local soloLabel = PVP_RATING
      local preMatchValue = gameInfo.rating
      local postMathValue = gameInfo.rating + gameInfo.ratingChange
      local valueChange = gameInfo.ratingChange
      if gameInfo.bracket == 6 and NS.db.global.showShuffleRating == false then
        soloLabel = "MMR:"
        preMatchValue = gameInfo.preMatchMMR
        postMathValue = gameInfo.postMatchMMR
        valueChange = gameInfo.mmrChange
      end
      if gameInfo.bracket == 8 and NS.db.global.showBlitzRating == false then
        soloLabel = "MMR:"
        preMatchValue = gameInfo.preMatchMMR
        postMathValue = gameInfo.postMatchMMR
        valueChange = gameInfo.mmrChange
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

      local bracketString = NS.TRACKED_BRACKETS[gameInfo.bracket] .. " " .. soloLabel .. " "
      local valueString = showMMRDifference and (preMatchValue .. " › " .. postMathValue) or postMathValue
      local positiveChange = valueChange > 0
      local valueDifference = positiveChange and ("+" .. valueChange) or valueChange
      local valueColor = valueChange == 0 and "" or positiveChange and "|cFF00FF00" or "|cFFFF0000"
      local userColor = "|c" .. userColorHex
      local colorString = includeChange and userColor or valueColor
      local changeString = showGainsLosses and (colorString .. " (" .. valueDifference .. ")" .. "|r") or ""
      local string = bracketString .. valueString .. changeString
      local str = sformat(string)
      local index = 0
      local key = "none"
      if gameInfo.bracket == 0 then
        index = 1
        key = "2v2"
      elseif gameInfo.bracket == 1 then
        index = 2
        key = "3v3"
      elseif gameInfo.bracket == 3 then
        index = 3
        key = "rbg"
      elseif gameInfo.bracket == 6 then
        index = 4
        key = "shuffle"
      elseif gameInfo.bracket == 8 then
        index = 5
        key = "blitz"
      end
      NS.Interface:AddText(NS.Interface, str, index, key, true)

      for i = 1, #NS.lines, 1 do
        local matchingText = NS.lines[i]
        if matchingText.bracket == "none" then
          matchingText:SetAlpha(0)
          break
        end
      end
    end
  end

  for i = 1, playerNum do
    local data = { GetBattlefieldScore(i) }
    if data[1]:lower() == UnitName("PLAYER"):lower() then
      playerNum = i
    end
  end

  if
    IsRatedBattleground()
    or IsSoloRBG()
    or (IsRatedArena() and not IsArenaSkirmish() and not isSoloShuffle)
    or IsRatedSoloShuffle()
  then
    isRated = true
  else
    isRated = false
  end

  if not isArena then
    if not isRated and playerNum then
      playerNum = 1
    end
  end

  -- Hide corrupted records
  if not playerNum or map == 1170 or map == 2177 or (isArena and isBrawl and not isSoloShuffle) then
    hidden = true
  else
    hidden = false
  end

  if hidden then
    print("\124cFF74D06C[MMRTracker]\124r " .. "API returned corrupted data. Match will not be recorded.")
  end

  MMRTrackerFrame.instanceName = ""
end

local ShuffleFrame = CreateFrame("Frame")
ShuffleFrame.eventRegistered = false

function MMRTracker:PLAYER_REGEN_ENABLED()
  MMRTrackerFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  ShuffleFrame.eventRegistered = false
end

function MMRTracker:GROUP_ROSTER_UPDATE()
  local _currentSpec = GetSpecialization()
  if _currentSpec then
    local _, _currentSpecName = GetSpecializationInfo(_currentSpec)
    local _, _classFilename, _ = UnitClass("player")
    NS.playerInfo.spec = _currentSpecName
    NS.playerInfo.class = _classFilename
  end

  if not MMRTrackerFrame.inArena then
    return
  end

  local aura = C_UnitAuras.GetAuraDataBySpellName("player", "Arena Preparation")
  local name = aura and aura.name
  if not name then
    return
  end

  if UnitAffectingCombat("player") then
    if not ShuffleFrame.eventRegistered then
      MMRTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
      ShuffleFrame.eventRegistered = true
    end
  else
  end
end

function MMRTracker:ARENA_OPPONENT_UPDATE()
  if not MMRTrackerFrame.inArena then
    return
  end

  local aura = C_UnitAuras.GetAuraDataBySpellName("player", "Arena Preparation")
  local name = aura and aura.name
  if not name then
    return
  end

  if UnitAffectingCombat("player") then
    if not ShuffleFrame.eventRegistered then
      MMRTrackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
      ShuffleFrame.eventRegistered = true
    end
  else
  end
end

function MMRTracker:PVP_MATCH_COMPLETE()
  After(1, NS.TrackMMR)
end

function MMRTracker:PLAYER_SPECIALIZATION_CHANGED()
  local _currentSpec = GetSpecialization()
  if _currentSpec then
    local _, _currentSpecName = GetSpecializationInfo(_currentSpec)
    local _, _classFilename, _ = UnitClass("player")
    NS.playerInfo.spec = _currentSpecName
    NS.playerInfo.class = _classFilename
  end

  NS.DisplayBracketData()
end

local function toggleVisibilityInQueue()
  local status = GetBattlefieldStatus(1)
  local inInstance, instanceType = IsInInstance()
  local inArena = inInstance and (instanceType == "arena")
  local inBattleground = inInstance and (instanceType == "pvp")
  local inPVP = inArena or inBattleground
  local inPVE = not inPVP and inInstance

  local showInPVE = NS.db.global.showInPVE and inPVE
  local showInPVP = NS.db.global.showInPVP and inPVP

  if status == "queued" then
    MMRTrackerFrame.inQueue = true

    if inInstance then
      if showInPVE or showInPVP then
        NS.Interface.textFrame:SetAlpha(1)
      else
        NS.Interface.textFrame:SetAlpha(0)
      end
    else
      NS.Interface.textFrame:SetAlpha(1)
    end
  else
    MMRTrackerFrame.inQueue = false

    if inInstance then
      if showInPVE or showInPVP then
        NS.Interface.textFrame:SetAlpha(1)
      else
        NS.Interface.textFrame:SetAlpha(0)
      end
    else
      if NS.db.global.showOnlyInQueue then
        NS.Interface.textFrame:SetAlpha(0)
      else
        NS.Interface.textFrame:SetAlpha(1)
      end
    end
  end
end

local function instanceCheck()
  local inInstance, instanceType = IsInInstance()

  MMRTrackerFrame.inArena = inInstance and (instanceType == "arena")

  if instanceType ~= MMRTrackerFrame.instanceType then
    MMRTrackerFrame.instanceType = instanceType
  end

  if instanceType ~= "none" then
    local name = GetInstanceInfo()
    MMRTrackerFrame.instanceName = name
  end
end

function MMRTracker:LOADING_SCREEN_DISABLED()
  After(2, function()
    MMRTrackerFrame.wasOnLoadingScreen = false

    if MMRTrackerFrame.wasInInstance then
      MMRTrackerFrame.ratedMap = IsRatedMap()
    end
  end)
end

function MMRTracker:LOADING_SCREEN_ENABLED()
  MMRTrackerFrame.wasOnLoadingScreen = true
end

function MMRTracker:PLAYER_LEAVING_WORLD()
  if MMRTrackerFrame.wasInInstance then
    MMRTrackerFrame.wasInInstance = false
  end

  After(2, function()
    MMRTrackerFrame.wasOnLoadingScreen = false
  end)
end

function MMRTracker:PVP_MATCH_ACTIVE()
  local name = GetInstanceInfo()
  MMRTrackerFrame.instanceName = name
end

function MMRTracker:UPDATE_BATTLEFIELD_STATUS(_)
  toggleVisibilityInQueue()
end

function MMRTracker:PLAYER_ENTERING_WORLD()
  MMRTrackerFrame.wasOnLoadingScreen = true

  instanceCheck()

  if MMRTrackerFrame.instanceType ~= "none" and MMRTrackerFrame.instanceType ~= nil then
    MMRTrackerFrame.wasInInstance = true
  end

  NS.DisplayBracketData()

  NS.DataTable.frame:ClearAllPoints()
  NS.DataTable.frame:SetPoint("TOP", SimpleGroup.frame, "TOP", 0, -65)

  NS.RefreshFilters()

  if MMRTrackerFrame.instanceType == "none" then
    toggleVisibilityInQueue()
  else
    if NS.db.global.showInInstances then
      NS.Interface.textFrame:SetAlpha(1)
    else
      NS.Interface.textFrame:SetAlpha(0)
    end
  end
end

function MMRTracker:PLAYER_LOGIN()
  MMRTrackerFrame:UnregisterEvent("PLAYER_LOGIN")

  NS.SessionStart, NS.Timezone = NS.GetUTCTimestamp(true)

  local _playerGUID = UnitGUID("player")
  local _region = NS.REGION_NAME[GetActualRegion(playerGUID)]
  local _name, _realm = UnitFullName("player")
  local _fullName = _name .. "-" .. _realm
  NS.playerInfo.region = _region
  NS.playerInfo.guid = _playerGUID
  NS.playerInfo.name = _fullName

  local _currentSpec = GetSpecialization()
  if _currentSpec then
    local _, _currentSpecName = GetSpecializationInfo(_currentSpec)
    local _, _classFilename, _ = UnitClass("player")
    NS.playerInfo.spec = _currentSpecName
    NS.playerInfo.class = _classFilename
  end

  local _currentSeason = GetCurrentArenaSeason()
  NS.season = _currentSeason

  NS.Interface:CreateInterface()

  -- Initialize filter defaults
  NS.filters.region = NS.playerInfo.region
  NS.filters.character = NS.playerInfo.name
  NS.filters.spec = NS.playerInfo.spec
  -- Determine if we're in an active season (season > 0 AND recognized in SEASON_NAMES)
  local isActiveSeason = NS.season and NS.season > 0 and NS.SEASON_NAMES[NS.season]

  if isActiveSeason then
    NS.filters.time = 7 -- "This Season"
    NS.TimeDropDown:SetList(NS.TIME_FILTERS, NS.TIME_FILTER_ORDER)
    NS.TimeDropDown:SetValue(7)
  else
    -- Hide "This Season" (7) and "Prev. Season" (8) during off-season
    local filteredList = {}
    local filteredOrder = {}
    for _, key in ipairs(NS.TIME_FILTER_ORDER) do
      if key ~= 7 and key ~= 8 then
        filteredList[key] = NS.TIME_FILTERS[key]
        tinsert(filteredOrder, key)
      end
    end
    NS.TimeDropDown:SetList(filteredList, filteredOrder)
    NS.filters.time = 9 -- "Select Season"
    -- API returned 0 → "Off-Season"; nil or unrecognized → "No Season"
    if NS.season == 0 then
      NS.filters.selectedSeason = 0
    else
      NS.filters.selectedSeason = NS.NO_SEASON -- -1
    end
    NS.TimeDropDown:SetValue(9)
    NS.SeasonDropDown.frame:Show()
  end

  MMRTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  MMRTrackerFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
  MMRTrackerFrame:RegisterEvent("LOADING_SCREEN_ENABLED")
  MMRTrackerFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
  MMRTrackerFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
  MMRTrackerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  MMRTrackerFrame:RegisterEvent("PVP_MATCH_COMPLETE")
  MMRTrackerFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  MMRTrackerFrame:RegisterEvent("PVP_MATCH_ACTIVE")
  MMRTrackerFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
end
MMRTrackerFrame:RegisterEvent("PLAYER_LOGIN")

function NS.OnDbChanged()
  MMRTrackerFrame.dbChanged = true

  local inInstance, instanceType = IsInInstance()
  local inArena = inInstance and (instanceType == "arena")
  local inBattleground = inInstance and (instanceType == "pvp")
  local inPVP = inArena or inBattleground
  local inPVE = not inPVP and inInstance

  local showInPVE = NS.db.global.showInPVE and inPVE
  local showInPVP = NS.db.global.showInPVP and inPVP

  NS.DisplayBracketData()

  NS.RefreshFilters()

  if NS.db.global.lock then
    NS.Interface:Lock(NS.Interface.textFrame)
  else
    NS.Interface:Unlock(NS.Interface.textFrame)
  end

  if inInstance then
    if showInPVE or showInPVP then
      NS.Interface.textFrame:SetAlpha(1)
    else
      NS.Interface.textFrame:SetAlpha(0)
    end
  else
    toggleVisibilityInQueue()
  end

  if NS.db.minimap.hide then
    NS.LDB.Icon:Hide(AddonName)
  else
    NS.LDB.Icon:Show(AddonName)
  end

  MMRTrackerFrame.dbChanged = false
end

function NS.LDB.Config:OnClick(button)
  if button == "LeftButton" then
    if not MMRTrackerGUI:IsVisible() then
      MMRTrackerGUI:Show()
    else
      MMRTrackerGUI:Hide()
    end
  elseif button == "RightButton" then
    if not AceConfigDialog.OpenFrames[AddonName] then
      AceConfigDialog:Open(AddonName)
    else
      AceConfigDialog:Close(AddonName)
    end
  end
end

function NS.Options_SlashCommands(message)
  if string.lower(message) == "table" then
    if not MMRTrackerGUI:IsVisible() then
      MMRTrackerGUI:Show()
    else
      MMRTrackerGUI:Hide()
    end
  else
    if not AceConfigDialog.OpenFrames[AddonName] then
      AceConfigDialog:Open(AddonName)
    else
      AceConfigDialog:Close(AddonName)
    end
  end
end

function NS.Options_Setup()
  AceConfig:RegisterOptionsTable(AddonName, NS.AceConfig)
  AceConfigDialog:AddToBlizOptions(AddonName, AddonName)
  NS.LDB.Icon:Register(AddonName, NS.LDB.Config, NS.db.minimap)

  SLASH_MMRT1 = "/mmrtracker"
  SLASH_MMRT2 = "/mmrt"

  function SlashCmdList.MMRT(message)
    NS.Options_SlashCommands(message)
  end
end

function MMRTracker:ADDON_LOADED(addon)
  if addon == AddonName then
    MMRTrackerDB = MMRTrackerDB and next(MMRTrackerDB) ~= nil and MMRTrackerDB or {}

    -- Copy any settings from default if they don't exist in current profile
    NS.CopyDefaults(NS.DefaultDatabase, MMRTrackerDB)

    -- Migrate old data with no seasons to now have seasons
    -- NS.MigrateDB(MMRTrackerDB)

    -- Reference to active db profile
    -- Always use this directly or reference will be invalid
    NS.db = MMRTrackerDB

    -- Remove table values no longer found in default settings
    NS.CleanupDB(MMRTrackerDB, NS.DefaultDatabase)

    NS.Options_Setup()
  elseif addon == "Blizzard_Calendar" then
    hooksecurefunc("CalendarDayButton_Click", NS.CalendarParser)
    CalendarFrame:HookScript("OnHide", NS.CalendarCleanup)
    MMRTrackerFrame:UnregisterEvent("ADDON_LOADED")
  end
end
MMRTrackerFrame:RegisterEvent("ADDON_LOADED")
