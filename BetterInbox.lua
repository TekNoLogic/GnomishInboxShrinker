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
local openAllValue = nil
local takeAll = nil
local inventoryFull = nil
local checked = {}

local L = LibStub("AceLocale-3.0"):GetLocale("BetterInbox")

local function MoneyString( money )
	local gold = abs(money / 10000)
	local silver = abs(mod(money / 100, 100))
	local copper = abs(mod(money, 100))
	if money >= 10000 then
		return string.format( "|cffffffff%d|r|cffffd700g|r |cffffffff%d|r|cffc7c7cfs|r |cffffffff%d|r|cffeda55fc|r", gold, silver, copper)
	elseif money >= 100 then
		return string.format( "|cffffffff%d|r|cffc7c7cfs|r |cffffffff%d|r|cffeda55fc|r", silver, copper)	
	else 
		return string.format("|cffffffff%d|r|cffeda55fc|r", copper )
	end
end

local function FullMoneyString( money )
	local gold = abs(money / 10000)
	local silver = abs(mod(money / 100, 100))
	local copper = abs(mod(money, 100))
	if money >= 10000 then
		return string.format( "|cffffffff%d|r|cffffd700|r |T"..iconpath.."\\UI-GoldIcon::|t |cffffffff%d|r|cffc7c7cf|r |T"..iconpath.."\\UI-SilverIcon::|t |cffffffff%d|r|cffeda55f|r |T"..iconpath.."\\UI-CopperIcon::|t", gold, silver, copper)
	elseif money >= 100 then
		return string.format( "|cffffffff%d|r|cffc7c7cf|r |T"..iconpath.."\\UI-SilverIcon::|t |cffffffff%d|r|cffeda55f|r |T"..iconpath.."\\UI-CopperIcon::|t", silver, copper)	
	else 
		return string.format("|cffffffff%d|r|cffeda55f|r |T"..iconpath.."\\UI-CopperIcon::|t", copper )
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
	
	if MailFrame:IsVisible() then
		self:MAIL_SHOW()
	end
end

function BetterInbox:OnDisable()
	if self.scrollframe then
		-- Show Blizzard Elements we replaced
		for i=1,7 do 
			_G["MailItem"..i]:Show()
		end
		InboxPrevPageButton:Show()
		InboxNextPageButton:Show()
		self.scrollframe:Hide()
		self.scrollframe.dropdown.frame:Hide()
		_G["BetterInboxCancelButton"]:Hide()
		_G["BetterInboxOpenButton"]:Hide()
		for i=1,7 do
			self.scrollframe.entries[i]:Hide()
		end
		local summary = self.summary
		summary.numitems:Hide()
		summary.numitemsText:Hide()
		summary.numitemsHover:Hide()
		summary.money:Hide()
		summary.moneyText:Hide()
		summary.moneyHover:Hide()
		summary.cod:Hide()
		summary.codHover:Hide()
		summary.codText:Hide()
		self.scrollframe.t1:Hide()
		self.scrollframe.t2:Hide()
		_G["InboxTitleText"]:SetText(INBOX)
		HideUIPanel(MailFrame)
	end
end

function BetterInbox:MAIL_SHOW()
	self:RegisterEvent("UI_ERROR_MESSAGE")
	self:SetupGUI()
	self:UpdateAll()
end

function BetterInbox:MAIL_CLOSED()
	-- abort any openall actions
	takeAll = nil
	aIndex = -1
	mIndex = 0
	inventoryFull = nil
	for k, v in pairs(checked) do
		checked[k] = nil
	end
	self:UnregisterEvent("UI_ERROR_MESSAGE")
end


function BetterInbox:UI_ERROR_MESSAGE( event, msg )
	if msg == ERR_INV_FULL then inventoryFull = true end
end

function BetterInbox:MAIL_INBOX_UPDATE()
	self:UpdateAll()
	if takeAll then
		self:TakeAll()
	end
end

function BetterInbox:UpdateAll()
	self:UpdateInboxSummary()
	self:UpdateInboxScroll()
end

