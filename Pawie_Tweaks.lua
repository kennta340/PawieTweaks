-- ==========================================
-- PAWIE TWEAKS - v2.60
-- ==========================================
local addonName, PT = ...
local coreFrame = CreateFrame("Frame")

local defaultSettings = {
    autoQuest = true,
    autoQuestReward = false,
    chatClassColors = true,
    shortChannelNames = true,
    blockDuels = false,         
    blockGuildInvites = false,
    hideGryphons = true,
    raidMarks = true,
    showRess = true,
    autoTransmog = true
}

local function ApplyChatColors(enable)
    local chatTypes = {"SAY", "EMOTE", "YELL", "WHISPER", "GUILD", "OFFICER", "PARTY", "RAID", "RAID_WARNING", "BATTLEGROUND", "BATTLEGROUND_LEADER"}
    for _, type in ipairs(chatTypes) do
        ToggleChatColorNamesByClassGroup(enable, type)
    end
    for i = 1, 10 do
        ToggleChatColorNamesByClassGroup(enable, "CHANNEL"..i)
    end
end

local function ApplyGryphons(hide)
    if hide then
        MainMenuBarLeftEndCap:Hide()
        MainMenuBarRightEndCap:Hide()
    else
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    end
end

-- ==========================================
-- MODULE: Background QoL
-- ==========================================
local function InitBackgroundQoL()
    if GameTooltipStatusBar then
        GameTooltipStatusBar:Hide()
        GameTooltipStatusBar:HookScript("OnShow", function(self) self:Hide() end)
    end

    if LFDLeaveFrameLeaveButton then
        LFDLeaveFrameLeaveButton:HookScript("OnClick", function() LeaveParty() end)
    end

    hooksecurefunc("StaticPopup_Show", function(which)
        if which == "DELETE_GOOD_ITEM" then
            local frame = StaticPopup_FindVisible(which)
            if frame then frame.editBox:SetText(DELETE_ITEM_CONFIRM_STRING) end
        end
    end)
    
    local lootConfirm = CreateFrame("Frame")
    lootConfirm:RegisterEvent("LOOT_BIND_CONFIRM")
    lootConfirm:RegisterEvent("CONFIRM_LOOT_ROLL")

    local bopPending = {}
    local bopDelay = CreateFrame("Frame")
    bopDelay:Hide()
    bopDelay:SetScript("OnUpdate", function(self)
        self:Hide()
        for slot in pairs(bopPending) do
            LootSlot(slot) 
            bopPending[slot] = nil
        end
    end)

    lootConfirm:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "LOOT_BIND_CONFIRM" then
            ConfirmLootSlot(arg1)
            StaticPopup_Hide("LOOT_BIND")
            bopPending[arg1] = true
            bopDelay:Show()
        elseif event == "CONFIRM_LOOT_ROLL" then
            ConfirmLootRoll(arg1, arg2)
            StaticPopup_Hide("CONFIRM_LOOT_ROLL")
        end
    end)

    local function ChatInviteFilter(self, event, msg, author, ...)
        local newMsg = string.gsub(msg, "%f[%a]([iI][nN][vV][iI]?[tT]?[eE]?)%f[%A]", "|Hpawieinv:"..author.."|h|cffffff00%1|r|h")
        return false, newMsg, author, ...
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ChatInviteFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", ChatInviteFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", ChatInviteFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", ChatInviteFilter)

    local orig_SetItemRef = SetItemRef
    function SetItemRef(link, text, button, chatFrame)
        local linkType, target = strsplit(":", link)
        if linkType == "pawieinv" then
            local inGroup = GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
            local isLeader = IsPartyLeader()
            if not inGroup or isLeader then
                InviteUnit(target)
                print("|cff00ff00Pawie Tweaks:|r Invited " .. target .. ".")
            else
                SendChatMessage("Can we invite " .. target .. "?", "PARTY")
            end
            return
        end
        orig_SetItemRef(link, text, button, chatFrame)
    end

    SetCVar("Sound_EnableErrorSpeech", "0")
    local originalAddMessage = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = function(frame, text, red, green, blue, id)
        if text then
            local lowerText = string.lower(text)
            if lowerText:match("bag is not empty") or lowerText:match("non%-empty") or lowerText:match("no more bag slots") or lowerText:match("free bag slot") or lowerText:match("inventory is full") or lowerText:match("cannot be equipped") or lowerText:match("with empty bags") then
                return
            end
            if lowerText:match("not ready") or lowerText:match("out of range") or lowerText:match("not enough") or lowerText:match("in progress") or lowerText:match("cooldown") or lowerText:match("can't cast") or lowerText:match("nothing to attack") then
                return
            end
        end
        originalAddMessage(frame, text, red, green, blue, id)
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame"..i.."EditBox"]
        if editBox then
            editBox:HookScript("OnShow", function(self)
                local inInstance, instanceType = IsInInstance()
                if inInstance and instanceType == "pvp" then
                    local cType = self:GetAttribute("chatType")
                    if cType == "SAY" or cType == "PARTY" or cType == "RAID" then
                        self:SetAttribute("chatType", "BATTLEGROUND")
                        ChatEdit_UpdateHeader(self)
                    end
                end
            end)
        end
    end
end

