local scene = {}
local AUTH = require 'parts.authModal'

--[[
    MAIN_SIMPLE SCENE - Minimalist, Modern Block-Themed Menu
    Refined and uncluttered:
      • Crisp glass top bar (52px) with centered logo and subtle rainbow accent
      • Centered primary action hero: "Play" + "All Modes"
      • Neat top-right utility dock for settings, language, dict, and quit
      • Subtle ambient tetromino shapes floating in background
      • Bottom-left "Full Menu" pill button
      • Clean tip ticker container
]]

-- ════════════════════════════════════════════════════════════
--  LAYOUT CONSTANTS
-- ════════════════════════════════════════════════════════════
local TB_H = 52

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
local tipW    = 800
local tip     = GC.newText(getFont(22), "")
local scrollX = tipW

-- ════════════════════════════════════════════════════════════
--  DECORATIVE CORNER SILHOUETTES
-- ════════════════════════════════════════════════════════════
local SILS = {
    { anchor={-10, 65},   col=7, cells={{0,0},{1,0},{2,0},{3,0}},       sz=42 },
    { anchor={1220, 65},  col=5, cells={{0,0},{-1,0},{1,0},{0,-1}},      sz=42 },
    { anchor={-10, 630},  col=2, cells={{0,0},{1,0},{-1,-1},{0,-1}},     sz=42 },
    { anchor={1220, 630}, col=4, cells={{0,0},{0,-1},{0,-2},{1,0}},      sz=42 },
}

-- ════════════════════════════════════════════════════════════
--  FALLING PARTICLES
-- ════════════════════════════════════════════════════════════
local fallers = {}
local N_FALL  = 12

local function spawnFaller(i, scatter)
    local sz = math.random(14, 28)
    fallers[i] = {
        x     = math.random(20, 1260),
        y     = scatter and math.random(-400, 720) or -(sz + math.random(10, 60)),
        sz    = sz,
        speed = math.random(14, 38),
        col   = math.random(1, 7),
        rot   = math.random() * 6.283,
        rs    = (math.random() > .5 and 1 or -1) * (math.random() * .35 + .03),
        alpha = math.random(6, 22) * .01,
    }
end

local function initFallers()
    for i = 1, N_FALL do spawnFaller(i, true) end
end

-- ════════════════════════════════════════════════════════════
--  SCENE CALLBACKS
-- ════════════════════════════════════════════════════════════
function scene.enter()
    BG.set()
    tip:set(text.getTip())
    scrollX = tipW
    destroyPlayers()
    GAME.modeEnv = NONE
    GAME.setting = {}
    initFallers()
    DiscordRPC.update("In Simple Menu")
end

function scene.leave()
    AUTH.close()
end

-- ════════════════════════════════════════════════════════════
--  KEYBOARD HANDLER
-- ════════════════════════════════════════════════════════════
function scene.keyDown(key, isRep)
    if AUTH.isOpen() then return AUTH.keyDown(key, isRep) end
    if isRep then return true end

    -- Ctrl+T: switch back to the full UI (main scene)
    if key == 't' and love.keyboard.isDown('lctrl', 'rctrl') then
        SETTING.simpMode = false
        for i = #SCN.stack, 1, -1 do SCN.stack[i] = nil end
        SCN.stack[1] = 'main'
        SCN.swapTo('main', 'fade')
        return false
    end

    if key == 'escape' or key == 'back' then
        if tryBack() then VOC.play('bye') SCN.back() end
        return false
    else
        return true
    end
end

function scene.textInput(t)
    if AUTH.isOpen() and AUTH.textInput(t) then return true end
end

function scene.mouseDown(x, y)
    if AUTH.isOpen() then
        AUTH.mouseClick(x, y)
        return true
    end
end
scene.touchDown = scene.mouseDown

function scene.mouseClick(x, y)
    if AUTH.isOpen() and AUTH.mouseClick(x, y) then return true end
end
scene.touchClick = scene.mouseClick

-- ════════════════════════════════════════════════════════════
--  UPDATE
-- ════════════════════════════════════════════════════════════
function scene.update(dt)
    if dt > .26 then return end

    AUTH.update(dt)

    scrollX = scrollX - 120 * dt
    if scrollX < -tip:getWidth() then
        scrollX = tipW
        tip:set(text.getTip())
    end

    for i = 1, #fallers do
        local f = fallers[i]
        f.y   = f.y + f.speed * dt
        f.rot = f.rot + f.rs * dt
        if f.y > 750 then spawnFaller(i, false) end
    end
end

-- ════════════════════════════════════════════════════════════
--  DRAW HELPERS
-- ════════════════════════════════════════════════════════════
local function _tipStencil()
    GC.rectangle('fill', 0, 0, tipW, 30)
end

