local scene = {}

--[[
    MAIN SCENE - Reworked with persistent top bar + sliding left sidebar
    Block-stacking game themed UI:
      • Top bar always visible; Ctrl+T (or click hamburger) toggles sidebar
      • Left sidebar slides in/out, containing all navigation options
      • Animated falling block particles inside sidebar backdrop
      • Block-grid strip decorates the sidebar's right edge
      • Rainbow spectrum border at the bottom of the top bar
]]

-- ════════════════════════════════════════════════════════════
--  LAYOUT CONSTANTS
-- ════════════════════════════════════════════════════════════
local SIDEBAR_W = 290       -- Sidebar panel width (px)
local TB_H      = 52        -- Top bar height (px)
local BW        = SIDEBAR_W - 18  -- Nav button width
local BH        = 70        -- Nav button height
local B_GAP     = 8         -- Gap between nav buttons
local SB_HIDE   = -(SIDEBAR_W + 20) -- Off-screen left target

-- Nav button grid start (y of first button)
local NAV0   = TB_H + 36   -- leaves a small header gap below top bar
local STRIDE = BH + B_GAP  -- vertical stride between nav buttons

-- Bottom sidebar buttons (About / Manual)
local BTM_Y1 = 616
local BTM_Y2 = 665
local BTM_W  = BW
local BTM_H  = 44

-- Top-bar icon buttons (small, fixed at top right)
local TB_ICONS   = {'music','notice','lang','dict'}
local TB_ICON_X  = {1096, 1142, 1188, 1234}  -- each 40 wide, 6px gap
local TB_ICON_Y  = 6
local TB_ICON_SZ = 40

-- ════════════════════════════════════════════════════════════
--  TETROMINO BLOCK COLOR PALETTE (7 types)
-- ════════════════════════════════════════════════════════════
local BCL = {
    COLOR.lR,  -- 1  Z / red
    COLOR.lS,  -- 2  S / sea-green
    COLOR.lV,  -- 3  J / violet
    COLOR.lO,  -- 4  L / orange
    COLOR.lM,  -- 5  T / magenta
    COLOR.lY,  -- 6  O / yellow
    COLOR.lC,  -- 7  I / cyan
}

-- ════════════════════════════════════════════════════════════
--  TIP / VERSION
-- ════════════════════════════════════════════════════════════
local verName = ("%s  %s  %s"):format(SYSTEM, VERSION.string, VERSION.name)
local tipW    = 820   -- width of the tip scroll area
local tip     = GC.newText(getFont(24), "")
local scrollX = tipW
local flash   = 0

-- ════════════════════════════════════════════════════════════
--  SIDEBAR STATE
-- ════════════════════════════════════════════════════════════
local sidebarOpen = true
local sidebarX    = 0          -- 0 = fully open; SB_HIDE = fully closed
local sbTarget    = 0

local function setSidebar(v)
    sidebarOpen = v
    sbTarget    = v and 0 or SB_HIDE
end

-- ════════════════════════════════════════════════════════════
--  QUICK-PLAY SUBMENU
-- ════════════════════════════════════════════════════════════
local submenu          = false
local searchPopupAlpha = 0

local PRIM_NAV = {'qplay','online','custom','settings','stat','replays'}
local SUB_NAV  = {'qp_40l','qp_sprint','qp_lock','offline','back'}

local function setSubmenu(v)
    submenu = v
    for _, n in next, PRIM_NAV do scene.widgetList[n].hide = v     end
    for _, n in next, SUB_NAV  do scene.widgetList[n].hide = not v  end
end

-- ════════════════════════════════════════════════════════════
--  DECORATIVE FALLING BLOCK PARTICLES
-- ════════════════════════════════════════════════════════════
local fallers  = {}
local N_FALL   = 22

