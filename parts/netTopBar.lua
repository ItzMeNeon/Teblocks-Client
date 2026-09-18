local gc = love.graphics
local gc_setColor, gc_setLineWidth = gc.setColor, gc.setLineWidth
local gc_rectangle, gc_circle = gc.rectangle, gc.circle
local gc_push, gc_pop = gc.push, gc.pop
local gc_replaceTransform = gc.replaceTransform
local setFont = FONT.set

local NET_BAR = {}

local BCL = {
    COLOR.lR, COLOR.lS, COLOR.lV, COLOR.lO,
    COLOR.lM, COLOR.lY, COLOR.lC,
}

local bgFallers = {}
local N_BG = 20

local function spawnBGFaller(i, scatter)
    local sz = math.random(14, 30)
    bgFallers[i] = {
        x     = math.random(20, 1260),
        y     = scatter and math.random(-400, 720) or -(sz + math.random(10, 60)),
        sz    = sz,
        speed = math.random(10, 24),
        col   = math.random(1, 7),
        rot   = math.random() * 6.283,
        rs    = (math.random() > .5 and 1 or -1) * (math.random() * .3 + .03),
        alpha = math.random(4, 12) * .01,
    }
end

function NET_BAR.initBG()
    for i = 1, N_BG do spawnBGFaller(i, true) end
end

function NET_BAR.update(dt)
    if #bgFallers == 0 then NET_BAR.initBG() end
    for i = 1, #bgFallers do
        local f = bgFallers[i]
        f.y   = f.y + f.speed * dt
        f.rot = f.rot + f.rs * dt
        if f.y > 740 then spawnBGFaller(i, false) end
    end
end

function NET_BAR.drawBG()
    if #bgFallers == 0 then NET_BAR.initBG() end
    for i = 1, #bgFallers do
        local f = bgFallers[i]
        local bc = BCL[f.col]
        gc_setColor(bc[1], bc[2], bc[3], f.alpha)
        gc_push('transform')
        gc.translate(f.x + f.sz * .5, f.y + f.sz * .5)
        gc.rotate(f.rot)
        gc_rectangle('fill', -f.sz * .5, -f.sz * .5, f.sz, f.sz, 3)
        gc_pop()
    end
end

local function getMousePos()
    if SCR and SCR.xOy then
        return SCR.xOy:inverseTransformPoint(love.mouse.getPosition())
    end
    return love.mouse.getPosition()
end

-- Back button coordinates (top left)
local BACK_X = 16
local BACK_Y = 8
local BACK_W = 120
local BACK_H = 36

function NET_BAR.draw(subtitle, backLabel)
    local t = love.timer.getTime()
    local mx, my = getMousePos()
    local TB_H = 52

    -- Top bar glass backdrop spans full window in SCR.origin
    gc_push('transform')
    gc_replaceTransform(SCR.origin)
    local topBarH_window = (TB_H + (SCR.y / (SCR.k > 0 and SCR.k or 1))) * (SCR.k > 0 and SCR.k or 1)
    gc_setColor(.035, .045, .10, .96)
    gc_rectangle('fill', 0, 0, SCR.w, topBarH_window)

    -- Rainbow spectrum line at the bottom
    local segW = SCR.w / 7
    for i = 1, 7 do
        local c = BCL[i]
        gc_setColor(c[1], c[2], c[3], .85)
        gc_rectangle('fill', (i - 1) * segW, topBarH_window - 2 * (SCR.k > 0 and SCR.k or 1), segW + 1, 2 * (SCR.k > 0 and SCR.k or 1))
    end
    gc_pop()

    -- Left Back Button
    local isBackHover = (mx >= BACK_X and mx <= BACK_X + BACK_W and my >= BACK_Y and my <= BACK_Y + BACK_H)
    if isBackHover then
        gc_setColor(.18, .26, .52, .9)
        gc_rectangle('fill', BACK_X, BACK_Y, BACK_W, BACK_H, 6)
        gc_setColor(.45, .72, 1.0, .95)
        gc_setLineWidth(1.5)
        gc_rectangle('line', BACK_X, BACK_Y, BACK_W, BACK_H, 6)
        gc_setColor(1, 1, 1, 1)
    else
        gc_setColor(.08, .12, .24, .7)
        gc_rectangle('fill', BACK_X, BACK_Y, BACK_W, BACK_H, 6)
        gc_setColor(.24, .34, .62, .6)
        gc_setLineWidth(1)
        gc_rectangle('line', BACK_X, BACK_Y, BACK_W, BACK_H, 6)
        gc_setColor(.85, .90, 1, .9)
    end
    setFont(14)
    gc.printf(backLabel or "← Back", BACK_X, BACK_Y + 9, BACK_W, 'center')

    -- Centered Logo & Subtitle
    gc_setColor(1, 1, 1, .95)
    if TEXTURE and TEXTURE.title_color then
        mDraw(TEXTURE.title_color, 640, 21, nil, .20)
    end
    gc_setColor(.48, .55, .72, .9)
    setFont(11)
    gc.printf(subtitle or "ONLINE MULTIPLAYER", 0, 36, 1280, 'center')

    -- Online Players Count Pill (top right, left of profile card)
    local pCountX = 874
    local pCountY = 8
    local pCountW = 144
    local pCountH = 36
    gc_setColor(.06, .09, .20, .65)
    gc_rectangle('fill', pCountX, pCountY, pCountW, pCountH, 6)
    gc_setColor(.20, .30, .55, .5)
    gc_setLineWidth(1)
    gc_rectangle('line', pCountX, pCountY, pCountW, pCountH, 6)

    -- Pulsing green online dot
    local dotAlpha = 0.6 + 0.4 * math.sin(t * 3)
    gc_setColor(.2, .9, .4, dotAlpha)
    gc_circle('fill', pCountX + 16, pCountY + pCountH * 0.5, 4)

    local countStr = (NET and NET.onlineCount and NET.onlineCount > 0)
        and (tostring(NET.onlineCount) .. " Online")
        or "Connecting..."
    gc_setColor(.85, .92, 1, .9)
    setFont(12)
    gc.print(countStr, pCountX + 28, pCountY + 10)
end

function NET_BAR.checkBackClick(x, y)
    return x >= BACK_X and x <= BACK_X + BACK_W and y >= BACK_Y and y <= BACK_Y + BACK_H
end

return NET_BAR
