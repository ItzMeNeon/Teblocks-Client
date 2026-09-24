local scene = {}

local AUTH = require 'parts.authModal'
local REG_CONFIRM = require 'parts.registerConfirmModal'
local NET_BAR = require 'parts.netTopBar'

--[[
    MAIN SCENE - Clean, Modern Block-Stacking Client UI
    Features:
      • Permanent main menu on screen (not toggleable / no slide away)
      • Top bar with synced compact Profile Card on the left (avatar, username, rank, ELO, quick dropdown)
      • Options / Settings button opens an animated Options sidebar overlay
      • Quick access to Game settings, Video, Audio, Controls, Keys, Touch, and Skin Direct
      • Top bar with centered Logo, Version subtitle, and Right action icons (Skin Direct, Music, Notice, Lang, Dict)
      • Clean navigation buttons & bottom utility buttons (About, Manual, Quit)
      • Smooth background particles and centered demo board
]]

-- ════════════════════════════════════════════════════════════
--  LAYOUT CONSTANTS
-- ════════════════════════════════════════════════════════════
--  LAYOUT & SCALING CONSTANTS
-- ════════════════════════════════════════════════════════════
local MENU_W    = 260       -- Main menu width (px)
local MENU_X    = 24        -- Fixed left position of menu
local TB_H      = 52        -- Top bar height (px)
local NAV0      = TB_H + 16 -- 68px from top

-- Dynamic UI Scaling variables
local uiScale   = (SETTING and SETTING.uiScale) or 1.0
local BW        = math.floor(240 * uiScale)
local BH        = math.floor(56 * uiScale)
local B_GAP     = math.max(4, math.floor(8 * uiScale))
local STRIDE    = BH + B_GAP
local BTM_W     = math.floor(115 * uiScale)
local BTM_H     = math.floor(38 * uiScale)
local BTM_Y1    = math.max(NAV0 + 6 * STRIDE + 6, 720 - BTM_H * 2 - 18)
local BTM_Y2    = BTM_Y1 + BTM_H + 6

-- Options sidebar is now handled globally by SETTINGS (parts.settingsSidebar)

-- Top-bar icon buttons (fixed, top left)
-- Neatly aligned horizontally with uniform 6px gap, 36px size, vertically centered in 52px top bar
local TB_ICONS   = {'skin', 'music', 'notice', 'lang', 'dict'}
local TB_ICON_X  = {16, 58, 100, 142, 184}
local TB_ICON_Y  = 8
local TB_ICON_SZ = 36

-- Compact Top-Bar Profile Card (top right)
local PROF_W       = 230
local PROF_H       = 40
local PROF_X       = 1280 - PROF_W - 16 -- 1034
local PROF_Y       = 6
local profMenuOpen = false
local profMenuAnim = 0

-- Helper to get transformed mouse position matching scene coordinate space
local function getMousePos()
    return SCR.xOy:inverseTransformPoint(love.mouse.getPosition())
end

-- Key hint labels for nav buttons
local KEY_HINTS = {'[1]','[A]','[Z]','[-]','[P]','[,]'}

-- ════════════════════════════════════════════════════════════
--  TETROMINO BLOCK COLOR PALETTE
-- ════════════════════════════════════════════════════════════
local BCL = {
    COLOR.lR, COLOR.lS, COLOR.lV, COLOR.lO,
    COLOR.lM, COLOR.lY, COLOR.lC,
}

-- ════════════════════════════════════════════════════════════
--  TIP / VERSION
-- ════════════════════════════════════════════════════════════
local verName = ("%s  %s  %s"):format(SYSTEM, VERSION.string, VERSION.name)
local tipW    = 660
local tip     = GC.newText(getFont(22), "")
local scrollX = tipW
local flash   = 0

-- ════════════════════════════════════════════════════════════
--  QUICK-PLAY SUBMENU & SLIDE ANIMATION
-- ════════════════════════════════════════════════════════════
local submenu          = false
local slideAnim        = 0     -- 0 = main menu visible; 1 = quickplay sub-menu visible
local slideTarget      = 0
local searchPopupAlpha = 0

local PRIM_NAV = {'qplay','online','custom','settings','stat','replays'}
local SUB_NAV  = {'qp_40l','qp_sprint','qp_lock','offline','back'}

local function applyUIScale(scale)
    if scale then
        SETTING.uiScale = math.max(0.75, math.min(1.35, scale))
    end
    uiScale = (SETTING and SETTING.uiScale) or 1.0
    BW = math.floor(240 * uiScale)
    BH = math.floor(56 * uiScale)
    B_GAP = math.max(4, math.floor(8 * uiScale))
    STRIDE = BH + B_GAP
    BTM_W = math.floor(115 * uiScale)
    BTM_H = math.floor(38 * uiScale)
    BTM_Y1 = math.max(NAV0 + 6 * STRIDE + 6, 720 - BTM_H * 2 - 18)
    BTM_Y2 = BTM_Y1 + BTM_H + 6

    local L = scene.widgetList
    if not L or not L.qplay then return end

    local navFont = math.floor(26 * math.min(1.2, uiScale))
    local btmFont = math.floor(20 * math.min(1.2, uiScale))

    for _, n in ipairs(PRIM_NAV) do
        local W = L[n]
        if W then
            W.w = BW
            W.h = BH
            W.font = navFont
        end
    end
    for _, n in ipairs(SUB_NAV) do
        local W = L[n]
        if W then
            W.w = BW
            W.h = BH
            W.font = navFont
        end
    end
    if L.about  then L.about.w = BTM_W;  L.about.h = BTM_H;  L.about.font = btmFont end
    if L.manual then L.manual.w = BTM_W; L.manual.h = BTM_H; L.manual.font = btmFont end
    if L.quit   then L.quit.w = BW;     L.quit.h = BTM_H;   L.quit.font = btmFont end
