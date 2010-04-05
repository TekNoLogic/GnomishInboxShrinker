--[[
	CheckInbox() - when called with mailbox open -> MAIL_INBOX_UPDATE event when done, information then available anywhere in world
	GetInboxNumItems() - how many mails do we have
	GetInboxHeaderInfo(index) - info on mail
	GetInboxInvoiceInfo(index) - is this an auction hous invoice?
	TakeInboxMoney(index) - get the omoney
	TakeInboxItem(index, attachIndex)
--]]


local ICONSIZE = 17

local BetterInbox = LibStub("AceAddon-3.0"):NewAddon("BetterInbox", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")

local AceGUI = LibStub("AceGUI-3.0")
local iconpath = "Interface\\AddOns\\BetterInbox\\icons"

local L = LibStub("AceLocale-3.0"):GetLocale("BetterInbox")


local function GSC(cash)
	if not cash then return end
	local g, s, c = floor(cash/10000), floor((cash/100)%100), cash%100
	if g > 0 then return string.format("|cffffd700%d.|cffc7c7cf%02d.|cffeda55f%02d", g, s, c)
	elseif s > 0 then return string.format("|cffc7c7cf%d.|cffeda55f%02d", s, c)
	else return string.format("|cffc7c7cf%d", c) end
end


function BetterInbox:OnEnable()
	self:RegisterEvent("MAIL_SHOW")
	self:RegisterEvent("MAIL_INBOX_UPDATE")

	self:SecureHook("SetSendMailShowing")
	self:SecureHook("OpenMailFrame_OnHide", "MAIL_INBOX_UPDATE")

	if MailFrame:IsVisible() then self:MAIL_SHOW() end
end


function BetterInbox:MAIL_SHOW()
	-- Hide Blizzard Elements we're replacing
	for i=1,7 do _G["MailItem"..i]:Hide() end
	InboxPrevPageButton:Hide()
	InboxNextPageButton:Hide()

	self:SetSendMailShowing(false) -- fix border textures

	if self.SetupGUI then self:SetupGUI() end
	self:MAIL_INBOX_UPDATE()
end


local titletext = InboxTitleText
function BetterInbox:MAIL_INBOX_UPDATE()
	-- Update title
	local numitems = GetInboxNumItems()
	local numread, cash, totalitems = 0, 0, 0
	for i=1,numitems do
		local _, _, _, _, money, _, _, itemCount, wasRead = GetInboxHeaderInfo(i)
		if wasRead then numread = numread + 1 end
		cash = cash + money
		if (itemCount or 0) > 0 then
			for j=1,ATTACHMENTS_MAX_RECEIVE do
				local name, itemTexture, count, quality, canUse = GetInboxItem(i,j)
				if name then totalitems = totalitems + count end
			end
		end
	end

	local txt = INBOX
	if numitems > 0 then txt = txt .. " (".. numitems.. ")" end
	if totalitems > 0 then txt = txt .. " - ".. totalitems.. " items" end
	if cash > 0 then txt = txt .. " - ".. GSC(cash) end
	titletext:SetText(txt)


	self:UpdateInboxScroll()
end


-- Basically a rip from InboxFrame_Update() by Blizzard.
local rows = {}
function BetterInbox:UpdateInboxScroll()
	local offset = FauxScrollFrame_GetOffset(self.scrollframe)
	local numitems = GetInboxNumItems()
	FauxScrollFrame_Update(self.scrollframe, numitems, #rows, 45)
	for i,row in pairs(rows) do
		local index = i + offset
		if index <= numitems then row:Update(index)
		else row:Hide() end
	end
	-- always show the scrollframe borders, looks better that way imho
	self.scrollframe.t1:Show()
	self.scrollframe.t2:Show()
end


function BetterInbox:SetupGUI()
	-- If we're already fixed up return early
	if self.scrollframe then return self.scrollframe:Show() end

	-- Scrolling body
	local sframe = CreateFrame("ScrollFrame", "BetterInboxScrollFrame", InboxFrame, "FauxScrollFrameTemplate")
	self.scrollframe = sframe
	sframe:SetParent(InboxFrame)
	sframe:SetWidth(292)
	-- sframe:SetHeight(309)
	sframe:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", 28, -77)
	sframe:SetPoint("BOTTOMLEFT", InboxFrame, "BOTTOMLEFT", 28, 84)

	local function updateScroll() self:UpdateInboxScroll() end
	sframe:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, 45, updateScroll) end)

	-- textures for scrollbars

	local t1 = InboxFrame:CreateTexture(nil,"BACKGROUND")
	t1:SetTexture("Interface\\AddOns\\BetterInbox\\images\\BetterInbox-ScrollBar")
	t1:SetWidth(30)
	t1:SetHeight(256)
	t1:SetPoint("TOPLEFT", sframe, "TOPRIGHT", -1, 5)
	t1:SetTexCoord(0, 0.484375, 0, 1)

	sframe.t1 = t1

	local t2 = InboxFrame:CreateTexture(nil,"BACKGROUND")
	t2:SetTexture("Interface\\AddOns\\BetterInbox\\images\\BetterInbox-ScrollBar")
	t2:SetWidth(30)
	t2:SetHeight(107)
	t2:SetPoint("BOTTOMLEFT", sframe, "BOTTOMRIGHT", -1, -4)
	t2:SetTexCoord(0.515625, 1,0, 0.421875)

	sframe.t2 = t2

	local function ShortTime(days)
		if days >= 1 then return math.floor(days).."d" end
		if (days*24) >= 1 then return string.format("%.1fh", days*24) end
		return math.floor(days*24*60).."m"
	end

	local function OnEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

		if self.hasItem then
			if self.itemCount == 1 then GameTooltip:SetInboxItem(self.index)
			else
				GameTooltip:AddLine(MAIL_MULTIPLE_ITEMS.." ("..self.itemCount..")")
				GameTooltip:AddLine(" ")
				for j=1, ATTACHMENTS_MAX_RECEIVE do
					local name, itemTexture, count, quality, canUse = GetInboxItem(self.index,j)
					if name then
						if count > 1 then
							GameTooltip:AddLine(GetInboxItemLink(self.index,j) .. "x" .. count)
						else
							GameTooltip:AddLine(GetInboxItemLink(self.index,j))
						end
					end
				end
			end
		end

		if self.cod then
			if self.hasItem then GameTooltip:AddLine(" ") end
			GameTooltip:AddLine(COD_AMOUNT, "", 1, 1, 1)
			SetTooltipMoney(GameTooltip, self.cod)
			if self.cod > GetMoney() then SetMoneyFrameColor("GameTooltipMoneyFrame", RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
			else SetMoneyFrameColor("GameTooltipMoneyFrame", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b) end
		end

		GameTooltip:Show()
	end

	local function OnLeave()
		GameTooltip:Hide()
		SetMoneyFrameColor("GameTooltipMoneyFrame", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	end

	local function OnClick(self, ...)
		if IsModifiedClick("MAILAUTOLOOTTOGGLE") and select(6, GetInboxHeaderInfo(self.index)) <= 0 then AutoLootMailItem(self.index) end
		if self:GetChecked() then
			InboxFrame.openMailID = self.index
			OpenMailFrame.updateButtonPositions = true
			OpenMail_Update()
			ShowUIPanel(OpenMailFrame)
			PlaySound("igSpellBookOpen")
		else
			InboxFrame.openMailID = 0
			HideUIPanel(OpenMailFrame)
		end
		BetterInbox:UpdateInboxScroll()
	end

	local function Update(self, i)
		local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(i)

		self.icon:SetTexture((not isGM and packageIcon) or stationeryIcon)
		self.sender:SetText(sender:gsub("Auction House", "AH"))
		self.subject:SetText(subject:gsub("Auction successful", "Sold"):gsub("Auction expired", "Failed")) --..(money > 0 and (" ("..GSC(money).."|r)") or ""))
		self.money:SetText(money > 0 and GSC(money) or "")

		-- Format expiration time
		self.expire:SetText((daysLeft >= 1 and "|cff00ff00" or "|cffff0000").. ShortTime(daysLeft).. (InboxItemCanDelete(index) and " |cffff0000d" or " |cffffff00r"))

		self.index = i

		self.hasItem = itemCount
		self.itemCount = itemCount

		if InboxFrame.openMailID == i then
			self:SetChecked(true)
			SetPortraitToTexture("OpenMailFrameIcon", stationeryIcon)
		else
			self:SetChecked(false)
		end

		if wasRead then
			self.subject:SetTextColor(0.75,0.75,0.75)
			self.sender:SetTextColor(0.75,0.75,0.75)
			SetDesaturation(self.icon, 1)
		else
			self.subject:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
			self.sender:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
			SetDesaturation(self.icon, nil)
		end

		if GameTooltip:IsOwned(self) then OnEnter(self) end
		self:Show()
	end


	for i=1,17 do
		local row = CreateFrame("CheckButton", nil, InboxFrame)
		row:SetWidth(305)
		row:SetHeight(20)

		row:SetHighlightTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight")
		row:GetHighlightTexture():SetTexCoord(0, 1, 0, 0.578125)

		row:SetCheckedTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight")
		row:GetCheckedTexture():SetTexCoord(0, 1, 0, 0.578125)

		if i == 1 then row:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", 22, -75)
		else row:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT") end

		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnClick", OnClick)
		row:SetScript("OnEnter", OnEnter)
		row:SetScript("OnLeave", OnLeave)
		row.Update = Update

		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetWidth(ICONSIZE)
		icon:SetHeight(ICONSIZE)
		icon:SetPoint("LEFT", 4, 0)
		row.icon = icon

		local sender = row:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		sender:SetPoint("LEFT", icon, "RIGHT", 6, 0)
		row.sender = sender

		local expire = row:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmallRight")
		expire:SetPoint("RIGHT", -4, 0)
		row.expire = expire

		local money = row:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		money:SetPoint("RIGHT", expire, "LEFT", -3, 0)
		row.money = money

		local subject = row:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		subject:SetPoint("LEFT", sender, "RIGHT", 6, 0)
		subject:SetPoint("RIGHT", money, "LEFT", -6, 0)
		subject:SetJustifyH("LEFT")
		row.subject = subject

		rows[i] = row
	end
	self.SetupGUI = nil
end


function BetterInbox:SetSendMailShowing(flag)
	if flag then return end -- textures set to the Send Mail Textures

	MailFrameTopLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
	MailFrameTopRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight")
	MailFrameBotLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft")
	MailFrameBotRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight")
	MailFrameTopLeft:SetPoint("TOPLEFT", "MailFrame", "TOPLEFT", 2, -1)
end