-- ==========================================
-- MODULE: Ascension Auto-Transmog & Bag Icons
-- ==========================================
local function InitAutoTransmog()
    local tmogFrame = CreateFrame("Frame")
    local scanTimer = 0
    local scanQueued = false
    local tmogTooltip = CreateFrame("GameTooltip", "PawieTweaksTmogTooltip", nil, "GameTooltipTemplate")

    local function ScanBagsForTransmog()
        if not C_AppearanceCollection or not C_Appearance then return end
        for b = 0, 4 do
            for s = 1, GetContainerNumSlots(b) do
                local itemID = GetContainerItemID(b, s)
                if itemID then
                    local appID = C_Appearance.GetItemAppearanceID(itemID)
                    if appID and not C_AppearanceCollection.IsAppearanceCollected(appID) then
                        tmogTooltip:SetOwner(UIParent, "ANCHOR_NONE")
                        tmogTooltip:ClearLines()
                        tmogTooltip:SetBagItem(b, s)
                        local isSoulbound = false
                        for line = 1, tmogTooltip:NumLines() do
                            local textL = _G["PawieTweaksTmogTooltipTextLeft"..line]
                            if textL then
                                local text = textL:GetText()
                                if text == ITEM_SOULBOUND then
                                    isSoulbound = true
                                    break
                                end
                            end
                        end
                        tmogTooltip:Hide()

                        if isSoulbound then
                            local guid = GetContainerItemGUID(b, s)
                            if guid then
                                C_AppearanceCollection.CollectItemAppearance(guid)
                                local link = GetContainerItemLink(b, s)
                                if link then
                                    print("|cff00ff00Pawie Tweaks:|r Auto-learned Soulbound appearance: " .. link)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    tmogFrame:RegisterEvent("BAG_UPDATE")
    tmogFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    tmogFrame:SetScript("OnEvent", function(self, event)
        if PawieTweaksDB.autoTransmog then
            scanQueued = true
        end
    end)
    
    tmogFrame:SetScript("OnUpdate", function(self, elapsed)
        if scanQueued then
            scanTimer = scanTimer + elapsed
            if scanTimer > 1.5 then
                scanQueued = false
                scanTimer = 0
                ScanBagsForTransmog()
            end
        end
    end)

    if ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", function(self)
            local bag = self:GetID()
            local name = self:GetName()
            for i = 1, self.size do
                local itemButton = _G[name .. "Item" .. i]
                if itemButton then
                    if not itemButton.ptTmogIcon then
                        itemButton.ptTmogIcon = itemButton:CreateTexture(nil, "OVERLAY")
                        itemButton.ptTmogIcon:SetSize(14, 14)
                        itemButton.ptTmogIcon:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", 2, 2)
                        itemButton.ptTmogIcon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")
                        itemButton.ptTmogIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    end
                    
                    itemButton.ptTmogIcon:Hide()
                    
                    if PawieTweaksDB.autoTransmog then
                        local slot = itemButton:GetID()
                        local itemID = GetContainerItemID(bag, slot)
                        if itemID and C_AppearanceCollection and C_Appearance then
                            local appID = C_Appearance.GetItemAppearanceID(itemID)
                            if appID and not C_AppearanceCollection.IsAppearanceCollected(appID) then
                                itemButton.ptTmogIcon:Show()
                            end
                        end
                    end
                end
            end
        end)
    end

    if SetItemButtonTexture then
        hooksecurefunc("SetItemButtonTexture", function(button, texture)
            if not button or not button.IsObjectType or not button:IsObjectType("Button") then return end
            
            local bag, slot
            if type(button.GetBag) == "function" then
                bag = button:GetBag()
            elseif type(button.bag) == "number" then
                bag = button.bag
            elseif button.GetParent and button:GetParent() and button:GetParent().GetID then
                bag = button:GetParent():GetID()
            end
            
            if button.GetID then
                slot = button:GetID()
            end
            
            if type(bag) == "number" and bag >= 0 and bag <= 4 and type(slot) == "number" and slot >= 1 and slot <= 36 then
                if not button.ptTmogIcon then
                    button.ptTmogIcon = button:CreateTexture(nil, "OVERLAY")
                    button.ptTmogIcon:SetSize(14, 14)
                    button.ptTmogIcon:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
                    button.ptTmogIcon:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")
                    button.ptTmogIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                end
                
                button.ptTmogIcon:Hide()
                
                if PawieTweaksDB.autoTransmog then
                    local itemID = GetContainerItemID(bag, slot)
                    if itemID and C_AppearanceCollection and C_Appearance then
                        local appID = C_Appearance.GetItemAppearanceID(itemID)
                        if appID and not C_AppearanceCollection.IsAppearanceCollected(appID) then
                            button.ptTmogIcon:Show()
                        end
                    end
                end
            end
        end)
    end
end

