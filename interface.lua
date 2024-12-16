local AddonName, NS = ...

local CreateFrame = CreateFrame
local LibStub = LibStub
local pairs = pairs

local LSM = LibStub("LibSharedMedia-3.0")

local Interface = {}
NS.Interface = Interface

local InterfaceFrame = CreateFrame("Frame", AddonName .. "InterfaceFrame")
InterfaceFrame.hideIntro = false
NS.Interface.frame = InterfaceFrame

local lines = {}
NS.lines = lines

local sformat = string.format

function Interface:StopMovement(frame)
  frame:SetMovable(false)
end

function Interface:MakeMoveable(frame)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(f)
    if NS.db.global.lock == false then
      f:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(f)
    if NS.db.global.lock == false then
      f:StopMovingOrSizing()
      local a, _, b, c, d = f:GetPoint()
      NS.db.global.position[1] = a
      NS.db.global.position[2] = b
      NS.db.global.position[3] = c
      NS.db.global.position[4] = d
    end
  end)
end

function Interface:Lock(frame)
  self:StopMovement(frame)
end

function Interface:Unlock(frame)
  self:MakeMoveable(frame)
end

function Interface:AddControls(frame)
  frame:EnableMouse(true)
  frame:SetScript("OnMouseUp", function(_, btn)
    if NS.db.global.lock == false then
      if btn == "RightButton" then
        LibStub("AceConfigDialog-3.0"):Open(AddonName)
      end
    end
  end)

  if NS.db.global.lock then
    self:StopMovement(frame)
  else
    self:MakeMoveable(frame)
  end
end

function Interface:CreateInterface()
  if not Interface.textFrame then
    local TextFrame = CreateFrame("Frame", AddonName .. "InterfaceTextFrame", UIParent)
    TextFrame:SetClampedToScreen(true)
    TextFrame:SetPoint(
      NS.db.global.position[1],
      UIParent,
      NS.db.global.position[2],
      NS.db.global.position[3],
      NS.db.global.position[4]
    )
    -- local border = TextFrame:CreateTexture(nil, "BACKGROUND")
    -- border:SetAllPoints(TextFrame)
    -- border:SetColorTexture(0, 0, 0, 1) -- Black border with full opacity
    Interface.textFrame = TextFrame
  end
end

-- New UpdateAnchors function to dynamically reposition visible text
function Interface:UpdateAnchors(frame, _lines)
  local anchor = frame.textFrame
  local firstVisible = nil

  for _, textFrame in pairs(_lines) do
    local line = textFrame
    if line and line:GetAlpha() > 0 then
      line:ClearAllPoints()

      if not firstVisible then
        firstVisible = true
        -- First visible line anchors to frame.textFrame
        line:SetPoint("TOPLEFT", frame.textFrame, "TOPLEFT", 0, 0)
      else
        -- Subsequent visible lines anchor to the previous visible line
        line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
      end

      -- Update anchor for the next visible line
      anchor = line
    end
  end
end

function Interface:AddText(frame, text, key, bracket, hasData)
  frame.textFrame:Show()

  if not lines[key] then
    local Text = frame.textFrame:CreateFontString(nil, "OVERLAY")
    Text:SetShadowOffset(0, 0)
    Text:SetShadowColor(0, 0, 0, 1)
    Text:SetJustifyH("CENTER")
    Text:SetJustifyV("MIDDLE")
    Text:SetTextColor(NS.db.global.color.r, NS.db.global.color.g, NS.db.global.color.b, NS.db.global.color.a)
    Text:SetFont(LSM:Fetch("font", NS.db.global.fontFamily), NS.db.global.fontSize, "OUTLINE")
    lines[key] = Text
  end

  local matchingText = lines[key]

  -- Update the text color and font
  matchingText:SetTextColor(NS.db.global.color.r, NS.db.global.color.g, NS.db.global.color.b, NS.db.global.color.a)
  matchingText:SetFont(LSM:Fetch("font", NS.db.global.fontFamily), NS.db.global.fontSize, "OUTLINE")

  -- Set visibility and alpha based on bracket type
  if hasData then
    if bracket == "none" then
      matchingText:SetAlpha(0)
    elseif bracket == "2v2" then
      matchingText:SetAlpha(NS.db.global.show2v2 and 1 or 0)
    elseif bracket == "3v3" then
      matchingText:SetAlpha(NS.db.global.show3v3 and 1 or 0)
    elseif bracket == "rbg" then
      matchingText:SetAlpha(NS.db.global.showRBG and 1 or 0)
    elseif bracket == "shuffle" then
      matchingText:SetAlpha(NS.db.global.showShuffle and 1 or 0)
    elseif bracket == "blitz" then
      matchingText:SetAlpha(NS.db.global.showBlitz and 1 or 0)
    end
  else
    local hideNoResults = NS.db.global.hideNoResults and 0 or 1
    if bracket == "none" then
      InterfaceFrame.hideIntro = NS.db.global.hideIntro
      local hideIntro = InterfaceFrame.hideIntro
      matchingText:SetAlpha(hideIntro and 0 or 1)
    elseif bracket == "2v2" then
      matchingText:SetAlpha(NS.db.global.show2v2 and hideNoResults or 0)
    elseif bracket == "3v3" then
      matchingText:SetAlpha(NS.db.global.show3v3 and hideNoResults or 0)
    elseif bracket == "rbg" then
      matchingText:SetAlpha(NS.db.global.showRBG and hideNoResults or 0)
    elseif bracket == "shuffle" then
      matchingText:SetAlpha(NS.db.global.showShuffle and hideNoResults or 0)
    elseif bracket == "blitz" then
      matchingText:SetAlpha(NS.db.global.showBlitz and hideNoResults or 0)
    end
  end

  if bracket == "none" then
    if not Interface.buttonFrame then
      local ButtonFrame = CreateFrame("Button", AddonName .. "NoDataButton", frame.textFrame, "UIPanelButtonTemplate")
      ButtonFrame:ClearAllPoints()
      ButtonFrame:SetPoint("LEFT", matchingText, "RIGHT", 5, 0)
      ButtonFrame:SetText("Dismiss")
      ButtonFrame:SetWidth(75)
      ButtonFrame:SetHeight(25)
      ButtonFrame:SetScript("OnClick", function()
        NS.db.global.hideIntro = true
        InterfaceFrame.hideIntro = true
        matchingText:SetAlpha(0)
        ButtonFrame:Hide()
      end)
      Interface.buttonFrame = ButtonFrame
    else
      if hasData or InterfaceFrame.hideIntro or NS.db.global.hideIntro then
        Interface.buttonFrame:Hide()
      else
        Interface.buttonFrame:Show()
      end
    end
  end

  -- Set the dynamic text content
  matchingText.text = text
  matchingText.bracket = bracket
  matchingText.hasData = hasData
  matchingText:SetText(sformat("%s", text))

  -- Update anchoring for all visible lines
  Interface:UpdateAnchors(frame, lines)

  -- Adjust the frame size and controls
  NS.SetTextFrameSize(frame, lines)
  Interface:AddControls(frame.textFrame)
  Interface.textFrame = frame.textFrame

  NS.lines = lines
end
