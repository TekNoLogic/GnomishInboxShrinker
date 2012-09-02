--[[
	CheckInbox() - when called with mailbox open -> MAIL_INBOX_UPDATE event when done, information then available anywhere in world
	GetInboxNumItems() - how many mails do we have
	GetInboxHeaderInfo(index) - info on mail
	GetInboxInvoiceInfo(index) - is this an auction hous invoice?
	TakeInboxMoney(index) - get the omoney
	TakeInboxItem(index, attachIndex)
--]]

-- local function GetInboxNumItems() return 50, 200 end
-- local orig_GetInboxHeaderInfo = GetInboxHeaderInfo
-- local function GetInboxHeaderInfo(index)
-- 	return orig_GetInboxHeaderInfo(index % 2 + 1)
-- end
-- local function GetInboxHeaderInfo(index)
-- 	return orig_GetInboxHeaderInfo(1)
-- end
-- local function GetInboxHeaderInfo(index)
-- 	-- packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity
-- 	return nil, "Interface\\Icons\\INV_Scroll_03", "Alliance Auction House", "Auction successful: Rawr n stuff", 56789, 0, 29.123, nil,nil,nil, 1, nil,nil,nil
-- end


local myname, ns = ...

local ICONSIZE, NUMROWS = 17, 17