local function drawTopBar()
    local W = 1280

    -- Top bar panel
    GC.setColor(.035, .045, .10, .96)
    GC.rectangle('fill', 0, 0, W, TB_H)

    -- Bottom rainbow line
    local segW = W / 7
    for i = 1, 7 do
        local c = BCL[i]
        GC.setColor(c[1], c[2], c[3], .85)
        GC.rectangle('fill', (i - 1) * segW, TB_H - 2, segW + 1, 2)
    end

    -- Logo
    GC.setColor(1, 1, 1, .95)
    mDraw(TEXTURE.title_color, 640, 21, nil, .22)

    -- Subtitle version
    GC.setColor(.48, .55, .72, .85)
    setFont(11)
    GC.mStr(verName, 640, 36)
end

local function drawBackground()
    -- Corner silhouettes
    for _, sil in ipairs(SILS) do
        local bc = BCL[sil.col]
        local ax, ay, sz = sil.anchor[1], sil.anchor[2], sil.sz
        GC.setColor(bc[1], bc[2], bc[3], .04)
        for _, cell in ipairs(sil.cells) do
            local cx = ax + cell[1] * (sz + 2)
            local cy = ay + cell[2] * (sz + 2)
            GC.rectangle('fill', cx, cy, sz, sz, 4)
        end
    end

    -- Ambient minos
    for i = 1, #fallers do
        local f  = fallers[i]
        local bc = BCL[f.col]
        GC.setColor(bc[1], bc[2], bc[3], f.alpha)
        GC.push('transform')
        GC.translate(f.x + f.sz * .5, f.y + f.sz * .5)
        GC.rotate(f.rot)
        GC.rectangle('fill', -f.sz * .5, -f.sz * .5, f.sz, f.sz, 3)
        GC.pop()
    end
end

local function drawTip()
    local tipX = 220
    local tipY = 680

    GC.setColor(.12, .16, .30, .5)
    GC.rectangle('fill', tipX, tipY, tipW, 30, 4)
    GC.setColor(.22, .30, .55, .35)
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
    drawBackground()
    drawTopBar()
    drawTip()
    AUTH.draw()
end

-- ════════════════════════════════════════════════════════════
--  WIDGET LIST
-- ════════════════════════════════════════════════════════════
local ICN_X  = 1236
local ICN_Y  = {78, 126, 174, 222, 270}
local ICN_SZ = 40

scene.widgetList = {
    -- Hero primary Play button
    WIDGET.newButton{
        name  = 'play',
        x     = 640,  y = 330,
        w     = 300,  h = 80,
        color = 'lM',
        font  = 44,
        edge  = 14,
        fText = "Play",
        code  = function() loadGame(STAT.lastPlay or 'sprint_40l', true) end,
    },

    -- All Modes secondary button
    WIDGET.newButton{
        name  = 'modes',
        x     = 640,  y = 432,
        w     = 220,  h = 58,
        color = 'lC',
        font  = 30,
        edge  = 10,
        fText = "All Modes",
        code  = goScene'mode',
    },

    -- Top-right utility icon buttons
    WIDGET.newButton{
        name   = 'skin',
        x      = ICN_X, y = ICN_Y[1],
        w      = ICN_SZ, h = ICN_SZ,
        color  = 'lP',
        font   = 22,
        fText  = CHAR.mino.T,
        code   = function()
            if not (USER and USER.uid and USER.uid ~= false) then
                MES.new('warn', "Please log in to access Skin Direct")
                local AUTH = require 'parts.authModal'
                AUTH.open('login')
            else
                SCN.go('skin_browse')
            end
        end,
    },
    WIDGET.newButton{
        name   = 'settings',
        x      = ICN_X, y = ICN_Y[2],
        w      = ICN_SZ, h = ICN_SZ,
        color  = 'lO',
        font   = 24,
        fText  = CHAR.icon.settings,
        code   = goScene'setting_game',
    },
    WIDGET.newButton{
        name   = 'lang',
        x      = ICN_X, y = ICN_Y[3],
        w      = ICN_SZ, h = ICN_SZ,
        color  = 'lN',
        font   = 24,
        fText  = CHAR.icon.language,
        code   = goScene'lang',
    },
    WIDGET.newButton{
        name   = 'dict',
        x      = ICN_X, y = ICN_Y[4],
        w      = ICN_SZ, h = ICN_SZ,
        color  = 'lG',
        font   = 24,
        fText  = CHAR.icon.zBook,
        code   = goScene'dict',
    },
    WIDGET.newButton{
        name   = 'quit',
        x      = ICN_X, y = ICN_Y[5],
        w      = ICN_SZ, h = ICN_SZ,
        color  = 'lR',
        font   = 22,
        fText  = CHAR.key.macEsc,
        code   = function() VOC.play('bye') SCN.swapTo('quit', 'slowFade') end,
    },

    -- Switch to Full UI (bottom-left button)
    WIDGET.newButton{
        name  = 'fullui',
        x     = 95,  y = 695,
        w     = 150, h = 32,
        color = 'lB',
        font  = 16,
        edge  = 4,
        fText = "Full Menu (Ctrl+T)",
        code  = function()
            SETTING.simpMode = false
            for i = #SCN.stack, 1, -1 do SCN.stack[i] = nil end
            SCN.stack[1] = 'main'
            SCN.swapTo('main', 'fade')
        end,
    },
}

return scene
