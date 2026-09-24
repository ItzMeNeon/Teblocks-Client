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

    -- Matchmaking persistent state & transition monitor
    if NET and NET.matchmaking then
        NET.searchTimer = (NET.searchTimer or 0) + dt
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

-- Top Bar Component Coordinates
local BACK_X = 16
local BACK_Y = 8
local BACK_W = 120
local BACK_H = 36

local QUEUE_X = 146
local QUEUE_Y = 8
local QUEUE_W = 310
local QUEUE_H = 36

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

    -- Persistent Ranked Matchmaking Pill
    if NET and NET.matchmaking then
        local qX, qY, qW, qH = QUEUE_X, QUEUE_Y, QUEUE_W, QUEUE_H
        local cancelX = qX + qW - 20
        local cancelY = qY + qH * 0.5
        local isCancelHov = (mx - cancelX) ^ 2 + (my - cancelY) ^ 2 <= 13 * 13
        local isPillHov = (mx >= qX and mx <= qX + qW and my >= qY and my <= qY + qH and not isCancelHov)

        -- Pulsing border glow
        local glow = 0.75 + 0.25 * math.sin(t * 4.5)
        gc_setColor(.08, .12, .24, .92)
        gc_rectangle('fill', qX, qY, qW, qH, 6)

        gc_setColor(1.0, .75, .20, glow)
        gc_setLineWidth(isPillHov and 2 or 1.2)
        gc_rectangle('line', qX, qY, qW, qH, 6)

        -- Pulsing radar indicator
        local dotGlow = 0.5 + 0.5 * math.sin(t * 6)
        gc_setColor(1.0, .80, .25, dotGlow)
        gc_circle('fill', qX + 16, qY + qH * 0.5, 4)
        gc_setColor(1.0, .80, .25, 0.3 * dotGlow)
        gc_circle('line', qX + 16, qY + qH * 0.5, 7 + 3 * dotGlow)

        -- Queue status & live timer
        local sec = math.floor(NET.searchTimer or 0)
        local timeStr = ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
        gc_setColor(1.0, .88, .40, .95)
        setFont(12)
        gc.print("RANKED 1v1", qX + 28, qY + 4)
        gc_setColor(.80, .90, 1.0, .85)
        setFont(11)
        gc.print("Searching • " .. timeStr, qX + 28, qY + 18)

        -- Circular Cancel Button [✕]
        if isCancelHov then
            gc_setColor(.85, .20, .25, .95)
            gc_circle('fill', cancelX, cancelY, 11)
            gc_setColor(1, 1, 1, 1)
        else
            gc_setColor(.40, .15, .20, .70)
            gc_circle('fill', cancelX, cancelY, 11)
            gc_setColor(1.0, .55, .55, .85)
        end
        gc_setLineWidth(1.5)
        gc_circle('line', cancelX, cancelY, 11)
        gc.line(cancelX - 4, cancelY - 4, cancelX + 4, cancelY + 4)
        gc.line(cancelX + 4, cancelY - 4, cancelX - 4, cancelY + 4)
    end

    -- Centered Logo & Subtitle
    gc_setColor(1, 1, 1, .95)
    if TEXTURE and TEXTURE.title_color then
        mDraw(TEXTURE.title_color, 640, 21, nil, .20)
    end
    gc_setColor(.48, .55, .72, .9)
    setFont(11)
    gc.printf(subtitle or "ONLINE MULTIPLAYER", 0, 36, 1280, 'center')

    -- Online Players Count Pill (top right, left of profile card)
    local pCountX = 854
    local pCountY = 8
    local pCountW = 164
    local pCountH = 36
    gc_setColor(.06, .09, .20, .65)
    gc_rectangle('fill', pCountX, pCountY, pCountW, pCountH, 6)
    gc_setColor(.20, .30, .55, .5)
    gc_setLineWidth(1)
    gc_rectangle('line', pCountX, pCountY, pCountW, pCountH, 6)

    -- Pulsing status dot and server connection indicator
    local dotAlpha = 0.6 + 0.4 * math.sin(t * 3)
    local isWsConnected = WS and WS.status('game') == 'running'
    local onlineNum = tonumber(NET and NET.onlineCount)
    local countStr

    if isWsConnected then
        gc_setColor(.2, .9, .4, dotAlpha)
        countStr = (onlineNum and onlineNum > 0) and (onlineNum .. " Online") or "1 Online"
        if NET and NET.ping then
            countStr = countStr .. " (" .. NET.ping .. "ms)"
        end
    elseif NET and NET.serverDown then
        gc_setColor(.85, .3, .3, dotAlpha)
        countStr = "Server Down"
    elseif NET and (NET._isReconnecting or NET._reconnectCountdown) then
        gc_setColor(.95, .75, .2, dotAlpha)
        countStr = "Reconnecting..."
    elseif NET and NET._connecting then
        gc_setColor(.3, .7, 1.0, dotAlpha)
        countStr = "Connecting..."
    else
        gc_setColor(.85, .3, .3, dotAlpha)
        countStr = "Server Offline"
    end
    gc_circle('fill', pCountX + 16, pCountY + pCountH * 0.5, 4)

    gc_setColor(.85, .92, 1, .9)
    setFont(12)
    gc.print(countStr, pCountX + 28, pCountY + 10)

    -- Bottom-Right Connection Status Indicator
    NET_BAR.drawBottomStatus()