-- ==========================================
-- MODULE: Raid Frame Tweaks (The "Sticky Note" Method)
-- ==========================================
local function InitRaidFrameTweaks()
    local incomingRes = {}
    local resSpells = {}
    local spellIDs = {2006, 7328, 2008, 50769, 20484} 
    
    for _, id in ipairs(spellIDs) do
        local name = GetSpellInfo(id)
        if name then resSpells[name] = true end
    end
    resSpells["Millhouse's Regeneration Matrix"] = true

    -- Vi skapar en databas för våra "Post-it lappar"
    local overlays = {}
    local function GetOverlay(id)
        if not overlays[id] then
            -- Rutorna tillhör skärmen, inte raidmenyn!
            local f = CreateFrame("Frame", nil, UIParent)
            f:SetSize(18, 18)
            f:SetFrameStrata("TOOLTIP") 
            
            local rIcon = f:CreateTexture(nil, "OVERLAY")
            rIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            rIcon:SetAllPoints()
            f.rIcon = rIcon

            local resIcon = f:CreateTexture(nil, "OVERLAY")
            resIcon:SetTexture("Interface\\Icons\\Spell_Holy_Resurrection")
            resIcon:SetAllPoints()
            resIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            f.resIcon = resIcon

            overlays[id] = f
        end
        return overlays[id]
    end

    local timer = 0
    local updater = CreateFrame("Frame")
    updater:SetScript("OnUpdate", function(self, elapsed)
        timer = timer + elapsed
        if timer < 0.2 then return end -- Uppdaterar 5 gånger i sekunden
        timer = 0

        -- Göm alla markeringar inför en ny skanning
        for _, o in pairs(overlays) do o:Hide() end

        if not PawieTweaksDB.raidMarks and not PawieTweaksDB.showRess then return end

        local activeOverlays = 0

        local function ProcessButton(btn)
            if not btn or not btn:IsVisible() then return end
            
            -- Läs vem som är i rutan genom att kolla spelets kod ELLER läsa texten på skärmen
            local unit = btn:GetAttribute("unit") or btn.unit
            if not unit or not UnitExists(unit) then
                local nameFS = btn.name or _G[btn:GetName().."Name"]
                if nameFS and nameFS.GetText then
                    local text = nameFS:GetText()
                    if text then
                        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                        if text == UnitName("player") then unit = "player"
                        else
                            for k=1,4 do if UnitName("party"..k) == text then unit = "party"..k; break end end
                            if not unit then
                                for k=1,40 do if UnitName("raid"..k) == text then unit = "raid"..k; break end end
                            end
                        end
                    end
                end
            end

            if not unit or not UnitExists(unit) then return end

            local mark = GetRaidTargetIndex(unit)
            local hasRes = incomingRes[UnitName(unit)]

            if (PawieTweaksDB.raidMarks and mark) or (PawieTweaksDB.showRess and hasRes) then
                activeOverlays = activeOverlays + 1
                local o = GetOverlay(activeOverlays)
                
                -- Den matematiska magin: Hitta rutans exakta koordinater på din bildskärm
                local x, y = btn:GetCenter()
                local height = btn:GetHeight()
                
                if x and y and height then
                    o:ClearAllPoints()
                    -- Klistra fast markeringen OVANFÖR rutan (y + höjden delat på 2 + 4 pixlars marginal)
                    o:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y + (height / 2) + 4)
                    
                    if PawieTweaksDB.raidMarks and mark then
                        local col = (mark - 1) % 4
                        local row = math.floor((mark - 1) / 4)
                        o.rIcon:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
                        o.rIcon:Show()
                        o.resIcon:Hide()
                    else
                        o.rIcon:Hide()
                        o.resIcon:Show()
                        o.resIcon:SetAlpha(0.85)
                    end
                    o:Show()
                end
            end
        end

        -- Skanna de fasta rutorna
        for i=1,8 do
            for j=1,5 do
                ProcessButton(_G["RaidGroup"..i.."Member"..j])
            end
        end

        -- Skanna de utdragna "Group 1", "Group 2" rutorna
        for i=1,40 do
            local pullout = _G["RaidPullout"..i]
            if pullout and pullout:IsVisible() then
                for j=1,40 do
                    ProcessButton(_G[pullout:GetName().."Button"..j])
                end
            end
        end
    end)

    local rfFrame = CreateFrame("Frame")
    rfFrame:RegisterEvent("UNIT_SPELLCAST_START")
    rfFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    rfFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    rfFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    rfFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

    rfFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
        if event == "UNIT_SPELLCAST_START" then
            if PawieTweaksDB.showRess and resSpells[arg2] then
                local target = arg1 .. "target"
                if UnitExists(target) and UnitIsDeadOrGhost(target) then
                    local name = UnitName(target)
                    if name then
                        incomingRes[name] = arg1
                    end
                end
            end
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_SUCCEEDED" then
            if PawieTweaksDB.showRess and resSpells[arg2] then
                for targetName, casterUnit in pairs(incomingRes) do
                    if casterUnit == arg1 then
                        incomingRes[targetName] = nil
                    end
                end
            end
        end
    end)
    
    PT.UpdateRaidFrames = function() end 
end