end

local function setSubmenu(v)
    submenu = v
    slideTarget = v and 1 or 0
    local L = scene.widgetList
    if L and L.qplay then
        if v then
            for _, n in ipairs(SUB_NAV) do L[n].hide = false end
        else
            for _, n in ipairs(PRIM_NAV) do L[n].hide = false end
        end
    end
end

local function toggleOptions(open)
    if not SETTINGS then return end
    if open == true then
        SETTINGS.open()
    elseif open == false then
        SETTINGS.close()
    else
        SETTINGS.toggle()
    end
end

-- ════════════════════════════════════════════════════════════
--  FALLING PARTICLES
-- ════════════════════════════════════════════════════════════
local bgFallers = {}
local N_BG = 18
local function spawnBGFaller(i, scatter)
    local sz = math.random(14, 32)
    bgFallers[i] = {
        x     = math.random(MENU_W + 20, 1260),
        y     = scatter and math.random(-400, 720) or -(sz + math.random(10, 60)),
        sz    = sz,
        speed = math.random(10, 26),
        col   = math.random(1, 7),
        rot   = math.random() * 6.283,
        rs    = (math.random() > .5 and 1 or -1) * (math.random() * .3 + .03),
        alpha = math.random(4, 12) * .01,
    }
end
local function initBGFallers()
    for i = 1, N_BG do spawnBGFaller(i, true) end
end

-- ════════════════════════════════════════════════════════════
--  CONSOLE EASTER-EGG
-- ════════════════════════════════════════════════════════════
local enterConsole = coroutine.wrap(function()
    while true do
        Snd('bell',.6,'A4',.7,'E5',1,MATH.coin('A5','B5'))coroutine.yield()
        Snd('bell',.6,'A4',.7,'F5',1,MATH.coin('C6','D6'))coroutine.yield()
        Snd('bell',.6,'A4',.7,'G5',1,MATH.coin('E6','G6'))coroutine.yield()
        Snd('bell',.6,'A4',.7,'A5',1,'A6')SFX.play('ren_mega')SCN.go('app_console')coroutine.yield()
    end
end)

-- ════════════════════════════════════════════════════════════
--  COMPACT PROFILE CARD & DROPDOWN MENU
-- ════════════════════════════════════════════════════════════
local function getProfileMenuItems()
    local baseWeb = (AUTHURL and AUTHURL:find("^http")) and AUTHURL or "https://teblocks.my.id"
    local uid = USER and USER.uid
    local isLogged = uid and uid ~= false
    local items = {}
    if isLogged then
        table.insert(items, {
            icon  = CHAR.mino.T,
            label = "Skin Direct",
            sub   = "Browse community skins",
            code  = function() SCN.go('skin_browse') end
        })
        table.insert(items, {
            icon  = CHAR.icon.globe,
            label = "View Profile",
            sub   = "Open web profile page",
            url   = baseWeb .. "/profile"
        })
        table.insert(items, {
            icon  = CHAR.icon.info,
            label = "Match History",
            sub   = "Replays & match records",
            url   = baseWeb .. "/history"
        })
        table.insert(items, {
            icon  = CHAR.icon.crossMark,
            label = "Log Out",
            sub   = "Sign out of account",
            color = COLOR.lR,
            code  = function()
                USER.__data.uid = false
                USER.__data.aToken = false
                USER.__data.oToken = false
                love.filesystem.remove('conf/user')
                STAT.elo = nil
                STAT.globalRank = nil
                NET.ws_close()
                MES.new('info', "Logged out")
            end
        })
    else
        table.insert(items, {
            icon  = CHAR.icon.checkMark,
            label = "Log In",
            sub   = "Sign into your account",
            color = COLOR.lG,
            code  = function() AUTH.open('login') end
        })
        table.insert(items, {
            icon  = CHAR.icon.export,
            label = "Register Account",
            sub   = "Create a new Teblocks ID",
            code  = function() REG_CONFIRM.open() end
        })
        table.insert(items, {
            icon  = CHAR.mino.T,
            label = "Skin Direct",
            sub   = "Browse community skins",
            code  = function()
                if not (USER and USER.uid and USER.uid ~= false) then
                    MES.new('warn', "Please log in to access Skin Direct")
                    AUTH.open('login')
                else
                    SCN.go('skin_browse')
                end
            end
        })
    end
    return items
end

