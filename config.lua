local _, NS = ...

local GetNumClasses = GetNumClasses
local GetClassInfo = GetClassInfo
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local GetCurrentArenaSeason = GetCurrentArenaSeason

local GetNumSpecializationsForClassID = C_SpecializationInfo.GetNumSpecializationsForClassID

-- CONQUEST_BRACKET_INDEXES
-- 1=7
-- 2=9
-- 3=1
-- 4=2
-- 5=4
NS.TRACKED_BRACKETS = {
  [0] = "2v2",
  [1] = "3v3",
  [3] = "RBG",
  [6] = "Shuffle",
  [8] = "Blitz",
}
NS.REGION_NAME = {
  [1] = "US",
  [2] = "KR",
  [3] = "EU",
  [4] = "TW",
  [5] = "CN",
  [90] = "PTR",
}

NS.SessionStart = nil
NS.Timezone = nil

-- Tab layout: All tabs on left side, growing right
-- Tab index → bracket key (nil = all)
NS.TAB_BRACKETS = {
  [1] = nil, -- All
  [2] = 0, -- 2v2
  [3] = 1, -- 3v3
  [4] = 3, -- RBG
  [5] = 6, -- Shuffle
  [6] = 8, -- Blitz
}
NS.TAB_LABELS = { "All", "2v2", "3v3", "RBG", "Shuffle", "Blitz" }

-- Time filter modes
NS.TIME_FILTERS = {
  [1] = "All",
  [2] = "Session",
  [3] = "Today",
  [4] = "Yesterday",
  [5] = "This Week",
  [6] = "This Month",
  [7] = "This Season",
  [8] = "Prev. Season",
  [9] = "Select Season",
  [10] = "Custom Range",
}
NS.TIME_FILTER_ORDER = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

-- Runtime filter state (not persisted between sessions)
NS.filters = {
  region = "All",
  character = "All",
  tab = nil, -- nil = all brackets, or bracket key number (0,1,3,6,8)
  spec = "All",
  map = "All",
  time = 7, -- default: "This Season"
  selectedSeason = 0, -- for "Select Season" mode
  customStart = 0,
  customEnd = 0,
}

-- Calendar state for custom date picker
NS.CalendarMode = 0 -- 0=inactive, 1=selecting start, 2=selecting end

-- Anti-recursion guard for dropdown SetValue callbacks
NS.refreshing = false

-- Cached row data for faceted filtering
NS.allRows = {}

-- 38 is the first season this addon came out - T.W.W. Season 1
-- 0 is when there is no active season
NS.season = GetCurrentArenaSeason and GetCurrentArenaSeason() or 0

-- https://warcraft.wiki.gg/wiki/PvP_season#Seasons
-- Static season lookup — update CURRENT_SEASON each time a new season starts
-- During off-season (API returns 0), filters use CURRENT_SEASON as fallback
NS.CURRENT_SEASON = 41 -- MN S1
NS.NO_SEASON = -1 -- sentinel for data with nil/missing season
NS.SEASON_NAMES = {
  [-1] = "No Season",
  [0] = "Off-Season",
  [1] = "TBC S1",
  [2] = "TBC S2",
  [3] = "TBC S3",
  [4] = "TBC S4",
  [5] = "Wrath S1",
  [6] = "Wrath S2",
  [7] = "Wrath S3",
  [8] = "Wrath S4",
  [9] = "Cata S1",
  [10] = "Cata S2",
  [11] = "Cata S3",
  [12] = "MoP S1",
  [13] = "MoP S2",
  [14] = "MoP S3",
  [15] = "MoP S4",
  [16] = "WoD S1",
  [17] = "WoD S2",
  [18] = "WoD S3",
  [19] = "Legion S1",
  [20] = "Legion S2",
  [21] = "Legion S3",
  [22] = "Legion S4",
  [23] = "Legion S5",
  [24] = "Legion S6",
  [25] = "Legion S7",
  [26] = "BfA S1",
  [27] = "BfA S2",
  [28] = "BfA S3",
  [29] = "BfA S4",
  [30] = "SL S1",
  [31] = "SL S2",
  [32] = "SL S3",
  [33] = "SL S4",
  [34] = "DF S1",
  [35] = "DF S2",
  [36] = "DF S3",
  [37] = "DF S4",
  [38] = "TWW S1",
  [39] = "TWW S2",
  [40] = "TWW S3",
  [41] = "MN S1",
  [42] = "MN S2",
  [43] = "MN S3",
}

NS.CLASS_INFO = {}
for classID = 1, GetNumClasses() do
  local _, classToken = GetClassInfo(classID)
  if classToken then
    NS.CLASS_INFO[classToken] = {}

    if GetNumSpecializationsForClassID then
      for i = 1, GetNumSpecializationsForClassID(classID) do
        local _, maleSpecName, _, icon = GetSpecializationInfoForClassID(classID, i, 2)
        NS.CLASS_INFO[classToken][maleSpecName] = { specIcon = icon }

        local _, femaleSpecName = GetSpecializationInfoForClassID(classID, i, 3)
        if femaleSpecName and femaleSpecName ~= maleSpecName then
          NS.CLASS_INFO[classToken][femaleSpecName] = NS.CLASS_INFO[classToken][maleSpecName]
        end
      end
    end
  end
end

NS.DefaultDatabase = {
  migrated = false,
  global = {
    lock = false,
    show2v2 = false,
    show3v3 = false,
    showRBG = false,
    showShuffle = false,
    showShuffleRating = false,
    showBlitz = true,
    showBlitzRating = false,
    showMMRDifference = true,
    showGainsLosses = true,
    showOnlyInQueue = false,
    showInPVE = false,
    showInPVP = false,
    showSpecIcon = false,
    hideNoResults = true,
    hideIntro = false,
    fontSize = 24,
    fontFamily = "Friz Quadrata TT",
    includeChange = false,
    growDirection = "DOWN",
    textAlignment = "LEFT",
    color = {
      r = 255 / 255,
      g = 255 / 255,
      b = 255 / 255,
      a = 1,
    },
    position = {
      "CENTER",
      "CENTER",
      0,
      0,
    },
  },
  minimap = {
    hide = false,
    minimapPos = 149.1457231725239,
  },
  data = {},
}