local function spawnFaller(i, scatter)
    local sz = math.random(10, 22)
    fallers[i] = {
        x     = math.random(4, SIDEBAR_W - sz - 4),
        y     = scatter and math.random(-400, 720) or -(sz + math.random(10, 60)),
        sz    = sz,
        speed = math.random(8, 38),
        col   = math.random(1, 7),
        rot   = math.random() * 6.283,
        rs    = (math.random() > .5 and 1 or -1) * (math.random() * .55 + .05),
        alpha = math.random(18, 58) * .01,
    }
end

local function initFallers()
    for i = 1, N_FALL do spawnFaller(i, true) end
end

-- ════════════════════════════════════════════════════════════
--  BLOCK-GRID STRIP DECORATION (sidebar right edge)
-- ════════════════════════════════════════════════════════════
local DC         = 13         -- decoration cell size (px)
local STRIP_COLS = 3          -- columns in the strip
local STRIP_ROWS = math.ceil(720 / DC) + 2
local stripGrid  = {}

local function buildStrip()
    local palette = {1,2,3,4,5,6,7,0,0,0,0,0}
    stripGrid = {}
    for r = 1, STRIP_ROWS do
        stripGrid[r] = {}
        local density = 0.20 + 0.60 * (r / STRIP_ROWS)
        for c = 1, STRIP_COLS do
            local v = palette[math.random(#palette)]
            stripGrid[r][c] = math.random() < density and v or 0
        end
    end
end

-- ════════════════════════════════════════════════════════════
--  CONSOLE EASTER-EGG  (unchanged from original)
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
    -- Shift demo player rightward so it's centred in the area beside the sidebar
    PLAYERS[1]:setPosition(760, 155, .76)
    DiscordRPC.update("In Main Menu")
    setSubmenu(false)
    -- Sidebar starts open
    setSidebar(true)
    sidebarX = 0
    initFallers()
    buildStrip()
end

function scene.resize() end

function scene.mouseDown(x, y)
    -- Hamburger hit-area: top-left corner of top bar
    if x >= 4 and x <= 50 and y >= 4 and y <= TB_H - 4 then
        setSidebar(not sidebarOpen)
        return
    end
    -- Console easter-egg: click the title region
    if x >= 400 and x <= 880 and y >= TB_H and y <= TB_H + 130 then
        enterConsole()
    end
end
scene.touchDown = scene.mouseDown

-- ════════════════════════════════════════════════════════════
--  KEYBOARD HANDLER
-- ════════════════════════════════════════════════════════════
local function _testButton(W)
    if WIDGET.isFocus(W) then return true
    else WIDGET.focus(W) end
end

function scene.keyDown(key, isRep)
    if isRep then return true end

    -- Ctrl+T: toggle sidebar
    if key == 't' and love.keyboard.isDown('lctrl','rctrl') then
        setSidebar(not sidebarOpen)
        return
    end

    if submenu then
        if     key=='q'                         then if _testButton(scene.widgetList.qp_40l)   then loadGame('sprint_40l',  true) end
        elseif key=='w'                         then if _testButton(scene.widgetList.qp_sprint) then loadGame('sprint_100l', true) end
        elseif key=='e'                         then if _testButton(scene.widgetList.qp_lock)   then loadGame('sprintLock',  true) end
        elseif key=='r'                         then if _testButton(scene.widgetList.offline)   then SCN.go('mode')                end
        elseif key=='escape' or key=='backspace' then if _testButton(scene.widgetList.back)      then setSubmenu(false)            end
        else return true
        end
    else
        if     key=='1'   then if _testButton(scene.widgetList.qplay)    then setSubmenu(true)                                        end
        elseif key=='a'   then if _testButton(scene.widgetList.online)   then NET.login(true)                                         end
        elseif key=='z'   then if _testButton(scene.widgetList.custom)   then SCN.go('customGame')                                    end
        elseif key=='p'   then if _testButton(scene.widgetList.stat)     then SCN.go('stat')                                          end
        elseif key==','   then if _testButton(scene.widgetList.replays)  then SCN.go('replays')                                       end
        elseif key=='-'   then if _testButton(scene.widgetList.settings) then SCN.go('setting_game')                                  end
        elseif key=='2'   then if _testButton(scene.widgetList.music)    then SCN.go('music')                                         end
        elseif key=='3'   then if _testButton(scene.widgetList.notice)   then NET.getNotice()                                         end
        elseif key=='4'   then if _testButton(scene.widgetList.lang)     then SCN.go('lang')                                          end
        elseif key=='x'   then if _testButton(scene.widgetList.about)    then SCN.go('about')                                         end
        elseif key=='h'   then
            if _testButton(scene.widgetList.manual) then
                SCN.go('textReader', nil,
                    FILE.load('parts/language/manual_'..(
                        SETTING.locale:find'zh' and 'zh' or
                        SETTING.locale:find'ja' and 'ja' or
                        SETTING.locale:find'vi' and 'vi' or 'en'
                    )..'.txt','-string'):split('\n'), 15, 'cubes')
            end
        elseif key=='b'   then if _testButton(scene.widgetList.dict)     then SCN.go('dict')                                          end
        elseif key=='c'   then enterConsole()
        elseif key=='escape' then
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

    PLAYERS[1]:update(dt)

    -- Tip scroll
    scrollX = scrollX - 148 * dt
    if scrollX < -tip:getWidth() then
        scrollX = tipW
        tip:set(text.getTip())
    end

    -- Animate sidebar toward target
    sidebarX = MATH.expApproach(sidebarX, sbTarget, dt * 10)

    -- Animate falling block particles
    for i = 1, #fallers do
        local f = fallers[i]
        f.y   = f.y + f.speed * dt
        f.rot = f.rot + f.rs * dt
        if f.y > 740 then spawnFaller(i, false) end
    end

    -- ── Position all widgets ───────────────────────────────
    local L  = scene.widgetList
    local SX = math.floor(sidebarX)  -- sidebar screen-left (pixel)
    -- Widget x,y in newButton are the CENTER; but after creation the stored
    -- .x is already left-edge (= center - w/2).  We therefore set .x directly
    -- as the left-edge here.
    local BX = SX + 9               -- left-edge of nav buttons inside sidebar

    -- Primary nav buttons
    for i, n in ipairs(PRIM_NAV) do
        local W = L[n]
        W.x = BX
        W.y = NAV0 + (i - 1) * STRIDE
    end
    -- Sub-menu nav buttons (same y-layout, different names)
    for i, n in ipairs(SUB_NAV) do
        local W = L[n]
        W.x = BX
        W.y = NAV0 + (i - 1) * STRIDE
    end
    -- Bottom sidebar buttons
    L.about.x  = BX;  L.about.y  = BTM_Y1
    L.manual.x = BX;  L.manual.y = BTM_Y2

    -- Top-bar icon buttons (fixed position, independent of sidebar)
    for i, n in ipairs(TB_ICONS) do
        local W = L[n]
        W.x = TB_ICON_X[i]
        W.y = TB_ICON_Y
    end

    -- Matchmaking search popup fade
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

-- Stencil function for clipping sidebar content
local _sbSX, _sbSW = 0, SIDEBAR_W
local function _sidebarStencil()
    GC.rectangle('fill', _sbSX, 0, _sbSW, 720)
end

-- Stencil for clipping the tip scroll box
local function _tipStencil()
    GC.rectangle('fill', 0, 0, tipW, 36)
end

-- ─── drawTopBar ──────────────────────────────────────────────
local function drawTopBar(t)
    local W = 1280

    -- Dark background panel
    GC.setColor(.04, .05, .12, .97)
    GC.rectangle('fill', 0, 0, W, TB_H)

    -- ── Rainbow block-color spectrum strip at bottom of top bar ──
    local segW = W / 7
    for i = 1, 7 do
        local c = BCL[i]
        GC.setColor(c[1], c[2], c[3], .90)
        GC.rectangle('fill', (i-1)*segW, TB_H - 3, segW + 1, 3)
    end

    -- ── Subtle block-grid accent in top-bar background ──
    -- Small 8×8 blocks tiled with low opacity
    for col = 0, math.floor(W / 10) do
        for row = 0, math.floor(TB_H / 10) do
            local idx = (col + row * 3) % 7 + 1
            local c = BCL[idx]
            GC.setColor(c[1], c[2], c[3], .04)
            GC.rectangle('fill', col*10, row*10, 9, 9, 1)
        end
    end

    -- ── Hamburger icon (3 bars) at top-left ──
    local hx, hy0 = 14, 14
    GC.setColor(.88, .92, .98, .92)
    GC.setLineWidth(2.5)
    for row = 0, 2 do
        GC.line(hx, hy0 + row * 9, hx + 22, hy0 + row * 9)
    end

    -- ── Game logo centred in top bar ──
    GC.setColor(1, 1, 1, .95)
    mDraw(TEXTURE.title_color, 640, TB_H * .5 + 1, nil, .27)

    -- ── Version string (small, under logo) ──
    GC.setColor(.42, .46, .58, .85)
    setFont(13)
    GC.mStr(verName, 640, TB_H - 13)
end

-- ─── drawSidebar ─────────────────────────────────────────────
local function drawSidebar(t)
    local SX  = math.floor(sidebarX)
    local SW  = SIDEBAR_W
    local H   = 720

    -- ── Main panel background ──
    GC.setColor(.04, .05, .11, .97)
    GC.rectangle('fill', SX, 0, SW, H)

    -- ── Block-grid strip decoration on the right edge ──
    local stripX = SX + SW - STRIP_COLS * DC
    for r = 1, #stripGrid do
        for c = 1, STRIP_COLS do
            local v = stripGrid[r][c]
            if v > 0 then
                local bc = BCL[v]
                GC.setColor(bc[1], bc[2], bc[3], .20)
                GC.rectangle('fill',
                    stripX + (c-1)*DC + 1,
                    (r-1)*DC + 1,
                    DC - 2, DC - 2, 2)
                -- Inner highlight
                GC.setColor(bc[1], bc[2], bc[3], .08)
                GC.rectangle('fill',
                    stripX + (c-1)*DC + 2,
                    (r-1)*DC + 2,
                    (DC-4)*.55, (DC-4)*.55)
            end
        end
    end

    -- ── Clip falling particles to sidebar bounds ──
    _sbSX, _sbSW = SX, SW
    GC.stencil(_sidebarStencil, 'replace', 1)
    GC.setStencilTest('equal', 1)

    for i = 1, #fallers do
        local f  = fallers[i]
        local bc = BCL[f.col]
        GC.setColor(bc[1], bc[2], bc[3], f.alpha)
        GC.push('transform')
        GC.translate(SX + f.x + f.sz*.5, f.y + f.sz*.5)
        GC.rotate(f.rot)
        GC.rectangle('fill', -f.sz*.5, -f.sz*.5, f.sz, f.sz, 3)
        -- Mini inner shine
        GC.setColor(1, 1, 1, f.alpha * .35)
        GC.rectangle('fill', -f.sz*.5 + 2, -f.sz*.5 + 2, f.sz*.45, f.sz*.35, 2)
        GC.pop()
    end

    GC.setStencilTest()

    -- ── Animated colour shimmer on the right edge ──
    local rightEdge = SX + SW - STRIP_COLS * DC - 1
    local phase     = (t * .35) % 1
    GC.setLineWidth(2)
    for seg = 0, 8 do
        local c  = BCL[(seg + math.floor(t * .8)) % 7 + 1]
        local sy = (seg * 89 + phase * 720) % 720
        local ey = math.min(sy + 60, 720)
        GC.setColor(c[1], c[2], c[3], .55)
        GC.line(rightEdge, sy, rightEdge, ey)
    end

    -- ── "NAVIGATION" sub-header ──
    local visAlpha = math.max(0, math.min(1, (sidebarX - SB_HIDE) / (0 - SB_HIDE)))
    if visAlpha > .01 then
        GC.setColor(.5, .58, .78, visAlpha * .65)
        setFont(12)
        GC.mStr("NAVIGATION", SX + (SW - STRIP_COLS * DC) * .5, TB_H + 10)
    end

    -- ── Separator between top-bar area and nav items ──
    GC.setColor(.18, .22, .42, .55)
    GC.setLineWidth(1)
    GC.line(SX + 6, TB_H + 28, SX + SW - STRIP_COLS*DC - 6, TB_H + 28)

    -- ── Separator between nav buttons and bottom items ──
    local sepY = BTM_Y1 - 10
    GC.setColor(.18, .22, .42, .45)
    GC.line(SX + 6, sepY, SX + SW - STRIP_COLS*DC - 6, sepY)

    -- ── Drop-shadow to the right of the sidebar ──
    for i = 1, 12 do
        local a = ((1 - i/12)^1.8) * .40
        GC.setColor(0, 0, 0, a)
        GC.setLineWidth(1)
        GC.line(SX + SW + i, 0, SX + SW + i, H)
    end
end

-- ─── drawTip ─────────────────────────────────────────────────
local function drawTip(t)
    local tipX = math.max(SIDEBAR_W + 22, math.floor(sidebarX) + SIDEBAR_W + 22)
    local tipY = 677

    GC.setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], .50)
    GC.push('transform')
    GC.translate(tipX, tipY)
    GC.setLineWidth(1.5)
    GC.rectangle('line', 0, 0, tipW, 36, 3)
    GC.stencil(_tipStencil, 'replace', 1)
    GC.setStencilTest('equal', 1)
    GC.setColor(.88, .92, .98, .80)
    GC.draw(tip, scrollX, 4)
    GC.setStencilTest()
    GC.pop()