local function drawProfilePill(t)
    local mx, my = getMousePos()
    local isHover = (mx >= PROF_X and mx <= PROF_X + PROF_W and my >= PROF_Y and my <= PROF_Y + PROF_H)
    local uid = USER and USER.uid
    local isLogged = uid and uid ~= false
    local uname = isLogged and USERS.getUsername(uid) or "Guest Player"
    if not uname or #uname == 0 then uname = "Guest Player" end

    -- Pill Background
    if isHover or profMenuOpen then
        GC.setColor(.14, .20, .42, .88)
        GC.rectangle('fill', PROF_X, PROF_Y, PROF_W, PROF_H, 7)
        GC.setColor(.38, .60, 1.0, .90)
        GC.setLineWidth(1.5)
        GC.rectangle('line', PROF_X, PROF_Y, PROF_W, PROF_H, 7)
    else
        GC.setColor(.07, .10, .22, .65)
        GC.rectangle('fill', PROF_X, PROF_Y, PROF_W, PROF_H, 7)
        GC.setColor(.22, .32, .60, .55)
        GC.setLineWidth(1)
        GC.rectangle('line', PROF_X, PROF_Y, PROF_W, PROF_H, 7)
    end

    -- Circular Avatar
    local avX, avY, avR = PROF_X + 20, PROF_Y + PROF_H * .5, 14
    local avatar = isLogged and USERS.getAvatar(uid) or USERS.getAvatar(nil)
    if avatar then
        GC.setColor(1, 1, 1, 1)
        GC.stencil(function() GC.circle('fill', avX, avY, avR) end, 'replace', 1)
        GC.setStencilTest('equal', 1)
        local aw, ah = avatar:getDimensions()
        local s = (avR * 2) / math.max(aw, ah)
        GC.draw(avatar, avX - avR, avY - avR, 0, s, s)
        GC.setStencilTest()

        GC.setColor(.35, .65, 1.0, isHover and .9 or .6)
        GC.setLineWidth(1.5)
        GC.circle('line', avX, avY, avR)
    else
        local idx = math.floor(t * .4) % 7 + 1
        local bc  = BCL[idx]
        GC.setColor(bc[1], bc[2], bc[3], .35)
        GC.circle('fill', avX, avY, avR)
        GC.setColor(bc[1], bc[2], bc[3], .80)
        GC.setLineWidth(1.5)
        GC.circle('line', avX, avY, avR)
        GC.setColor(1, 1, 1, .6)
        setFont(14)
        GC.mStr("?", avX, avY - 8)
    end

    -- Text Info
    local tx = PROF_X + 42
    local maxTextW = PROF_W - 62
    setFont(13)
    local displayName = uname
    if FONT.get(13):getWidth(displayName) > maxTextW then
        while #displayName > 3 and FONT.get(13):getWidth(displayName .. "...") > maxTextW do
            displayName = displayName:sub(1, -2)
        end
        displayName = displayName .. "..."
    end

    GC.setColor(.95, .98, 1, .95)
    GC.print(displayName, tx, PROF_Y + 5)

    -- Status dot (online green dot if logged in)
    if isLogged then
        local dotX = tx + FONT.get(13):getWidth(displayName) + 6
        if dotX < PROF_X + PROF_W - 20 then
            GC.setColor(.22, .95, .45, 1)
            GC.circle('fill', dotX, PROF_Y + 12, 3)
        end
    end

    -- Subtitle
    setFont(11)
    if isLogged then
        local rank = STAT.globalRank or 0
        local elo = STAT.elo or 1200
        local rankStr = rank > 0 and ("#" .. rank .. " • ") or ""
        GC.setColor(.60, .75, .95, .8)
        GC.print(rankStr .. elo .. " ELO", tx, PROF_Y + 22)
    else
        GC.setColor(COLOR.lY[1], COLOR.lY[2], COLOR.lY[3], isHover and 1 or .85)
        GC.print("Sign In / Account", tx, PROF_Y + 22)
    end

    -- Dropdown chevron arrow
    GC.setColor(.6, .72, .95, isHover and 1 or .6)
    setFont(11)
    GC.mStr(profMenuOpen and "▲" or "▼", PROF_X + PROF_W - 12, PROF_Y + 13)
end

local function drawProfileDropdown(t)
    if profMenuAnim < 0.01 then return end

    local alpha = profMenuAnim
    local mx, my = getMousePos()
    local uid = USER and USER.uid
    local isLogged = uid and uid ~= false
    local items = getProfileMenuItems()

    local itemH = 38
    local headerH = isLogged and 46 or 36
    local menuW = 240
    local menuH = headerH + #items * itemH + 8
    local menuX = PROF_X + PROF_W - menuW
    local menuY = PROF_Y + PROF_H + 4

    -- Backdrop glass panel
    GC.setColor(.05, .07, .16, .98 * alpha)
    GC.rectangle('fill', menuX, menuY, menuW, menuH, 6)
    GC.setColor(.28, .42, .85, .85 * alpha)
    GC.setLineWidth(1.5)
    GC.rectangle('line', menuX, menuY, menuW, menuH, 6)

    -- Header stats
    GC.setColor(.10, .14, .32, .75 * alpha)
    GC.rectangle('fill', menuX + 2, menuY + 2, menuW - 4, headerH, 4)

    if isLogged then
        local rank = STAT.globalRank or 0
        local elo = STAT.elo or 1200
        local rankStr = rank > 0 and ("Global Rank #" .. rank) or "Unranked Player"
        setFont(11)
        GC.setColor(COLOR.lH[1], COLOR.lH[2], COLOR.lH[3], alpha * .95)
        GC.print(rankStr, menuX + 12, menuY + 8)

        GC.setColor(COLOR.lY[1], COLOR.lY[2], COLOR.lY[3], alpha * .95)
        GC.print("Rating: " .. elo .. " ELO", menuX + 12, menuY + 24)
    else
        setFont(11)
        GC.setColor(COLOR.lY[1], COLOR.lY[2], COLOR.lY[3], alpha * .95)
        GC.print("Playing as Guest", menuX + 12, menuY + 8)
        GC.setColor(.55, .65, .85, alpha * .75)
        GC.print("Sign in to track rank & sync skins", menuX + 12, menuY + 22)
    end

    -- Divider
    GC.setColor(.22, .32, .65, .45 * alpha)
    GC.setLineWidth(1)
    GC.line(menuX + 8, menuY + headerH, menuX + menuW - 8, menuY + headerH)

    -- Items list
    for i, item in ipairs(items) do
        local iy = menuY + headerH + 4 + (i - 1) * itemH
        local isHover = (mx >= menuX + 4 and mx <= menuX + menuW - 4 and my >= iy and my < iy + itemH)

        if isHover then
            GC.setColor(.18, .26, .55, .80 * alpha)
            GC.rectangle('fill', menuX + 4, iy, menuW - 8, itemH - 2, 4)
            GC.setColor(.45, .65, 1.0, .65 * alpha)
            GC.setLineWidth(1)
            GC.rectangle('line', menuX + 4, iy, menuW - 8, itemH - 2, 4)
        end

        local c = item.color or (isHover and {1, 1, 1} or {.85, .92, 1})
        GC.setColor(c[1], c[2], c[3], alpha * (isHover and 1 or .85))
        setFont(14)
        GC.print(item.icon or "•", menuX + 10, iy + 8)

        setFont(12)
        GC.print(item.label, menuX + 32, iy + 4)

        setFont(9)
        GC.setColor(.55, .65, .85, alpha * .75)
        GC.print(item.sub or "", menuX + 32, iy + 20)
    end
