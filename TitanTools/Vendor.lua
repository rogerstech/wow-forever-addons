-- TitanTools: repair and sell grey items when you open a vendor.
local ADDON, TT = ...

-- The buyback tab only holds 12 items, so stop there and let the next visit sell the rest.
local MAX_SELL = 12

local function SellJunk()
	local sold = 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue and not info.isLocked then
				C_Container.UseContainerItem(bag, slot)
				sold = sold + 1
				if sold >= MAX_SELL then return sold end
			end
		end
	end
	return sold
end

local function OnMerchantShow()
	local cfg = TT.db.vendor
	local before, repairCost = GetMoney(), 0

	if cfg.repair and CanMerchantRepair() then
		local cost, canRepair = GetRepairAllCost()
		if canRepair and cost > 0 then
			if cost <= GetMoney() then
				RepairAllItems()
				repairCost = cost
			else
				TT:Print("Not enough money to repair everything (" .. GetMoneyString(cost) .. ").")
			end
		end
	end

	local sold = cfg.junk and SellJunk() or 0

	if repairCost > 0 or sold > 0 then
		-- Sale money arrives a moment later; total it up then.
		C_Timer.After(1, function()
			local parts = {}
			if repairCost > 0 then table.insert(parts, "repaired for " .. GetMoneyString(repairCost)) end
			if sold > 0 then
				local earned = GetMoney() - before + repairCost
				table.insert(parts, ("sold %d junk item%s for %s"):format(sold, sold == 1 and "" or "s", GetMoneyString(math.max(0, earned))))
			end
			TT:Print(table.concat(parts, ", ") .. ".")
		end)
	end
end

function TT:SetupVendor()
	local events = CreateFrame("Frame")
	events:RegisterEvent("MERCHANT_SHOW")
	events:SetScript("OnEvent", OnMerchantShow)
end