local BetterInbox = LibStub("AceAddon-3.0"):NewAddon("BetterInbox", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("BetterInbox")


local function GSC(cash)
	if not cash then return end
	local g, s, c = floor(cash/10000), floor((cash/100)%100), cash%100
	if g > 0 then
		return string.format("|cffffd700%d.|cffc7c7cf%02d.|cffeda55f%02d", g, s, c)
	elseif s > 0 then
		return string.format("|cffc7c7cf%d.|cffeda55f%02d", s, c)
	else return string.format("|cffc7c7cf%d", c) end
end


local function ShortTime(days)
	if days >= 1 then return math.floor(days).."d" end
	if (days*24) >= 1 then return string.format("%.1fh", days*24) end
	return math.floor(days*24*60).."m"
end


local function SetMoneyColor(color)
	SetMoneyFrameColor("GameTooltipMoneyFrame", color.r, color.g, color.b)
end


local function ExpandColor(c)
	return c.r, c.g, c.b
end


function BetterInbox:OnEnable()
	self:RegisterEvent("MAIL_SHOW")
	self:RegisterEvent("MAIL_INBOX_UPDATE")

	self:SecureHook("OpenMailFrame_OnHide", "MAIL_INBOX_UPDATE")

	if MailFrame:IsVisible() then self:MAIL_SHOW() end
end


local justshown
function BetterInbox:MAIL_SHOW()
	-- Hide Blizzard Elements we're replacing
	for i=1,7 do _G["MailItem"..i]:Hide() end
	InboxPrevPageButton:Hide()
	InboxNextPageButton:Hide()

	if self.SetupGUI then self:SetupGUI() end
	justshown = true
	self:MAIL_INBOX_UPDATE()
	justshown = false
end


local titletext = InboxTitleText
function BetterInbox:MAIL_INBOX_UPDATE()
	-- Update title
	local numitems, totalitems = GetInboxNumItems()
	local numread, cash, attachments = 0, 0, 0
	for i=1,numitems do
		local _, _, _, _, money, _, _, itemCount, wasRead = GetInboxHeaderInfo(i)
		if wasRead then numread = numread + 1 end
		cash = cash + money
		if (itemCount or 0) > 0 then
			for j=1,ATTACHMENTS_MAX_RECEIVE do
				local name, itemTexture, count, quality, canUse = GetInboxItem(i,j)
				if name then attachments = attachments + count end
			end
		end
	end

	local txt = INBOX
	if totalitems > numitems then
		txt = txt .. " (".. numitems.. "/".. totalitems.. ")"
	elseif numitems > 0 then txt = txt .. " (".. numitems.. ")" end
	if attachments > 0 then txt = txt .. " - ".. attachments.. " items" end
	if cash > 0 then txt = txt .. " - ".. GSC(cash) end
	titletext:SetText(txt)

	self:UpdateInboxScroll()

	if not justshown and (numitems + totalitems) == 0 then
		MiniMapMailFrame:Hide() else MiniMapMailFrame:Show()
	end
end


local rows = {}
function BetterInbox:UpdateInboxScroll()
	local numitems = GetInboxNumItems()
	local offset = self.scroll:GetValue()

	self.scroll:SetMinMaxValues(0, math.max(0, numitems-NUMROWS))

	for i,row in pairs(rows) do
		local index = i + offset
		if index <= numitems then row:Update(index)
		else row:Hide() end
	end
end


function BetterInbox:SetupGUI()
	local f = CreateFrame("Frame", nil, InboxFrame)
	f:SetPoint("TOPLEFT", 7, -61)
	f:SetPoint("BOTTOMRIGHT", -55, 94)


	local bg = InboxFrame:GetRegions()
	bg:Hide()


	local scroll = ns.tekScrollBar(f, 2, 9)
	self.scroll = scroll
	function scroll.OnValueChanged(self, value)
		BetterInbox:UpdateInboxScroll()
	end

	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(self, val)
		scroll:SetValue(scroll:GetValue() - val*3)
	end)


	local function OnEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

		if self.hasItem then
			if self.itemCount == 1 then GameTooltip:SetInboxItem(self.index)
			else
				GameTooltip:AddLine(MAIL_MULTIPLE_ITEMS.." ("..self.itemCount..")")
				GameTooltip:AddLine(" ")
				for j=1, ATTACHMENTS_MAX_RECEIVE do
					local name, itemTexture, count = GetInboxItem(self.index,j)
					if name then
						if count > 1 then
							GameTooltip:AddLine(GetInboxItemLink(self.index,j).. "x".. count)
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
			if self.cod > GetMoney() then SetMoneyColor(RED_FONT_COLOR)
			else SetMoneyColor(HIGHLIGHT_FONT_COLOR) end
		end

		GameTooltip:Show()
	end

	local function OnLeave()
		GameTooltip:Hide()
		SetMoneyColor(HIGHLIGHT_FONT_COLOR)
	end

	local function OnClick(self, ...)
		if IsModifiedClick("MAILAUTOLOOTTOGGLE")
			and select(6, GetInboxHeaderInfo(self.index)) <= 0 then
			AutoLootMailItem(self.index)
		end

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
		local packageIcon, stationeryIcon, sender, subject, money, CODAmount,
			daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM,
			itemQuantity = GetInboxHeaderInfo(i)

		subject = subject:gsub("Auction successful", "Sold")
		subject = subject:gsub("Auction expired", "Failed")
		subject = subject:gsub("Auction won", "Won")

		self.subject:SetText(subject)
		self.icon:SetTexture((not isGM and packageIcon) or stationeryIcon)
		self.sender:SetText((sender or "<unknown>"):gsub("Auction House", "AH"))
		self.money:SetText(
			money > 0 and GSC(money)
			or CODAmount > 0 and ("|cffff0000COD (".. GSC(CODAmount).. "|cffff0000)")
			or ""
		)

		-- Format expiration time
		self.expire:SetText(
			(daysLeft >= 1 and "|cff00ff00" or "|cffff0000")..
			ShortTime(daysLeft)..
			(InboxItemCanDelete(i) and " |cffff0000d" or " |cffffff00r")
		)

		self.index = i

		self.hasItem = itemCount
		self.itemCount = itemCount

		-- SetItemButtonCount(button, itemQuantity)

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
			self.subject:SetTextColor(ExpandColor(NORMAL_FONT_COLOR))
			self.sender:SetTextColor(ExpandColor(HIGHLIGHT_FONT_COLOR))
			SetDesaturation(self.icon, nil)
		end

		if GameTooltip:IsOwned(self) then OnEnter(self) end
		self:Show()
	end


	local function cfs(parent, font)
		return parent:CreateFontString(nil, "BACKGROUND", font)
	end

	for i=1,NUMROWS do
		local row = CreateFrame("CheckButton", nil, f)
		row:SetHeight(20)

		row:SetHighlightTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight")
		row:GetHighlightTexture():SetTexCoord(0, 1, 0, 0.578125)

		row:SetCheckedTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight")
		row:GetCheckedTexture():SetTexCoord(0, 1, 0, 0.578125)

		if i == 1 then row:SetPoint("TOPLEFT")
		else row:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT") end
		row:SetPoint("RIGHT", scroll, "LEFT", -3, 0)

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

		local sender = cfs(row, "GameFontHighlightSmall")
		sender:SetPoint("LEFT", icon, "RIGHT", 6, 0)
		row.sender = sender

		local expire = cfs(row, "GameFontHighlightSmallRight")
		expire:SetPoint("RIGHT", -4, 0)
		row.expire = expire

		local money = cfs(row, "GameFontHighlightSmall")
		money:SetPoint("RIGHT", expire, "LEFT", -3, 0)
		row.money = money

		local subject = cfs(row, "GameFontHighlightSmall")
		subject:SetPoint("LEFT", sender, "RIGHT", 6, 0)
		subject:SetPoint("RIGHT", money, "LEFT", -6, 0)
		subject:SetJustifyH("LEFT")
		row.subject = subject

		rows[i] = row
	end

	scroll:SetMinMaxValues(0, GetInboxNumItems())
	scroll:SetValue(0)

	self.SetupGUI = nil
end