function BetterInbox:TakeAll( first )
	local nritems = GetInboxNumItems()
	if first then
		mIndex = nritems
		inventoryFull = nil
		-- destroy button functionality.
	end
	if mIndex <= 0 then
		takeAll = nil
		aIndex = -1
		mIndex = 0
		for k, v in pairs(checked) do
			checked[k] = nil
		end
		-- restore button functionality
		return
	end
	if not checked[mIndex] and ( openAllValue == "sall" or openAllValue == "sitems" or openAllValue == "sgold" ) then
		-- skip unchecked mail
		mIndex = mIndex -1
		aIndex = -1
		return self:TakeAll()
	end

	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(mIndex)
	if subject then

		if aIndex == -1 then -- new mail, not tried aattachments yet
			aIndex = ATTACHMENTS_MAX_RECEIVE -- there can be gaps, so we can't rely on itemCount...
		end
		while not GetInboxItem( mIndex, aIndex ) and aIndex > 0 do  -- no attachment here, next!
			aIndex = aIndex - 1
		end
		-- valid mail
		if aIndex == 0 or openAllValue == "gold" or openAllValue == "sgold" then -- all attachments passed, try and get the moneys
			-- take money
			if money > 0 and openAllValue ~= "items" and openAllValue ~= "sitems" then
				TakeInboxMoney(mIndex)
				return self:ScheduleTimer("TakeAll", .1)
			else
				-- done with this mail, next!
				mIndex = mIndex - 1
				aIndex = -1
			end
		elseif CODAmount == 0 and not inventoryFull and not isGM then
			-- take item
			TakeInboxItem(mIndex, aIndex)
			return self:ScheduleTimer("TakeAll", .1)
		else -- skip this mail
			mIndex = mIndex - 1
			aIndex = -1
		end
	else -- end of the run
		mIndex = -1
		aIndex = -1
	end
	return self:TakeAll()
end