-- ==========================================
-- MODULE: Change Any Bag
-- ==========================================
local function InitBagUpgrade()
    local bu = nil 
    local buFrame = CreateFrame("Frame")
    local BU_TIMEOUT = 15 

    local function SlotLocked(bag, slot)
        return select(3, GetContainerItemInfo(bag, slot)) and true or false
    end

    local function SlotEmpty(bag, slot)
        return GetContainerItemLink(bag, slot) == nil
    end

    local function ItemFamily(link)
        return (link and GetItemFamily(link)) or 0
    end

    local function FamilyFits(bagFamily, itemFamily)
        return bagFamily == 0 or itemFamily == 0 or bit.band(bagFamily, itemFamily) ~= 0
    end

    local function StopBagUpgrade(errMsg)
        if errMsg then print("|cffff0000Pawie Tweaks:|r " .. errMsg) end
        bu = nil
        buFrame:UnregisterEvent("BAG_UPDATE")
        buFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
        buFrame:SetScript("OnUpdate", nil)
    end

    local function StepBagUpgrade()
        if not bu then return end

        if bu.phase == "moving" then
            local mv = bu.moves[1]
            if not mv then
                bu.phase = "equip"
                return StepBagUpgrade()
            end
            if SlotEmpty(mv.fromBag, mv.fromSlot) then
                table.remove(bu.moves, 1) 
                return StepBagUpgrade()
            end
            if SlotLocked(mv.fromBag, mv.fromSlot) or SlotLocked(mv.toBag, mv.toSlot) then
                return 
            end
            PickupContainerItem(mv.fromBag, mv.fromSlot)
            PickupContainerItem(mv.toBag, mv.toSlot)
            return

        elseif bu.phase == "equip" then
            if GetInventoryItemLink("player", bu.targetInvSlot) ~= bu.oldBagLink then
                bu.phase = "park"
                return StepBagUpgrade()
            end
            if CursorHasItem() then return end
            if SlotLocked(bu.newBag, bu.newSlot) then return end
            PickupContainerItem(bu.newBag, bu.newSlot) 
            PutItemInBag(bu.targetInvSlot) 
            return

        elseif bu.phase == "park" then
            if not CursorHasItem() then
                StopBagUpgrade() 
                print("|cff00ff00Pawie Tweaks:|r Bag swap complete!")
                return
            end
            if SlotLocked(bu.parkBag, bu.parkSlot) or not SlotEmpty(bu.parkBag, bu.parkSlot) then
                return
            end
            PickupContainerItem(bu.parkBag, bu.parkSlot)
            StopBagUpgrade()
            print("|cff00ff00Pawie Tweaks:|r Bag swap complete!")
        end
    end

    buFrame:SetScript("OnEvent", StepBagUpgrade)

    local buElapsed = 0
    local function BuWatchdog(_, elapsed)
        buElapsed = buElapsed + elapsed
        if buElapsed > BU_TIMEOUT then
            buElapsed = 0
            StopBagUpgrade("Bag swap timed out.")
        end
    end

    local function StartBagUpgrade(state)
        bu = state
        buElapsed = 0
        buFrame:RegisterEvent("BAG_UPDATE")
        buFrame:RegisterEvent("ITEM_LOCK_CHANGED")
        buFrame:SetScript("OnUpdate", BuWatchdog)
        StepBagUpgrade()
    end

    local function TryBagUpgrade(bag, slot)
        if bu then return false end 
        if InCombatLockdown() then return false end
        if BankFrame and BankFrame:IsShown() then return false end 
        if MerchantFrame and MerchantFrame:IsShown() then return false end 

        local link = GetContainerItemLink(bag, slot)
        if not link then return false end
        local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
        if equipLoc ~= "INVTYPE_BAG" then return false end

        for bagID = 1, NUM_BAG_SLOTS do
            if GetContainerNumSlots(bagID) == 0 then return false end
        end

        local targetBag, targetSlots
        for bagID = 1, NUM_BAG_SLOTS do
            local n = GetContainerNumSlots(bagID)
            if not targetSlots or n < targetSlots then
                targetBag, targetSlots = bagID, n
            end
        end
        if not targetBag then return false end

        local freeSlots = {} 
        for bagID = 0, NUM_BAG_SLOTS do
            if bagID ~= targetBag then
                local bagFamily = 0
                if bagID > 0 then
                    bagFamily = ItemFamily(GetInventoryItemLink("player", ContainerIDToInventoryID(bagID)))
                end
                for s = 1, GetContainerNumSlots(bagID) do
                    if SlotEmpty(bagID, s) then
                        table.insert(freeSlots, { bag = bagID, slot = s, family = bagFamily })
                    end
                end
            end
        end

        local newBag, newSlot = bag, slot
        local moves, usedFree = {}, {}
        local ok = true
        local itemsToMove = 0

        for s = 1, targetSlots do
            local itemLink = GetContainerItemLink(targetBag, s)
            if itemLink then
                itemsToMove = itemsToMove + 1
                local family = ItemFamily(itemLink)
                local dest
                for i, free in ipairs(freeSlots) do
                    if not usedFree[i] and FamilyFits(free.family, family) then
                        dest, usedFree[i] = free, true
                        break
                    end
                end
                if not dest then ok = false break end
                table.insert(moves, { fromBag = targetBag, fromSlot = s, toBag = dest.bag, toSlot = dest.slot })
                if targetBag == bag and s == slot then
                    newBag, newSlot = dest.bag, dest.slot
                end
            end
        end

        local parkBag, parkSlot
        if ok then
            for i, free in ipairs(freeSlots) do
                if not usedFree[i] and free.family == 0 then 
                    parkBag, parkSlot = free.bag, free.slot
                    usedFree[i] = true
                    break
                end
            end
            if not parkBag then ok = false end
        end

        if not ok then
            local neededSlots = itemsToMove + 1
            print("|cffff0000Pawie Tweaks:|r Auto-swap failed: You need at least " .. neededSlots .. " empty slots in your other bags to clear your smallest bag!")
            return true
        end

        print("|cff00ff00Pawie Tweaks:|r Change Any Bag initiated! Moving items...")
        StartBagUpgrade({
            phase = "moving",
            moves = moves,
            targetBag = targetBag,
            targetInvSlot = ContainerIDToInventoryID(targetBag),
            oldBagLink = GetInventoryItemLink("player", ContainerIDToInventoryID(targetBag)),
            newBag = newBag,
            newSlot = newSlot,
            parkBag = parkBag,
            parkSlot = parkSlot,
        })
        return true
    end

    hooksecurefunc("UseContainerItem", function(bag, slot)
        TryBagUpgrade(bag, slot)
    end)
end

