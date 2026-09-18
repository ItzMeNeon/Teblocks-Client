local scene = {}

local SKIN_REPO = require 'parts.skin_repo'

--[[
    ============================================================
    TEBLOCKS SKIN DIRECT - osu!-Style Community Skin Hub
    ============================================================
    Features:
      • Beatmap-listing / osu! Direct style browsable cards
      • Online Community Repository (Curated + Server Sync)
      • 1-Click Download, Direct Equip, and Hot-Reload
      • Drag & Drop PNG Auto-Import (240×90 specification)
      • User Skin Publisher / Community Uploader to backend
      • High-Fidelity 7-Tetromino Animated Preview + 24-Palette Grid
      • Native OS skins folder integration
]]

-- View mode / navigation tabs
local currentTab = 'online' -- 'online', 'installed', 'publish'
local tabs = {
    { id = 'online',    label = "🌐 Online Repository" },
    { id = 'installed', label = "📦 Installed Skins"   },
    { id = 'publish',   label = "📤 Publish Skin"      },
}

-- List states
local onlineList = {}
local installedList = {}
local onlineSelect = 1
local installedSelect = 1
local scrollOffset = 0
local maxScroll = 0

-- Filter chips for Online Library
local filterChips = {
    { id = 'all',       label = "All",       w = 48 },
    { id = 'popular',   label = "Popular",   w = 70 },
    { id = 'latest',    label = "Latest",    w = 62 },
    { id = 'top_rated', label = "Top Rated", w = 78 },
    { id = 'official',  label = "Official",  w = 68 },
}
local currentFilter = 'all'

-- Helper to truncate and fit text within a given pixel width
local function fitText(str, maxW)
    if not str then return "" end
    local font = GC.getFont()
    if not font or font:getWidth(str) <= maxW then return str end
    local s = str
    while #s > 1 and font:getWidth(s .. "…") > maxW do
        s = s:sub(1, -2)
    end
    return s .. "…"
end

-- Download animation states (map of id -> download status)
local downloadState = {}

-- Publish form states
local publishCustomIndex = 1
local customSkinsList = {}

-- 24 Mino Quads for 240×90 texture sheet preview
local minoQuads = {}
for i = 1, 24 do
    local col = (i - 1) % 8
    local row = math.floor((i - 1) / 8)
    minoQuads[i] = love.graphics.newQuad(col * 30, row * 30, 30, 30, 240, 90)
end

-- ════════════════════════════════════════════════════════════
--  WIDGETS (Search & Publish Form)
-- ════════════════════════════════════════════════════════════
local searchBox = WIDGET.newInputBox{
    name  = 'searchBox',
    x     = 40,
    y     = 82,
    w     = 260,
    h     = 38,
    font  = 16,
    limit = 48,
}

local pubTitleBox = WIDGET.newInputBox{
    name  = 'pubTitle',
    x     = 70,
    y     = 270,
    w     = 480,
    h     = 42,
    font  = 18,
    limit = 40,
}

local pubAuthorBox = WIDGET.newInputBox{
    name  = 'pubAuthor',
    x     = 70,
    y     = 350,
    w     = 480,
    h     = 42,
    font  = 18,
    limit = 32,
}

local pubTagsBox = WIDGET.newInputBox{
    name  = 'pubTags',
    x     = 70,
    y     = 430,
    w     = 480,
    h     = 42,
    font  = 18,
    limit = 64,
}

local pubDescBox = WIDGET.newInputBox{
    name  = 'pubDesc',
    x     = 70,
    y     = 510,
    w     = 480,
    h     = 60,
    font  = 16,
    limit = 120,
}

scene.widgetList = { searchBox, pubTitleBox, pubAuthorBox, pubTagsBox, pubDescBox }

-- ════════════════════════════════════════════════════════════
--  TAB & WIDGET VISIBILITY MANAGEMENT
-- ════════════════════════════════════════════════════════════
local function updateWidgetVisibility()
    searchBox.hide    = (currentTab ~= 'online')
    pubTitleBox.hide  = (currentTab ~= 'publish')
    pubAuthorBox.hide = (currentTab ~= 'publish')
    pubTagsBox.hide   = (currentTab ~= 'publish')
    pubDescBox.hide   = (currentTab ~= 'publish')
end

