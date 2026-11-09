-- TitanTools: accepts and turns in quests for you. Hold Shift while talking to an
-- NPC to do it yourself. When a quest offers a choice of rewards it stops and marks
-- the one that sells for the most, so you can still take an upgrade instead.
local ADDON, TT = ...

local coin

local function Skip()
	return not TT.db.quest.enabled or IsShiftKeyDown()
end

local function OnGossip()
	for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
		if q.isComplete then
			C_GossipInfo.SelectActiveQuest(q.questID)
			return
		end
	end
	for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
		if not q.isTrivial and not q.isIgnored then
			C_GossipInfo.SelectAvailableQuest(q.questID)
			return
		end
	end
end

-- The older quest-giver window (no gossip text), used by some NPCs and objects.
local function OnGreeting()
	for i = 1, GetNumActiveQuests() do
		local _, isComplete = GetActiveTitle(i)
		if isComplete then
			SelectActiveQuest(i)
			return
		end
	end
	for i = 1, GetNumAvailableQuests() do
		local isTrivial = GetAvailableQuestInfo(i)
		if not isTrivial then
			SelectAvailableQuest(i)
			return
		end
	end
end

local function OnDetail(questStartItemID)
	-- Quests started from an item or an area are handled by Blizzard's pop-up.
	if questStartItemID and questStartItemID ~= 0 then return end
	if QuestFlagsPVP and QuestFlagsPVP() then return end
	if QuestFrame and QuestFrame.autoQuest then
		AcknowledgeAutoAcceptQuest()
	else
		AcceptQuest()
	end
end

local function OnProgress()
	if IsQuestCompletable() then CompleteQuest() end
end

local function SellPrice(index)
	local link = GetQuestItemLink("choice", index)
	if not link then return 0 end
	local price = select(11, C_Item.GetItemInfo(link))
	return price or 0
end

local function MarkBestReward(index)
	local rewards = QuestInfoFrame and QuestInfoFrame.rewardsFrame
	local button
	for _, b in ipairs(rewards and rewards.RewardButtons or {}) do
		if b.type == "choice" and b:GetID() == index and b:IsShown() then button = b end
	end
	if not button then return end
	if not coin then
		coin = UIParent:CreateTexture(nil, "OVERLAY")
		coin:SetSize(18, 18)
		coin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
	end
	coin:SetParent(button)
	coin:SetDrawLayer("OVERLAY", 7)
	coin:ClearAllPoints()
	coin:SetPoint("TOPRIGHT", button.Icon or button, "TOPRIGHT", 4, 4)
	coin:Show()
end

local function OnComplete()
	local choices = GetNumQuestChoices()
	if choices <= 1 then
		-- Quests that cost gold to finish keep Blizzard's confirmation.
		local cost = GetQuestMoneyToGet and GetQuestMoneyToGet()
		if cost and cost > 0 then return end
		GetQuestReward(choices)
		return
	end
	local best, bestPrice = nil, 0
	for i = 1, choices do
		local price = SellPrice(i)
		if price > bestPrice then best, bestPrice = i, price end
	end
	if best then
		-- The reward buttons are filled in after this event, so wait a frame.
		C_Timer.After(0, function() MarkBestReward(best) end)
		TT:Print(("Pick a reward. The gold coin marks the one that sells for most (%s)."):format(GetCoinTextureString(bestPrice)))
	end
end

function TT:SetupQuests()
	local events = CreateFrame("Frame")
	for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS",
		"QUEST_COMPLETE", "QUEST_FINISHED" }) do
		events:RegisterEvent(e)
	end
	events:SetScript("OnEvent", function(_, event, arg1)
		if event == "QUEST_FINISHED" then
			if coin then coin:Hide() end
			return
		end
		if Skip() then return end
		if event == "GOSSIP_SHOW" then OnGossip()
		elseif event == "QUEST_GREETING" then OnGreeting()
		elseif event == "QUEST_DETAIL" then OnDetail(arg1)
		elseif event == "QUEST_PROGRESS" then OnProgress()
		elseif event == "QUEST_COMPLETE" then OnComplete()
		end
	end)
end