end

-- ════════════════════════════════════════════════════════════
--  SCENE CALLBACKS
-- ════════════════════════════════════════════════════════════
function scene.enter()
    if THEME.cur == 'halloween' then
        TASK.new(function()
            TEST.yieldT(.26)
            while SCN.cur == 'main' do
                flash = .355
                SFX.play('clear_'..math.random(4,6), 1, math.random()*2-1, -9-math.random()*3)
                TEST.yieldT(.626 + math.random()*6.26)
            end
        end)
    end
    BG.set()
    tip:set(text.getTip())
    scrollX = tipW
    applyUIScale()
    slideAnim = 0
    slideTarget = 0
    destroyPlayers()
    GAME.modeEnv = NONE
    GAME.setting = {}
    PLY.newDemoPlayer(1)
    PLAYERS[1]:setPosition(640, 150, .76)
    DiscordRPC.update("In Main Menu")
    setSubmenu(false)
    toggleOptions(false)
    WIDGET.blockZone = function(x, y)
        return SETTINGS and SETTINGS.isOpen and (x <= SETTINGS.w)
    end
    initBGFallers()
    profMenuOpen = false
    profMenuAnim = 0
    if USER and USER.uid then
        NET.getUserInfo(USER.uid)
    end
    if WS.status('game') == 'dead' then
        NET.startupConnect()
    end
end

function scene.leave()
    profMenuOpen = false
    profMenuAnim = 0
    AUTH.close()
    WIDGET.blockZone = nil
    saveSettings()
end

function scene.resize()
    applyUIScale()
end

function scene.mouseClick(x, y)
    if REG_CONFIRM.isOpen() or AUTH.isOpen() then return true end
    return false
end
scene.touchClick = scene.mouseClick

function scene.textInput(t)
    if REG_CONFIRM.isOpen() then return true end
    if AUTH.isOpen() and AUTH.textInput(t) then return true end
end

function scene.mouseDown(x, y)
    -- Modal input interactions: forward clicks to active modal and consume event
    if REG_CONFIRM.isOpen() then
        WIDGET.unFocus(true)
        REG_CONFIRM.mouseClick(x, y)
        return true
    end
    if AUTH.isOpen() then
        WIDGET.unFocus(true)
        AUTH.mouseClick(x, y)
        return true
    end

    -- Matchmaking persistent pill cancel / jump click
    if NET and NET.matchmaking then
        local qX, qY, qW, qH = 750, 8, 270, 36
        local cancelX = qX + qW - 18
        local cancelY = qY + qH * 0.5
        if (x - cancelX) ^ 2 + (y - cancelY) ^ 2 <= 14 * 14 then
            NET.matchmaking = false
            NET.searchTimer = 0
            NET.matchFoundPending = false
            NET.matchFoundCountdown = 0
            NET.matchFoundSeed = nil
            NET.matchFoundOppId = nil
            NET.matchFoundMatchId = nil
            NET._pendingMatchFoundScene = false
            NET.ranked_leave()
            SFX.play('click')
            MES.new('info', "Matchmaking cancelled")
            return true
        elseif x >= qX and x <= qX + qW and y >= qY and y <= qY + qH then
            SCN.go('net_ranked')
            SFX.play('click')
            return true
        end
    end

    -- Profile dropdown menu interactions
    if profMenuOpen or profMenuAnim > 0.05 then
        local items = getProfileMenuItems()
        local itemH = 38
        local uid = USER and USER.uid
        local isLogged = uid and uid ~= false
        local headerH = isLogged and 46 or 36
        local menuW = 240
        local menuH = headerH + #items * itemH + 8
        local menuX = PROF_X + PROF_W - menuW
        local menuY = PROF_Y + PROF_H + 4

        if x >= menuX and x <= menuX + menuW and y >= menuY and y <= menuY + menuH then
            for i, item in ipairs(items) do
                local iy = menuY + headerH + 4 + (i - 1) * itemH
                if y >= iy and y < iy + itemH then
                    profMenuOpen = false
                    SFX.play('click')
                    if item.url then
                        love.system.openURL(item.url)
                    elseif item.code then
                        item.code()
                    end
                    return true
                end
            end
            -- Clicked inside header or padding: keep dropdown open and consume click
            return true
        end

        -- Click outside dropdown closes it (unless clicking the profile pill itself)
        if not (x >= PROF_X and x <= PROF_X + PROF_W and y >= PROF_Y and y <= PROF_Y + PROF_H) then
            profMenuOpen = false
            return true
        end
    end

    -- Profile pill toggle
    if x >= PROF_X and x <= PROF_X + PROF_W and y >= PROF_Y and y <= PROF_Y + PROF_H then
        if SETTINGS and SETTINGS.isOpen then SETTINGS.close() end
        profMenuOpen = not profMenuOpen
        SFX.play('click')
        return true
    end

    -- Console easter-egg on title
    if x >= 500 and x <= 780 and y >= 0 and y <= TB_H then
        enterConsole()
    end
