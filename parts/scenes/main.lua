local scene = {}

--[[
    MAIN SCENE - Clean, Modern Block-Stacking Client UI
    Features:
      • Permanent main menu on screen (not toggleable / no slide away)
      • Top bar with User Profile on the left (avatar, username, login status/button)
      • Options / Settings button opens an animated Options sidebar overlay
      • Quick access to Game settings, Video, Audio, Controls, Keys, Touch, and Skin
      • Top bar with centered Logo, Version subtitle, and Right action icons (Skin, Music, Notice, Lang, Dict)
      • Clean navigation buttons & bottom utility buttons (About, Manual, Quit)
      • Smooth background particles and centered demo board
]]

-- ════════════════════════════════════════════════════════════
--  LAYOUT CONSTANTS
-- ════════════════════════════════════════════════════════════
local MENU_W    = 260       -- Main menu width (px)
local MENU_X    = 24        -- Fixed left position of menu
local TB_H      = 52        -- Top bar height (px)
local BW        = 240       -- Nav button width
local BH        = 56        -- Compact button height
local B_GAP     = 8         -- Gap between buttons

-- Navigation items placement
local NAV0      = TB_H + 16 -- 68px from top
local STRIDE    = BH + B_GAP -- 64px per item

-- Bottom dock buttons (About, Manual, Quit)
local BTM_Y1    = 616
local BTM_Y2    = 662
local BTM_W     = 115
local BTM_H     = 38

-- Options Sidebar (slides in from right for clean in-scene overlay)
local OPT_W        = 340       -- Options panel width
local optTarget    = 0         -- 0 = closed, 1 = open
local optAnim      = 0         -- Interpolated 0 -> 1
local optTab       = 'general' -- 'general', 'audio', 'video'
local activeSlider = nil       -- 'mainVol', 'bgm', 'sfx' when dragging

-- Top-bar icon buttons (fixed, top right)
-- Neatly aligned horizontally with uniform 6px gap, 36px size, vertically centered in 52px top bar
local TB_ICONS   = {'skin', 'music', 'notice', 'lang', 'dict'}
local TB_ICON_X  = {1046, 1088, 1130, 1172, 1214}
local TB_ICON_Y  = 8
local TB_ICON_SZ = 36

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
--  QUICK-PLAY SUBMENU
-- ════════════════════════════════════════════════════════════
local submenu          = false
local searchPopupAlpha = 0

local PRIM_NAV = {'qplay','online','custom','settings','stat','replays'}
local SUB_NAV  = {'qp_40l','qp_sprint','qp_lock','offline','back'}

local function setSubmenu(v)
    submenu = v
    for _, n in next, PRIM_NAV do scene.widgetList[n].hide = v end
    for _, n in next, SUB_NAV  do scene.widgetList[n].hide = not v end
end

local function toggleOptions(open)
    if open ~= nil then
        optTarget = open and 1 or 0
    else
        optTarget = (optTarget == 0) and 1 or 0
    end
    if optTarget == 0 then
        activeSlider = nil
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
    scene.resize()
    destroyPlayers()
    GAME.modeEnv = NONE
    GAME.setting = {}
    PLY.newDemoPlayer(1)
    PLAYERS[1]:setPosition(640, 150, .76)
    DiscordRPC.update("In Main Menu")
    setSubmenu(false)
    toggleOptions(false)
    optAnim = 0
    activeSlider = nil
    WIDGET.blockZone = function(x, y) return optAnim > 0.05 end
    initBGFallers()
    if WS.status('game') == 'dead' then
        NET.startupConnect()
    end
end

function scene.leave()
    activeSlider = nil
    WIDGET.blockZone = nil
    saveSettings()
end

function scene.resize() end

