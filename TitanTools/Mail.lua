-- TitanTools: an "Open all" button on the mailbox that takes every item and all gold.
-- Skips COD and GM mail, which you have to open yourself. If the client's own mailbox
-- already has Blizzard's Open All button, this does nothing.
local ADDON, TT = ...

local DELAY = 0.3
local button, ticker, taken

local function Stop(reason)
	if ticker then ticker:Cancel() end
	ticker = nil
	button:Enable()
	button:SetText("Open all")
	if reason then TT:Print(reason) end
	if taken > 0 then TT:Print(("Took %s from the mail."):format(GetCoinTextureString(taken))) end
end

-- Takes one thing from the first mail that has something. Returns false when done.
local function TakeNext()
	for i = 1, GetInboxNumItems() do
		local _, _, _, _, money, cod, _, itemCount, _, _, _, _, isGM = GetInboxHeaderInfo(i)
		if not isGM and not (cod and cod > 0) then
			if money and money > 0 then
				taken = taken + money
				TakeInboxMoney(i)
				return true
			end
			if itemCount and itemCount > 0 then
				for slot = ATTACHMENTS_MAX_RECEIVE or 16, 1, -1 do
					if HasInboxItem(i, slot) then
						TakeInboxItem(i, slot)
						return true
					end
				end
			end
		end
	end
	return false
end

local function Step()
	if C_Mail and C_Mail.IsCommandPending and C_Mail.IsCommandPending() then return end
	if C_Container.CalculateTotalNumberOfFreeBagSlots and C_Container.CalculateTotalNumberOfFreeBagSlots() == 0 then
		Stop("Bags are full.")
		return
	end
	if not TakeNext() then Stop() end
end

local function Start()
	taken = 0
	button:Disable()
	button:SetText("Opening...")
	ticker = C_Timer.NewTicker(DELAY, Step)
end

function TT:SetupMail()
	local events = CreateFrame("Frame")
	events:RegisterEvent("MAIL_SHOW")
	events:RegisterEvent("MAIL_CLOSED")
	events:RegisterEvent("UI_ERROR_MESSAGE")
	events:SetScript("OnEvent", function(_, event, _, msg)
		if event == "MAIL_SHOW" then
			if button or not InboxFrame or _G.OpenAllMail then return end
			button = CreateFrame("Button", "TitanToolsOpenAll", InboxFrame, "UIPanelButtonTemplate")
			button:SetSize(100, 22)
			button:SetPoint("BOTTOM", InboxFrame, "BOTTOM", -10, 100)
			button:SetText("Open all")
			button:SetScript("OnClick", Start)
		elseif event == "MAIL_CLOSED" then
			if ticker then Stop() end
		elseif event == "UI_ERROR_MESSAGE" and ticker and msg == ERR_INV_FULL then
			Stop("Bags are full.")
		end
	end)
end
