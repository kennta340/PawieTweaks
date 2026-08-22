-- ==========================================
-- PAWIE TWEAKS - v2.52
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

    -- SMART DEFAULT BG CHAT
    local bgChatForced = false
    local bgChatFrame = CreateFrame("Frame")
    bgChatFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    bgChatFrame:SetScript("OnEvent", function()
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "pvp" then
            bgChatForced = false
        else
            bgChatForced = true
        end
    end)

    if ChatEdit_ActivateChat then
        hooksecurefunc("ChatEdit_ActivateChat", function(editBox)
            if not bgChatForced then
                local inInstance, instanceType = IsInInstance()
                if inInstance and instanceType == "pvp" then
                    local cType = editBox:GetAttribute("chatType")
                    if cType == "SAY" or cType == "PARTY" or cType == "RAID" then
                        editBox:SetAttribute("chatType", "BATTLEGROUND")
                        ChatEdit_UpdateHeader(editBox)
                        bgChatForced = true
                    end
                end
            end
        end)
    end
end

-- ==========================================
-- MODULE: Ascension Auto-Transmog & Bag Icons
-- ==========================================
local function InitAutoTransmog()
    local tmogFrame = CreateFrame("Frame")
    local scanTimer = 0
    local scanQueued = false
    local iconUpdateTimer = 0
    local activeTmogButtons = {} -- Radar-listan för alla aktiva ikoner
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

        -- Radarn som stänger av ikoner sekunden du lär dig dom
        iconUpdateTimer = iconUpdateTimer + elapsed
        if iconUpdateTimer > 0.5 then
            iconUpdateTimer = 0
            for btn in pairs(activeTmogButtons) do
                if not btn:IsVisible() then
                    activeTmogButtons[btn] = nil
                else
                    local bag, slot
                    if type(btn.GetBag) == "function" then bag = btn:GetBag()
                    elseif type(btn.bag) == "number" then bag = btn.bag
                    elseif btn.GetParent and btn:GetParent() and btn:GetParent().GetID then bag = btn:GetParent():GetID() end
                    if btn.GetID then slot = btn:GetID() end

                    if type(bag) == "number" and type(slot) == "number" then
                        local itemID = GetContainerItemID(bag, slot)
                        if itemID then
                            local appID = C_Appearance and C_Appearance.GetItemAppearanceID(itemID)
                            -- Om du HAR lärt dig föremålet nu, släck ikonen!
                            if appID and C_AppearanceCollection and C_AppearanceCollection.IsAppearanceCollected(appID) then
                                if btn.ptTmogIcon then btn.ptTmogIcon:Hide() end
                                activeTmogButtons[btn] = nil
                            end
                        else
                            if btn.ptTmogIcon then btn.ptTmogIcon:Hide() end
                            activeTmogButtons[btn] = nil
                        end
                    else
                        activeTmogButtons[btn] = nil
                    end
                end
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
                    activeTmogButtons[itemButton] = nil
                    
                    if PawieTweaksDB.autoTransmog then
                        local slot = itemButton:GetID()
                        local itemID = GetContainerItemID(bag, slot)
                        if itemID and C_AppearanceCollection and C_Appearance then
                            local appID = C_Appearance.GetItemAppearanceID(itemID)
                            if appID and not C_AppearanceCollection.IsAppearanceCollected(appID) then
                                itemButton.ptTmogIcon:Show()
                                activeTmogButtons[itemButton] = true -- Sätt knappen på radarn
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
                activeTmogButtons[button] = nil
                
                if PawieTweaksDB.autoTransmog then
                    local itemID = GetContainerItemID(bag, slot)
                    if itemID and C_AppearanceCollection and C_Appearance then
                        local appID = C_Appearance.GetItemAppearanceID(itemID)
                        if appID and not C_AppearanceCollection.IsAppearanceCollected(appID) then
                            button.ptTmogIcon:Show()
                            activeTmogButtons[button] = true -- Sätt knappen på radarn
                        end
                    end
                end
            end
        end)
    end
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
    
    local cbTransmog = CreateCB("PT_CBTransmog", "Auto-Collect Soulbound Transmogs in Bags", "autoTransmog", cbGryphons)
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
        InitUITweaks()
        InitMenuAndCommands()
    end
end)