--[[
	CheckInbox() - when called with mailbox open -> MAIL_INBOX_UPDATE event when done, information then available anywhere in world
	GetInboxNumItems() - how many mails do we have
	GetInboxHeaderInfo(index) - info on mail
	GetInboxInvoiceInfo(index) - is this an auction hous invoice?
	TakeInboxMoney(index) - get the omoney
	TakeInboxItem(index, attachIndex)
--]]

local BetterInbox = LibStub("AceAddon-3.0"):NewAddon("BetterInbox", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")

local AceGUI = LibStub("AceGUI-3.0")
local iconpath = "Interface\\AddOns\\BetterInbox\\icons"
local mIndex = 0
local aIndex = -1
local inventoryFull = nil
local checked = {}

local L = LibStub("AceLocale-3.0"):GetLocale("BetterInbox")


local function GSC(cash)
	if not cash then return end
	local g, s, c = floor(cash/10000), floor((cash/100)%100), cash%100
	if g > 0 then return string.format("|cffffd700%d.|cffc7c7cf%02d.|cffeda55f%02d", g, s, c)
	elseif s > 0 then return string.format("|cffc7c7cf%d.|cffeda55f%02d", s, c)
	else return string.format("|cffc7c7cf%d", c) end
end


local function MoneyString(money)
	local gold = abs(money / 10000)
	local silver = abs(mod(money / 100, 100))
	local copper = abs(mod(money, 100))
	if money >= 10000 then
		return string.format("|cffffffff%d|r|cffffd700g|r |cffffffff%d|r|cffc7c7cfs|r |cffffffff%d|r|cffeda55fc|r", gold, silver, copper)
	elseif money >= 100 then
		return string.format("|cffffffff%d|r|cffc7c7cfs|r |cffffffff%d|r|cffeda55fc|r", silver, copper)
	else
		return string.format("|cffffffff%d|r|cffeda55fc|r", copper)
	end
end

local function FullMoneyString(money)
	local gold = abs(money / 10000)
	local silver = abs(mod(money / 100, 100))
	local copper = abs(mod(money, 100))
	if money >= 10000 then
		return string.format("|cffffffff%d|r|cffffd700|r |T"..iconpath.."\\UI-GoldIcon::|t |cffffffff%d|r|cffc7c7cf|r |T"..iconpath.."\\UI-SilverIcon::|t |cffffffff%d|r|cffeda55f|r |T"..iconpath.."\\UI-CopperIcon::|t", gold, silver, copper)
	elseif money >= 100 then
		return string.format("|cffffffff%d|r|cffc7c7cf|r |T"..iconpath.."\\UI-SilverIcon::|t |cffffffff%d|r|cffeda55f|r |T"..iconpath.."\\UI-CopperIcon::|t", silver, copper)
	else
		return string.format("|cffffffff%d|r|cffeda55f|r |T"..iconpath.."\\UI-CopperIcon::|t", copper)
	end
end


function BetterInbox:OnEnable()
	self:RegisterEvent("MAIL_SHOW")
	self:RegisterEvent("MAIL_CLOSED")
	self:RegisterEvent("PLAYER_LEAVING_WORLD", "MAIL_CLOSED")
	self:RegisterEvent("MAIL_INBOX_UPDATE")

	self:SecureHook("SetSendMailShowing")
	self:SecureHook("InboxFrameItem_OnEnter")
	self:SecureHook("OpenMailFrame_OnHide", "MAIL_INBOX_UPDATE")

	if MailFrame:IsVisible() then self:MAIL_SHOW() end
end


function BetterInbox:MAIL_SHOW()
	self:RegisterEvent("UI_ERROR_MESSAGE")
	self:SetupGUI()
	self:MAIL_INBOX_UPDATE()
end

function BetterInbox:MAIL_CLOSED()
	-- abort any openall actions
	aIndex = -1
	mIndex = 0
	inventoryFull = nil
	for k, v in pairs(checked) do
		checked[k] = nil
	end
	self:UnregisterEvent("UI_ERROR_MESSAGE")
end


function BetterInbox:UI_ERROR_MESSAGE(event, msg)
	if msg == ERR_INV_FULL then inventoryFull = true end
end

function BetterInbox:MAIL_INBOX_UPDATE()
	self:UpdateInboxSummary()
	self:UpdateInboxScroll()
end

local titletext = InboxTitleText
function BetterInbox:UpdateInboxSummary()
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

	if numread < numitems then
		MiniMapMailFrame:Hide()
	end
end


-- Basically a rip from InboxFrame_Update() by Blizzard.
function BetterInbox:UpdateInboxScroll()
	if not self.scrollframe then return end
	local scrollframe = self.scrollframe
	local nritems = GetInboxNumItems()
	FauxScrollFrame_Update(scrollframe, nritems, 7, 45)
	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity
	local icon, button, buttonIcon, buttonSlot, subjectText, senderText
	for i = 1, 7 do
		local index = i + FauxScrollFrame_GetOffset(scrollframe)
		local entry = scrollframe.entries[i]
		expireTime = _G["BetterInboxItem"..i.."ExpireTime"]
		button = _G["BetterInboxItem"..i.."Button"]
		senderText = _G["BetterInboxItem"..i.."Sender"]
		subjectText = _G["BetterInboxItem"..i.."Subject"]
		buttonIcon = _G["BetterInboxItem"..i.."ButtonIcon"]
		buttonSlot = _G["BetterInboxItem"..i.."ButtonSlot"]
		if index <= nritems then
			button:Show()
			packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(index)

			if packageIcon and not isGM then
				icon = packageIcon
			else
				icon = stationeryIcon
			end
			buttonIcon:SetTexture(icon)
			subjectText:SetText(subject)
			senderText:SetText(sender)
			SetItemButtonCount(button, itemQuantity)
			button.index = index
			entry.index = index -- fallback
			button.hasItem = itemCount
			button.itemCount = itemCount

			if wasRead then
				subjectText:SetTextColor(0.75,0.75,0.75)
				senderText:SetTextColor(0.75,0.75,0.75)
				buttonSlot:SetVertexColor(0.5,0.5,0.5)
				SetDesaturation(buttonIcon,1)
			else
				subjectText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
				senderText:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
				buttonSlot:SetVertexColor(0.5,0.5,0.5)
				SetDesaturation(buttonIcon,nil)
			end

			-- Format expiration time
			if daysLeft >= 1 then
				daysLeft = GREEN_FONT_COLOR_CODE..format(DAYS_ABBR, floor(daysLeft)).." "..FONT_COLOR_CODE_CLOSE
			else
				daysLeft = RED_FONT_COLOR_CODE..SecondsToTime(floor(daysLeft * 24 * 60 * 60))..FONT_COLOR_CODE_CLOSE
			end
			expireTime:SetText(daysLeft)

			-- Set expiration time tooltip
			if InboxItemCanDelete(index) then
				expireTime.tooltip = TIME_UNTIL_DELETED
			else
				expireTime.tooltip = TIME_UNTIL_RETURNED
			end
			expireTime:Show()

			-- Is a C.O.D. package
			if CODAmount > 0 then
				_G["BetterInboxItem"..i.."ButtonCOD"]:Show()
				button.cod = CODAmount
			else
				_G["BetterInboxItem"..i.."ButtonCOD"]:Hide()
				button.cod = nil
			end

			-- Contains money
			if money > 0 then
				button.money = money
			else
				button.money = nil
			end

			-- Set highlight
			if InboxFrame.openMailID == index then
				button:SetChecked(1)
				SetPortraitToTexture("OpenMailFrameIcon", stationeryIcon)
			else
				button:SetChecked(nil)
			end
			entry:Show()
		else
			entry:Hide()
			button:Hide()
			senderText:SetText("")
			subjectText:SetText("")
			expireTime:Hide()
		end
	end
	-- always show the scrollframe borders, looks better that way imho
	scrollframe.t1:Show()
	scrollframe.t2:Show()
end


function BetterInbox:SetupGUI()
	-- Hide Blizzard Elements we're replacing
	for i=1,7 do
		_G["MailItem"..i]:Hide()
	end
	InboxPrevPageButton:Hide()
	InboxNextPageButton:Hide()

	self:SetSendMailShowing(false) -- fix border textures

	-- If we're already fixed up return early
	if self.scrollframe then
		self.scrollframe:Show()
		return
	end

	-- Scrolling body
	local sframe = CreateFrame("ScrollFrame", "BetterInboxScrollFrame", InboxFrame, "FauxScrollFrameTemplate")
	self.scrollframe = sframe
	sframe:SetParent(InboxFrame)
	sframe:SetWidth(292)
	sframe:SetHeight(309)
	sframe:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", 28, -100)

	local function updateScroll()
		self:UpdateInboxScroll()
	end

	sframe:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, 45, updateScroll)
	end)

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

	-- ScrollFrameEntries

	local function CheckBoxChanged(widget, callback, value)
		if widget.entry.index then
			checked[widget.entry.index] = value
		end
	end

	local entries = {}
	local kids

	for i =1, 7 do
		entries[i] = CreateFrame("CheckButton", "BetterInboxItem"..i, InboxFrame, "MailItemTemplate")
		entries[i]:SetHighlightTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight", "ADD")
		local high = entries[i]:GetHighlightTexture()
		high:SetTexCoord(0,1,0,0.5)

		if i == 1 then
			entries[i]:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", 22, -98)
		else
			entries[i]:SetPoint("TOPLEFT", entries[i -1], "BOTTOMLEFT")
		end

	--[[ failed attempt to fix bleed into scrollbar
		local tex1, tex2 = entries[i]:GetRegions()
		tex1:SetWidth(233)
		tex1:SetTexCoord(0.1640625, 233/266, 0, 0.75)
	--]]

		entries[i]:RegisterForClicks("LeftButtonUp","RightButtonUp")
		entries[i]:SetScript("OnClick", function(...) self:Entry_OnClick(...) end)
		entries[i]:SetScript("OnEnter", function(...) self:Entry_OnEnter(...) end)
		entries[i]:SetScript("OnLeave", function(...) self:Entry_OnLeave(...) end)
	end

	sframe.entries = entries