end

-- ════════════════════════════════════════════════════════════
--  MAIN DRAW
-- ════════════════════════════════════════════════════════════
function scene.draw()
    local t = TIME()

    -- Demo player (drawn first, behind UI panels)
    PLAYERS[1]:draw()

    -- Halloween theme decorations
    if THEME.cur == 'halloween' then
        GC.setColor(1,1,1)
        GC.mDraw(TEXTURE.spiderweb, 820, 50, .26, 1.26)
        GC.mDraw(TEXTURE.spiderweb, 1050, 94.2, .62)
        GC.setColor(COLOR.O)
        GC.mDraw(TEXTURE.miniBlock[1], 1126, 90, -.16, 40)
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
            GC.mStr(text.pumpkin, 0, -13)
        GC.pop()
    end

    -- Sidebar (drawn over player, under top bar and widgets)
    drawSidebar(t)

    -- Top bar (drawn over sidebar top)
    drawTopBar(t)

    -- Scrolling tip box at bottom
    drawTip(t)

    -- Halloween flash overlay
    if flash > 0 then
        GC.replaceTransform(SCR.origin)
        GC.setColor(1, 1, 1, flash)
        GC.rectangle('fill', 0, 0, SCR.w, SCR.h)
        GC.replaceTransform(SCR.xOy)
    end

    -- Ranked matchmaking search popup
    if searchPopupAlpha > .01 then
        GC.setColor(COLOR.lY[1], COLOR.lY[2], COLOR.lY[3], searchPopupAlpha * .85)
        FONT.set(20)
        GC.mStr("Ranked match searching...", 790, 648)
        if NET.searchTimer then
            GC.setColor(COLOR.lH[1], COLOR.lH[2], COLOR.lH[3], searchPopupAlpha * .70)
            GC.mStr(("Elapsed: %.1fs"):format(NET.searchTimer), 790, 668)
        end
    end