-- ==========================================
-- MODULE: Auto Quest
-- ==========================================
local function InitAutoQuest()
    local questFrame = CreateFrame("Frame")
    questFrame:RegisterEvent("QUEST_GREETING")
    questFrame:RegisterEvent("GOSSIP_SHOW")
    questFrame:RegisterEvent("QUEST_DETAIL")
    questFrame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
    questFrame:RegisterEvent("QUEST_PROGRESS")
    questFrame:RegisterEvent("QUEST_COMPLETE")
    questFrame:RegisterEvent("MERCHANT_SHOW")
    questFrame:RegisterEvent("MERCHANT_UPDATE")
    questFrame:RegisterEvent("MERCHANT_CLOSED")
    
    local processingEvent = false
    local PT_AutoBought = {}
    local scanTooltip = CreateFrame("GameTooltip", "PawieTweaksScanTooltip", nil, "GameTooltipTemplate")

    local playerClassLocalized, playerClassEnglish = UnitClass("player")
    local optimalArmor = "None"
    local isClassless = false
    
    if playerClassEnglish == "HERO" or playerClassLocalized == "Hero" then
        isClassless = true
    elseif playerClassEnglish == "WARRIOR" or playerClassEnglish == "PALADIN" or playerClassEnglish == "DEATHKNIGHT" then
        optimalArmor = "Plate"
    elseif playerClassEnglish == "HUNTER" or playerClassEnglish == "SHAMAN" then
        optimalArmor = "Mail"
    elseif playerClassEnglish == "ROGUE" or playerClassEnglish == "DRUID" then
        optimalArmor = "Leather"
    elseif playerClassEnglish == "MAGE" or playerClassEnglish == "PRIEST" or playerClassEnglish == "WARLOCK" then
        optimalArmor = "Cloth"
    end

    questFrame:SetScript("OnEvent", function(self, ev)
        if ev == "MERCHANT_CLOSED" then
            PT_AutoBought = {}
            return
        end
        
        if ev == "MERCHANT_SHOW" or ev == "MERCHANT_UPDATE" then
            if not PawieTweaksDB.autoQuest then return end
            if IsShiftKeyDown() then return end
            
            local numItems = GetMerchantNumItems()
            for i = 1, numItems do
                local link = GetMerchantItemLink(i)
                if link then
                    local itemID = tonumber(link:match("item:(%d+)"))
                    if itemID and not PT_AutoBought[itemID] then
                        local _, _, price, _, _, _, extendedCost = GetMerchantItemInfo(i)
                        if price and price <= 3000 and not extendedCost then
                            local isQuestItem = false
                            local itemName, _, _, _, _, itemType = GetItemInfo(link)
                            
                            if itemName and (itemType == "Quest" or itemType == "Quest Item") then
                                isQuestItem = true
                            else
                                scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
                                scanTooltip:ClearLines()
                                scanTooltip:SetMerchantItem(i)
                                for line = 1, scanTooltip:NumLines() do
                                    local textL = _G["PawieTweaksScanTooltipTextLeft"..line]
                                    if textL then
                                        local text = textL:GetText()
                                        if text and (text == "Quest Item" or text == ITEM_BIND_QUEST) then
                                            isQuestItem = true
                                            break
                                        end
                                    end
                                end
                                scanTooltip:Hide()
                            end

                            if isQuestItem then
                                if GetItemCount(itemID) == 0 then
                                    BuyMerchantItem(i, 1)
                                    print("|cff00ff00Pawie Tweaks:|r Auto-bought quest item: " .. link)
                                end
                                PT_AutoBought[itemID] = true
                            end
                        end
                    end
                end
            end
            return
        end

        if not PawieTweaksDB.autoQuest then return end
        if IsShiftKeyDown() then return end 
        if processingEvent then return end
        
        local npcName = string.lower(UnitName("npc") or "")
        local targetName = string.lower(UnitName("target") or "")
        if npcName:match("board") or targetName:match("board") or npcName:match("hero's call") or targetName:match("hero's call") then 
            return 
        end
        
        processingEvent = true
        
        if ev == "QUEST_GREETING" then
            local numActive = GetNumActiveQuests()
            for i = 1, numActive do 
                local _, isComplete = GetActiveTitle(i)
                if isComplete then 
                    SelectActiveQuest(i)
                    processingEvent = false
                    return 
                end
            end
            local numAvailable = GetNumAvailableQuests()
            if numAvailable > 0 then 
                SelectAvailableQuest(1)
                processingEvent = false
                return 
            end
            
        elseif ev == "GOSSIP_SHOW" then
            local active = {GetGossipActiveQuests()}
            if #active > 0 then
                local qIndex = 1
                local i = 1
                while i <= #active do
                    local nextQ = i + 1
                    while nextQ <= #active do
                        if type(active[nextQ]) == "string" and type(active[nextQ+1]) == "number" then
                            break
                        end
                        nextQ = nextQ + 1
                    end
                    
                    local isComplete = active[i+3]
                    if isComplete == true or isComplete == 1 then
                        SelectGossipActiveQuest(qIndex)
                        processingEvent = false
                        return
                    end
                    
                    qIndex = qIndex + 1
                    i = nextQ
                end
            end
            
            local available = {GetGossipAvailableQuests()}
            if #available > 0 then 
                SelectGossipAvailableQuest(1)
                processingEvent = false
                return 
            end
            
            local options = {GetGossipOptions()}
            if #options == 2 and options[2] == "vendor" then
                SelectGossipOption(1)
                processingEvent = false
                return
            end
            
        elseif ev == "QUEST_DETAIL" then
            local objective = string.lower(GetObjectiveText() or "")
            local text = string.lower(GetQuestText() or "")
            if string.find(objective, "escort") or string.find(objective, "protect") or string.find(text, "escort") then
                print("|cff00ff00Pawie Tweaks:|r Escort quest detected. Auto-accept paused.")
            else 
                AcceptQuest() 
            end
            
        elseif ev == "QUEST_ACCEPT_CONFIRM" then
            print("|cff00ff00Pawie Tweaks:|r Event warning detected. Auto-accept paused.")
        elseif ev == "QUEST_PROGRESS" then
            if IsQuestCompletable() then CompleteQuest() end
        elseif ev == "QUEST_COMPLETE" then
            local choices = GetNumQuestChoices() or 0
            if choices <= 1 then 
                GetQuestReward(choices) 
            elseif PawieTweaksDB.autoQuestReward then
                local bestIndex = nil
                local bestValue = -1
                local isSafeToPick = true
                local foundOptimalArmor = false
                
                for i = 1, choices do
                    local itemLink = GetQuestItemLink("choice", i)
                    if itemLink then
                        local _, _, rarity, _, _, itemType, itemSubType, _, _, _, itemSellPrice = GetItemInfo(itemLink)
                        
                        if rarity and rarity > 1 then
                            isSafeToPick = false
                            break
                        end
                        
                        local sellPrice = itemSellPrice or 0
                        
                        if isClassless then
                            if sellPrice > bestValue then
                                bestValue = sellPrice
                                bestIndex = i
                            end
                        else
                            if itemType == "Armor" then
                                local isOptimal = false
                                
                                if itemSubType == optimalArmor then
                                    isOptimal = true
                                elseif UnitLevel("player") < 40 then
                                    if optimalArmor == "Plate" and itemSubType == "Mail" then isOptimal = true end
                                    if optimalArmor == "Mail" and itemSubType == "Leather" then isOptimal = true end
                                end

                                if isOptimal then
                                    if foundOptimalArmor then
                                        if sellPrice > bestValue then
                                            bestValue = sellPrice
                                            bestIndex = i
                                        end
                                    else
                                        foundOptimalArmor = true
                                        bestValue = sellPrice
                                        bestIndex = i
                                    end
                                end
                            end
                            
                            if not foundOptimalArmor then
                                if sellPrice > bestValue then
                                    bestValue = sellPrice
                                    bestIndex = i
                                end
                            end
                        end
                    end
                end
                
                if isSafeToPick and bestIndex then
                    GetQuestReward(bestIndex)
                end
            end
        end

        processingEvent = false
    end)