function BetterInbox:UpdateInboxSummary()
	if not self.summary then return end
	local nritems = GetInboxNumItems()
	local unreaditems = nritems
	local totalmoney = 0
	local totalcod = 0
	local totalstacks = 0
	local totalitems = 0
	local totalsoon = 0
	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity
	local name, itemTexture, count, quality, canUse	
	local invoiceType, itemName, playerName, bid, buyout, deposit, consignment, moneyDelay, etaHour, etaMin
	for i =1, nritems do
		packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(i)
		if wasRead then
			unreaditems = unreaditems - 1
		end
		totalmoney = totalmoney + money
		totalcod = totalcod + CODAmount
		invoiceType, itemName, playerName, bid, buyout, deposit, consignment, moneyDelay, etaHour, etaMin = GetInboxInvoiceInfo(i)
		if invoiceType and invoiceType == "seller_temp_invoice" then
			totalsoon = totalsoon + ( bid + deposit - consignment )
		end
		if itemCount and itemCount > 0 then
			totalstacks = totalstacks + itemCount
			for j=1, ATTACHMENTS_MAX_RECEIVE do
				name, itemTexture, count, quality, canUse = GetInboxItem(i,j)
				if name then
					totalitems = totalitems + count
				end
			end		
		end
	end
	_G["InboxTitleText"]:SetText( string.format(INBOX.." (%d/%d)", unreaditems, nritems) )
	if totalmoney > 0 then
		self.summary.money:SetText(FullMoneyString(totalmoney))	
		self.summary.money:Show()
		self.summary.moneyText:Show()
		self.summary.moneyHover:Show()
	else
		self.summary.money:Hide()
		self.summary.moneyText:Hide()
		self.summary.moneyHover:Hide()
	end
	if totalsoon > 0 then
		self.summary.soon:SetText(FullMoneyString(totalsoon))
		self.summary.soon:Show()
		self.summary.soonText:Show()
		self.summary.soonHover:Show()
	else
		self.summary.soon:Hide()
		self.summary.soonText:Hide()
		self.summary.soonHover:Hide()
	end	
	if totalcod > 0 then
		self.summary.cod:SetText(FullMoneyString(totalcod))
		self.summary.cod:Show()
		self.summary.codText:Show()
		self.summary.codHover:Show()
	else
		self.summary.cod:Hide()
		self.summary.codText:Hide()
		self.summary.codHover:Hide()
	end
	if totalitems > 0 then
		self.summary.numitemsText:SetFormattedText(L["%d items in %d stacks"], totalitems, totalstacks)
		self.summary.numitemsText:Show()
		self.summary.numitems:Show()
		self.summary.numitemsHover:Show()
	else
		self.summary.numitemsText:Hide()
		self.summary.numitems:Hide()
		self.summary.numitemsHover:Hide()
	end
	if unreaditems == 0 then
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
			buttonIcon:SetTexture( icon )
			subjectText:SetText( subject )
			senderText:SetText( sender )
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
		self.scrollframe.dropdown.frame:Show()
		_G["BetterInboxOpenButton"]:Show()
		_G["BetterInboxCancelButton"]:Show()
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
		tex1:SetWidth( 233 )
		tex1:SetTexCoord( 0.1640625, 233/266, 0, 0.75)
	--]]
		
		entries[i]:RegisterForClicks("LeftButtonUp","RightButtonUp")
		entries[i]:SetScript("OnClick", function( ... ) self:Entry_OnClick( ... ) end )
		entries[i]:SetScript("OnEnter", function( ... ) self:Entry_OnEnter( ... ) end )
		entries[i]:SetScript("OnLeave", function( ... ) self:Entry_OnLeave( ... ) end )
	end
	
	sframe.entries = entries


	
	local cancel = CreateFrame("Button", "BetterInboxCancelButton", InboxFrame, "UIPanelButtonTemplate")
	cancel:SetWidth(80)
	cancel:SetHeight(22)
	cancel:SetPoint("BOTTOMRIGHT", InboxFrame, "BOTTOMRIGHT", -39, 80)
	cancel:SetText(CANCEL)
	cancel:SetScript("OnClick", function() HideUIPanel(MailFrame) end )
	
	local all = CreateFrame("Button", "BetterInboxOpenButton", InboxFrame, "UIPanelButtonTemplate")
	all:SetWidth(80)
	all:SetHeight(22)
	all:SetPoint("RIGHT", cancel, "LEFT", 0, 0)
	all:SetText(L["Open"])
	all:SetScript("OnClick", function() self:TakeAll(true) end )	

	local dropdownValues = {
		["all"] = L["All Mail"],
		["gold"] = L["All Gold"],
		["items"] = L["All Items"],
	}
	local defaultValue = "all"
	openAllValue = defaultValue
	
	local function DropDownChanged( widget, callback, value )
		openAllValue = value
	end
	
	local dropdown = AceGUI:Create("Dropdown")
	dropdown:SetCallback("OnValueChanged", DropDownChanged )
	dropdown:SetList( dropdownValues )
	dropdown:SetValue( defaultValue )
	
	dropdown.frame:SetParent(InboxFrame)
	dropdown.frame:SetPoint("BOTTOMRIGHT", InboxFrame, "BOTTOMLEFT", 183, 80)
	dropdown.frame:SetWidth( 164 )
	dropdown.frame:SetHeight( 22 )
	dropdown.frame:SetFrameStrata("HIGH")
	dropdown.frame:Show()
	
	dropdown.button:SetFrameStrata("DIALOG")
	dropdown.button:SetWidth( 22 )
	dropdown.button:SetHeight( 22 )
	sframe.dropdown = dropdown
	
	-- Summary at the top
	local font = GameFontNormal:GetFont()

	
	self.summary = {}
	local summary = self.summary

	summary.numitems = InboxFrame:CreateFontString(nil, "OVERLAY")
	summary.numitems:SetFont(font, 12)
	summary.numitems:SetJustifyH( "RIGHT")
	summary.numitems:SetTextColor( 1, 1, 1, 1)
	summary.numitems:ClearAllPoints()
	summary.numitems:SetPoint( "TOPRIGHT", InboxFrame, "TOPLEFT", 160, -35 )
	summary.numitems:SetText(L["Attachments:"])
	
	summary.numitemsText = InboxFrame:CreateFontString(nil, "OVERLAY")
	summary.numitemsText:SetFont(font, 12)
	summary.numitemsText:SetJustifyH( "LEFT")
	summary.numitemsText:SetTextColor( 1, 1, 1, 1)
	summary.numitemsText:ClearAllPoints()
	summary.numitemsText:SetPoint( "TOPLEFT", InboxFrame, "TOPLEFT", 170, -35 )

	summary.numitemsHover = CreateFrame('Frame', 'BetterInboxAttachmentsHover', InboxFrame)
	summary.numitemsHover:SetPoint("TOPLEFT", summary.numitems, "TOPLEFT")
	summary.numitemsHover:SetPoint("BOTTOMRIGHT", summary.numitemsText, "BOTTOMRIGHT")
	summary.numitemsHover:SetScript("OnEnter", function( ... ) self:ShowAttachmentTooltip( ... ) end )
	summary.numitemsHover:SetScript("OnLeave", function() GameTooltip:Hide() end )
	summary.numitemsHover:EnableMouse(true)

	summary.moneyText = InboxFrame:CreateFontString(nil, "OVERLAY")
	summary.moneyText:SetFont(font, 12)
	summary.moneyText:SetJustifyH("RIGHT")
	summary.moneyText:SetTextColor( 1, 1, 1, 1)
	summary.moneyText:ClearAllPoints()
	summary.moneyText:SetPoint( "TOPRIGHT", InboxFrame, "TOPLEFT", 160, -50 )
	summary.moneyText:SetText(L["Enclosed:"])

	summary.money = InboxFrame:CreateFontString(nil, "OVERLAY")
	summary.money:SetFont(font, 12)
	summary.money:SetJustifyH( "RIGHT")
	summary.money:SetTextColor( 1, 1, 1, 1)
	summary.money:ClearAllPoints()
	summary.money:SetPoint( "TOPLEFT", InboxFrame, "TOPLEFT", 170, -50 )
	summary.money:SetText("")	

	summary.moneyHover = CreateFrame('Frame', 'BetterInboxMoneyHover', InboxFrame)
	summary.moneyHover:SetPoint("TOPLEFT", summary.moneyText, "TOPLEFT")
	summary.moneyHover:SetPoint("BOTTOMRIGHT", summary.money, "BOTTOMRIGHT")
	summary.moneyHover:SetScript("OnEnter", function( ... ) self:ShowMoneyTooltip( ... ) end )
	summary.moneyHover:SetScript("OnLeave", function() GameTooltip:Hide() end )
	summary.moneyHover:EnableMouse(true)

	summary.soonText = InboxFrame:CreateFontString(nil, "OVERLAY")
	summary.soonText:SetFont(font, 12)
	summary.soonText:SetJustifyH( "RIGHT")
	summary.soonText:SetTextColor( 1, 1, 1, 1)
	summary.soonText:ClearAllPoints()
	summary.soonText:SetPoint( "TOPRIGHT", InboxFrame, "TOPLEFT", 160, -65 )
	summary.soonText:SetText(L["Pending:"])

	summary.soon = InboxFrame:CreateFontString(nil, "OVERLAY")
	summary.soon:SetFont(font, 12)
	summary.soon:SetJustifyH( "RIGHT")
	summary.soon:SetTextColor( 1, 1, 1, 1)
	summary.soon:ClearAllPoints()
	summary.soon:SetPoint( "TOPLEFT", InboxFrame, "TOPLEFT", 170, -65 )
	summary.soon:SetText("")
	
	summary.soonHover = CreateFrame('Frame', 'BetterInboxSoonHover', InboxFrame)
	summary.soonHover:SetPoint("TOPLEFT", summary.soonText, "TOPLEFT")
	summary.soonHover:SetPoint("BOTTOMRIGHT", summary.soon, "BOTTOMRIGHT")
	summary.soonHover:SetScript("OnEnter", function( ... ) self:ShowSoonTooltip( ... ) end )
	summary.soonHover:SetScript("OnLeave", function() GameTooltip:Hide() end )
	summary.soonHover:EnableMouse(true)
	
	summary.codText = InboxFrame:CreateFontString(nil, "OVERLAY")
	summary.codText:SetFont(font, 12)
	summary.codText:SetJustifyH( "RIGHT")
	summary.codText:SetTextColor( 1, 1, 1, 1)
	summary.codText:ClearAllPoints()
	summary.codText:SetPoint( "TOPRIGHT", InboxFrame, "TOPLEFT", 160, -80 )
	summary.codText:SetText(L["Costs:"])

	summary.cod = InboxFrame:CreateFontString(nil, "OVERLAY")
	summary.cod:SetFont(font, 12)
	summary.cod:SetJustifyH( "RIGHT")
	summary.cod:SetTextColor( 1, 1, 1, 1)
	summary.cod:ClearAllPoints()
	summary.cod:SetPoint( "TOPLEFT", InboxFrame, "TOPLEFT", 170, -80 )
	summary.cod:SetText("")	
	
	summary.codHover = CreateFrame('Frame', 'BetterInboxCoDHover', InboxFrame)
	summary.codHover:SetPoint("TOPLEFT", summary.codText, "TOPLEFT")
	summary.codHover:SetPoint("BOTTOMRIGHT", summary.cod, "BOTTOMRIGHT")
	summary.codHover:SetScript("OnEnter", function( ... ) self:ShowCoDTooltip( ... ) end )
	summary.codHover:SetScript("OnLeave", function() GameTooltip:Hide() end )
	summary.codHover:EnableMouse(true)
