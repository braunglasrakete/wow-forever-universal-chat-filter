-- Universal Chat Filter v2.0.0
-- World of Warcraft: Forever (interface 16001 / modern mainline UI)
-- Local-only message filtering. No messages are sent or stored by this addon.

local addonName = ...
local PREFIX = "|cff59d3ffUniversal Chat Filter|r: "
local db
local knownTerms = {}
local normalizedTerms = {}
local window
local refreshList
local updateToggle
local listOffset = 0
local visibleRows = 11
local clearPending = false

local function Print(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(text))
    end
end

local function Trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Basic Unicode support for German uppercase characters. The usual
-- ASCII case-insensitivity is handled by string.lower.
local function Normalize(text)
    return text:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"):gsub("ẞ", "ß"):lower()
end

local function RebuildIndex()
    knownTerms = {}
    normalizedTerms = {}
    for _, term in ipairs(db.words) do
        local normalized = Normalize(term)
        knownTerms[normalized] = true
        normalizedTerms[#normalizedTerms + 1] = normalized
    end
end

local function AddTerm(text)
    local term = Trim(text or "")
    if term == "" then
        return false, "empty"
    end
    if #term > 200 then
        return false, "too_long"
    end
    local key = Normalize(term)
    if knownTerms[key] then
        return false, "duplicate"
    end
    db.words[#db.words + 1] = term
    knownTerms[key] = true
    normalizedTerms[#normalizedTerms + 1] = key
    return true
end

local function RemoveTerm(index)
    if not db.words[index] then
        return
    end
    table.remove(db.words, index)
    RebuildIndex()
    if refreshList then refreshList() end
end

-- These events cover the usual public, custom, group, guild, private,
-- community, system, and loot chat messages. They do not cover the combat
-- log, chat bubbles, or text drawn by unrelated addon windows.
local CHAT_EVENTS = {
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_BN_CONVERSATION",
    "CHAT_MSG_AFK",
    "CHAT_MSG_DND",
    "CHAT_MSG_SYSTEM",
    "CHAT_MSG_LOOT",
    "CHAT_MSG_MONEY",
    "CHAT_MSG_CURRENCY",
    "CHAT_MSG_ACHIEVEMENT",
    "CHAT_MSG_GUILD_ACHIEVEMENT",
}

local function ChatFilter(_, _, message)
    if not db or not db.enabled or #normalizedTerms == 0 then
        return false
    end
    -- On modern WoW versions, some event arguments may be secret values.
    -- Accessing such a string can raise an error. Leave those lines alone.
    if type(issecretvalue) == "function" and issecretvalue(message) then
        return false
    end
    if type(message) ~= "string" or message == "" then
        return false
    end
    local normalized = Normalize(message)
    for i = 1, #normalizedTerms do
        if normalized:find(normalizedTerms[i], 1, true) then
            return true
        end
    end
    return false
end

-- UI helpers. All elements are created in plain Lua (no XML or libraries).
local function Text(parent, content, point, relative, relativePoint, x, y, font, r, g, b, width)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetPoint(point, relative, relativePoint, x, y)
    label:SetText(content)
    if r then label:SetTextColor(r, g, b) end
    if width then
        label:SetWidth(width)
        label:SetJustifyH("LEFT")
    end
    return label
end

local function Fill(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a or 1)
    return texture
end

local function Accent(parent, x, y, w, h, r, g, b, alpha)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    texture:SetSize(w, h)
    texture:SetColorTexture(r, g, b, alpha or 1)
    return texture
end

local function Panel(parent, x, y, w, h)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    panel:SetSize(w, h)
    Fill(panel, "BACKGROUND", 0.07, 0.085, 0.12, 0.97)
    Accent(panel, 0, 0, w, 1, 0.32, 0.46, 0.58, 0.9)
    Accent(panel, 0, h - 1, w, 1, 0.32, 0.46, 0.58, 0.9)
    Accent(panel, 0, 0, 1, h, 0.32, 0.46, 0.58, 0.9)
    Accent(panel, w - 1, 0, 1, h, 0.32, 0.46, 0.58, 0.9)
    return panel
end

local function Button(parent, label, x, y, w, h, handler)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    button:SetSize(w, h)
    button:SetText(label)
    button:SetScript("OnClick", handler)
    return button
end

local function Input(parent, x, y, w)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    input:SetSize(w, 27)
    input:SetAutoFocus(false)
    input:SetMaxLetters(200)
    input:SetTextInsets(6, 6, 2, 2)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return input
end

local function BuildWindow()
    if window then return window end

    local frame = CreateFrame("Frame", "UniversalChatFilterFrame", UIParent)
    frame:SetSize(800, 620)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnShow", function()
        clearPending = false
        if refreshList then refreshList() end
        if updateToggle then updateToggle() end
    end)
    frame:Hide()
    window = frame
    Fill(frame, "BACKGROUND", 0.035, 0.045, 0.07, 0.98)
    Accent(frame, 0, 0, 800, 3, 0.22, 0.77, 0.98)
    Accent(frame, 0, 77, 800, 1, 0.25, 0.39, 0.52)
    Accent(frame, 0, 618, 800, 2, 0.25, 0.39, 0.52)

    Text(frame, "UNIVERSAL CHAT FILTER", "TOPLEFT", frame, "TOPLEFT", 24, -20,
         "GameFontNormalLarge", 0.98, 0.83, 0.49)
    Text(frame, "Block unwanted words and phrases across your chat channels",
         "TOPLEFT", frame, "TOPLEFT", 25, -49, "GameFontHighlightSmall",
         0.68, 0.78, 0.86)

    local toggle = Button(frame, "FILTER: ON", 618, 24, 125, 29, function()
        db.enabled = not db.enabled
        updateToggle()
    end)
    updateToggle = function()
        toggle:SetText(db.enabled and "FILTER: ON" or "FILTER: OFF")
        local text = toggle:GetFontString()
        if text then
            if db.enabled then
                text:SetTextColor(0.45, 1, 0.60)
            else
                text:SetTextColor(1, 0.55, 0.50)
            end
        end
    end
    Button(frame, "X", 752, 24, 28, 29, function() frame:Hide() end)

    local left = Panel(frame, 20, 91, 461, 484)
    local right = Panel(frame, 495, 91, 284, 484)

    Text(left, "BLOCKED TERMS", "TOPLEFT", left, "TOPLEFT", 14, -17,
         "GameFontNormal", 0.97, 0.83, 0.51)
    local countText = Text(left, "0 terms", "TOPRIGHT", left, "TOPRIGHT", -15, -18,
                           "GameFontHighlightSmall", 0.71, 0.80, 0.87)
    Accent(left, 14, 47, 430, 1, 0.25, 0.36, 0.48, 0.85)

    local rows = {}
    for rowNumber = 1, visibleRows do
        local y = 55 + (rowNumber - 1) * 30
        local row = CreateFrame("Frame", nil, left)
        row:SetPoint("TOPLEFT", left, "TOPLEFT", 13, -y)
        row:SetSize(435, 28)
        if rowNumber % 2 == 1 then
            Fill(row, "BACKGROUND", 0.12, 0.15, 0.20, 0.9)
        end
        local number = Text(row, "", "LEFT", row, "LEFT", 9, 0,
                            "GameFontHighlightSmall", 0.51, 0.63, 0.70)
        number:SetWidth(31)
        local term = Text(row, "", "LEFT", row, "LEFT", 42, 0,
                          "GameFontHighlight", 0.94, 0.96, 1.0, 341)
        term:SetMaxLines(1)
        local remove = Button(row, "X", 403, 1, 27, 25, function()
            local index = row.termIndex
            if index then
                clearPending = false
                RemoveTerm(index)
            end
        end)
        rows[rowNumber] = {frame = row, number = number, term = term, remove = remove}
    end

    local paging = Text(left, "", "BOTTOMLEFT", left, "BOTTOMLEFT", 15, 18,
                        "GameFontHighlightSmall", 0.65, 0.77, 0.85)
    local prev = Button(left, "<", 232, 446, 37, 27, function()
        listOffset = math.max(0, listOffset - visibleRows)
        refreshList()
    end)
    local next = Button(left, ">", 274, 446, 37, 27, function()
        listOffset = math.min(math.max(0, #db.words - visibleRows), listOffset + visibleRows)
        refreshList()
    end)
    local clearButton
    clearButton = Button(left, "Clear All", 325, 446, 122, 27, function()
        if #db.words == 0 then return end
        if not clearPending then
            clearPending = true
            clearButton:SetText("Confirm Clear")
            paging:SetText("Click again to erase all terms")
        else
            db.words = {}
            RebuildIndex()
            listOffset = 0
            clearPending = false
            refreshList()
        end
    end)
    left:EnableMouseWheel(true)
    left:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = math.max(0, #db.words - visibleRows)
        listOffset = math.max(0, math.min(maxOffset, listOffset - delta * 3))
        refreshList()
    end)

    refreshList = function()
        if not db then return end
        local total = #db.words
        listOffset = math.min(math.max(0, total - visibleRows), math.max(0, listOffset))
        countText:SetText(total == 1 and "1 term" or (total .. " terms"))
        for i = 1, visibleRows do
            local row = rows[i]
            local index = i + listOffset
            local term = db.words[index]
            if term then
                row.frame.termIndex = index
                row.number:SetText(index .. ".")
                row.term:SetText(term)
                row.frame:Show()
            else
                row.frame.termIndex = nil
                row.frame:Hide()
            end
        end
        if not clearPending then
            clearButton:SetText("Clear All")
            paging:SetText(total == 0 and "No blocked terms yet" or
                           ("Showing " .. (listOffset + 1) .. "-" ..
                            math.min(total, listOffset + visibleRows) .. " of " .. total))
        end
        if total == 0 then
            clearPending = false
            clearButton:SetText("Clear All")
            paging:SetText("No blocked terms yet")
        end
        prev:SetEnabled(listOffset > 0)
        next:SetEnabled(listOffset + visibleRows < total)
        clearButton:SetEnabled(total > 0)
    end

    Text(right, "ADD A TERM", "TOPLEFT", right, "TOPLEFT", 14, -17,
         "GameFontNormal", 0.97, 0.83, 0.51)
    local oneTerm = Input(right, 17, 51, 250)
    local status = Text(right, "", "TOPLEFT", right, "TOPLEFT", 17, -427,
                        "GameFontHighlightSmall", 0.55, 0.88, 0.77, 250)
    status:SetJustifyH("LEFT")
    status:SetHeight(38)
    local function Status(message, good)
        status:SetText(message)
        if good then
            status:SetTextColor(0.48, 0.92, 0.65)
        else
            status:SetTextColor(1.0, 0.70, 0.47)
        end
    end

    local function AddFromInput()
        local text = Trim(oneTerm:GetText())
        local added, reason = AddTerm(text)
        if added then
            oneTerm:SetText("")
            listOffset = math.max(0, #db.words - visibleRows)
            clearPending = false
            refreshList()
            Status("Added: " .. text, true)
        elseif reason == "duplicate" then
            Status("This term is already in the list.", false)
        elseif reason == "too_long" then
            Status("A term can be at most 200 bytes.", false)
        else
            Status("Enter a word or phrase first.", false)
        end
        oneTerm:ClearFocus()
    end
    Button(right, "Add Term", 17, 88, 250, 29, AddFromInput)
    oneTerm:SetScript("OnEnterPressed", AddFromInput)

    Accent(right, 14, 139, 255, 1, 0.25, 0.36, 0.48, 0.85)
    Text(right, "BULK IMPORT / EXPORT", "TOPLEFT", right, "TOPLEFT", 14, -157,
         "GameFontNormal", 0.97, 0.83, 0.51)
    Text(right, "Paste comma-separated terms below.", "TOPLEFT", right, "TOPLEFT",
         16, -181, "GameFontHighlightSmall", 0.68, 0.78, 0.86)

    local entryPanel = Panel(right, 14, 210, 256, 132)
    -- A multiline EditBox inside a ScrollFrame makes long pasted lists usable.
    local scroll = CreateFrame("ScrollFrame", nil, entryPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", entryPanel, "TOPLEFT", 9, -8)
    scroll:SetPoint("BOTTOMRIGHT", entryPanel, "BOTTOMRIGHT", -28, 8)
    local bulkInput = CreateFrame("EditBox", nil, scroll)
    bulkInput:SetMultiLine(true)
    bulkInput:SetAutoFocus(false)
    bulkInput:SetFontObject(GameFontHighlightSmall)
    bulkInput:SetTextColor(0.96, 0.98, 1)
    bulkInput:SetSize(211, 112)
    bulkInput:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    bulkInput:SetMaxLetters(0)
    bulkInput:SetJustifyH("LEFT")
    bulkInput:SetJustifyV("TOP")
    bulkInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    bulkInput:SetScript("OnTextChanged", function(self)
        self:SetHeight(math.max(112, self:GetStringHeight() + 18))
        scroll:UpdateScrollChildRect()
    end)
    bulkInput:SetScript("OnCursorChanged", function(self, _, y, _, height)
        local offset = scroll:GetVerticalScroll()
        local top = -y
        if top < offset then
            scroll:SetVerticalScroll(top)
        elseif top + height > offset + scroll:GetHeight() then
            scroll:SetVerticalScroll(top + height - scroll:GetHeight())
        end
    end)
    scroll:SetScrollChild(bulkInput)

    Button(right, "Import Terms", 17, 352, 250, 29, function()
        local raw = bulkInput:GetText()
        if Trim(raw) == "" then
            Status("Paste comma-separated terms first.", false)
            return
        end
        local added, duplicates, invalid = 0, 0, 0
        -- Also accept line breaks to make pasting from a spreadsheet easy.
        local contents = raw:gsub("\r\n", "\n"):gsub("[\r\n]", ",")
        for term in (contents .. ","):gmatch("(.-),") do
            local ok, reason = AddTerm(term)
            if ok then
                added = added + 1
            elseif reason == "duplicate" then
                duplicates = duplicates + 1
            elseif reason == "too_long" then
                invalid = invalid + 1
            end
        end
        clearPending = false
        refreshList()
        Status("Imported " .. added .. " new; " .. duplicates .. " duplicates" ..
               (invalid > 0 and ("; " .. invalid .. " too long") or "") .. ".", true)
        bulkInput:SetText("")
        bulkInput:ClearFocus()
    end)

    Button(right, "Export List", 17, 390, 122, 29, function()
        bulkInput:SetText(table.concat(db.words, ", "))
        bulkInput:SetFocus()
        bulkInput:HighlightText()
        Status("Copy the selected text with Ctrl+C.", true)
    end)
    Button(right, "Clear Input", 145, 390, 122, 29, function()
        bulkInput:SetText("")
        bulkInput:ClearFocus()
        Status("Input cleared (saved list unchanged).", true)
    end)

    Text(frame, "Type /ucf to open  |  Use the mouse wheel to browse terms  |  Settings save automatically",
         "BOTTOMLEFT", frame, "BOTTOMLEFT", 23, 24, "GameFontHighlightSmall",
         0.65, 0.77, 0.84)
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "UniversalChatFilterFrame")
    end
    refreshList()
    updateToggle()
    return frame
end

local function ToggleWindow()
    if not db then
        Print("Settings are still loading. Try again after logging in.")
        return
    end
    local frame = BuildWindow()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

local function PrintHelp()
    Print("/ucf - open or close the filter window")
    Print("/ucf add WORD OR PHRASE - add a blocked term")
    Print("/ucf remove WORD OR PHRASE - remove a blocked term")
    Print("/ucf list - show blocked terms in chat")
    Print("/ucf on | off - enable or disable filtering")
    Print("/ucf clear - clear the list (no confirmation via command)")
    Print("/ucf help - show this help")
end

local function SlashHandler(input)
    input = Trim(input or "")
    if input == "" or input:lower() == "config" or input:lower() == "ui" then
        ToggleWindow()
        return
    end
    if not db then return end
    local command, argument = input:match("^(%S+)%s*(.-)%s*$")
    command = command and command:lower() or ""
    argument = Trim(argument or "")
    if command == "add" then
        local added, reason = AddTerm(argument)
        if added then
            Print("Added: " .. argument)
        elseif reason == "duplicate" then
            Print("Already blocked: " .. argument)
        elseif reason == "too_long" then
            Print("Terms cannot exceed 200 bytes.")
        else
            Print("Usage: /ucf add WORD OR PHRASE")
        end
    elseif command == "remove" or command == "del" then
        local key = Normalize(argument)
        for i = #db.words, 1, -1 do
            if Normalize(db.words[i]) == key then
                Print("Removed: " .. db.words[i])
                RemoveTerm(i)
                return
            end
        end
        Print("Term not found: " .. argument)
    elseif command == "list" then
        Print((db.enabled and "Enabled" or "Disabled") .. " | " .. #db.words .. " terms")
        for i, term in ipairs(db.words) do Print(i .. ". " .. term) end
    elseif command == "on" or command == "off" then
        db.enabled = (command == "on")
        if updateToggle then updateToggle() end
        Print(db.enabled and "Filtering enabled." or "Filtering disabled.")
    elseif command == "clear" then
        db.words = {}
        clearPending = false
        RebuildIndex()
        Print("All blocked terms removed.")
    else
        PrintHelp()
    end
    if refreshList then refreshList() end
end

SLASH_UNIVERSALCHATFILTER1 = "/ucf"
SLASH_UNIVERSALCHATFILTER2 = "/chatfilter"
SLASH_UNIVERSALCHATFILTER3 = "/cbf" -- Compatibility alias for previous version.
SlashCmdList["UNIVERSALCHATFILTER"] = SlashHandler

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then return end
    if type(UniversalChatFilterDB) ~= "table" then UniversalChatFilterDB = {} end
    db = UniversalChatFilterDB
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if type(db.words) ~= "table" then db.words = {} end

    -- Ignore invalid or duplicate saved entries.
    local cleaned, seen = {}, {}
    for _, term in ipairs(db.words) do
        if type(term) == "string" then
            term = Trim(term)
            local key = Normalize(term)
            if term ~= "" and #term <= 200 and not seen[key] then
                cleaned[#cleaned + 1] = term
                seen[key] = true
            end
        end
    end
    db.words = cleaned
    RebuildIndex()

    local register = ChatFrame_AddMessageEventFilter
    if type(register) ~= "function" and type(ChatFrameUtil) == "table" then
        register = ChatFrameUtil.AddMessageEventFilter
    end
    if type(register) == "function" then
        local registered = 0
        for _, event in ipairs(CHAT_EVENTS) do
            -- Guard against events missing from a particular client build.
            local ok = pcall(register, event, ChatFilter)
            if ok then registered = registered + 1 end
        end
        if registered > 0 then
            Print("Loaded. Type /ucf to open the settings.")
        else
            Print("Error: chat filtering was unavailable in this client build.")
        end
    else
        Print("Error: the chat filter API was not found.")
    end
    self:UnregisterEvent("ADDON_LOADED")
end)