end

-- ==========================================
-- MODULE: UI Tweaks
-- ==========================================
local function InitUITweaks()
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        local _, unit = self:GetUnit()
        if not unit or not UnitIsPlayer(unit) then return end
        
        local name = UnitName(unit)
        local _, class = UnitClass(unit)
        if not name or not class then return end
        
        local color = RAID_CLASS_COLORS[class]
        if color then
            local hexColor = string.format("ff%02x%02x%02x", color.r*255, color.g*255, color.b*255)
            local titleText = GameTooltipTextLeft1:GetText()
            if titleText and string.find(titleText, name) then
                GameTooltipTextLeft1:SetText(string.gsub(titleText, name, "|c" .. hexColor .. name .. "|r"))
            end
        end
        
        local guildName = GetGuildInfo(unit)
        if guildName then
            local guildText = GameTooltipTextLeft2:GetText()
            if guildText and string.find(guildText, guildName) then
                GameTooltipTextLeft2:SetText("|cFFFFFF00" .. guildText .. "|r")
            end
        end
    end)

    local copyWindow = CreateFrame("Frame", nil, UIParent)
    copyWindow:SetSize(600, 450)
    copyWindow:SetPoint("CENTER")
    copyWindow:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    copyWindow:Hide()
    copyWindow:SetFrameStrata("DIALOG")

    local closeBtn = CreateFrame("Button", nil, copyWindow, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local scrollArea = CreateFrame("ScrollFrame", "PawieChatCopyScroll", copyWindow, "UIPanelScrollFrameTemplate")
    scrollArea:SetPoint("TOPLEFT", 15, -15)
    scrollArea:SetPoint("BOTTOMRIGHT", -30, 15)

    local editBox = CreateFrame("EditBox", nil, scrollArea)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(99999)
    editBox:EnableMouse(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(550)
    scrollArea:SetScrollChild(editBox)

    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            chatFrame.pawieHistory = {}
            
            if not chatFrame.originalAddMessage then
                chatFrame.originalAddMessage = chatFrame.AddMessage
            end
            
            chatFrame.AddMessage = function(frame, text, ...)
                if text then
                    if PawieTweaksDB.shortChannelNames then
                        text = text:gsub("(|Hchannel:[^|]+|h)%[(%d+)%..-%](|h)", "%1[%2.]%3")
                        text = text:gsub("%[(%d+)%..-%]", "[%1.]")
                        
                        local channels = {
                            {"Battleground Leader", "BGL"},
                            {"Battleground", "BG"},
                            {"Dungeon Guide", "DG"},
                            {"Party Leader", "PL"},
                            {"Party", "P"},
                            {"Raid Leader", "RL"},
                            {"Raid Warning", "RW"},
                            {"Raid", "R"},
                            {"Guild", "G"},
                            {"Officer", "O"}
                        }
                        for _, map in ipairs(channels) do
                            local full = map[1]
                            local short = map[2]
                            text = text:gsub("(|Hchannel:[^|]+|h)%["..full.."%](|h)", "%1["..short.."]%2")
                            text = text:gsub("%["..full.."%]", "["..short.."]")
                        end
                    end
                    
                    table.insert(frame.pawieHistory, text)
                    if #frame.pawieHistory > 200 then table.remove(frame.pawieHistory, 1) end
                end
                frame.originalAddMessage(frame, text, ...)
            end

            local copyBtn = CreateFrame("Button", nil, chatFrame)
            copyBtn:SetSize(24, 24)
            copyBtn:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", -5, -5)
            copyBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
            copyBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
            copyBtn:SetAlpha(0.3) 
            copyBtn:SetScript("OnEnter", function(self) self:SetAlpha(1.0) end)
            copyBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.3) end)
            copyBtn:SetScript("OnClick", function()
                local allText = ""
                for j = 1, #chatFrame.pawieHistory do allText = allText .. chatFrame.pawieHistory[j] .. "\n" end
                allText = allText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
                editBox:SetText(allText)
                copyWindow:Show()
                editBox:HighlightText() 
            end)
        end
    end

    ApplyChatColors(PawieTweaksDB.chatClassColors)

    local orig_MerchantItemButton_OnModifiedClick = MerchantItemButton_OnModifiedClick
    function MerchantItemButton_OnModifiedClick(self, button)
        if IsAltKeyDown() and button == "LeftButton" then
            local id = self:GetID()
            local maxStack = GetMerchantItemMaxStack(id)
            local _, _, _, quantity = GetMerchantItemInfo(id)
            if maxStack > 1 then BuyMerchantItem(id, math.floor(maxStack/quantity)); return end
        end
        orig_MerchantItemButton_OnModifiedClick(self, button)
    end

    local blockFrame = CreateFrame("Frame")
    blockFrame:RegisterEvent("DUEL_REQUESTED")
    blockFrame:RegisterEvent("GUILD_INVITE_REQUEST")
    blockFrame:SetScript("OnEvent", function(self, event, name)
        local function IsFriend(n)
            for i = 1, GetNumFriends() do if GetFriendInfo(i) == n then return true end end
            if IsInGuild() then
                for i = 1, GetNumGuildMembers() do
                    local gName = select(1, GetGuildRosterInfo(i))
                    if gName and strsplit("-", gName) == n then return true end
                end
            end
            return false
        end

        if not IsFriend(name) then
            if event == "DUEL_REQUESTED" and PawieTweaksDB.blockDuels then
                CancelDuel(); StaticPopup_Hide("DUEL_REQUESTED")
                print("|cff00ff00Pawie Tweaks:|r Blocked duel request from " .. tostring(name) .. ".")
            elseif event == "GUILD_INVITE_REQUEST" and PawieTweaksDB.blockGuildInvites then
                DeclineGuild(); StaticPopup_Hide("GUILD_INVITE")
                print("|cff00ff00Pawie Tweaks:|r Blocked guild invite from " .. tostring(name) .. ".")
            end
        end
    end)