end

function BetterInbox:SetSendMailShowing( flag )
	if not flag then -- textures set to the Send Mail Textures
		MailFrameTopLeft:SetTexture("Interface\\AddOns\\BetterInbox\\images\\BetterInbox-TopLeft")
		MailFrameTopRight:SetTexture("Interface\\AddOns\\BetterInbox\\images\\BetterInbox-TopRight")
		MailFrameBotLeft:SetTexture("Interface\\AddOns\\BetterInbox\\images\\BetterInbox-BotLeft")
		MailFrameBotRight:SetTexture("Interface\\AddOns\\BetterInbox\\images\\BetterInbox-BotRight")
		MailFrameTopLeft:SetPoint("TOPLEFT", "MailFrame", "TOPLEFT", 2, -1)
	end
end

function BetterInbox:Entry_OnEnter( entry )
	local button = _G[entry:GetName().."Button"]
	self:ShowTooltip( button )
end

function BetterInbox:Entry_OnLeave( entry )
	GameTooltip:Hide()
	SetMoneyFrameColor("GameTooltipMoneyFrame", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
end

function BetterInbox:Entry_OnClick( entry, ... )
	local button = _G[entry:GetName().."Button"]
	button:Click( ... )
	self:UpdateInboxScroll()
end

function BetterInbox:InboxFrameItem_OnEnter()
	self:ShowTooltip( this )
end

-- Partial reimplementation of blizzard
function BetterInbox:ShowTooltip( this ) 
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
						GameTooltip:AddLine( GetInboxItemLink(this.index,j) .. "x" .. count )
					else
						GameTooltip:AddLine( GetInboxItemLink(this.index,j) )					
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


function BetterInbox:ShowMoneyTooltip( this )
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:AddLine(ENCLOSED_MONEY)
	local nritems = GetInboxNumItems()
	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity
	local invoiceType, itemName, playerName, bid, buyout, deposit, consignment, moneyDelay, etaHour, etaMin
	for i =1, nritems do
		invoiceType, itemName, playerName, bid, buyout, deposit, consignment, moneyDelay, etaHour, etaMin = GetInboxInvoiceInfo(i)
		packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(i)
		if invoiceType and invoiceType == "seller" then
			GameTooltip:AddDoubleLine( itemName, MoneyString(money))
		elseif money > 0 then
			GameTooltip:AddDoubleLine( sender, MoneyString(money))
		end
	end
	GameTooltip:Show()
end

function BetterInbox:ShowCoDTooltip( this )
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:AddLine(L["CoD Costs"])
	local nritems = GetInboxNumItems()
	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity
	for i =1, nritems do
		packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(i)
		if CODAmount > 0 then
			GameTooltip:AddDoubleLine(sender, MoneyString(CODAmount))
		end
	end
	GameTooltip:Show()
end

function BetterInbox:ShowSoonTooltip( this )
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:AddLine(L["Delayed Money"])
	local nritems = GetInboxNumItems()
	local invoiceType, itemName, playerName, bid, buyout, deposit, consignment, moneyDelay, etaHour, etaMin
	for i =1, nritems do
		invoiceType, itemName, playerName, bid, buyout, deposit, consignment, moneyDelay, etaHour, etaMin = GetInboxInvoiceInfo(i)
		if invoiceType and invoiceType == "seller_temp_invoice" then
			GameTooltip:AddDoubleLine(itemName, MoneyString( bid + deposit - consignment ))
		end
	end
	GameTooltip:Show()
end


function BetterInbox:ShowAttachmentTooltip( this )
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:AddLine(L["Attachments"])
	local nritems = GetInboxNumItems()
	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity
	local name, itemTexture, count, quality, canUse
	for i =1, nritems do
		packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(i)
		for j=1, ATTACHMENTS_MAX_RECEIVE do
			name, itemTexture, count, quality, canUse = GetInboxItem(i,j)
			if name then
				if count > 1 then
					GameTooltip:AddDoubleLine(sender, GetInboxItemLink(i,j) .. "x" .. count )
				else
					GameTooltip:AddDoubleLine(sender,GetInboxItemLink(i,j) )					
				end
			end
		end		
	end
	GameTooltip:Show()
end
