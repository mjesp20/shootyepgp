local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("shootyepgp")

sepgp_bids = sepgp:NewModule("sepgp_bids", "AceDB-2.0", "AceEvent-2.0")

function sepgp_bids:OnEnable()
  if not T:IsRegistered("sepgp_bids") then
    T:Register("sepgp_bids",
      "children", function()
        T:SetTitle(L["shootyepgp bids"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() sepgp_bids:Refresh() end
        )
      end      
    )
  end
  if not T:IsAttached("sepgp_bids") then
    T:Open("sepgp_bids")
  end
end

function sepgp_bids:OnDisable()
  T:Close("sepgp_bids")
end

function sepgp_bids:Refresh()
  T:Refresh("sepgp_bids")
end

function sepgp_bids:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "sepgp_bids" then
      sepgp:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("sepgp_bids") then
            T:Attach("sepgp_bids")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function sepgp_bids:Top()
  if T:IsRegistered("sepgp_bids") and (T.registry.sepgp_bids.tooltip) then
    T.registry.sepgp_bids.tooltip.scroll=0
  end  
end

function sepgp_bids:Toggle(forceShow)
  self:Top()
  if T:IsAttached("sepgp_bids") then
    T:Detach("sepgp_bids") -- show
    if (T:IsLocked("sepgp_bids")) then
      T:ToggleLocked("sepgp_bids")
    end
    self:setHideScript()
  else
    if (forceShow) then
      sepgp_bids:Refresh()
    else
      T:Attach("sepgp_bids") -- hide
    end
  end  
end

function sepgp_bids:on_bid_clicked(bid)
	local name, class, rank, spec, r_idx, ep, pr = unpack(bid)
	if IsControlKeyDown() then
		_, _, item = string.find(sepgp.bid_item.linkFull, "%[(.*)%]")
		local loot_idx, raid_idx
		for i = 1, GetNumLootItems() do
			local lootIcon, lootName, lootQuantity, rarity, locked = GetLootSlotInfo(i)
			if lootName == item then
				loot_idx = i
				break
			end
		end
		for i = 1, 40 do
			if GetMasterLootCandidate(i) == name then
				raid_idx = i
				break
			end
		end
		if loot_idx and raid_idx then
			GiveMasterLoot(loot_idx, raid_idx)
		end
		return
	end

	if IsShiftKeyDown() then
		sepgp:processLoot(name,sepgp.bid_item.linkFull,"bids")
		return
	end

  sepgp:widestAudience(string.format("Winning Bid: %s %s (%.03f PR)",name,(rank..'('..spec..')'),pr))
end

function sepgp_bids:countdownCounter()
  self._counter = (self._counter or 6) - 1
  if GetNumRaidMembers()>0 and self._counter > 0 then
    self._counterText = C:Yellow(tostring(self._counter))
    sepgp:widestAudience(tostring(self._counter))
    --SendChatMessage(tostring(self._counter),"RAID")
    self:Refresh()
  end
end

function sepgp_bids:countdownFinish(reset)
  if self:IsEventScheduled("shootyepgpBidCountdown") then
    self:CancelScheduledEvent("shootyepgpBidCountdown")
  end
  self._counter = 6
  if (reset) then
    self._counterText = C:Green("Starting")
  else
    self._counterText = C:Red("Finished")
  end
  self:Refresh()
end

function sepgp_bids:bidCountdown()
  self:countdownFinish(true)
  self:ScheduleRepeatingEvent("shootyepgpBidCountdown",self.countdownCounter,1,self)
  self:ScheduleEvent("shootyepgpBidCountdownFinish",self.countdownFinish,6,self)
end

local pr_sorter_bids = function(a,b)
	_, _, _, _, a_rank_idx, a_ep, a_pr = unpack(a)
	_, _, _, _, b_rank_idx, b_ep, b_pr = unpack(b)
	if a_rank_idx == b_rank_idx then
		local a_over, b_over
		if sepgp_minep > 0 then
			a_over = a_ep >= sepgp_minep
			b_over = b_ep >= sepgp_minep
		end
		if a_over == b_over then
			return a_pr == b_pr and a_ep > b_ep or a_pr > b_pr
		else
			return a_over
		end
	else
		return a_rank_idx < b_rank_idx
	end

end

function sepgp_bids:OnTooltipUpdate()
  if not (sepgp.bid_item and sepgp.bid_item.link) then return end
  local link = sepgp.bid_item.link
  local itemName = sepgp.bid_item.name
  local price = sepgp_prices:GetPrice(link,sepgp_progress)
  local offspec
  if not price then 
    price = "<n/a>"
    offspec = "<n/a>"
  else
    offspec = math.floor(price*sepgp_discount)
  end
  local bidcat = T:AddCategory(
      "columns", 3,    
      "text", C:Orange("Bid Item"), "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("GP Cost"),     "child_text2R", 50/255, "child_text2G", 205/255, "child_text2B", 50/255, "child_justify2", "RIGHT",
      "text3", C:Orange("OffSpec"),  "child_text3R", 32/255, "child_text3G", 178/255, "child_text3B", 170/255, "child_justify3", "RIGHT",      
      "hideBlankLine", true
    )
  bidcat:AddLine(
      "text", itemName,
      "text2", price,
      "text3", offspec
    )
  local countdownHeader = T:AddCategory(
      "columns", 2,
      "text","","child_textR",  1, "child_textG",  1, "child_textB",  1,"child_justify", "LEFT",
      "text2","","child_text2R",  1, "child_text2G",  1, "child_text2B",  1,"child_justify2", "CENTER",
      "hideBlankLine", true
    )
  countdownHeader:AddLine(
      "text", C:Green("Countdown"), 
      "text2", self._counterText, 
      "func", "bidCountdown", "arg1", self
    )  
  local maincatHeader = T:AddCategory(
      "columns", 1,
      "text", C:Gold("Bids List")
    ):AddLine("text","click to announce winner, ctrl+click to give loot, shift+click to give GP(tmog trade)")
  local maincat = T:AddCategory(
      "columns", 5,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("MS/OS"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT",
      "text3", C:Orange("Rank"),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange("pr"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "text5", C:Orange("EP"),     "child_text5R",   1, "child_text5G",   1, "child_text5B",   0, "child_justify5", "RIGHT",      
      "hideBlankLine", true
    )
  table.sort(sepgp.bids, pr_sorter_bids)
  for i = 1, table.getn(sepgp.bids) do
    local name, class, rank, spec, r_idx, ep, pr, main = unpack(sepgp.bids[i])
    local namedesc
    namedesc = C:Colorize(BC:GetHexColor(class), name)
    --[[ old, added alt to name with my change 
    if (main) then
      namedesc = string.format("%s(%s)", C:Colorize(BC:GetHexColor(class), name), L["Alt"])
    else
      namedesc = C:Colorize(BC:GetHexColor(class), name)
    end
    --]]
    local text2, text4
    if sepgp_minep > 0 and ep < sepgp_minep then
      text4 = C:Red(string.format("%.4g", pr))
    else
      text4 = string.format("%.4g", pr)
    end
    maincat:AddLine(
      "text", namedesc,
      "text2", spec,
      "text3", rank,
      "text4", text4,
      "text5", (main or ""),
      "func", "on_bid_clicked", "arg1", self, "arg2", sepgp.bids[i]
    )
  end
end

-- GLOBALS: sepgp_saychannel,sepgp_groupbyclass,sepgp_groupbyarmor,sepgp_groupbyrole,sepgp_raidonly,sepgp_decay,sepgp_minep,sepgp_reservechannel,sepgp_main,sepgp_progress,sepgp_discount,sepgp_log,sepgp_dbver,sepgp_looted
-- GLOBALS: sepgp,sepgp_prices,sepgp_standings,sepgp_bids,sepgp_loot,sepgp_reserves,sepgp_alts,sepgp_logs