end
scene.touchDown = scene.mouseDown

function scene.mouseMove(x, y) end
scene.touchMove = scene.mouseMove

function scene.mouseUp(x, y) end
scene.touchUp = scene.mouseUp

-- ════════════════════════════════════════════════════════════
--  KEYBOARD
-- ════════════════════════════════════════════════════════════
local function _testButton(W)
    if WIDGET.isFocus(W) then return true else WIDGET.focus(W) end
end

function scene.keyDown(key, isRep)
    if REG_CONFIRM.isOpen() then
        REG_CONFIRM.keyDown(key, isRep)
        return false
    end
    if AUTH.isOpen() then
        AUTH.keyDown(key, isRep)
        return false
    end
    if isRep then return false end

    -- Options sidebar closes on escape or Android back
    if SETTINGS and SETTINGS.isOpen and (key == 'escape' or key == 'back' or key == 'backspace') then
        SETTINGS.close()
        return false
    end

    -- Close profile dropdown menu on escape or Android back
    if profMenuOpen and (key == 'escape' or key == 'back' or key == 'backspace') then
        profMenuOpen = false
        return false
    end

    -- Toggle profile menu on enter
    if (not SETTINGS or not SETTINGS.isOpen) and (key == 'return' or key == 'kpenter') then
        profMenuOpen = not profMenuOpen
        return false
    end

    if submenu then
        if     key == 'q'                         then if _testButton(scene.widgetList.qp_40l)    then loadGame('sprint_40l', true) end
        elseif key == 'w'                         then if _testButton(scene.widgetList.qp_sprint) then loadGame('sprint_100l', true) end
        elseif key == 'e'                         then if _testButton(scene.widgetList.qp_lock)   then loadGame('sprintLock', true) end
        elseif key == 'r'                         then if _testButton(scene.widgetList.offline)   then SCN.go('mode') end
        elseif key == 'escape' or key == 'back' or key == 'backspace' then
            if _testButton(scene.widgetList.back) then setSubmenu(false) end
            return false
        else return true
        end
    else
        if     key == '1'      then if _testButton(scene.widgetList.qplay)    then setSubmenu(true) end
        elseif key == 'a'      then
            if _testButton(scene.widgetList.online) then
                if WS.status('game') == 'running' then
                    SCN.go('lobby')
                else
                    NET.ws_connect()
                    SCN.go('lobby')
                end
            end
        elseif key == 'z'      then if _testButton(scene.widgetList.custom)   then SCN.go('customGame') end
        elseif key == 'p'      then if _testButton(scene.widgetList.stat)     then SCN.go('stat') end
        elseif key == ','      then if _testButton(scene.widgetList.replays)  then SCN.go('replays') end
        elseif key == '-'      then toggleOptions()
        elseif key == '2'      then if _testButton(scene.widgetList.music)    then SCN.go('music') end
        elseif key == '3'      then if _testButton(scene.widgetList.notice)   then NET.getNotice() end
        elseif key == '4'      then if _testButton(scene.widgetList.lang)     then SCN.go('lang') end
        elseif key == '5'      then
            if not (USER and USER.uid and USER.uid ~= false) then
                MES.new('warn', "Please log in to access Skin Direct")
                AUTH.open('login')
            elseif _testButton(scene.widgetList.skin) then
                SCN.go('skin_browse')
            end
        elseif key == 'x'      then if _testButton(scene.widgetList.about)    then SCN.go('about') end
        elseif key == 'h'      then
            if _testButton(scene.widgetList.manual) then
                SCN.go('textReader', nil,
                    FILE.load('parts/language/manual_'..(
                        SETTING.locale:find'zh' and 'zh' or
                        SETTING.locale:find'ja' and 'ja' or
                        SETTING.locale:find'vi' and 'vi' or 'en'
                    )..'.txt','-string'):split('\n'), 15, 'cubes')
            end
        elseif key == 'b'      then if _testButton(scene.widgetList.dict)     then SCN.go('dict') end
        elseif key == 'c'      then enterConsole()
        elseif key == 'escape' or key == 'back' then
            if tryBack() then VOC.play('bye') SCN.back() end
            return false
        else return true
        end
    end
end

