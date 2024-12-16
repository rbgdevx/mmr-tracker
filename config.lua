local _, NS = ...

local GetNumClasses = GetNumClasses
local GetClassInfo = GetClassInfo
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID

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
}

NS.Timezone = nil

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
  global = {
    lock = false,
    show2v2 = false,
    show3v3 = false,
    showRBG = false,
    showShuffle = true,
    showShuffleRating = false,
    showBlitz = true,
    showBlitzRating = false,
    showMMRDifference = true,
    showOnlyInQueue = false,
    showInInstances = false,
    showSpecIcon = false,
    hideNoResults = true,
    hideIntro = false,
    fontSize = 24,
    fontFamily = "Friz Quadrata TT",
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