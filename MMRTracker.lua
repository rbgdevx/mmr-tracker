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
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
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
MMRTrackerGUI:SetWidth(750)
MMRTrackerGUI:SetHeight(540)
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
    width = 120,
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
    width = 135,
    align = "CENTER",
  },
  {
    name = "Spec",
    width = 85,
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
      -- 	preMatchValue = 0
      -- end
      -- if postMathValue < 0 then
      -- 	postMathValue = 0
      -- end
      local bracketString = NS.TRACKED_BRACKETS[gameInfo.bracket] .. " " .. soloLabel .. " "
      local valueString = NS.db.global.showMMRDifference and (preMatchValue .. " › " .. postMathValue)
        or postMathValue
      local positiveChange = valueChange > 0
      local valueDifference = positiveChange and ("+" .. valueChange) or valueChange
      local valueColor = positiveChange and "|cFF00FF00" or "|cFFFF0000"
      -- convert user color rgb to hex
      local dbColor = NS.db.global.color
      local userColorHex =
        sformat("%02X%02X%02X%02X", dbColor.a * 255, dbColor.r * 255, dbColor.g * 255, dbColor.b * 255)
      local userColor = "|c" .. userColorHex
      local colorString = valueChange == 0 and "" or NS.db.global.includeChange and userColor or valueColor
      local changeString = NS.db.global.showMMRDifference and (colorString .. " (" .. valueDifference .. ")" .. "|r")
        or ""
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

  local name = AuraUtil.FindAuraByName("Arena Preparation", "player", "HELPFUL")
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

  local name = AuraUtil.FindAuraByName("Arena Preparation", "player", "HELPFUL")
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
  NS.DataTable.frame:SetPoint("TOP", SimpleGroup.frame, "TOP", 0, -20)

  local rows = NS.UpdateTable()
  NS.DataTable:SetData(rows, true)

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

  local rows = NS.UpdateTable()
  NS.DataTable:SetData(rows, true)

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
    MMRTrackerFrame:UnregisterEvent("ADDON_LOADED")

    MMRTrackerDB = MMRTrackerDB and next(MMRTrackerDB) ~= nil and MMRTrackerDB or {}

    -- Copy any settings from default if they don't exist in current profile
    NS.CopyDefaults(NS.DefaultDatabase, MMRTrackerDB)

    -- Migrate old data with no seasons to now have seasons
    NS.MigrateDB(MMRTrackerDB)

    -- Reference to active db profile
    -- Always use this directly or reference will be invalid
    NS.db = MMRTrackerDB

    -- Remove table values no longer found in default settings
    NS.CleanupDB(MMRTrackerDB, NS.DefaultDatabase)

    NS.Options_Setup()
  end
end
MMRTrackerFrame:RegisterEvent("ADDON_LOADED")