-- ════════════════════════════════════════════════════════════
--  UPDATE
-- ════════════════════════════════════════════════════════════
function scene.update(dt)
    if dt > .26 then return end

    if flash > 0 then flash = flash - dt * .6 end

    -- Close profile dropdown when options sidebar opens
    if SETTINGS and SETTINGS.isOpen then
        profMenuOpen = false
    end
    profMenuAnim = MATH.expApproach(profMenuAnim, profMenuOpen and 1 or 0, dt * 16)
    REG_CONFIRM.update(dt)
    AUTH.update(dt)

    -- Dynamic centering of demo board
    local pCenterX = 640
    PLAYERS[1]:setPosition(pCenterX, 150, .76)
    PLAYERS[1]:update(dt)

    -- Tip ticker
    scrollX = scrollX - 120 * dt
    if scrollX < -tip:getWidth() then
        scrollX = tipW
        tip:set(text.getTip())
    end

    -- Ambient background particles
    for i = 1, #bgFallers do
        local f = bgFallers[i]
        f.y   = f.y + f.speed * dt
        f.rot = f.rot + f.rs * dt
        if f.y > 740 then spawnBGFaller(i, false) end
    end

    -- ── Widget Positioning & Slide Transitions ─────────
    local L = scene.widgetList

    slideAnim = MATH.expApproach(slideAnim, slideTarget, dt * 16)
    if slideAnim < 0.005 and slideTarget == 0 then
        slideAnim = 0
        for _, n in ipairs(SUB_NAV) do L[n].hide = true end
        for _, n in ipairs(PRIM_NAV) do L[n].hide = false end
    elseif slideAnim > 0.995 and slideTarget == 1 then
        slideAnim = 1
        for _, n in ipairs(PRIM_NAV) do L[n].hide = true end
        for _, n in ipairs(SUB_NAV) do L[n].hide = false end
    else
        for _, n in ipairs(PRIM_NAV) do L[n].hide = false end
        for _, n in ipairs(SUB_NAV) do L[n].hide = false end
    end

    local primExitDist = MENU_X + BW + 50
    for i, n in ipairs(PRIM_NAV) do
        local W = L[n]
        W.x = MENU_X - slideAnim * primExitDist
        W.y = NAV0 + (i - 1) * STRIDE
    end
    for i, n in ipairs(SUB_NAV) do
        local W = L[n]
        W.x = MENU_X + (1 - slideAnim) * 350
        W.y = NAV0 + (i - 1) * STRIDE
    end

    -- Bottom action buttons (stationary, do NOT slide)
    L.about.x  = MENU_X
    L.about.y  = BTM_Y1
    L.manual.x = MENU_X + BTM_W + 10
    L.manual.y = BTM_Y1
    L.quit.x   = MENU_X
    L.quit.y   = BTM_Y2

    -- Top bar icons (stationary, do NOT slide)
    for i, n in ipairs(TB_ICONS) do
        L[n].x = TB_ICON_X[i]
        L[n].y = TB_ICON_Y
    end

    -- Matchmaking persistent state & transition
    if NET and NET.matchmaking then
        NET.searchTimer = (NET.searchTimer or 0) + dt
    end
end

-- ════════════════════════════════════════════════════════════
--  DRAW HELPERS
-- ════════════════════════════════════════════════════════════
local function _tipStencil()
    GC.rectangle('fill', 0, 0, tipW, 30)
end

-- ─── drawBGParticles ─────────────────────────────────────────
local function drawBGParticles()
    for i = 1, #bgFallers do
        local f = bgFallers[i]
        local bc = BCL[f.col]
        GC.setColor(bc[1], bc[2], bc[3], f.alpha)
        GC.push('transform')
        GC.translate(f.x + f.sz * .5, f.y + f.sz * .5)
        GC.rotate(f.rot)
        GC.rectangle('fill', -f.sz * .5, -f.sz * .5, f.sz, f.sz, 3)
        GC.pop()
    end
end