end

function NET_BAR.drawBottomStatus()
    local isWsConnected = WS and WS.status('game') == 'running'
    if isWsConnected then return end

    local isConnecting = NET and NET._connecting
    local isReconnecting = NET and (NET._isReconnecting or NET._reconnectCountdown)
    local isWsConnecting = WS and WS.status('game') == 'connecting'

    if not (isConnecting or isReconnecting or isWsConnecting) then
        return
    end

    local t = love.timer.getTime()
    local bw, bh = 248, 34
    local bx = 1280 - bw - 16
    local by = 720 - bh - 12

    gc_push('transform')
    gc_replaceTransform(SCR.xOy)

    -- Dark rounded pill background
    gc_setColor(.04, .06, .14, .90)
    gc_rectangle('fill', bx, by, bw, bh, 7)

    -- Pulsing border
    local borderCol = isReconnecting and {.95, .75, .20, .80} or {.30, .75, 1.0, .80}
    gc_setColor(borderCol[1], borderCol[2], borderCol[3], borderCol[4])
    gc_setLineWidth(1.2)
    gc_rectangle('line', bx, by, bw, bh, 7)

    -- Rotating spinner
    local cx, cy = bx + 18, by + bh * 0.5
    local r = 6.5
    for i = 0, 7 do
        local a = (i / 8) * math.pi * 2 + t * 6.5
        local alpha = (i / 8) * 0.85 + 0.15
        gc_setColor(borderCol[1], borderCol[2], borderCol[3], alpha)
        gc_circle('fill', cx + math.cos(a) * r, cy + math.sin(a) * r, 1.6)
    end

    -- Status text
    local msg
    if isReconnecting then
        local cd = NET._reconnectCountdown and math.ceil(NET._reconnectCountdown) or 0
        msg = cd > 0 and ("Reconnecting in " .. cd .. "s...") or "Reconnecting to server..."
    else
        msg = "Connecting to game server..."
    end

    gc_setColor(.88, .93, 1, .95)
    setFont(12)
    gc.print(msg, bx + 32, by + 10)

    gc_pop()
end

function NET_BAR.checkBackClick(x, y)
    return x >= BACK_X and x <= BACK_X + BACK_W and y >= BACK_Y and y <= BACK_Y + BACK_H
end

function NET_BAR.mouseDown(x, y)
    if NET_BAR.checkBackClick(x, y) then
        return 'back'
    end

    if NET and NET.matchmaking then
        local qX, qY, qW, qH = QUEUE_X, QUEUE_Y, QUEUE_W, QUEUE_H
        local cancelX = qX + qW - 20
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
            return 'cancel_matchmaking'
        elseif x >= qX and x <= qX + qW and y >= qY and y <= qY + qH then
            if SCN.cur ~= 'net_ranked' then
                SCN.go('net_ranked')
                SFX.play('click')
            end
            return 'open_ranked'
        end
    end

    return false
end

return NET_BAR