end

-- ════════════════════════════════════════════════════════════
--  WIDGET LIST
--  Note: WIDGET.newButton{x, y} treats x,y as the CENTRE of the
--  button; the stored .x becomes (centre - w/2).  In scene.update
--  we directly overwrite .x with the desired left-edge value.
-- ════════════════════════════════════════════════════════════
scene.widgetList = {
    -- ── Primary navigation (live inside sidebar) ──────────
    WIDGET.newButton{name='qplay',    x=-200, y=NAV0+0*STRIDE+BH*.5, w=BW, h=BH, color='lR', font=34, align='L', edge=12, code=pressKey'1'},
    WIDGET.newButton{name='online',   x=-200, y=NAV0+1*STRIDE+BH*.5, w=BW, h=BH, color='lV', font=34, align='L', edge=12, code=pressKey'a'},
    WIDGET.newButton{name='custom',   x=-200, y=NAV0+2*STRIDE+BH*.5, w=BW, h=BH, color='lS', font=34, align='L', edge=12, code=pressKey'z'},
    WIDGET.newButton{name='settings', x=-200, y=NAV0+3*STRIDE+BH*.5, w=BW, h=BH, color='lO', font=34, align='L', edge=12, code=pressKey'-'},
    WIDGET.newButton{name='stat',     x=-200, y=NAV0+4*STRIDE+BH*.5, w=BW, h=BH, color='lL', font=30, align='L', edge=12, code=pressKey'p'},
    WIDGET.newButton{name='replays',  x=-200, y=NAV0+5*STRIDE+BH*.5, w=BW, h=BH, color='lC', font=30, align='L', edge=12, code=pressKey','},

    -- ── Quick-Play sub-menu (same y-positions, toggled via hide) ──
    WIDGET.newButton{name='qp_40l',    x=-200, y=NAV0+0*STRIDE+BH*.5, w=BW, h=BH, color='lM', font=30, align='L', edge=12, code=pressKey'q',      hide=true},
    WIDGET.newButton{name='qp_sprint', x=-200, y=NAV0+1*STRIDE+BH*.5, w=BW, h=BH, color='lM', font=30, align='L', edge=12, code=pressKey'w',      hide=true},
    WIDGET.newButton{name='qp_lock',   x=-200, y=NAV0+2*STRIDE+BH*.5, w=BW, h=BH, color='lM', font=30, align='L', edge=12, code=pressKey'e',      hide=true},
    WIDGET.newButton{name='offline',   x=-200, y=NAV0+3*STRIDE+BH*.5, w=BW, h=BH, color='lY', font=30, align='L', edge=12, code=pressKey'r',      hide=true},
    WIDGET.newButton{name='back',      x=-200, y=NAV0+4*STRIDE+BH*.5, w=BW, h=BH, color='lB', font=30, align='L', edge=12, code=pressKey'escape', hide=true},

    -- ── Bottom sidebar: About + How-to-play ───────────────
    WIDGET.newButton{name='about',  x=-200, y=BTM_Y1+BTM_H*.5, w=BTM_W, h=BTM_H, color='lB', align='L', edge=10, code=pressKey'x', font=26, fText=CHAR.icon.info},
    WIDGET.newButton{name='manual', x=-200, y=BTM_Y2+BTM_H*.5, w=BTM_W, h=BTM_H, color='lR', align='L', edge=10, code=pressKey'h', font=26, fText=CHAR.icon.help},

    -- ── Top-bar persistent icon buttons (always visible) ──
    WIDGET.newButton{name='music',  x=TB_ICON_X[1]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lY', code=pressKey'2', font=28, fText=CHAR.icon.music},
    WIDGET.newButton{name='notice', x=TB_ICON_X[2]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lG', code=pressKey'3', font=28, fText=CHAR.key.winMenu},
    WIDGET.newButton{name='lang',   x=TB_ICON_X[3]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lN', code=pressKey'4', font=28, fText=CHAR.icon.language},
    WIDGET.newButton{name='dict',   x=TB_ICON_X[4]+TB_ICON_SZ*.5, y=TB_ICON_Y+TB_ICON_SZ*.5, w=TB_ICON_SZ, h=TB_ICON_SZ, color='lG', code=pressKey'b', font=28, fText=CHAR.icon.zBook},
}

return scene