local function refreshLists()
    SKIN_REPO.filter = currentFilter
    SKIN_REPO.searchQuery = searchBox:getText()
    onlineList = SKIN_REPO.getFilteredList()
    installedList = SKIN.getList()

    -- Filter user-only skins for publishing form
    customSkinsList = {}
    for _, name in ipairs(installedList) do
        if name:sub(1, 7) == '[User] ' then
            table.insert(customSkinsList, name:sub(8))
        end
    end

    if currentTab == 'online' then
        maxScroll = math.max(0, #onlineList * 96 - 480)
        onlineSelect = math.min(onlineSelect, math.max(1, #onlineList))
    elseif currentTab == 'installed' then
        maxScroll = math.max(0, #installedList * 88 - 380)
        installedSelect = math.min(installedSelect, math.max(1, #installedList))
    else
        maxScroll = 0
    end
end

local function setTab(tab)
    if tab == 'publish' then
        if not (USER and USER.uid and USER.uid ~= false) then
            MES.new('warn', "Please log in to publish skins to the community repository")
            local AUTH = require 'parts.authModal'
            AUTH.open('login')
            return
        end
    end

    currentTab = tab
    scrollOffset = 0
    updateWidgetVisibility()
    refreshLists()

    if tab == 'publish' then
        -- Prefill fields
        local currentCustom = customSkinsList[publishCustomIndex] or "MySkin"
        if pubTitleBox:getText() == "" then pubTitleBox:setText(currentCustom) end
        if pubAuthorBox:getText() == "" then
            local pName = (USERS and USER and USERS.getUsername(USER.uid)) or "Player"
            pubAuthorBox:setText(pName)
        end
        if pubTagsBox:getText() == "" then pubTagsBox:setText("clean, minimal, teblocks") end
        if pubDescBox:getText() == "" then pubDescBox:setText("Custom mino skin created for Teblocks.") end
    end
end

-- ════════════════════════════════════════════════════════════
--  SCENE LIFECYCLE
-- ════════════════════════════════════════════════════════════
function scene.enter()
    BG.set()
    SKIN_REPO.init()
    setTab('online')

    -- Pre-select currently equipped skin in installed list
    for i, name in ipairs(installedList) do
        if name == SETTING.skinSet then
            installedSelect = i
            break
        end
    end

    DiscordRPC.update("Browsing Teblocks Skin Direct")
end

local lastSearchValue = ""
local lastRepoVersion = -1

function scene.update(dt)
    if currentTab == 'online' then
        local curSearch = searchBox:getText()
        if curSearch ~= lastSearchValue or (SKIN_REPO.version and SKIN_REPO.version ~= lastRepoVersion) then
            lastSearchValue = curSearch
            lastRepoVersion = SKIN_REPO.version
            refreshLists()
        end
    end
end

function scene.leave()
    saveSettings()
end

function scene.wheelMoved(x, y)
    scrollOffset = math.max(0, math.min(maxScroll, scrollOffset - y * 70))
end

-- ════════════════════════════════════════════════════════════
--  DRAG & DROP PNG HANDLER
-- ════════════════════════════════════════════════════════════
function scene.fileDropped(file)
    local filename = file:getFilename()
    local name = filename:match("([^/\\]+)%.png$") or filename:match("([^/\\]+)%.PNG$")
    if not name then
        MES.new('warn', "Only .png image files are supported")
        return
    end

    name = name:gsub("[^%w_%- ]", "")
    if #name == 0 then name = "CustomSkin" end

    local success, img = pcall(love.graphics.newImage, file)
    if not success or not img then
        MES.new('error', "Failed to load image from dropped file")
        return
    end

    local w, h = img:getDimensions()
    if w ~= 240 or h ~= 90 then
        MES.new('warn', ("Note: standard skin sheet is 240x90 px (got %dx%d)"):format(w, h))
    end

    file:open('r')
    local data = file:read()
    file:close()

    if not data or #data == 0 then
        MES.new('error', "Could not read file data")
        return
    end

    love.filesystem.createDirectory('skins')
    local saveSuccess, err = love.filesystem.write('skins/' .. name .. '.png', data)
    if not saveSuccess then
        MES.new('error', "Failed to save skin: " .. tostring(err))
        return
    end

    local fh = io.open('skins/' .. name .. '.png', 'wb')
    if fh then fh:write(data) fh:close() end

    SKIN.reloadUser('skins')
    refreshLists()

    -- Automatically select and equip
    local targetName = '[User] ' .. name
    for i, sn in ipairs(installedList) do
        if sn == targetName or sn == name then
            installedSelect = i
            SETTING.skinSet = sn
            saveSettings()
            break
        end
    end

    setTab('installed')
    SFX.play('reach')
    MES.new('check', "Skin imported & equipped: " .. name)
end

-- ════════════════════════════════════════════════════════════
--  MINO & TETROMINO DRAWING HELPERS
-- ════════════════════════════════════════════════════════════
local function drawMinoTile(item, skinName, blockIdx, x, y, scale)
    scale = scale or 1
    -- 1. If installed/loaded in SKIN
    if skinName and (SKIN.isLoaded(skinName) or SKIN.exists(skinName)) then
        local lib = SKIN.lib[skinName]
        if lib and lib[blockIdx] then
            GC.setColor(1, 1, 1, 1)
            GC.draw(lib[blockIdx], x, y, 0, scale)
            return
        end
    end

    -- 2. If available from SKIN_REPO preview image
    if item then
        local img = SKIN_REPO.getPreviewImage(item)
        if img and minoQuads[blockIdx] then
            GC.setColor(1, 1, 1, 1)
            GC.draw(img, minoQuads[blockIdx], x, y, 0, scale, scale)
            return
        end
    end

    -- 3. Colorful fallback placeholder block
    local paletteColors = {
        {0.95, 0.25, 0.35}, -- 1 Z
        {0.30, 0.85, 0.40}, -- 2 S
        {0.25, 0.45, 0.95}, -- 3 J
        {0.95, 0.60, 0.20}, -- 4 L
        {0.70, 0.30, 0.95}, -- 5 T
        {0.95, 0.85, 0.25}, -- 6 O
        {0.25, 0.85, 0.95}, -- 7 I
    }
    local col = paletteColors[((blockIdx - 1) % 7) + 1] or {0.4, 0.5, 0.7}
    GC.setColor(col[1], col[2], col[3], 0.75)
    GC.rectangle('fill', x, y, 30 * scale, 30 * scale, math.max(1, math.floor(3 * scale)))
    GC.setColor(1, 1, 1, 0.5)
    GC.rectangle('line', x, y, 30 * scale, 30 * scale, math.max(1, math.floor(3 * scale)))
end

local function drawTetrominoRow(item, skinName, startX, startY, scale, animTime)
    scale = scale or 1
    local pieceLabels = { 'Z', 'S', 'J', 'L', 'T', 'O', 'I' }
    -- Standard Teblocks piece colors mapping (1:1 with top row slots 1..7)
    local pieceColors = { 1, 2, 3, 4, 5, 6, 7 }

    for n = 1, 7 do
        local bx = startX + ((n - 1) % 4) * 110 * scale
        local by = startY + math.floor((n - 1) / 4) * 95 * scale
        local bob = math.sin(animTime * 3 + n * 0.8) * 3

        -- Piece letter
        GC.setColor(.6, .75, 1, .6)
        setFont(12 * scale)
        GC.print(pieceLabels[n], bx, by + bob)

        -- Piece matrix
        local B = BLOCKS[n][0]
        local colIdx = pieceColors[n]
        for r = 1, #B do
            for c = 1, #B[1] do
                if B[r][c] then
                    drawMinoTile(item, skinName, colIdx, bx + c * 24 * scale - 12 * scale, by + bob + r * 24 * scale, scale * 0.8)
                end
            end
        end
    end
end

-- ════════════════════════════════════════════════════════════
--  MOUSE CLICKS & TOUCH
-- ════════════════════════════════════════════════════════════
function scene.mouseDown(x, y)
    -- ── 1. Top Tabs Navigation (y=20..62) ───────────────────
    if y >= 20 and y <= 62 then
        local tabX = 420
        for _, tab in ipairs(tabs) do
            local tabW = 160
            if x >= tabX and x <= tabX + tabW then
                if currentTab ~= tab.id then
                    SFX.play('click')
                    setTab(tab.id)
                end
                return
            end
            tabX = tabX + tabW + 10
        end

        -- Top Right: "📁 Open Folder" (x=950..1060)
        if x >= 950 and x <= 1060 then
            love.filesystem.createDirectory('skins')
            local saveDir = love.filesystem.getSaveDirectory() .. '/skins'
            love.system.openURL("file://" .. saveDir)
            SFX.play('click')
            MES.new('info', "Opened skins directory")
            return
        end

        -- Top Right: "🔄 Refresh" (x=1070..1160)
        if x >= 1070 and x <= 1160 then
            SKIN.reloadUser('skins')
            SFX.play('rotate')
            MES.new('info', "Looking for skins on server...")
            SKIN_REPO.refresh(function(connected, count)
                refreshLists()
                if connected then
                    MES.new('check', ("Found %d skins on server"):format(count or 0))
                else
                    MES.new('warn', "Could not reach gameserver")
                end
            end)
            refreshLists()
            return
        end

        -- Top Right: "✕ Back" (x=1170..1240)
        if x >= 1170 and x <= 1240 then
            SCN.back()
            return
        end
    end

    -- ── 2. Online Library Tab Interactions ───────────────────
    if currentTab == 'online' then
        -- Filter chips (y=82..122)
        if y >= 82 and y <= 122 and x >= 315 and x <= 670 then
            local chipX = 315
            for _, chip in ipairs(filterChips) do
                local chipW = chip.w or 60
                if x >= chipX and x <= chipX + chipW then
                    if currentFilter ~= chip.id then
                        currentFilter = chip.id
                        SFX.play('click')
                        refreshLists()
                    end
                    return
                end
                chipX = chipX + chipW + 6
            end
        end

        -- If online list is empty, check clicks on empty state buttons
        if #onlineList == 0 and not SKIN_REPO.loading then
            local listX, listY, listW = 40, 135, 710
            if not SKIN_REPO.connected then
                local btnW, btnH = 200, 42
                local btnX = listX + (listW - btnW) * 0.5 - 110
                local btnY = listY + 145
                if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                    SFX.play('click')
                    MES.new('info', "Connecting to gameserver...")
                    SKIN_REPO.refresh(function(connected, count)
                        refreshLists()
                        if connected then
                            MES.new('check', ("Connected! %d skins available"):format(count or 0))
                        else
                            MES.new('warn', "Connection failed")
                        end
                    end)
                    refreshLists()
                    return
                end
                local btn2X = listX + (listW - btnW) * 0.5 + 110
                if x >= btn2X and x <= btn2X + btnW and y >= btnY and y <= btnY + btnH then
                    setTab('installed')
                    SFX.play('click')
                    return
                end
            else
                local bW, bH = 190, 42
                local startBX = listX + (listW - (bW * 3 + 24)) * 0.5
                local bY = listY + 180
                local b1X = startBX
                local b2X = b1X + bW + 12
                local b3X = b2X + bW + 12
                if y >= bY and y <= bY + bH then
                    if x >= b1X and x <= b1X + bW then
                        setTab('installed')
                        SFX.play('click')
                        return
                    elseif x >= b2X and x <= b2X + bW then
                        setTab('publish')
                        SFX.play('click')
                        return
                    elseif x >= b3X and x <= b3X + bW then
                        love.filesystem.createDirectory('skins')
                        local saveDir = love.filesystem.getSaveDirectory() .. '/skins'
                        love.system.openURL("file://" .. saveDir)
                        SFX.play('click')
                        MES.new('info', "Opened skins folder")
                        return
                    end
                end
            end
        end

        -- Online Cards List (x=40..740, y=135..670)
        if x >= 40 and x <= 740 and y >= 135 and y <= 670 then
            local clickedIndex = math.floor((y - 135 + scrollOffset) / 96) + 1
            if clickedIndex >= 1 and clickedIndex <= #onlineList then
                onlineSelect = clickedIndex
                local item = onlineList[onlineSelect]
                local cardY = 135 + (clickedIndex - 1) * 96 - scrollOffset

                -- Check Action Button on the card (x=610..725, y=cardY+24..cardY+68)
                if x >= 610 and x <= 725 and y >= cardY + 24 and y <= cardY + 68 then
                    local isInst = SKIN_REPO.isInstalled(item)
                    local isEq = (SETTING.skinSet == item.installedName) or (item.isOfficial and SETTING.skinSet == 'Neon Cyber (Teblocks)')

                    if isInst and not isEq then
                        -- Already downloaded & installed -> Equip it!
                        SETTING.skinSet = item.installedName or ('[User] ' .. item.title)
                        saveSettings()
                        SFX.play('reach')
                        MES.new('check', "Equipped: " .. item.title)
                        return
                    elseif not isInst then
                        -- Must download skin first! Do NOT equip yet.
                        downloadState[item.id] = true
                        SFX.play('click')
                        MES.new('info', "Downloading " .. item.title .. "...")
                        SKIN_REPO.download(item, function(success, msg)
                            downloadState[item.id] = false
                            if success then
                                SFX.play('reach')
                                MES.new('check', "Downloaded " .. item.title .. "! Click Equip to use it.")
                                refreshLists()
                            else
                                MES.new('error', msg or "Download failed")
                            end
                        end)
                        return
                    end
                end

                SFX.play('click')
                return
            end
        end

        -- Right Panel Action Buttons (x=770..1240, y=620..675)
        local curItem = onlineList[onlineSelect]
        if curItem and y >= 620 and y <= 675 then
            -- Primary Button: Download / Equip (x=780..1000)
            if x >= 780 and x <= 1000 then
                local isInst = SKIN_REPO.isInstalled(curItem)
                local isEq = (SETTING.skinSet == curItem.installedName) or (curItem.isOfficial and SETTING.skinSet == 'Neon Cyber (Teblocks)')

                if isInst and not isEq then
                    -- Already downloaded -> Equip it!
                    SETTING.skinSet = curItem.installedName or ('[User] ' .. curItem.title)
                    saveSettings()
                    SFX.play('reach')
                    MES.new('check', "Equipped: " .. curItem.title)
                elseif not isInst then
                    -- Download first!
                    downloadState[curItem.id] = true
                    SFX.play('click')
                    MES.new('info', "Downloading " .. curItem.title .. "...")
                    SKIN_REPO.download(curItem, function(success, msg)
                        downloadState[curItem.id] = false
                        if success then
                            SFX.play('reach')
                            MES.new('check', "Downloaded " .. curItem.title .. "! Click Equip to use it.")
                            refreshLists()
                        else
                            MES.new('error', msg or "Download failed")
                        end
                    end)
                end
                return
            end

            -- Secondary Button: Color Settings (x=1015..1230)
            if x >= 1015 and x <= 1230 then
                SCN.go('setting_skin')
                return
            end
        elseif not curItem and y >= 620 and y <= 675 then
            local prevX = 770
            if x >= prevX + 15 and x <= prevX + 240 then
                setTab('installed')
                SFX.play('click')
                return
            elseif x >= prevX + 250 and x <= prevX + 455 then
                SCN.go('setting_skin')
                return
            end
        end
    end

    -- ── 3. Installed Skins Tab Interactions ──────────────────
    if currentTab == 'installed' then
        -- Cards List (x=40..740, y=100..545)
        if x >= 40 and x <= 740 and y >= 100 and y <= 545 then
            local clickedIndex = math.floor((y - 100 + scrollOffset) / 88) + 1
            if clickedIndex >= 1 and clickedIndex <= #installedList then
                installedSelect = clickedIndex
                local selName = installedList[installedSelect]
                local cardY = 100 + (clickedIndex - 1) * 88 - scrollOffset

                -- Action button: Equip (x=530..620, y=cardY+22..cardY+66)
                if x >= 530 and x <= 620 and y >= cardY + 22 and y <= cardY + 66 then
                    if SETTING.skinSet ~= selName then
                        SETTING.skinSet = selName
                        saveSettings()
                        SFX.play('reach')
                        MES.new('check', "Equipped: " .. selName)
                    end
                    return
                end

                -- Action button: Publish (if user skin, x=625..720, y=cardY+22..cardY+66)
                local isUser = selName:sub(1, 7) == '[User] '
                if isUser and x >= 625 and x <= 720 and y >= cardY + 22 and y <= cardY + 66 then
                    local rawName = selName:sub(8)
                    for idx, cName in ipairs(customSkinsList) do
                        if cName == rawName then
                            publishCustomIndex = idx
                            break
                        end
                    end
                    pubTitleBox:setText(rawName)
                    setTab('publish')
                    SFX.play('click')
                    return
                end

                SFX.play('click')
                return
            end
        end

        -- Bottom Drag & Drop dropzone click (x=40..740, y=560..675)
        if x >= 40 and x <= 740 and y >= 560 and y <= 675 then
            love.filesystem.createDirectory('skins')
            local saveDir = love.filesystem.getSaveDirectory() .. '/skins'
            love.system.openURL("file://" .. saveDir)
            SFX.play('click')
            MES.new('info', "Opened skins folder. Drop any 240x90 PNG to install.")
            return
        end

        -- Right Panel Action Buttons (x=770..1240, y=620..675)
        local selName = installedList[installedSelect]
        local isUser = selName and selName:sub(1, 7) == '[User] '
        local isEq  = (selName == SETTING.skinSet)
        if y >= 620 and y <= 675 then
            -- Primary Button (x=780..1000): Equip skin if not active
            if x >= 780 and x <= 1000 then
                if not isEq and selName then
                    SETTING.skinSet = selName
                    saveSettings()
                    SFX.play('reach')
                    MES.new('check', "Equipped: " .. selName)
                end
                return
            end

            -- Secondary Button (x=1010..1230): Delete if custom, or Color Settings if built-in
            if x >= 1010 and x <= 1230 then
                if isUser then
                    local rawName = selName:sub(8)
                    love.filesystem.remove('skins/' .. rawName .. '.png')
                    pcall(os.remove, 'skins/' .. rawName .. '.png')
                    SKIN.reloadUser('skins')
                    refreshLists()
                    if SETTING.skinSet == selName then
                        SETTING.skinSet = installedList[1] or 'Neon Cyber (Teblocks)'
                        saveSettings()
                    end
                    SFX.play('click')
                    MES.new('info', "Deleted skin: " .. rawName)
                else
                    SCN.go('setting_skin')
                end
                return
            end
        end
    end

    -- ── 4. Publish Skin Tab Interactions ─────────────────────
    if currentTab == 'publish' then
        -- Select custom skin buttons (y=160..210)
        if y >= 160 and y <= 210 then
            -- Left arrow (x=70..110)
            if x >= 70 and x <= 110 and publishCustomIndex > 1 then
                publishCustomIndex = publishCustomIndex - 1
                pubTitleBox:setText(customSkinsList[publishCustomIndex] or "")
                SFX.play('click')
                return
            end
            -- Right arrow (x=510..550)
            if x >= 510 and x <= 550 and publishCustomIndex < #customSkinsList then
                publishCustomIndex = publishCustomIndex + 1
                pubTitleBox:setText(customSkinsList[publishCustomIndex] or "")
                SFX.play('click')
                return
            end
        end

        -- Publish button (x=70..550, y=600..665)
        if x >= 70 and x <= 550 and y >= 600 and y <= 665 then
            local curSkinName = customSkinsList[publishCustomIndex]
            if not curSkinName then
                MES.new('warn', "No local custom skin selected to publish")
                return
            end

            local title = pubTitleBox:getText():gsub("^%s*(.-)%s*$", "%1")
            if #title == 0 then title = curSkinName end

            local meta = {
                title       = title,
                author      = pubAuthorBox:getText(),
                tags        = pubTagsBox:getText(),
                description = pubDescBox:getText(),
            }

            SFX.play('click')
            SKIN_REPO.upload(curSkinName, meta, function(success, msg)
                if success then
                    SFX.play('reach')
                    MES.new('check', msg or "Skin published to community repository!")
                    setTab('online')
                else
                    MES.new('error', msg or "Publish failed")
                end
            end)
            return
        end
    end
end
scene.touchDown = scene.mouseDown

-- ════════════════════════════════════════════════════════════
--  KEYBOARD NAVIGATION
-- ════════════════════════════════════════════════════════════
function scene.keyDown(key)
    if key == 'escape' then
        SCN.back()
        return
    end

    if currentTab == 'online' and not WIDGET.isFocus(searchBox) then
        if key == 'up' and onlineSelect > 1 then
            onlineSelect = onlineSelect - 1
            scrollOffset = math.max(0, math.min(maxScroll, (onlineSelect - 1) * 96 - 180))
            SFX.play('click')
        elseif key == 'down' and onlineSelect < #onlineList then
            onlineSelect = onlineSelect + 1
            scrollOffset = math.max(0, math.min(maxScroll, (onlineSelect - 1) * 96 - 180))
            SFX.play('click')
        end
    elseif currentTab == 'installed' then
        if key == 'up' and installedSelect > 1 then
            installedSelect = installedSelect - 1
            scrollOffset = math.max(0, math.min(maxScroll, (installedSelect - 1) * 88 - 180))
            SFX.play('click')
        elseif key == 'down' and installedSelect < #installedList then
            installedSelect = installedSelect + 1
            scrollOffset = math.max(0, math.min(maxScroll, (installedSelect - 1) * 88 - 180))
            SFX.play('click')
        end
    end
end

-- ════════════════════════════════════════════════════════════
--  SCENE DRAW
-- ════════════════════════════════════════════════════════════
function scene.draw()
    local t = TIME()
    local mx, my = SCR.xOy:inverseTransformPoint(love.mouse.getPosition())

    -- ── 1. Top Header Bar ────────────────────────────────────
    GC.setColor(.04, .06, .14, .95)
    GC.rectangle('fill', 0, 0, 1280, 72)
    -- Sleek neon accent stripe (osu! / Teblocks themed)
    GC.setColor(.25, .65, 1, .9)
    GC.rectangle('fill', 0, 70, 640, 2)
    GC.setColor(.85, .35, .95, .9)
    GC.rectangle('fill', 640, 70, 640, 2)

    -- Header Title
    GC.setColor(1, 1, 1, .98)
    setFont(24)
    GC.print("TEBLOCKS SKIN DIRECT", 40, 14)

    GC.setColor(.55, .72, .95, .8)
    setFont(11)
    GC.print("Community & Server Skins Repository", 40, 44)

    -- ── Top Navigation Tabs ──────────────────────────────────
    local tabX = 420
    for _, tab in ipairs(tabs) do
        local tabW = 160
        local isActive = (currentTab == tab.id)
        local isHov = (mx >= tabX and mx <= tabX + tabW and my >= 20 and my <= 62)

        if isActive then
            GC.setColor(.22, .45, .88, .9)
            GC.rectangle('fill', tabX, 20, tabW, 42, 6)
            GC.setColor(.5, .8, 1, 1)
            GC.setLineWidth(1.5)
            GC.rectangle('line', tabX, 20, tabW, 42, 6)
            GC.setColor(1, 1, 1, 1)
        elseif isHov then
            GC.setColor(.14, .22, .45, .8)
            GC.rectangle('fill', tabX, 20, tabW, 42, 6)
            GC.setColor(.35, .55, .95, .7)
            GC.setLineWidth(1)
            GC.rectangle('line', tabX, 20, tabW, 42, 6)
            GC.setColor(.85, .92, 1, .95)
        else
            GC.setColor(.08, .12, .25, .6)
            GC.rectangle('fill', tabX, 20, tabW, 42, 6)
            GC.setColor(.2, .3, .55, .4)
            GC.setLineWidth(1)
            GC.rectangle('line', tabX, 20, tabW, 42, 6)
            GC.setColor(.7, .8, .95, .75)
        end

        setFont(13)
        GC.mStr(tab.label, tabX + tabW * 0.5, 33)
        tabX = tabX + tabW + 10
    end

    -- Top Right Utility Buttons
    -- 📁 Open Folder
    local isHovFold = (mx >= 950 and mx <= 1060 and my >= 20 and my <= 62)
    GC.setColor(isHovFold and .20 or .10, isHovFold and .30 or .15, isHovFold and .60 or .32, .8)
    GC.rectangle('fill', 950, 20, 110, 42, 6)
    GC.setColor(.35, .55, .95, .7)
    GC.setLineWidth(1)
    GC.rectangle('line', 950, 20, 110, 42, 6)
    GC.setColor(.9, .95, 1, 1)
    setFont(12)
    GC.mStr("📁 Folder", 1005, 34)

    -- 🔄 Refresh
    local isHovRef = (mx >= 1070 and mx <= 1160 and my >= 20 and my <= 62)
    GC.setColor(isHovRef and .20 or .10, isHovRef and .30 or .15, isHovRef and .60 or .32, .8)
    GC.rectangle('fill', 1070, 20, 90, 42, 6)
    GC.setColor(.35, .55, .95, .7)
    GC.setLineWidth(1)
    GC.rectangle('line', 1070, 20, 90, 42, 6)
    GC.setColor(.9, .95, 1, 1)
    setFont(12)
    GC.mStr("🔄 Refresh", 1115, 34)

    -- ✕ Back
    local isHovBack = (mx >= 1170 and mx <= 1240 and my >= 20 and my <= 62)
    GC.setColor(isHovBack and .45 or .18, isHovBack and .18 or .10, isHovBack and .25 or .15, .85)
    GC.rectangle('fill', 1170, 20, 70, 42, 6)
    GC.setColor(.85, .35, .45, .8)
    GC.setLineWidth(1)
    GC.rectangle('line', 1170, 20, 70, 42, 6)
    GC.setColor(1, 1, 1, 1)
    setFont(13)
    GC.mStr("Back", 1205, 33)

    -- ════════════════════════════════════════════════════════════
    --  TAB 1: ONLINE LIBRARY (osu! Direct style beatmap listing)
    -- ════════════════════════════════════════════════════════════
    if currentTab == 'online' then
        -- Search input hint if empty
        if searchBox:getText() == "" and not WIDGET.isFocus(searchBox) then
            GC.setColor(.45, .55, .75, .6)
            setFont(14)
            GC.print("🔍 Type to search skins, authors, tags...", 55, 93)
        end

        -- Filter Chips (x=315..665)
        local chipX = 315
        for _, chip in ipairs(filterChips) do
            local chipW = chip.w or 60
            local isSel = (currentFilter == chip.id)
            local isHov = (mx >= chipX and mx <= chipX + chipW and my >= 82 and my <= 120)

            if isSel then
                GC.setColor(.25, .55, .95, .9)
                GC.rectangle('fill', chipX, 82, chipW, 38, 5)
                GC.setColor(1, 1, 1, 1)
            elseif isHov then
                GC.setColor(.15, .25, .45, .8)
                GC.rectangle('fill', chipX, 82, chipW, 38, 5)
                GC.setColor(.85, .92, 1, 1)
            else
                GC.setColor(.08, .12, .24, .6)
                GC.rectangle('fill', chipX, 82, chipW, 38, 5)
                GC.setColor(.65, .75, .90, .75)
            end
            GC.setLineWidth(1)
            GC.rectangle('line', chipX, 82, chipW, 38, 5)
            setFont(12)
            GC.mStr(chip.label, chipX + chipW * 0.5, 94)
            chipX = chipX + chipW + 6
        end

        -- ── Cards Scrollable List (x=40..740, y=135..680) ────
        local listX, listY, listW, listH = 40, 135, 710, 545
        GC.stencil(function()
            GC.rectangle('fill', listX, listY, listW, listH)
        end, 'replace', 1)
        GC.setStencilTest('equal', 1)

        if #onlineList == 0 then
            if SKIN_REPO.loading then
                GC.setColor(.55, .80, 1, .95)
                setFont(18)
                local dots = string.rep(".", math.floor(t * 3) % 4)
                GC.mStr("Connecting to gameserver" .. dots, listX + listW * 0.5, listY + 110)
                GC.setColor(.45, .60, .85, .75)
                setFont(13)
                GC.mStr("Querying online community skins repository", listX + listW * 0.5, listY + 140)
            elseif not SKIN_REPO.connected then
                GC.setColor(.95, .45, .50, .95)
                setFont(18)
                GC.mStr("Gameserver Offline or Unreachable", listX + listW * 0.5, listY + 80)
                GC.setColor(.65, .75, .90, .8)
                setFont(13)
                GC.mStr("Could not retrieve remote skins (" .. (SKIN_REPO.lastError or "Connection timed out") .. ")", listX + listW * 0.5, listY + 110)

                -- Retry button
                local btnW, btnH = 200, 42
                local btnX = listX + (listW - btnW) * 0.5 - 110
                local btnY = listY + 145
                local isHovBtn = (mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH)
                GC.setColor(isHovBtn and .22 or .14, isHovBtn and .50 or .32, isHovBtn and .95 or .75, .9)
                GC.rectangle('fill', btnX, btnY, btnW, btnH, 6)
                GC.setColor(.50, .80, 1, 1)
                GC.setLineWidth(1)
                GC.rectangle('line', btnX, btnY, btnW, btnH, 6)
                GC.setColor(1, 1, 1, 1)
                setFont(14)
                GC.mStr("🔄 Connect & Retry", btnX + btnW * 0.5, btnY + 11)

                -- View Installed button
                local btn2X = listX + (listW - btnW) * 0.5 + 110
                local isHovBtn2 = (mx >= btn2X and mx <= btn2X + btnW and my >= btnY and my <= btnY + btnH)
                GC.setColor(isHovBtn2 and .20 or .12, isHovBtn2 and .30 or .18, isHovBtn2 and .60 or .38, .85)
                GC.rectangle('fill', btn2X, btnY, btnW, btnH, 6)
                GC.setColor(.45, .65, .95, .8)
                GC.setLineWidth(1)
                GC.rectangle('line', btn2X, btnY, btnW, btnH, 6)
                GC.setColor(1, 1, 1, 1)
                setFont(14)
                GC.mStr("📦 View Installed", btn2X + btnW * 0.5, btnY + 11)
            else
                -- Connected, but 0 skins match filter or search
                local statW, statH = 260, 32
                local statX = listX + (listW - statW) * 0.5
                local statY = listY + 45
                GC.setColor(.08, .28, .16, .85)
                GC.rectangle('fill', statX, statY, statW, statH, 16)
                GC.setColor(.30, .85, .45, .9)
                GC.setLineWidth(1)
                GC.rectangle('line', statX, statY, statW, statH, 16)
                GC.setColor(.35, 1, .55, 1)
                setFont(12)
                GC.mStr("● Connected to Teblocks Server", statX + statW * 0.5, statY + 8)

                GC.setColor(1, 1, 1, .95)
                setFont(18)
                GC.mStr("No Community Skins Found", listX + listW * 0.5, listY + 100)
                GC.setColor(.65, .75, .90, .8)
                setFont(13)
                GC.mStr("Be the first to publish a custom mino skin!", listX + listW * 0.5, listY + 130)

                -- 3 Quick Action buttons
                local bW, bH = 190, 42
                local startBX = listX + (listW - (bW * 3 + 24)) * 0.5
                local bY = listY + 180

                -- 1. View Installed Skins
                local b1X = startBX
                local isHov1 = (mx >= b1X and mx <= b1X + bW and my >= bY and my <= bY + bH)
                GC.setColor(isHov1 and .22 or .12, isHov1 and .45 or .26, isHov1 and .85 or .55, .9)
                GC.rectangle('fill', b1X, bY, bW, bH, 6)
                GC.setColor(.45, .75, 1, 1)
                GC.setLineWidth(1)
                GC.rectangle('line', b1X, bY, bW, bH, 6)
                GC.setColor(1, 1, 1, 1)
                setFont(13)
                GC.mStr("📦 Installed Skins", b1X + bW * 0.5, bY + 12)

                -- 2. Publish Custom
                local b2X = b1X + bW + 12
                local isHov2 = (mx >= b2X and mx <= b2X + bW and my >= bY and my <= bY + bH)
                GC.setColor(isHov2 and .30 or .16, isHov2 and .55 or .35, isHov2 and 1 or .75, .9)
                GC.rectangle('fill', b2X, bY, bW, bH, 6)
                GC.setColor(.65, .85, 1, 1)
                GC.setLineWidth(1)
                GC.rectangle('line', b2X, bY, bW, bH, 6)
                GC.setColor(1, 1, 1, 1)
                setFont(13)
                GC.mStr("📤 Publish Custom", b2X + bW * 0.5, bY + 12)

                -- 3. Open Skins Folder
                local b3X = b2X + bW + 12
                local isHov3 = (mx >= b3X and mx <= b3X + bW and my >= bY and my <= bY + bH)
                GC.setColor(isHov3 and .20 or .12, isHov3 and .30 or .18, isHov3 and .60 or .38, .85)
                GC.rectangle('fill', b3X, bY, bW, bH, 6)
                GC.setColor(.45, .65, .95, .8)
                GC.setLineWidth(1)
                GC.rectangle('line', b3X, bY, bW, bH, 6)
                GC.setColor(1, 1, 1, 1)
                setFont(13)
                GC.mStr("📁 Open Folder", b3X + bW * 0.5, bY + 12)
            end
        end

        for i, item in ipairs(onlineList) do
            local cardY = listY + (i - 1) * 96 - scrollOffset
            if cardY >= listY - 96 and cardY <= listY + listH then
                local isSel = (i == onlineSelect)
                local isHov = (mx >= listX and mx <= listX + listW and my >= cardY and my <= cardY + 86)
                local isInst = SKIN_REPO.isInstalled(item)
                local isEq = (SETTING.skinSet == item.installedName) or (item.isOfficial and SETTING.skinSet == 'Neon Cyber (Teblocks)')

                -- Card Body
                if isSel then
                    GC.setColor(.14, .20, .44, .95)
                    GC.rectangle('fill', listX, cardY, listW, 86, 6)
                    GC.setColor(.35, .70, 1, 1)
                    GC.setLineWidth(1.5)
                    GC.rectangle('line', listX, cardY, listW, 86, 6)
                    -- Left highlight indicator
                    GC.setColor(.35, .80, 1, 1)
                    GC.rectangle('fill', listX, cardY + 2, 4, 82, 2)
                elseif isHov then
                    GC.setColor(.10, .14, .30, .85)
                    GC.rectangle('fill', listX, cardY, listW, 86, 6)
                    GC.setColor(.25, .45, .80, .7)
                    GC.setLineWidth(1)
                    GC.rectangle('line', listX, cardY, listW, 86, 6)
                else
                    GC.setColor(.06, .09, .20, .80)
                    GC.rectangle('fill', listX, cardY, listW, 86, 6)
                    GC.setColor(.16, .24, .45, .5)
                    GC.setLineWidth(1)
                    GC.rectangle('line', listX, cardY, listW, 86, 6)
                end

                -- Mini preview strip (left side of card, 5 blocks)
                for b = 1, 6 do
                    drawMinoTile(item, item.installedName, b, listX + 16 + (b - 1) * 20, cardY + 34, 0.6)
                end

                -- Title & Creator
                GC.setColor(isSel and 1 or .92, isSel and 1 or .95, 1, 1)
                setFont(17)
                GC.print(fitText(item.title, 420), listX + 148, cardY + 14)

                GC.setColor(.55, .75, 1, .9)
                setFont(12)
                GC.print(fitText("by " .. item.author, 420), listX + 148, cardY + 38)

                -- Stats row
                GC.setColor(.65, .75, .90, .7)
                setFont(11)
                local dl = tonumber(item.downloads) or 0
                local statsStr = ("⬇ %s  •  ★ %.1f  •  %s"):format(
                    dl > 1000 and ("%.1fk"):format(dl/1000) or tostring(dl),
                    tonumber(item.rating) or 5.0,
                    item.date or "2026"
                )
                GC.print(statsStr, listX + 148, cardY + 58)

                -- Badges & Action Buttons (Right side of card)
                if isEq then
                    -- Currently Active badge
                    GC.setColor(.15, .45, .25, .9)
                    GC.rectangle('fill', listX + listW - 115, cardY + 26, 100, 36, 4)
                    GC.setColor(.35, 1, .55, 1)
                    GC.setLineWidth(1)
                    GC.rectangle('line', listX + listW - 115, cardY + 26, 100, 36, 4)
                    setFont(12)
                    GC.mStr("● ACTIVE", listX + listW - 65, cardY + 37)
                elseif isInst then
                    -- Installed -> Equip button
                    local isHovBtn = (mx >= listX + listW - 115 and mx <= listX + listW - 15 and my >= cardY + 26 and my <= cardY + 62)
                    GC.setColor(isHovBtn and .22 or .15, isHovBtn and .45 or .30, isHovBtn and .85 or .65, .9)
                    GC.rectangle('fill', listX + listW - 115, cardY + 26, 100, 36, 4)
                    GC.setColor(.45, .75, 1, 1)
                    GC.setLineWidth(1)
                    GC.rectangle('line', listX + listW - 115, cardY + 26, 100, 36, 4)
                    GC.setColor(1, 1, 1, 1)
                    setFont(12)
                    GC.mStr("✓ Equip", listX + listW - 65, cardY + 37)
                else
                    -- Not installed -> Download button
                    local isHovBtn = (mx >= listX + listW - 115 and mx <= listX + listW - 15 and my >= cardY + 26 and my <= cardY + 62)
                    GC.setColor(isHovBtn and .25 or .18, isHovBtn and .65 or .50, isHovBtn and 1 or .85, .95)
                    GC.rectangle('fill', listX + listW - 115, cardY + 26, 100, 36, 4)
                    GC.setColor(.75, .90, 1, 1)
                    GC.setLineWidth(1)
                    GC.rectangle('line', listX + listW - 115, cardY + 26, 100, 36, 4)
                    GC.setColor(1, 1, 1, 1)
                    setFont(12)
                    local btnLabel = downloadState[item.id] and "Loading..." or "⬇ Download"
                    GC.mStr(btnLabel, listX + listW - 65, cardY + 37)
                end
            end
        end
        GC.setStencilTest()

        -- Online List Scrollbar
        if maxScroll > 0 then
            local sbX = listX + listW + 6
            local sbY = listY
            local sbW = 5
            local sbH = listH
            GC.setColor(.10, .14, .30, .5)
            GC.rectangle('fill', sbX, sbY, sbW, sbH, 2)
            local thumbH = math.max(30, sbH * (sbH / (sbH + maxScroll)))
            local thumbY = sbY + (scrollOffset / maxScroll) * (sbH - thumbH)
            GC.setColor(.35, .65, 1, .85)
            GC.rectangle('fill', sbX, thumbY, sbW, thumbH, 2)
        end

        -- ── Right Column: osu!-style Detail & Live Inspection ──
        local prevX, prevY, prevW, prevH = 770, 82, 470, 598
        GC.setColor(.05, .07, .17, .90)
        GC.rectangle('fill', prevX, prevY, prevW, prevH, 8)
        GC.setColor(.22, .32, .60, .6)
        GC.setLineWidth(1.5)
        GC.rectangle('line', prevX, prevY, prevW, prevH, 8)

        local curItem = onlineList[onlineSelect]
        if curItem then
            local isInst = SKIN_REPO.isInstalled(curItem)
            local isEq = (SETTING.skinSet == curItem.installedName) or (curItem.isOfficial and SETTING.skinSet == 'Neon Cyber (Teblocks)')

            -- Header Banner
            GC.setColor(1, 1, 1, .98)
            setFont(22)
            GC.print(fitText(curItem.title, prevW - 44), prevX + 22, prevY + 16)

            GC.setColor(.45, .78, 1, .95)
            setFont(13)
            GC.print(fitText("Creator: " .. curItem.author, prevW - 44), prevX + 22, prevY + 44)

            -- Description: scissor clamped to 32px height to avoid overlapping preview
            GC.setColor(.65, .75, .92, .80)
            setFont(11)
            GC.stencil(function()
                GC.rectangle('fill', prevX + 22, prevY + 64, prevW - 44, 34)
            end, 'replace', 2)
            GC.setStencilTest('equal', 2)
            GC.printf(curItem.description or "No description provided.", prevX + 22, prevY + 64, prevW - 44)
            GC.setStencilTest()

            -- Live 7 Tetromino Showcase
            GC.setColor(.35, .55, .90, .4)
            GC.line(prevX + 20, prevY + 104, prevX + prevW - 20, prevY + 104)

            GC.setColor(.75, .88, 1, .9)
            setFont(12)
            GC.print("Live Mino Preview (7 Tetrominoes):", prevX + 22, prevY + 112)

            drawTetrominoRow(curItem, curItem.installedName, prevX + 24, prevY + 134, 0.88, t)

            -- 24 Palette Block Tiles Grid
            local palY = prevY + 310
            GC.setColor(.35, .55, .90, .4)
            GC.line(prevX + 20, palY - 8, prevX + prevW - 20, palY - 8)

            GC.setColor(.75, .88, 1, .9)
            setFont(12)
            GC.print("Complete 24-Tile Palette Sheet (240×90 RGBA):", prevX + 22, palY)

            for row = 0, 2 do
                for col = 1, 8 do
                    local bIdx = row * 8 + col
                    local px = prevX + 22 + (col - 1) * 52
                    local py = palY + 20 + row * 40
                    drawMinoTile(curItem, curItem.installedName, bIdx, px, py, 1.1)
                    GC.setColor(.25, .35, .60, .5)
                    GC.setLineWidth(1)
                    GC.rectangle('line', px, py, 34, 34, 2)
                end
            end

            -- Metadata row
            local metaY = prevY + 452
            GC.setColor(.35, .55, .90, .4)
            GC.line(prevX + 20, metaY - 6, prevX + prevW - 20, metaY - 6)

            GC.setColor(.65, .75, .92, .85)
            setFont(12)
            local dl = tonumber(curItem.downloads) or 0
            local statText = ("Downloads: %s   •   Rating: ★ %.1f   •   Updated: %s"):format(
                dl > 1000 and ("%.1fk"):format(dl/1000) or tostring(dl),
                tonumber(curItem.rating) or 5.0,
                curItem.date or "2026"
            )
            GC.print(statText, prevX + 22, metaY)

            local tagStr = ""
            if type(curItem.tags) == 'table' then
                tagStr = table.concat(curItem.tags, ", ")
            elseif type(curItem.tags) == 'string' then
                tagStr = curItem.tags
            end
            if #tagStr > 0 then
                GC.setColor(.45, .65, .85, .75)
                setFont(11)
                GC.print(fitText("Tags: " .. tagStr, prevW - 44), prevX + 22, metaY + 20)
            end

            -- Bottom Action Buttons
            local isHovBtn1 = (mx >= prevX + 15 and mx <= prevX + 235 and my >= prevY + prevH - 58 and my <= prevY + prevH - 12)
            if isEq then
                GC.setColor(.12, .40, .22, .9)
                GC.rectangle('fill', prevX + 15, prevY + prevH - 58, 220, 46, 6)
                GC.setColor(.35, 1, .55, 1)
                GC.setLineWidth(1.5)
                GC.rectangle('line', prevX + 15, prevY + prevH - 58, 220, 46, 6)
                GC.setColor(1, 1, 1, 1)
                setFont(14)
                GC.mStr("● Currently Equipped", prevX + 125, prevY + prevH - 44)
            elseif isInst then
                GC.setColor(isHovBtn1 and .25 or .18, isHovBtn1 and .55 or .40, isHovBtn1 and 1 or .85, .95)
                GC.rectangle('fill', prevX + 15, prevY + prevH - 58, 220, 46, 6)
                GC.setColor(.65, .85, 1, 1)
                GC.setLineWidth(1.5)
                GC.rectangle('line', prevX + 15, prevY + prevH - 58, 220, 46, 6)
                GC.setColor(1, 1, 1, 1)
                setFont(14)
                GC.mStr("✓ Equip This Skin", prevX + 125, prevY + prevH - 44)
            else
                local isDownloading = downloadState[curItem.id]
                GC.setColor(isHovBtn1 and .25 or .18, isHovBtn1 and .65 or .50, isHovBtn1 and 1 or .85, .95)
                GC.rectangle('fill', prevX + 15, prevY + prevH - 58, 220, 46, 6)
                GC.setColor(.75, .90, 1, 1)
                GC.setLineWidth(1.5)
                GC.rectangle('line', prevX + 15, prevY + prevH - 58, 220, 46, 6)
                GC.setColor(1, 1, 1, 1)
                setFont(14)
                local btnLabel = isDownloading and "Downloading..." or "⬇ Download Skin"
                GC.mStr(btnLabel, prevX + 125, prevY + prevH - 44)
            end

            -- Color settings button
            local isHovCol = (mx >= prevX + 245 and mx <= prevX + prevW - 15 and my >= prevY + prevH - 58 and my <= prevY + prevH - 12)
            GC.setColor(isHovCol and .22 or .12, isHovCol and .28 or .16, isHovCol and .55 or .35, .85)
            GC.rectangle('fill', prevX + 245, prevY + prevH - 58, 210, 46, 6)
            GC.setColor(.45, .60, .95, .8)
            GC.setLineWidth(1)
            GC.rectangle('line', prevX + 245, prevY + prevH - 58, 210, 46, 6)
            GC.setColor(.90, .94, 1, 1)
            setFont(14)
            GC.mStr("🎨 Color Settings", prevX + 350, prevY + prevH - 44)
        else
            -- Live preview of the currently equipped skin
            local eqSkin = SETTING.skinSet or 'Neon Cyber (Teblocks)'
            local isUser = (eqSkin:sub(1, 7) == '[User] ')
            local dispName = isUser and eqSkin:sub(8) or eqSkin

            -- Header Banner
            GC.setColor(1, 1, 1, .98)
            setFont(22)
            GC.print(fitText(dispName, prevW - 44), prevX + 22, prevY + 16)

            GC.setColor(.45, .78, 1, .95)
            setFont(13)
            GC.print("Currently Equipped Skin (" .. (isUser and "Custom User Skin" or "Built-in Preset") .. ")", prevX + 22, prevY + 44)

            GC.setColor(.65, .75, .92, .80)
            setFont(11)
            GC.printf("This skin is currently equipped and active in your offline and multiplayer matches.", prevX + 22, prevY + 64, prevW - 44)

            -- Live 7 Tetromino Showcase
            GC.setColor(.35, .55, .90, .4)
            GC.line(prevX + 20, prevY + 104, prevX + prevW - 20, prevY + 104)

            GC.setColor(.75, .88, 1, .9)
            setFont(12)
            GC.print("Live Mino Preview (7 Tetrominoes):", prevX + 22, prevY + 112)

            drawTetrominoRow(nil, eqSkin, prevX + 24, prevY + 134, 0.88, t)

            -- 24 Palette Block Tiles Grid
            local palY = prevY + 310
            GC.setColor(.35, .55, .90, .4)
            GC.line(prevX + 20, palY - 8, prevX + prevW - 20, palY - 8)

            GC.setColor(.75, .88, 1, .9)
            setFont(12)
            GC.print("Complete 24-Tile Palette Sheet (240×90 RGBA):", prevX + 22, palY)

            for row = 0, 2 do
                for col = 1, 8 do
                    local bIdx = row * 8 + col
                    local px = prevX + 22 + (col - 1) * 52
                    local py = palY + 20 + row * 40
                    drawMinoTile(nil, eqSkin, bIdx, px, py, 1.1)
                    GC.setColor(.25, .35, .60, .5)
                    GC.setLineWidth(1)
                    GC.rectangle('line', px, py, 34, 34, 2)
                end
            end

            -- Bottom Action Buttons
            local isHovBtn1 = (mx >= prevX + 15 and mx <= prevX + 235 and my >= prevY + prevH - 58 and my <= prevY + prevH - 12)
            GC.setColor(isHovBtn1 and .22 or .14, isHovBtn1 and .45 or .28, isHovBtn1 and .85 or .58, .9)
            GC.rectangle('fill', prevX + 15, prevY + prevH - 58, 220, 46, 6)
            GC.setColor(.45, .75, 1, 1)
            GC.setLineWidth(1.5)
            GC.rectangle('line', prevX + 15, prevY + prevH - 58, 220, 46, 6)
            GC.setColor(1, 1, 1, 1)
            setFont(14)
            GC.mStr("📦 Installed Skins", prevX + 125, prevY + prevH - 44)

            local isHovCol = (mx >= prevX + 245 and mx <= prevX + prevW - 15 and my >= prevY + prevH - 58 and my <= prevY + prevH - 12)
            GC.setColor(isHovCol and .22 or .12, isHovCol and .28 or .16, isHovCol and .55 or .35, .85)
            GC.rectangle('fill', prevX + 245, prevY + prevH - 58, 210, 46, 6)
            GC.setColor(.45, .60, .95, .8)
            GC.setLineWidth(1)
            GC.rectangle('line', prevX + 245, prevY + prevH - 58, 210, 46, 6)
            GC.setColor(.90, .94, 1, 1)
            setFont(14)
            GC.mStr("🎨 Color Settings", prevX + 350, prevY + prevH - 44)
        end
    end

    -- ════════════════════════════════════════════════════════════
    --  TAB 2: INSTALLED SKINS (Local collection & Dropzone)
    -- ════════════════════════════════════════════════════════════
    if currentTab == 'installed' then
        local listX, listY, listW, listH = 40, 90, 710, 450
        GC.stencil(function()
            GC.rectangle('fill', listX, listY, listW, listH)
        end, 'replace', 1)
        GC.setStencilTest('equal', 1)

        for i, name in ipairs(installedList) do
            local cardY = listY + (i - 1) * 88 - scrollOffset
            if cardY >= listY - 88 and cardY <= listY + listH then
                local isSel = (i == installedSelect)
                local isEq  = (name == SETTING.skinSet)
                local isUser = (name:sub(1, 7) == '[User] ')
                local displayName = isUser and name:sub(8) or name

                if isSel then
                    GC.setColor(.14, .20, .44, .95)
                    GC.rectangle('fill', listX, cardY, listW, 78, 6)
                    GC.setColor(.35, .70, 1, 1)
                    GC.setLineWidth(1.5)
                    GC.rectangle('line', listX, cardY, listW, 78, 6)
                else
                    GC.setColor(.06, .09, .20, .80)
                    GC.rectangle('fill', listX, cardY, listW, 78, 6)
                    GC.setColor(.16, .24, .45, .5)
                    GC.setLineWidth(1)
                    GC.rectangle('line', listX, cardY, listW, 78, 6)
                end

                -- Preview blocks
                for b = 1, 6 do
                    drawMinoTile(nil, name, b, listX + 16 + (b - 1) * 20, cardY + 28, 0.6)
                end

                -- Title & Tag
                GC.setColor(1, 1, 1, .98)
                setFont(17)
                GC.print(fitText(displayName, 350), listX + 148, cardY + 16)

                if isUser then
                    GC.setColor(.95, .65, .25, .90)
                    setFont(11)
                    GC.print("CUSTOM USER SKIN", listX + 148, cardY + 44)
                else
                    GC.setColor(.35, .80, 1, .90)
                    setFont(11)
                    GC.print("OFFICIAL BUILT-IN SKIN", listX + 148, cardY + 44)
                end

                -- Equip Button
                if isEq then
                    GC.setColor(.15, .45, .25, .9)
                    GC.rectangle('fill', listX + listW - 200, cardY + 22, 90, 36, 4)
                    GC.setColor(.35, 1, .55, 1)
                    GC.setLineWidth(1)
                    GC.rectangle('line', listX + listW - 200, cardY + 22, 90, 36, 4)
                    setFont(11)
                    GC.mStr("● ACTIVE", listX + listW - 155, cardY + 34)
                else
                    GC.setColor(.18, .40, .85, .9)
                    GC.rectangle('fill', listX + listW - 200, cardY + 22, 90, 36, 4)
                    GC.setColor(.5, .8, 1, 1)
                    GC.setLineWidth(1)
                    GC.rectangle('line', listX + listW - 200, cardY + 22, 90, 36, 4)
                    GC.setColor(1, 1, 1, 1)
                    setFont(12)
                    GC.mStr("✓ Equip", listX + listW - 155, cardY + 33)
                end

                -- If user custom: Publish shortcut button
                if isUser then
                    GC.setColor(.28, .18, .55, .85)
                    GC.rectangle('fill', listX + listW - 100, cardY + 22, 90, 36, 4)
                    GC.setColor(.75, .45, 1, 1)
                    GC.setLineWidth(1)
                    GC.rectangle('line', listX + listW - 100, cardY + 22, 90, 36, 4)
                    GC.setColor(1, 1, 1, 1)
                    setFont(12)
                    GC.mStr("🚀 Publish", listX + listW - 55, cardY + 33)
                end
            end
        end
        GC.setStencilTest()

        -- Installed List Scrollbar
        if maxScroll > 0 then
            local sbX = listX + listW + 6
            local sbY = listY
            local sbW = 5
            local sbH = listH
            GC.setColor(.10, .14, .30, .5)
            GC.rectangle('fill', sbX, sbY, sbW, sbH, 2)
            local thumbH = math.max(30, sbH * (sbH / (sbH + maxScroll)))
            local thumbY = sbY + (scrollOffset / maxScroll) * (sbH - thumbH)
            GC.setColor(.35, .65, 1, .85)
            GC.rectangle('fill', sbX, thumbY, sbW, thumbH, 2)
        end

        -- Bottom Dropzone for Drag & Drop
        local dropX, dropY, dropW, dropH = 40, 555, 710, 125
        GC.setColor(.07, .10, .24, .85)
        GC.rectangle('fill', dropX, dropY, dropW, dropH, 8)
        GC.setColor(.30, .55, .95, .7)
        GC.setLineWidth(1.5)
        GC.rectangle('line', dropX, dropY, dropW, dropH, 8)

        GC.setColor(.45, .75, 1, 1)
        setFont(16)
        GC.mStr("⬆ DRAG & DROP PNG FILE HERE TO AUTO-INSTALL", dropX + dropW * 0.5, dropY + 24)

        GC.setColor(.65, .75, .95, .8)
        setFont(12)
        GC.mStr("Standard skin sheets are 240×90 px (8×3 blocks of 30×30 px tiles).", dropX + dropW * 0.5, dropY + 56)
        GC.mStr("Click to open skins folder or drop your custom PNG directly into the window.", dropX + dropW * 0.5, dropY + 78)

        -- Right Column Live Preview
        local prevX, prevY, prevW, prevH = 770, 82, 470, 598
        GC.setColor(.05, .07, .17, .90)
        GC.rectangle('fill', prevX, prevY, prevW, prevH, 8)
        GC.setColor(.22, .32, .60, .6)
        GC.setLineWidth(1.5)
        GC.rectangle('line', prevX, prevY, prevW, prevH, 8)

        local selName = installedList[installedSelect] or 'Neon Cyber (Teblocks)'
        local isUser = selName:sub(1, 7) == '[User] '
        local cleanName = isUser and selName:sub(8) or selName
        local isEq = (selName == SETTING.skinSet)

        GC.setColor(1, 1, 1, .98)
        setFont(22)
        GC.print(fitText(cleanName, prevW - 44), prevX + 22, prevY + 16)

        GC.setColor(.45, .78, 1, .95)
        setFont(13)
        GC.print(isUser and ("User Custom Skin (skins/" .. cleanName .. ".png)") or "Official Teblocks Built-In Skin", prevX + 22, prevY + 44)

        -- Live Mino Preview
        GC.setColor(.35, .55, .90, .4)
        GC.line(prevX + 20, prevY + 76, prevX + prevW - 20, prevY + 76)

        GC.setColor(.75, .88, 1, .9)
        setFont(12)
        GC.print("Live Mino Preview (7 Tetrominoes):", prevX + 22, prevY + 84)

        drawTetrominoRow(nil, selName, prevX + 24, prevY + 106, 0.88, t)

        -- 24 Palette
        local palY = prevY + 282
        GC.setColor(.35, .55, .90, .4)
        GC.line(prevX + 20, palY - 8, prevX + prevW - 20, palY - 8)

        GC.setColor(.75, .88, 1, .9)
        setFont(12)
        GC.print("Complete 24-Tile Palette Sheet (240×90 RGBA):", prevX + 22, palY)

        for row = 0, 2 do
            for col = 1, 8 do
                local bIdx = row * 8 + col
                local px = prevX + 22 + (col - 1) * 52
                local py = palY + 20 + row * 40
                drawMinoTile(nil, selName, bIdx, px, py, 1.1)
                GC.setColor(.25, .35, .60, .5)
                GC.setLineWidth(1)
                GC.rectangle('line', px, py, 34, 34, 2)
            end
        end

        -- Status message
        local statusY = prevY + 440
        GC.setColor(.35, .55, .90, .4)
        GC.line(prevX + 20, statusY - 6, prevX + prevW - 20, statusY - 6)

        if isEq then
            GC.setColor(.35, 1, .55, .95)
            setFont(13)
            GC.print("● Currently Active in All Modes", prevX + 22, statusY)
            GC.setColor(.65, .75, .92, .8)
            setFont(11)
            GC.print("This skin is currently selected and active in offline and multiplayer games.", prevX + 22, statusY + 20)
        else
            GC.setColor(.75, .88, 1, .9)
            setFont(13)
            GC.print("○ Ready to Equip", prevX + 22, statusY)
            GC.setColor(.65, .75, .92, .8)
            setFont(11)
            GC.print("Click 'Equip This Skin' below to make this your active skin.", prevX + 22, statusY + 20)
        end

        -- Bottom Action Buttons
        -- Button 1: Equip / Active (x = prevX + 15..prevX + 235)
        local isHovBtn1 = (mx >= prevX + 15 and mx <= prevX + 235 and my >= prevY + prevH - 58 and my <= prevY + prevH - 12)
        if isEq then
            GC.setColor(.12, .40, .22, .9)
            GC.rectangle('fill', prevX + 15, prevY + prevH - 58, 220, 46, 6)
            GC.setColor(.35, 1, .55, 1)
            GC.setLineWidth(1.5)
            GC.rectangle('line', prevX + 15, prevY + prevH - 58, 220, 46, 6)
            GC.setColor(1, 1, 1, 1)
            setFont(14)
            GC.mStr("● Active Skin", prevX + 125, prevY + prevH - 44)
        else
            GC.setColor(isHovBtn1 and .25 or .18, isHovBtn1 and .55 or .40, isHovBtn1 and 1 or .85, .95)
            GC.rectangle('fill', prevX + 15, prevY + prevH - 58, 220, 46, 6)
            GC.setColor(.65, .85, 1, 1)
            GC.setLineWidth(1.5)
            GC.rectangle('line', prevX + 15, prevY + prevH - 58, 220, 46, 6)
            GC.setColor(1, 1, 1, 1)
            setFont(14)
            GC.mStr("✓ Equip This Skin", prevX + 125, prevY + prevH - 44)
        end

        -- Button 2: Delete (if custom) or Color Settings (if built-in) (x = prevX + 245..prevX + 455)
        local isHovBtn2 = (mx >= prevX + 245 and mx <= prevX + prevW - 15 and my >= prevY + prevH - 58 and my <= prevY + prevH - 12)
        if isUser then
            GC.setColor(isHovBtn2 and .75 or .60, isHovBtn2 and .20 or .15, isHovBtn2 and .25 or .20, .9)
            GC.rectangle('fill', prevX + 245, prevY + prevH - 58, 210, 46, 6)
            GC.setColor(.95, .45, .50, .9)
            GC.setLineWidth(1.5)
            GC.rectangle('line', prevX + 245, prevY + prevH - 58, 210, 46, 6)
            GC.setColor(1, 1, 1, 1)
            setFont(14)
            GC.mStr("🗑 Delete Skin", prevX + 350, prevY + prevH - 44)
        else
            GC.setColor(isHovBtn2 and .22 or .12, isHovBtn2 and .28 or .16, isHovBtn2 and .55 or .35, .85)
            GC.rectangle('fill', prevX + 245, prevY + prevH - 58, 210, 46, 6)
            GC.setColor(.45, .60, .95, .8)
            GC.setLineWidth(1)
            GC.rectangle('line', prevX + 245, prevY + prevH - 58, 210, 46, 6)
            GC.setColor(.90, .94, 1, 1)
            setFont(14)
            GC.mStr("🎨 Color Settings", prevX + 350, prevY + prevH - 44)
        end
    end

    -- ════════════════════════════════════════════════════════════
    --  TAB 3: PUBLISH SKIN (Community Uploader Modal / Studio)
    -- ════════════════════════════════════════════════════════════
    if currentTab == 'publish' then
        -- Left Form Panel
        local formX, formY, formW, formH = 40, 90, 550, 590
        GC.setColor(.05, .08, .18, .90)
        GC.rectangle('fill', formX, formY, formW, formH, 8)
        GC.setColor(.25, .38, .70, .6)
        GC.setLineWidth(1.5)
        GC.rectangle('line', formX, formY, formW, formH, 8)

        GC.setColor(1, 1, 1, .98)
        setFont(22)
        GC.print("Publish Skin to Community Repository", formX + 24, formY + 20)

        GC.setColor(.55, .72, .95, .8)
        setFont(12)
        GC.print("Share your skins with the Teblocks player network.", formX + 24, formY + 52)

        -- 1. Skin Selector
        GC.setColor(.85, .92, 1, .9)
        setFont(14)
        GC.print("1. Select Installed Custom Skin to Publish:", formX + 24, formY + 80)

        local curCustomName = customSkinsList[publishCustomIndex] or "No custom skins installed"
        GC.setColor(.09, .14, .30, .8)
        GC.rectangle('fill', formX + 24, formY + 105, formW - 48, 44, 6)
        GC.setColor(.35, .55, .90, .7)
        GC.setLineWidth(1)
        GC.rectangle('line', formX + 24, formY + 105, formW - 48, 44, 6)

        -- Left / Right arrows
        GC.setColor(.6, .8, 1, 1)
        setFont(18)
        GC.mStr("◀", formX + 44, formY + 117)
        GC.mStr("▶", formX + formW - 44, formY + 117)

        GC.setColor(1, 1, 1, 1)
        setFont(15)
        GC.mStr(curCustomName, formX + formW * 0.5, formY + 117)

        -- 2. Skin Title Input
        GC.setColor(.85, .92, 1, .9)
        setFont(14)
        GC.print("2. Skin Title:", formX + 24, formY + 160)

        -- 3. Creator Name Input
        GC.setColor(.85, .92, 1, .9)
        setFont(14)
        GC.print("3. Creator / Author Name:", formX + 24, formY + 240)

        -- 4. Tags Input
        GC.setColor(.85, .92, 1, .9)
        setFont(14)
        GC.print("4. Tags (comma separated):", formX + 24, formY + 320)

        -- 5. Description Input
        GC.setColor(.85, .92, 1, .9)
        setFont(14)
        GC.print("5. Description:", formX + 24, formY + 400)

        -- Big Publish Button (formX+24 .. formX+formW-24, y=formY+formH-70)
        local pubBtnY = formY + formH - 75
        local isHovPub = (mx >= formX + 24 and mx <= formX + formW - 24 and my >= pubBtnY and my <= pubBtnY + 54)
        GC.setColor(isHovPub and .28 or .20, isHovPub and .60 or .45, isHovPub and 1 or .90, .95)
        GC.rectangle('fill', formX + 24, pubBtnY, formW - 48, 54, 6)
        GC.setColor(.75, .92, 1, 1)
        GC.setLineWidth(1.5)
        GC.rectangle('line', formX + 24, pubBtnY, formW - 48, 54, 6)
        GC.setColor(1, 1, 1, 1)
        setFont(18)
        GC.mStr("🚀 Publish to Community Repository", formX + formW * 0.5, pubBtnY + 16)

        -- Right Column Preview of the skin to be published
        local prevX, prevY, prevW, prevH = 610, 90, 630, 590
        GC.setColor(.05, .07, .17, .90)
        GC.rectangle('fill', prevX, prevY, prevW, prevH, 8)
        GC.setColor(.22, .32, .60, .6)
        GC.setLineWidth(1.5)
        GC.rectangle('line', prevX, prevY, prevW, prevH, 8)

        local pubSkinFullName = curCustomName and ('[User] ' .. curCustomName)
        GC.setColor(1, 1, 1, .98)
        setFont(22)
        GC.print(fitText("Live Preview: " .. (pubTitleBox:getText() ~= "" and pubTitleBox:getText() or curCustomName), prevW - 48), prevX + 24, prevY + 20)

        GC.setColor(.55, .75, 1, .9)
        setFont(13)
        GC.print(fitText("Author: " .. (pubAuthorBox:getText() ~= "" and pubAuthorBox:getText() or "Anonymous"), prevW - 48), prevX + 24, prevY + 50)

        drawTetrominoRow(nil, pubSkinFullName, prevX + 40, prevY + 120, 1.1, t)

        local palY = prevY + 360
        GC.setColor(.75, .88, 1, .9)
        setFont(13)
        GC.print("Palette Sheet Verification (240×90 RGBA):", prevX + 24, palY)

        for row = 0, 2 do
            for col = 1, 8 do
                local bIdx = row * 8 + col
                local px = prevX + 24 + (col - 1) * 72
                local py = palY + 26 + row * 52
                drawMinoTile(nil, pubSkinFullName, bIdx, px, py, 1.4)
                GC.setColor(.25, .35, .60, .5)
                GC.setLineWidth(1)
                GC.rectangle('line', px, py, 42, 42, 2)
            end
        end
    end
end

return scene