function scene.mouseDown(x, y)
    -- Top-bar profile click (User Accounts / Login)
    if x >= 10 and x <= 220 and y >= 6 and y <= TB_H - 6 then
        local uid = USER and USER.uid
        if uid and uid ~= false then
            SCN.go('net_menu')
        else
            NET.login(true)
        end
        return
    end

    -- Options sidebar overlay handling
    if optAnim > 0.05 then
        local panelLeft = 1280 - OPT_W * optAnim
        if x < panelLeft then
            toggleOptions(false)
            return
        end

        -- Close button
        if x >= 1280 - 45 and x <= 1280 - 15 and y >= TB_H + 10 and y <= TB_H + 42 then
            toggleOptions(false)
            return
        end

        -- Tab switching inside Options (General, Audio, Video)
        local tabY = TB_H + 50
        if y >= tabY and y <= tabY + 32 then
            if x >= panelLeft + 16 and x <= panelLeft + 112 then
                optTab = 'general'
                SFX.play('click')
                return
            elseif x >= panelLeft + 118 and x <= panelLeft + 214 then
                optTab = 'audio'
                SFX.play('click')
                return
            elseif x >= panelLeft + 220 and x <= panelLeft + 316 then
                optTab = 'video'
                SFX.play('click')
                return
            end
        end

        -- In-scene settings controls
        local itemY0 = TB_H + 92
        local rowH   = 52
        local stride = 58

        if optTab == 'general' then
            -- Row 1: Rotation System (TRS, SRS, etc.)
            if y >= itemY0 and y <= itemY0 + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                local rsList = {'TRS','SRS','SRS_plus','BiRS','Classic'}
                local curRS = TABLE.find(rsList, SETTING.RS) or 1
                curRS = (curRS % #rsList) + 1
                SETTING.RS = rsList[curRS]
                saveSettings()
                SFX.play('rotate')
                return
            end
            -- Row 2: Auto Pause Toggle
            if y >= itemY0 + stride and y <= itemY0 + stride + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SETTING.autoPause = not SETTING.autoPause
                saveSettings()
                SFX.play('click')
                return
            end
            -- Row 3: Auto Save Records Toggle
            if y >= itemY0 + stride * 2 and y <= itemY0 + stride * 2 + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SETTING.autoSave = not SETTING.autoSave
                saveSettings()
                SFX.play('click')
                return
            end
            -- Row 4: Simplistic Mode Toggle
            if y >= itemY0 + stride * 3 and y <= itemY0 + stride * 3 + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SETTING.simpMode = not SETTING.simpMode
                saveSettings()
                local p = TABLE.find(SCN.stack,'main') or TABLE.find(SCN.stack,'main_simple')
                if p then SCN.stack[p] = SETTING.simpMode and 'main_simple' or 'main' end
                SCN.swapTo(SETTING.simpMode and 'main_simple' or 'main', 'fade')
                return
            end
            -- Row 5: Open Full Keyboard Config
            if y >= itemY0 + stride * 4 and y <= itemY0 + stride * 4 + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SCN.go('setting_key')
                return
            end
            -- Row 6: Open Advanced Game Settings
            if y >= itemY0 + stride * 5 and y <= itemY0 + stride * 5 + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SCN.go('setting_game')
                return
            end

        elseif optTab == 'audio' then
            -- Row 1: Master Volume Slider
            if y >= itemY0 and y <= itemY0 + 58 and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                activeSlider = 'mainVol'
                local v = math.max(0, math.min(1, (x - (panelLeft + 30)) / (OPT_W - 60)))
                SETTING.mainVol = math.floor(v * 100) / 100
                love.audio.setVolume(SETTING.mainVol)
                saveSettings()
                return
            end
            -- Row 2: Music Volume Slider
            if y >= itemY0 + 64 and y <= itemY0 + 122 and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                activeSlider = 'bgm'
                local v = math.max(0, math.min(1, (x - (panelLeft + 30)) / (OPT_W - 60)))
                SETTING.bgm = math.floor(v * 100) / 100
                BGM.setVol(SETTING.bgm)
                saveSettings()
                return
            end
            -- Row 3: SFX Volume Slider
            if y >= itemY0 + 128 and y <= itemY0 + 186 and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                activeSlider = 'sfx'
                local v = math.max(0, math.min(1, (x - (panelLeft + 30)) / (OPT_W - 60)))
                SETTING.sfx = math.floor(v * 100) / 100
                SFX.setVol(SETTING.sfx)
                saveSettings()
                SFX.play('warn_1')
                return
            end
            -- Row 4: Auto Mute Toggle
            if y >= itemY0 + 192 and y <= itemY0 + 244 and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SETTING.autoMute = not SETTING.autoMute
                saveSettings()
                SFX.play('click')
                return
            end
            -- Row 5: Voice & Sound Packs
            if y >= itemY0 + 250 and y <= itemY0 + 302 and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SCN.go('setting_sound')
                return
            end

        elseif optTab == 'video' then
            -- Row 1: Active Piece Toggle
            if y >= itemY0 and y <= itemY0 + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SETTING.block = not SETTING.block
                saveSettings()
                SFX.play('click')
                return
            end
            -- Row 2: Smooth Falling Toggle
            if y >= itemY0 + stride and y <= itemY0 + stride + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SETTING.smooth = not SETTING.smooth
                saveSettings()
                SFX.play('click')
                return
            end
            -- Row 3: 3D Blocks Toggle
            if y >= itemY0 + stride * 2 and y <= itemY0 + stride * 2 + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SETTING.upEdge = not SETTING.upEdge
                saveSettings()
                SFX.play('click')
                return
            end
            -- Row 4: Fullscreen Toggle
            if y >= itemY0 + stride * 3 and y <= itemY0 + stride * 3 + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SETTING.fullscreen = not SETTING.fullscreen
                applySettings()
                saveSettings()
                SFX.play('click')
                return
            end
            -- Row 5: Skin Gallery
            if y >= itemY0 + stride * 4 and y <= itemY0 + stride * 4 + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SCN.go('skin_browse')
                return
            end
            -- Row 6: Advanced Video Settings
            if y >= itemY0 + stride * 5 and y <= itemY0 + stride * 5 + rowH and x >= panelLeft + 16 and x <= panelLeft + OPT_W - 16 then
                SCN.go('setting_video')
                return
            end
        end
        return
    end

    -- Console easter-egg on title
    if x >= 500 and x <= 780 and y >= 0 and y <= TB_H then
        enterConsole()
    end
end
scene.touchDown = scene.mouseDown

function scene.mouseMove(x, y)
    if activeSlider and love.mouse.isDown(1) then
        local panelLeft = 1280 - OPT_W * optAnim
        local v = math.max(0, math.min(1, (x - (panelLeft + 30)) / (OPT_W - 60)))
        v = math.floor(v * 100) / 100
        if activeSlider == 'mainVol' then
            SETTING.mainVol = v
            love.audio.setVolume(v)
        elseif activeSlider == 'bgm' then
            SETTING.bgm = v
            BGM.setVol(v)
        elseif activeSlider == 'sfx' then
            SETTING.sfx = v
            SFX.setVol(v)
        end
    end
end
scene.touchMove = scene.mouseMove

function scene.mouseUp(x, y)
    if activeSlider then
        if activeSlider == 'sfx' then
            SFX.play('warn_1')
        end
        saveSettings()
        activeSlider = nil
    end
end
scene.touchUp = scene.mouseUp

-- ════════════════════════════════════════════════════════════
--  KEYBOARD
-- ════════════════════════════════════════════════════════════
local function _testButton(W)
    if WIDGET.isFocus(W) then return true else WIDGET.focus(W) end
end

function scene.keyDown(key, isRep)
    if isRep then return true end

    -- Options sidebar closes on escape
    if optTarget == 1 and (key == 'escape' or key == 'backspace') then
        toggleOptions(false)
        return
    end

    if submenu then
        if     key == 'q'                         then if _testButton(scene.widgetList.qp_40l)    then loadGame('sprint_40l', true) end
        elseif key == 'w'                         then if _testButton(scene.widgetList.qp_sprint) then loadGame('sprint_100l', true) end
        elseif key == 'e'                         then if _testButton(scene.widgetList.qp_lock)   then loadGame('sprintLock', true) end
        elseif key == 'r'                         then if _testButton(scene.widgetList.offline)   then SCN.go('mode') end
        elseif key == 'escape' or key == 'backspace' then if _testButton(scene.widgetList.back)  then setSubmenu(false) end
        else return true
        end
    else
        if     key == '1'      then if _testButton(scene.widgetList.qplay)    then setSubmenu(true) end
        elseif key == 'a'      then if _testButton(scene.widgetList.online)   then if WS.status('game') == 'running' then SCN.go('lobby') else NET.login(true) end end
        elseif key == 'z'      then if _testButton(scene.widgetList.custom)   then SCN.go('customGame') end
        elseif key == 'p'      then if _testButton(scene.widgetList.stat)     then SCN.go('stat') end
        elseif key == ','      then if _testButton(scene.widgetList.replays)  then SCN.go('replays') end
        elseif key == '-'      then toggleOptions()
        elseif key == '2'      then if _testButton(scene.widgetList.music)    then SCN.go('music') end
        elseif key == '3'      then if _testButton(scene.widgetList.notice)   then NET.getNotice() end
        elseif key == '4'      then if _testButton(scene.widgetList.lang)     then SCN.go('lang') end
        elseif key == '5'      then if _testButton(scene.widgetList.skin)     then SCN.go('skin_browse') end
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
        elseif key == 'escape' then
            if tryBack() then VOC.play('bye') SCN.back() end
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

    -- Options sidebar animation
    optAnim = MATH.expApproach(optAnim, optTarget, dt * 14)

    -- Dynamic centering of demo board (centered at 640, smoothly adjusts if options open)
    local pCenterX = 640 - (optAnim * 38)
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

    -- ── Widget Positioning (Fixed Clean Placement) ─────────
    local L = scene.widgetList

    for i, n in ipairs(PRIM_NAV) do
        local W = L[n]
        W.x = MENU_X
        W.y = NAV0 + (i - 1) * STRIDE
    end
    for i, n in ipairs(SUB_NAV) do
        local W = L[n]
        W.x = MENU_X
        W.y = NAV0 + (i - 1) * STRIDE
    end

    -- Bottom action buttons
    L.about.x  = MENU_X
    L.about.y  = BTM_Y1
    L.manual.x = MENU_X + BTM_W + 10
    L.manual.y = BTM_Y1
    L.quit.x   = MENU_X
    L.quit.y   = BTM_Y2

    -- Top bar icons (always visible)
    for i, n in ipairs(TB_ICONS) do
        L[n].x = TB_ICON_X[i]
        L[n].y = TB_ICON_Y
    end

    -- Matchmaking popup fade
    if NET.matchFoundPending then
        searchPopupAlpha = math.max(0, searchPopupAlpha - dt * 6)
    elseif NET.matchmaking then
        searchPopupAlpha = math.min(1, searchPopupAlpha + dt * 6)
    else
        searchPopupAlpha = math.max(0, searchPopupAlpha - dt * 6)
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
    local hints = submenu and {'[Q]','[W]','[E]','[R]','[Esc]'} or KEY_HINTS
    local navList = submenu and SUB_NAV or PRIM_NAV
    for i, _ in ipairs(navList) do
        local by = NAV0 + (i - 1) * STRIDE
        GC.setColor(1, 1, 1, .28)
        setFont(11)
        GC.print(hints[i] or '', MENU_X + BW - 18 - #(hints[i] or '') * 6, by + BH - 14)
    end
end

-- ─── drawTopBar ──────────────────────────────────────────────
local function drawTopBar(t)
    local W = 1280

    -- Top bar glass backdrop
    GC.setColor(.035, .045, .10, .96)
    GC.rectangle('fill', 0, 0, W, TB_H)

    -- Rainbow spectrum line at the bottom
    local segW = W / 7
    for i = 1, 7 do
        local c = BCL[i]
        GC.setColor(c[1], c[2], c[3], .85)
        GC.rectangle('fill', (i - 1) * segW, TB_H - 2, segW + 1, 2)
    end

    -- ── User Profile Pill (Top-Left of Top Bar) ──────────────
    local profX, profY, profW, profH = 10, 6, 210, 40
    local mx, my = love.mouse.getPosition()
    local isHoverProf = (mx >= profX and mx <= profX + profW and my >= profY and my <= profY + profH)

    if isHoverProf then
        GC.setColor(.16, .22, .44, .70)
        GC.rectangle('fill', profX, profY, profW, profH, 6)
    else
        GC.setColor(.08, .11, .24, .50)
        GC.rectangle('fill', profX, profY, profW, profH, 6)
    end
    GC.setColor(.22, .28, .52, .50)
    GC.setLineWidth(1)
    GC.rectangle('line', profX, profY, profW, profH, 6)

    local uid      = USER and USER.uid
    local uname    = uid and USERS and USERS[uid] and USERS[uid].username or nil
    local isLogged = uid and uid ~= false

    -- Avatar circular frame
    local avX, avY, avR = profX + 20, profY + profH * .5, 14
    if isLogged and USERS and USERS[uid] and USERS.getAvatar then
        local img = USERS.getAvatar(uid)
        if img then
            GC.setColor(1, 1, 1, 1)
            GC.stencil(function() GC.circle('fill', avX, avY, avR) end, 'replace', 1)
            GC.setStencilTest('equal', 1)
            GC.draw(img, avX - avR, avY - avR, 0, (avR * 2) / 128)
            GC.setStencilTest()
        end
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

    -- Username and Status
    local tx = profX + 42
    if isLogged and uname then
        GC.setColor(.95, .97, 1, .95)
        setFont(14)
        GC.print(uname, tx, profY + 5)
        -- Online indicator dot
        GC.setColor(.22, .95, .45, 1)
        GC.circle('fill', tx + math.min(#uname * 8 + 8, profW - 60), profY + 12, 3)
        GC.setColor(.55, .65, .85, .75)
        setFont(11)
        GC.print("Account (Click)", tx, profY + 22)
    else
        GC.setColor(.88, .92, 1, .9)
        setFont(14)
        GC.print("Guest Player", tx, profY + 5)
        GC.setColor(.50, .60, .82, .75)
        setFont(11)
        GC.print("Sign In [A]", tx, profY + 22)
    end

    -- ── Title Logo & Version (Centered) ──────────────────────
    GC.setColor(1, 1, 1, .95)
    mDraw(TEXTURE.title_color, 640, 21, nil, .22)

    GC.setColor(.48, .55, .72, .85)
    setFont(11)
    GC.mStr(verName, 640, 36)
end

-- ─── drawOptionsSidebar ──────────────────────────────────────
local function drawOptionsSidebar(t)
    if optAnim < 0.005 then return end

    local panelLeft = 1280 - OPT_W * optAnim
    local alpha = optAnim
    local mx, my = love.mouse.getPosition()

    -- Dim background layer
    GC.setColor(0, 0, 0, alpha * 0.45)
    GC.rectangle('fill', 0, TB_H, 1280, 720 - TB_H)

    -- Sidebar background
    GC.setColor(.05, .06, .14, alpha * 0.98)
    GC.rectangle('fill', panelLeft, TB_H, OPT_W, 720 - TB_H)

    -- Left border glowing accent line
    GC.setColor(.24, .36, .75, alpha * 0.85)
    GC.setLineWidth(2)
    GC.line(panelLeft, TB_H, panelLeft, 720)

    -- Header
    GC.setColor(.90, .94, 1, alpha)
    setFont(18)
    GC.print("OPTIONS & SETTINGS", panelLeft + 20, TB_H + 16)

    -- Close [✕] Button
    local isCloseHover = (mx >= 1280 - 45 and mx <= 1280 - 15 and my >= TB_H + 10 and my <= TB_H + 42)
    if isCloseHover then
        GC.setColor(1, .35, .45, alpha)
    else
        GC.setColor(.60, .68, .88, alpha * 0.85)
    end
    setFont(20)
    GC.mStr("✕", 1280 - 28, TB_H + 14)

    -- Tabs bar: General, Audio, Video
    local tabY = TB_H + 50
    local tabH = 30
    local tabs = {
        { id = 'general', label = "General", x = panelLeft + 16,  w = 96 },
        { id = 'audio',   label = "Audio",   x = panelLeft + 118, w = 96 },
        { id = 'video',   label = "Video",   x = panelLeft + 220, w = 96 },
    }

    for _, tb in ipairs(tabs) do
        local isCur = (optTab == tb.id)
        local isHover = (mx >= tb.x and mx <= tb.x + tb.w and my >= tabY and my <= tabY + tabH)
        if isCur then
            GC.setColor(.22, .34, .75, alpha * 0.9)
            GC.rectangle('fill', tb.x, tabY, tb.w, tabH, 5)
            GC.setColor(.45, .70, 1, alpha)
            GC.setLineWidth(1.5)
            GC.rectangle('line', tb.x, tabY, tb.w, tabH, 5)
            GC.setColor(1, 1, 1, alpha)
        elseif isHover then
            GC.setColor(.14, .18, .36, alpha * 0.75)
            GC.rectangle('fill', tb.x, tabY, tb.w, tabH, 5)
            GC.setColor(.35, .45, .80, alpha * 0.6)
            GC.setLineWidth(1)
            GC.rectangle('line', tb.x, tabY, tb.w, tabH, 5)
            GC.setColor(.85, .90, 1, alpha * 0.9)
        else
            GC.setColor(.08, .11, .24, alpha * 0.55)
            GC.rectangle('fill', tb.x, tabY, tb.w, tabH, 5)
            GC.setColor(.18, .22, .42, alpha * 0.4)
            GC.setLineWidth(1)
            GC.rectangle('line', tb.x, tabY, tb.w, tabH, 5)
            GC.setColor(.60, .68, .85, alpha * 0.75)
        end
        setFont(13)
        GC.mStr(tb.label, tb.x + tb.w * 0.5, tabY + 7)
    end

    -- Tab Content Controls
    local itemY0 = TB_H + 92
    local itemW  = OPT_W - 32
    local itemX  = panelLeft + 16

    local function drawCard(rx, ry, rw, rh, isHover)
        if isHover then
            GC.setColor(.16, .22, .44, alpha * 0.85)
            GC.rectangle('fill', rx, ry, rw, rh, 6)
            GC.setColor(.35, .50, .90, alpha * 0.75)
            GC.setLineWidth(1)
            GC.rectangle('line', rx, ry, rw, rh, 6)
        else
            GC.setColor(.09, .12, .25, alpha * 0.65)
            GC.rectangle('fill', rx, ry, rw, rh, 6)
            GC.setColor(.18, .22, .42, alpha * 0.40)
            GC.setLineWidth(1)
            GC.rectangle('line', rx, ry, rw, rh, 6)
        end
    end

    local function drawSwitch(rx, ry, rw, rh, isOn)
        local sw, sh = 44, 22
        local sx, sy = rx + rw - sw - 12, ry + (rh - sh) * 0.5
        if isOn then
            GC.setColor(.18, .75, .42, alpha * 0.9)
        else
            GC.setColor(.22, .26, .38, alpha * 0.7)
        end
        GC.rectangle('fill', sx, sy, sw, sh, sh * 0.5)
        local knobX = isOn and (sx + sw - sh + 2) or (sx + 2)
        local knobY = sy + 2
        local knobD = sh - 4
        GC.setColor(1, 1, 1, alpha)
        GC.circle('fill', knobX + knobD * 0.5, knobY + knobD * 0.5, knobD * 0.5)
        setFont(11)
        if isOn then
            GC.setColor(.3, .95, .5, alpha)
            GC.print("ON", sx - 26, sy + 3)
        else
            GC.setColor(.6, .65, .75, alpha * 0.8)
            GC.print("OFF", sx - 28, sy + 3)
        end
    end

    local function drawSliderCtrl(rx, ry, rw, rh, val, label, isHover)
        drawCard(rx, ry, rw, rh, isHover)
        GC.setColor(.92, .96, 1, alpha * 0.95)
        setFont(14)
        GC.print(label, rx + 14, ry + 8)
        local pct = ("%d%%"):format(math.floor(val * 100))
        setFont(13)
        GC.setColor(.55, .78, 1, alpha * 0.9)
        GC.mStr(pct, rx + rw - 30, ry + 8)

        local trackX = rx + 14
        local trackY = ry + 34
        local trackW = rw - 28
        local trackH = 8
        GC.setColor(.14, .18, .32, alpha * 0.85)
        GC.rectangle('fill', trackX, trackY, trackW, trackH, 4)

        local fillW = math.max(0, math.min(trackW, trackW * val))
        if fillW > 0 then
            GC.setColor(.32, .68, 1, alpha * 0.95)
            GC.rectangle('fill', trackX, trackY, fillW, trackH, 4)
        end
        local knobX = trackX + fillW
        local knobY = trackY + trackH * 0.5
        GC.setColor(1, 1, 1, alpha)
        GC.circle('fill', knobX, knobY, 7)
        GC.setColor(.22, .45, .88, alpha * 0.85)
        GC.setLineWidth(1.5)
        GC.circle('line', knobX, knobY, 7)
    end

    if optTab == 'general' then
        local stride = 58
        local rowH   = 52
        local genRows = {
            {
                title = "Rotation System",
                sub   = "Piece rotation rule",
                badge = "[ " .. tostring(SETTING.RS or 'TRS') .. " ]",
                badgeCol = COLOR.lY,
            },
            {
                title = "Auto Pause",
                sub   = "Pause when window unfocused",
                isSwitch = true,
                val   = SETTING.autoPause,
            },
            {
                title = "Auto Save Records",
                sub   = "Save replays on game over",
                isSwitch = true,
                val   = SETTING.autoSave,
            },
            {
                title = "Simplistic Mode",
                sub   = "Clean distraction-free menu",
                isSwitch = true,
                val   = SETTING.simpMode,
            },
            {
                title = "Keyboard Controls",
                sub   = "Customize game keys",
                badge = "Configure →",
                badgeCol = COLOR.lC,
            },
            {
                title = "Handling & Tuning",
                sub   = "DAS, ARR, SD-ARR, Finesse",
                badge = "Advanced →",
                badgeCol = COLOR.lM,
            },
        }

        for idx, row in ipairs(genRows) do
            local ry = itemY0 + (idx - 1) * stride
            local isHover = (mx >= itemX and mx <= itemX + itemW and my >= ry and my <= ry + rowH)
            drawCard(itemX, ry, itemW, rowH, isHover)

            GC.setColor(.92, .96, 1, alpha * 0.95)
            setFont(14)
            GC.print(row.title, itemX + 14, ry + 7)

            GC.setColor(.55, .62, .80, alpha * 0.75)
            setFont(11)
            GC.print(row.sub, itemX + 14, ry + 28)

            if row.isSwitch then
                drawSwitch(itemX, ry, itemW, rowH, row.val)
            elseif row.badge then
                local bc = row.badgeCol or COLOR.lC
                GC.setColor(bc[1], bc[2], bc[3], alpha * 0.9)
                setFont(12)
                GC.mStr(row.badge, itemX + itemW - 48, ry + 16)
            end
        end

    elseif optTab == 'audio' then
        local isHov1 = (mx >= itemX and mx <= itemX + itemW and my >= itemY0 and my <= itemY0 + 58)
        drawSliderCtrl(itemX, itemY0, itemW, 58, SETTING.mainVol or 1, "Master Volume", isHov1)

        local isHov2 = (mx >= itemX and mx <= itemX + itemW and my >= itemY0 + 64 and my <= itemY0 + 122)
        drawSliderCtrl(itemX, itemY0 + 64, itemW, 58, SETTING.bgm or 1, "Music (BGM)", isHov2)

        local isHov3 = (mx >= itemX and mx <= itemX + itemW and my >= itemY0 + 128 and my <= itemY0 + 186)
        drawSliderCtrl(itemX, itemY0 + 128, itemW, 58, SETTING.sfx or 1, "Sound Effects", isHov3)

        -- Auto Mute
        local ry4 = itemY0 + 192
        local isHov4 = (mx >= itemX and mx <= itemX + itemW and my >= ry4 and my <= ry4 + 52)
        drawCard(itemX, ry4, itemW, 52, isHov4)
        GC.setColor(.92, .96, 1, alpha * 0.95)
        setFont(14)
        GC.print("Auto Mute", itemX + 14, ry4 + 7)
        GC.setColor(.55, .62, .80, alpha * 0.75)
        setFont(11)
        GC.print("Mute audio on focus loss", itemX + 14, ry4 + 28)
        drawSwitch(itemX, ry4, itemW, 52, SETTING.autoMute)

        -- Sound Scene
        local ry5 = itemY0 + 250
        local isHov5 = (mx >= itemX and mx <= itemX + itemW and my >= ry5 and my <= ry5 + 52)
        drawCard(itemX, ry5, itemW, 52, isHov5)
        GC.setColor(.92, .96, 1, alpha * 0.95)
        setFont(14)
        GC.print("Voice & Sound Packs", itemX + 14, ry5 + 7)
        GC.setColor(.55, .62, .80, alpha * 0.75)
        setFont(11)
        GC.print("Voice packs, stereo, alert SFX", itemX + 14, ry5 + 28)
        GC.setColor(COLOR.lY[1], COLOR.lY[2], COLOR.lY[3], alpha * 0.9)
        setFont(12)
        GC.mStr("Sound Scene →", itemX + itemW - 54, ry5 + 16)

    elseif optTab == 'video' then
        local stride = 58
        local rowH   = 52
        local vidRows = {
            {
                title = "Active Piece",
                sub   = "Show falling active tetromino",
                isSwitch = true,
                val   = SETTING.block,
            },
            {
                title = "Smooth Falling",
                sub   = "Sub-pixel smooth fall movement",
                isSwitch = true,
                val   = SETTING.smooth,
            },
            {
                title = "3D Block Edges",
                sub   = "Isometric bevel edge lighting",
                isSwitch = true,
                val   = SETTING.upEdge,
            },
            {
                title = "Fullscreen Mode",
                sub   = "Toggle borderless / fullscreen",
                isSwitch = true,
                val   = SETTING.fullscreen,
            },
            {
                title = "Skin & Textures",
                sub   = "Current: " .. tostring(SETTING.skinSet or 'default'),
                badge = "Browse Skins →",
                badgeCol = COLOR.lP,
            },
            {
                title = "Visual Effects",
                sub   = "Ghost piece, grid, shaders",
                badge = "Advanced →",
                badgeCol = COLOR.lC,
            },
        }

        for idx, row in ipairs(vidRows) do
            local ry = itemY0 + (idx - 1) * stride
            local isHover = (mx >= itemX and mx <= itemX + itemW and my >= ry and my <= ry + rowH)
            drawCard(itemX, ry, itemW, rowH, isHover)

            GC.setColor(.92, .96, 1, alpha * 0.95)
            setFont(14)
            GC.print(row.title, itemX + 14, ry + 7)

            GC.setColor(.55, .62, .80, alpha * 0.75)
            setFont(11)
            GC.print(row.sub, itemX + 14, ry + 28)

            if row.isSwitch then
                drawSwitch(itemX, ry, itemW, rowH, row.val)
            elseif row.badge then
                local bc = row.badgeCol or COLOR.lC
                GC.setColor(bc[1], bc[2], bc[3], alpha * 0.9)
                setFont(12)
                GC.mStr(row.badge, itemX + itemW - 54, ry + 16)
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
    drawOptionsSidebar(t)

    if flash > 0 then
        GC.replaceTransform(SCR.origin)
        GC.setColor(1, 1, 1, flash)
        GC.rectangle('fill', 0, 0, SCR.w, SCR.h)
        GC.replaceTransform(SCR.xOy)
    end

    if searchPopupAlpha > .01 then
        GC.setColor(COLOR.lY[1], COLOR.lY[2], COLOR.lY[3], searchPopupAlpha * .85)
        FONT.set(18)
        GC.mStr("Ranked match searching...", 790, 648)
        if NET.searchTimer then
            GC.setColor(COLOR.lH[1], COLOR.lH[2], COLOR.lH[3], searchPopupAlpha * .70)
            GC.mStr(("Elapsed: %.1fs"):format(NET.searchTimer), 790, 668)
        end
    end
end

-- ════════════════════════════════════════════════════════════
--  WIDGET LIST
-- ════════════════════════════════════════════════════════════
scene.widgetList = {
    -- Primary Navigation (Always visible on screen)
    WIDGET.newButton{name='qplay',    x=MENU_X, y=NAV0+0*STRIDE+BH*.5, w=BW, h=BH, color='lR', font=28, align='L', edge=12, code=pressKey'1'},
    WIDGET.newButton{name='online',   x=MENU_X, y=NAV0+1*STRIDE+BH*.5, w=BW, h=BH, color='lV', font=28, align='L', edge=12, code=pressKey'a'},
    WIDGET.newButton{name='custom',   x=MENU_X, y=NAV0+2*STRIDE+BH*.5, w=BW, h=BH, color='lS', font=28, align='L', edge=12, code=pressKey'z'},
    WIDGET.newButton{name='settings', x=MENU_X, y=NAV0+3*STRIDE+BH*.5, w=BW, h=BH, color='lO', font=28, align='L', edge=12, code=function() toggleOptions() end},
    WIDGET.newButton{name='stat',     x=MENU_X, y=NAV0+4*STRIDE+BH*.5, w=BW, h=BH, color='lL', font=26, align='L', edge=12, code=pressKey'p'},
    WIDGET.newButton{name='replays',  x=MENU_X, y=NAV0+5*STRIDE+BH*.5, w=BW, h=BH, color='lC', font=26, align='L', edge=12, code=pressKey','},

    -- Quick-Play Sub-Menu
    WIDGET.newButton{name='qp_40l',    x=MENU_X, y=NAV0+0*STRIDE+BH*.5, w=BW, h=BH, color='lM', font=26, align='L', edge=12, code=pressKey'q',      hide=true},
    WIDGET.newButton{name='qp_sprint', x=MENU_X, y=NAV0+1*STRIDE+BH*.5, w=BW, h=BH, color='lM', font=26, align='L', edge=12, code=pressKey'w',      hide=true},
    WIDGET.newButton{name='qp_lock',   x=MENU_X, y=NAV0+2*STRIDE+BH*.5, w=BW, h=BH, color='lM', font=26, align='L', edge=12, code=pressKey'e',      hide=true},
    WIDGET.newButton{name='offline',   x=MENU_X, y=NAV0+3*STRIDE+BH*.5, w=BW, h=BH, color='lY', font=26, align='L', edge=12, code=pressKey'r',      hide=true},
    WIDGET.newButton{name='back',      x=MENU_X, y=NAV0+4*STRIDE+BH*.5, w=BW, h=BH, color='lB', font=26, align='L', edge=12, code=pressKey'escape', hide=true},

    -- Bottom actions
    WIDGET.newButton{name='about',  x=MENU_X, y=BTM_Y1+BTM_H*.5, w=BTM_W, h=BTM_H, color='lB', align='M', edge=6, code=pressKey'x', font=22, fText=CHAR.icon.info},
    WIDGET.newButton{name='manual', x=MENU_X+BTM_W+10, y=BTM_Y1+BTM_H*.5, w=BTM_W, h=BTM_H, color='lR', align='M', edge=6, code=pressKey'h', font=22, fText=CHAR.icon.help},
    WIDGET.newButton{name='quit',   x=MENU_X, y=BTM_Y2+BTM_H*.5, w=BW,    h=BTM_H, color='lH', align='M', edge=6, font=20, fText="Quit Game", code=function() if tryBack() then VOC.play('bye') SCN.back() end end},

    -- Top-bar icon buttons
    WIDGET.newButton{name='skin',   x=TB_ICON_X[1]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lP', code=function() SCN.go('skin_browse') end, font=22, fText=CHAR.mino.T},
    WIDGET.newButton{name='music',  x=TB_ICON_X[2]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lY', code=pressKey'2', font=24, fText=CHAR.icon.music},
    WIDGET.newButton{name='notice', x=TB_ICON_X[3]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lG', code=pressKey'3', font=24, fText=CHAR.key.winMenu},
    WIDGET.newButton{name='lang',   x=TB_ICON_X[4]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lN', code=pressKey'4', font=24, fText=CHAR.icon.language},
    WIDGET.newButton{name='dict',   x=TB_ICON_X[5]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lC', code=pressKey'b', font=24, fText=CHAR.icon.zBook},
}

return scene