-- ─── drawKeyHints ─────────────────────────────────────────────
local function drawKeyHints()
    local L = scene.widgetList
    if not L or not L.qplay then return end

    if slideAnim < 0.99 then
        for i, n in ipairs(PRIM_NAV) do
            local W = L[n]
            if W and not W.hide then
                local alpha = (1 - slideAnim) * 0.28
                if alpha > 0.02 and W.x > -BW then
                    local by = NAV0 + (i - 1) * STRIDE
                    local hint = KEY_HINTS[i] or ''
                    GC.setColor(1, 1, 1, alpha)
                    setFont(11)
                    GC.print(hint, W.x + BW - 18 - #hint * 6, by + BH - 14)
                end
            end
        end
    end
    if slideAnim > 0.01 then
        local subHints = {'[Q]','[W]','[E]','[R]','[Esc]'}
        for i, n in ipairs(SUB_NAV) do
            local W = L[n]
            if W and not W.hide then
                local alpha = slideAnim * 0.28
                if alpha > 0.02 and W.x < 1280 then
                    local by = NAV0 + (i - 1) * STRIDE
                    local hint = subHints[i] or ''
                    GC.setColor(1, 1, 1, alpha)
                    setFont(11)
                    GC.print(hint, W.x + BW - 18 - #hint * 6, by + BH - 14)
                end
            end
        end
    end
end

-- ─── drawTopBar ──────────────────────────────────────────────
local function drawTopBar(t)
    -- Top bar glass backdrop spans full window in SCR.origin
    GC.push('transform')
    GC.replaceTransform(SCR.origin)
    local topBarH_window = (TB_H + (SCR.y / (SCR.k > 0 and SCR.k or 1))) * (SCR.k > 0 and SCR.k or 1)
    GC.setColor(.035, .045, .10, .96)
    GC.rectangle('fill', 0, 0, SCR.w, topBarH_window)

    -- Rainbow spectrum line at the bottom
    local segW = SCR.w / 7
    for i = 1, 7 do
        local c = BCL[i]
        GC.setColor(c[1], c[2], c[3], .85)
        GC.rectangle('fill', (i - 1) * segW, topBarH_window - 2 * (SCR.k > 0 and SCR.k or 1), segW + 1, 2 * (SCR.k > 0 and SCR.k or 1))
    end
    GC.pop()

    -- Top-right compact profile pill
    drawProfilePill(t)

    -- Persistent Ranked Matchmaking Pill
    if NET and NET.matchmaking then
        local qX, qY, qW, qH = 746, 8, 276, 36
        local cancelX = qX + qW - 18
        local cancelY = qY + qH * 0.5
        local mx, my = getMousePos()
        local isCancelHov = (mx - cancelX) ^ 2 + (my - cancelY) ^ 2 <= 13 * 13
        local isPillHov = (mx >= qX and mx <= qX + qW and my >= qY and my <= qY + qH and not isCancelHov)

        local glow = 0.75 + 0.25 * math.sin(t * 4.5)
        GC.setColor(.08, .12, .24, .92)
        GC.rectangle('fill', qX, qY, qW, qH, 6)

        GC.setColor(1.0, .75, .20, glow)
        GC.setLineWidth(isPillHov and 2 or 1.2)
        GC.rectangle('line', qX, qY, qW, qH, 6)

        local dotGlow = 0.5 + 0.5 * math.sin(t * 6)
        GC.setColor(1.0, .80, .25, dotGlow)
        GC.circle('fill', qX + 16, qY + qH * 0.5, 4)
        GC.setColor(1.0, .80, .25, 0.3 * dotGlow)
        GC.circle('line', qX + 16, qY + qH * 0.5, 7 + 3 * dotGlow)

        local sec = math.floor(NET.searchTimer or 0)
        local timeStr = ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
        GC.setColor(1.0, .88, .40, .95)
        setFont(12)
        GC.print("RANKED 1v1", qX + 28, qY + 4)
        GC.setColor(.80, .90, 1.0, .85)
        setFont(11)
        GC.print("Searching • " .. timeStr, qX + 28, qY + 18)

        if isCancelHov then
            GC.setColor(.85, .20, .25, .95)
            GC.circle('fill', cancelX, cancelY, 11)
            GC.setColor(1, 1, 1, 1)
        else
            GC.setColor(.40, .15, .20, .70)
            GC.circle('fill', cancelX, cancelY, 11)
            GC.setColor(1.0, .55, .55, .85)
        end
        GC.setLineWidth(1.5)
        GC.circle('line', cancelX, cancelY, 11)
        GC.line(cancelX - 4, cancelY - 4, cancelX + 4, cancelY + 4)
        GC.line(cancelX + 4, cancelY - 4, cancelX - 4, cancelY + 4)
    end

    -- ── Title Logo & Version (Centered) ──────────────────────
    GC.setColor(1, 1, 1, .95)
    mDraw(TEXTURE.title_color, 640, 21, nil, .22)

    GC.setColor(.48, .55, .72, .85)
    setFont(11)
    GC.mStr(verName, 640, 36)
end

-- ─── drawTopBarTooltips ──────────────────────────────────────
local function drawTopBarTooltips()
    local iconTips = {
        skin   = "Skin Direct [5]",
        music  = "Music Player [2]",
        notice = "Announcements [3]",
        lang   = "Language [4]",
        dict   = "Dictionary [B]",
    }
    local mx, my = getMousePos()
    for i, name in ipairs(TB_ICONS) do
        local ix = TB_ICON_X[i]
        local iy = TB_ICON_Y
        if mx >= ix and mx <= ix + TB_ICON_SZ and my >= iy and my <= iy + TB_ICON_SZ then
            local tipStr = iconTips[name]
            if tipStr then
                setFont(12)
                local tw = FONT.get(12):getWidth(tipStr) + 14
                local tx = math.max(10, ix + TB_ICON_SZ * .5 - tw * .5)
                local ty = TB_H + 6
                GC.setColor(.06, .08, .18, .96)
                GC.rectangle('fill', tx, ty, tw, 22, 4)
                GC.setColor(.3, .55, .95, .85)
                GC.setLineWidth(1)
                GC.rectangle('line', tx, ty, tw, 22, 4)
                GC.setColor(1, 1, 1, .98)
                GC.print(tipStr, tx + 7, ty + 4)
            end
        end
    end
end


-- ─── drawTip ─────────────────────────────────────────────────
local function drawTip()
    local tipX = MENU_X + BW + 36
    local tipY = 680

    GC.setColor(.12, .16, .30, .6)
    GC.rectangle('fill', tipX, tipY, tipW, 30, 4)
    GC.setColor(.22, .30, .55, .4)
    GC.setLineWidth(1)
    GC.rectangle('line', tipX, tipY, tipW, 30, 4)

    GC.push('transform')
    GC.translate(tipX + 8, tipY + 4)
    GC.stencil(_tipStencil, 'replace', 1)
    GC.setStencilTest('equal', 1)
    GC.setColor(.85, .90, .98, .75)
    GC.draw(tip, scrollX, 0)
    GC.setStencilTest()
    GC.pop()
end

-- ════════════════════════════════════════════════════════════
--  MAIN DRAW
-- ════════════════════════════════════════════════════════════
function scene.draw()
    local t = TIME()

    drawBGParticles()
    PLAYERS[1]:draw()

    -- Halloween Theme overlay if active
    if THEME.cur == 'halloween' then
        GC.setColor(1,1,1)
        GC.mDraw(TEXTURE.spiderweb,820,50,.26,1.26)
        GC.mDraw(TEXTURE.spiderweb,1050,94.2,.62)
        GC.setColor(COLOR.O)
        GC.mDraw(TEXTURE.miniBlock[1],1126,90,-.16,40)
        GC.setColor(COLOR.lO)
        GC.setLineWidth(12)
        GC.line(1037,25,1032,101)
        GC.line(1099,16,1082,93)
        GC.line(1151,16,1113,169)
        GC.line(1196,83,1184,159)
        GC.line(1244,101,1235,150)
        GC.push('transform')
            GC.translate(1126,90)
            GC.setColor(.1,.5,.1)
            GC.setLineWidth(16)
            GC.line(20,-30,48,-60,70,-65)
            GC.rotate(.162)
            GC.setColor(COLOR.D)
            FONT.set(20)
            GC.mStr(text.pumpkin,0,-13)
        GC.pop()
    end

    drawKeyHints()
    drawTopBar(t)
    drawTip()
end

-- ════════════════════════════════════════════════════════════
--  SCENE OVERDRAW (Rendered ON TOP of all widgets & buttons)
-- ════════════════════════════════════════════════════════════
function scene.overDraw()
    local t = TIME()

    -- Ensure coordinate transform is SCR.xOy (WIDGET_draw leaves transform at gc_origin)
    GC.replaceTransform(SCR.xOy)

    -- 1. Top bar action icon tooltips (rendered ON TOP of Quickplay and other buttons)
    drawTopBarTooltips()

    -- 2. Compact Profile Dropdown menu (rendered ON TOP of buttons)
    drawProfileDropdown(t)

    -- 3. Modals (Dark full-screen overlay + sharp dialog on top of everything)
    AUTH.draw()
    REG_CONFIRM.draw()

    -- 5. Bottom-Right Connection Status Indicator
    NET_BAR.drawBottomStatus()

    -- 6. Screen flash transition
    if flash > 0 then
        GC.replaceTransform(SCR.origin)
        GC.setColor(1, 1, 1, flash)
        GC.rectangle('fill', 0, 0, SCR.w, SCR.h)
        GC.replaceTransform(SCR.xOy)
    end
end

-- ════════════════════════════════════════════════════════════
--  WIDGET LIST
-- ════════════════════════════════════════════════════════════
scene.widgetList = {
    -- Primary Navigation (Always visible on screen)
    WIDGET.newButton{name='qplay',    x=MENU_X+BW*.5, y=NAV0+0*STRIDE+BH*.5, w=BW, h=BH, color='lR', font=28, align='L', edge=12, code=pressKey'1'},
    WIDGET.newButton{name='online',   x=MENU_X+BW*.5, y=NAV0+1*STRIDE+BH*.5, w=BW, h=BH, color='lV', font=28, align='L', edge=12, code=pressKey'a'},
    WIDGET.newButton{name='custom',   x=MENU_X+BW*.5, y=NAV0+2*STRIDE+BH*.5, w=BW, h=BH, color='lS', font=28, align='L', edge=12, code=pressKey'z'},
    WIDGET.newButton{name='settings', x=MENU_X+BW*.5, y=NAV0+3*STRIDE+BH*.5, w=BW, h=BH, color='lO', font=28, align='L', edge=12, code=function() toggleOptions() end},
    WIDGET.newButton{name='stat',     x=MENU_X+BW*.5, y=NAV0+4*STRIDE+BH*.5, w=BW, h=BH, color='lL', font=26, align='L', edge=12, code=pressKey'p'},
    WIDGET.newButton{name='replays',  x=MENU_X+BW*.5, y=NAV0+5*STRIDE+BH*.5, w=BW, h=BH, color='lC', font=26, align='L', edge=12, code=pressKey','},

    -- Quick-Play Sub-Menu
    WIDGET.newButton{name='qp_40l',    x=MENU_X+BW*.5, y=NAV0+0*STRIDE+BH*.5, w=BW, h=BH, color='lM', font=26, align='L', edge=12, code=pressKey'q',      hide=true},
    WIDGET.newButton{name='qp_sprint', x=MENU_X+BW*.5, y=NAV0+1*STRIDE+BH*.5, w=BW, h=BH, color='lM', font=26, align='L', edge=12, code=pressKey'w',      hide=true},
    WIDGET.newButton{name='qp_lock',   x=MENU_X+BW*.5, y=NAV0+2*STRIDE+BH*.5, w=BW, h=BH, color='lM', font=26, align='L', edge=12, code=pressKey'e',      hide=true},
    WIDGET.newButton{name='offline',   x=MENU_X+BW*.5, y=NAV0+3*STRIDE+BH*.5, w=BW, h=BH, color='lY', font=26, align='L', edge=12, code=pressKey'r',      hide=true},
    WIDGET.newButton{name='back',      x=MENU_X+BW*.5, y=NAV0+4*STRIDE+BH*.5, w=BW, h=BH, color='lB', font=26, align='L', edge=12, code=pressKey'escape', hide=true},

    -- Bottom actions
    WIDGET.newButton{name='about',  x=MENU_X+BTM_W*.5,              y=BTM_Y1+BTM_H*.5, w=BTM_W, h=BTM_H, color='lB', align='M', edge=6, code=pressKey'x', font=22, fText=CHAR.icon.info},
    WIDGET.newButton{name='manual', x=MENU_X+BTM_W+10+BTM_W*.5,     y=BTM_Y1+BTM_H*.5, w=BTM_W, h=BTM_H, color='lR', align='M', edge=6, code=pressKey'h', font=22, fText=CHAR.icon.help},
    WIDGET.newButton{name='quit',   x=MENU_X+BW*.5,                 y=BTM_Y2+BTM_H*.5, w=BW,    h=BTM_H, color='lH', align='M', edge=6, font=20, fText="Quit Game", code=function() if tryBack() then VOC.play('bye') SCN.back() end end},

    -- Top-bar icon buttons (top left)
    WIDGET.newButton{name='skin',   x=TB_ICON_X[1]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lP', code=function()
        if not (USER and USER.uid and USER.uid ~= false) then
            MES.new('warn', "Please log in to access Skin Direct")
            AUTH.open('login')
        else
            SCN.go('skin_browse')
        end
    end, font=22, fText=CHAR.mino.T},
    WIDGET.newButton{name='music',  x=TB_ICON_X[2]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lY', code=pressKey'2', font=24, fText=CHAR.icon.music},
    WIDGET.newButton{name='notice', x=TB_ICON_X[3]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lG', code=pressKey'3', font=24, fText=CHAR.key.winMenu},
    WIDGET.newButton{name='lang',   x=TB_ICON_X[4]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lN', code=pressKey'4', font=24, fText=CHAR.icon.language},
    WIDGET.newButton{name='dict',   x=TB_ICON_X[5]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lC', code=pressKey'b', font=24, fText=CHAR.icon.zBook},
}

return scene
