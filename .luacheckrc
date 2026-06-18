-- Static analysis for the mmr-tracker WoW addon.  Run from the repo root: luacheck .
--
-- Tailored to the addon: WoW globals seeded from its .luarc.json and completed
-- with a luacheck harvest of APIs the code actually calls (luacheck has no WoW
-- API library of its own, unlike the LSP's WoW addon the .luarc.json leans on).
-- NOTE: luacheck must run under Lua <= 5.4 (it crashes on 5.5). The `luacheck`
-- on PATH is built against lua@5.4; we still lint WoW's 5.1 dialect via std.

std = "lua51"            -- WoW runs Lua 5.1
max_line_length = false  -- WoW addon lines are routinely wide

exclude_files = {
  ".libraries", "libs",
}

-- WoW idioms that aren't defects: `_ADDON` addon-load vararg; `self` on
-- `:` colon-method APIs that don't use it.
ignore = { "_ADDON", "212/self" }

-- Globals the addon DEFINES/WRITES (saved-vars, slash handlers).
globals = {
  "MMRTrackerDB", "SLASH_MMRT1", "SLASH_MMRT2", "SlashCmdList",
}

-- Blizzard client API the addon READS.
read_globals = {
  "CLOSE", "CONQUEST_BUTTONS", "CUSTOM_CLASS_COLORS", "C_AddOns", "C_BattleNet",
  "C_DateAndTime", "C_PaperDollInfo", "C_PvP", "C_SpecializationInfo", "C_Timer",
  "C_UnitAuras", "ConquestFrame", "ConquestTooltip", "CopyTable", "CreateFrame",
  "FACTION_ALLIANCE", "FACTION_HORDE", "FauxScrollFrame_GetOffset", "FauxScrollFrame_Update",
  "GetAddOnMetadata", "GetBattlefieldStatus", "GetBattlefieldTeamInfo", "GetBattlefieldWinner",
  "GetClassInfo", "GetCurrentArenaSeason", "GetCurrentRegion", "GetInspectArenaData",
  "GetInstanceInfo", "GetNumBattlefieldScores", "GetNumClasses", "GetPersonalRatedInfo",
  "GetServerTime", "GetSpecializationInfoForClassID", "GetTime", "InCombatLockdown",
  "InspectPVPFrame", "IsInInstance", "IsShiftKeyDown", "LibStub", "PVP_RATING",
  "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab", "RAID_CLASS_COLORS",
  "SetBattlefieldScoreFaction", "UIParent", "UISpecialFrames", "UnitAffectingCombat",
  "UnitClass", "UnitFullName", "UnitGUID", "VICTORY_TEXT_ARENA0", "VICTORY_TEXT_ARENA1",
  "date", "format", "hooksecurefunc", "issecretvalue", "tinsert", "wipe",
}