end

-- ==========================================
-- MODULE: UI Options Menu & Mass Learn
-- ==========================================
local function LearnAllAppearancesInBags()
    if not C_AppearanceCollection or not C_Appearance then return end
    local count = 0
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b) do
            local itemID = GetContainerItemID(b, s)
            if itemID then
                local appID = C_Appearance.GetItemAppearanceID(itemID)
                if appID and not C_AppearanceCollection.IsAppearanceCollected(appID) then
                    local guid = GetContainerItemGUID(b, s)
                    if guid then
                        C_AppearanceCollection.CollectItemAppearance(guid)
                        count = count + 1
                    end
                end
            end
        end
    end
    if count > 0 then
        print("|cff00ff00Pawie Tweaks:|r Mass-learned " .. count .. " new appearances from bags!")
    else
        print("|cff00ff00Pawie Tweaks:|r No new appearances found in bags.")
    end
end

local function InitMenuAndCommands()
    SLASH_PAWIERELOAD1 = "/rl"
    SlashCmdList["PAWIERELOAD"] = function() ReloadUI() end
    
    SLASH_PAWIEITEM1 = "/pi"
    SlashCmdList["PAWIEITEM"] = function() LearnAllAppearancesInBags() end

    SLASH_PAWIETWEAKS1 = "/pawie"
    SlashCmdList["PAWIETWEAKS"] = function(msg)
        msg = string.lower(msg or "")
        msg = msg:match("^%s*(.-)%s*$")
        
        if msg == "quest" then
            PawieTweaksDB.autoQuest = not PawieTweaksDB.autoQuest
            print("|cff00ff00Pawie Tweaks:|r Auto-Quest is now " .. (PawieTweaksDB.autoQuest and "ON" or "OFF") .. ".")
        elseif msg == "reward" then
            PawieTweaksDB.autoQuestReward = not PawieTweaksDB.autoQuestReward
            print("|cff00ff00Pawie Tweaks:|r Auto-Quest Reward is now " .. (PawieTweaksDB.autoQuestReward and "ON" or "OFF") .. ".")
        elseif msg == "duel" then
            PawieTweaksDB.blockDuels = not PawieTweaksDB.blockDuels
            print("|cff00ff00Pawie Tweaks:|r Block Duels is now " .. (PawieTweaksDB.blockDuels and "ON" or "OFF") .. ".")
        elseif msg == "ginv" then
            PawieTweaksDB.blockGuildInvites = not PawieTweaksDB.blockGuildInvites
            print("|cff00ff00Pawie Tweaks:|r Block Guild Invites is now " .. (PawieTweaksDB.blockGuildInvites and "ON" or "OFF") .. ".")
        elseif msg == "colors" then
            PawieTweaksDB.chatClassColors = not PawieTweaksDB.chatClassColors
            ApplyChatColors(PawieTweaksDB.chatClassColors)
            print("|cff00ff00Pawie Tweaks:|r Chat Class Colors are now " .. (PawieTweaksDB.chatClassColors and "ON" or "OFF") .. ".")
        elseif msg == "shortchat" then
            PawieTweaksDB.shortChannelNames = not PawieTweaksDB.shortChannelNames
            print("|cff00ff00Pawie Tweaks:|r Short Channel Names are now " .. (PawieTweaksDB.shortChannelNames and "ON" or "OFF") .. ".")
        elseif msg == "marks" then
            PawieTweaksDB.raidMarks = not PawieTweaksDB.raidMarks
            if PT.UpdateRaidFrames then PT.UpdateRaidFrames() end
            print("|cff00ff00Pawie Tweaks:|r Raid Marks on Default Frames are now " .. (PawieTweaksDB.raidMarks and "ON" or "OFF") .. ".")
        elseif msg == "ress" then
            PawieTweaksDB.showRess = not PawieTweaksDB.showRess
            if PT.UpdateRaidFrames then PT.UpdateRaidFrames() end
            print("|cff00ff00Pawie Tweaks:|r Incoming Resurrection tracking is now " .. (PawieTweaksDB.showRess and "ON" or "OFF") .. ".")
        elseif msg == "tmog" then
            PawieTweaksDB.autoTransmog = not PawieTweaksDB.autoTransmog
            print("|cff00ff00Pawie Tweaks:|r Auto-Collect Soulbound Transmogs is now " .. (PawieTweaksDB.autoTransmog and "ON" or "OFF") .. ".")
        elseif msg == "item" then
            LearnAllAppearancesInBags()
        else
            print("|cff00ff00Pawie Tweaks Commands:|r")
            print("  |cffffff00/pawie quest|r - Toggles Auto-Quest accept and turn-in.")
            print("  |cffffff00/pawie reward|r - Toggles Auto-Pick for white/gray quest rewards.")
            print("  |cffffff00/pawie duel|r - Toggles blocking of duel requests.")
            print("  |cffffff00/pawie ginv|r - Toggles blocking of guild invites.")
            print("  |cffffff00/pawie colors|r - Toggles class colors in chat.")
            print("  |cffffff00/pawie shortchat|r - Toggles shortening of chat channels (e.g. [1.]).")
            print("  |cffffff00/pawie marks|r - Toggles Raid Marks on default frames.")
            print("  |cffffff00/pawie ress|r - Toggles Incoming Resurrection tracking.")
            print("  |cffffff00/pawie tmog|r - Toggles auto-learning uncollected Soulbound appearances.")
            print("  |cffffff00/pawie item|r (or |cffffff00/pi|r) - Mass-learns all uncollected items in bags. |cffff0000(WARNING: Binds BoE items!)|r")
            print("  |cffffff00/rl|r - Reloads the UI.")
        end
    end

    local optionsPanel = CreateFrame("Frame", "PawieTweaksOptionsPanel", UIParent)
    optionsPanel.name = "Pawie Tweaks"
    InterfaceOptions_AddCategory(optionsPanel)

    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16); title:SetText("Pawie Tweaks Settings")
    local desc = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8); desc:SetJustifyH("LEFT")
    desc:SetText("A lightweight addon to automate tedious tasks.")

    local optHeader = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    optHeader:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20); optHeader:SetText("Togglable Settings")

    local function CreateCB(name, label, dbKey, relativeTo, cbFunc)
        local cb = CreateFrame("CheckButton", name, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", 0, -3)
        _G[cb:GetName() .. "Text"]:SetText(label)
        cb:SetScript("OnShow", function(self) self:SetChecked(PawieTweaksDB[dbKey]) end)
        cb:SetScript("OnClick", function(self) 
            PawieTweaksDB[dbKey] = self:GetChecked() and true or false 
            if cbFunc then cbFunc(PawieTweaksDB[dbKey]) end
        end)
        return cb
    end

    local cbQuest = CreateCB("PT_CBQuest", "Auto-Quest (Accepts/Turns in quests. Hold SHIFT to pause)", "autoQuest", optHeader)
    cbQuest:SetPoint("TOPLEFT", optHeader, "BOTTOMLEFT", 0, -8)
    
    local cbQuestReward = CreateCB("PT_CBQuestReward", "Auto-Pick Quest Rewards (Gray/White items only)", "autoQuestReward", cbQuest)

    local cbColors = CreateCB("PT_CBColors", "Class Colors in Chat", "chatClassColors", cbQuestReward, function(val) ApplyChatColors(val) end)
    
    local cbChatShort = CreateCB("PT_CBChatShort", "Short Channel Names (e.g. [1. Ascension] -> [1.])", "shortChannelNames", cbColors)

    local cbDuel = CreateCB("PT_CBDuel", "Block Duel Requests", "blockDuels", cbChatShort)
    local cbGinv = CreateCB("PT_CBGinv", "Block Guild Invites", "blockGuildInvites", cbDuel)
    local cbGryphons = CreateCB("PT_CBGryphons", "Hide Action Bar Gryphons", "hideGryphons", cbGinv, function(val) ApplyGryphons(val) end)
    
    local cbRaidMarks = CreateCB("PT_CBRaidMarks", "Show Raid Marks on Default Raid Frames", "raidMarks", cbGryphons, function(val) 
        if PT.UpdateRaidFrames then PT.UpdateRaidFrames() end 
    end)
    
    local cbRaidRess = CreateCB("PT_CBRaidRess", "Show Incoming Res on Raid Frames", "showRess", cbRaidMarks, function(val) 
        if PT.UpdateRaidFrames then PT.UpdateRaidFrames() end 
    end)
    
    local cbTransmog = CreateCB("PT_CBTransmog", "Auto-Collect Soulbound Transmogs in Bags", "autoTransmog", cbRaidRess)
end

-- ==========================================
-- EVENT HANDLER
-- ==========================================
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:RegisterEvent("PLAYER_LOGIN")

coreFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if type(PawieTweaksDB) ~= "table" then PawieTweaksDB = {} end
        for key, value in pairs(defaultSettings) do
            if PawieTweaksDB[key] == nil then PawieTweaksDB[key] = value end
        end
    elseif event == "PLAYER_LOGIN" then
        ApplyGryphons(PawieTweaksDB.hideGryphons)
        InitBackgroundQoL()
        InitBagUpgrade()
        InitAutoTransmog()
        InitAutoQuest()
        InitRaidFrameTweaks()
        InitUITweaks()
        InitMenuAndCommands()
    end
end)