end


function BetterInbox:SetSendMailShowing(flag)
	if flag then return end -- textures set to the Send Mail Textures

	MailFrameTopLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
	MailFrameTopRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight")
	MailFrameBotLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft")
	MailFrameBotRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight")
	MailFrameTopLeft:SetPoint("TOPLEFT", "MailFrame", "TOPLEFT", 2, -1)
end


function BetterInbox:Entry_OnEnter(entry)
	local button = _G[entry:GetName().."Button"]
	self:ShowTooltip(button)
end


function BetterInbox:Entry_OnLeave(entry)
	GameTooltip:Hide()
	SetMoneyFrameColor("GameTooltipMoneyFrame", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
end


function BetterInbox:Entry_OnClick(entry, ...)
	local button = _G[entry:GetName().."Button"]
	button:Click(...)
	self:UpdateInboxScroll()
end


function BetterInbox:InboxFrameItem_OnEnter()
	self:ShowTooltip(this)
end


-- Partial reimplementation of blizzard
function BetterInbox:ShowTooltip(this)
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	if this.hasItem then
		if this.itemCount == 1 then
			GameTooltip:SetInboxItem(this.index)
		else
			GameTooltip:AddLine(MAIL_MULTIPLE_ITEMS.." ("..this.itemCount..")")
			GameTooltip:AddLine(" ")
			local name, itemTexture, count, quality, canUse
			for j=1, ATTACHMENTS_MAX_RECEIVE do
				name, itemTexture, count, quality, canUse = GetInboxItem(this.index,j)
				if name then
					if count > 1 then
						GameTooltip:AddLine(GetInboxItemLink(this.index,j) .. "x" .. count)
					else
						GameTooltip:AddLine(GetInboxItemLink(this.index,j))
					end
				end
			end
		end
	end
	if this.money then
		if this.hasItem then GameTooltip:AddLine(" ") end
		GameTooltip:AddLine(ENCLOSED_MONEY, "", 1, 1, 1)
		SetTooltipMoney(GameTooltip, this.money)
		SetMoneyFrameColor("GameTooltipMoneyFrame", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	elseif this.cod then
		if this.hasItem then GameTooltip:AddLine(" ") end
		GameTooltip:AddLine(COD_AMOUNT, "", 1, 1, 1)
		SetTooltipMoney(GameTooltip, this.cod)
		if this.cod > GetMoney() then
			SetMoneyFrameColor("GameTooltipMoneyFrame", RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
		else
			SetMoneyFrameColor("GameTooltipMoneyFrame", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		end
	end
	GameTooltip:Show()
end
