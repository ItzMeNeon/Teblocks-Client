local scene={}

local gc,kb,tc=love.graphics,love.keyboard,love.touch
local gc_setColor,gc_setLineWidth=gc.setColor,gc.setLineWidth
local gc_print,gc_printf=gc.print,gc.printf
local gc_rectangle,gc_circle,gc_line,gc_polygon=gc.rectangle,gc.circle,gc.line,gc.polygon
local setFont,mStr=FONT.set,GC.mStr

local SCR,VK,NET,NETPLY=SCR,VK,NET,NETPLY
local PLAYERS,GAME=PLAYERS,GAME
local REPORT=require 'parts.reportModal'
local AC=require 'parts.anticheatClient'

local playing=false
local lastUpstreamTime=0
local upstreamProgress=1
local noTouch,noKey=false,false
local touchMoveLastFrame=false
local forfeitModalOpen=false

-- First to 3 Wins series tracking
local currentRound=1
local targetWins=3
local myWins=0
local oppWins=0
local roundState='playing' -- 'playing' | 'round_over'
local roundOverTimer=0
local roundWinnerName=""

-- Round Start Banner flare
local roundStartBanner={
    timer=0,
    round=1,
}

-- Point scoring presentation animation
local scoreAnim={
    active=false,
    timer=0,
    duration=0.85,
    startX=0,
    startY=0,
    targetX=0,
    targetY=0,
    curX=0,
    curY=0,
    winnerIsYou=true,
    impactDone=false,
    pipPulse=1.0,
    particles={},
    trail={},
    shockwaves={},
    floatingTexts={},
}

local function _getRankTier(elo)
    elo = elo or 1200
    if elo >= 2000 then return {0.95, 0.40, 0.95}, "GM"
    elseif elo >= 1800 then return {0.70, 0.50, 0.98}, "MASTER"
    elseif elo >= 1600 then return {0.35, 0.85, 0.98}, "DIAMOND"
    elseif elo >= 1400 then return {0.35, 0.95, 0.55}, "PLAT"
    elseif elo >= 1200 then return {0.98, 0.85, 0.30}, "GOLD"
    elseif elo >= 1000 then return {0.80, 0.85, 0.95}, "SILVER"
    else return {0.85, 0.55, 0.35}, "BRONZE"
    end
end

local function _stepPlayers(dt)
    for p=1,#PLAYERS do
        if PLAYERS[p] then
            PLAYERS[p]:update(dt)
        end
    end
end

local function _forfeitMatch()
    forfeitModalOpen=false
    MES.new('warn', "Surrendered ranked series — match settled", 3)
    NET.ranked_leave()
end

local function _openReport()
    local oppUid = NET.matchFoundOppId
    local oppName = NET.matchFoundOppName or "Opponent"
    if (not oppUid or oppUid == "") and #PLAYERS > 1 then
        for i=1,#PLAYERS do
            if PLAYERS[i].uid and PLAYERS[i].uid ~= USER.uid then
                oppUid = PLAYERS[i].uid
                oppName = PLAYERS[i].username or "Opponent"
                break
            end
        end
    end
    REPORT.open(oppUid or "unknown", oppName, "Ranked Arena", NET.matchFoundMatchId or "")
end

local function _updateScoreAnim(dt)
    if not scoreAnim.active then return end
    scoreAnim.timer = scoreAnim.timer + dt
    local t = scoreAnim.timer
    local dur = scoreAnim.duration

    -- Flight phase (t < dur)
    if t < dur then
        local p = t / dur
        local smoothP = p * p * (3 - 2 * p)
        scoreAnim.curX = scoreAnim.startX + (scoreAnim.targetX - scoreAnim.startX) * smoothP
        local arc = math.sin(p * math.pi) * 85
        scoreAnim.curY = scoreAnim.startY + (scoreAnim.targetY - scoreAnim.startY) * smoothP - arc

        -- Sparkling trail
        local col = scoreAnim.winnerIsYou and {0.25, 0.95, 0.55} or {1.0, 0.40, 0.35}
        for _=1, 2 do
            table.insert(scoreAnim.trail, {
                x = scoreAnim.curX + (math.random() - 0.5) * 16,
                y = scoreAnim.curY + (math.random() - 0.5) * 16,
                r = col[1], g = col[2], b = col[3],
                a = 0.95,
                size = math.random(3, 7)
            })
        end
    elseif not scoreAnim.impactDone then
        -- Impact moment at score pip!
        scoreAnim.impactDone = true
        scoreAnim.pipPulse = 1.8
        scoreAnim.curX = scoreAnim.targetX
        scoreAnim.curY = scoreAnim.targetY

        SFX.play('reach')

        -- Explosive impact particles
        local col = scoreAnim.winnerIsYou and {0.25, 0.95, 0.55} or {1.0, 0.40, 0.35}
        for _=1, 30 do
            local ang = math.random() * math.pi * 2
            local spd = math.random(70, 260)
            table.insert(scoreAnim.particles, {
                x = scoreAnim.targetX,
                y = scoreAnim.targetY,
                vx = math.cos(ang) * spd,
                vy = math.sin(ang) * spd,
                size = math.random(3, 8),
                r = (math.random() > 0.3) and col[1] or 1.0,
                g = (math.random() > 0.3) and col[2] or 1.0,
                b = (math.random() > 0.3) and col[3] or 1.0,
                a = 1.0,
                life = 0,
                maxLife = math.random(45, 80) / 100
            })
        end

        -- Shockwave ring
        table.insert(scoreAnim.shockwaves, {
            x = scoreAnim.targetX,
            y = scoreAnim.targetY,
            radius = 6,
            maxRadius = 60,
            r = col[1], g = col[2], b = col[3],
            a = 0.95,
            life = 0,
            maxLife = 0.45
        })

        -- Floating score popup
        table.insert(scoreAnim.floatingTexts, {
            text = "+1 POINT",
            x = scoreAnim.targetX,
            y = scoreAnim.targetY - 14,
            vy = -38,
            r = col[1], g = col[2], b = col[3],
            a = 1.0,
            life = 0,
            maxLife = 1.3
        })
    end

    -- Decay pip pulse with elastic bounce
    if scoreAnim.pipPulse > 1.0 then
        scoreAnim.pipPulse = math.max(1.0, scoreAnim.pipPulse - dt * 2.2)
    end

    -- Update trail
    for i=#scoreAnim.trail, 1, -1 do
        local tr = scoreAnim.trail[i]
        tr.a = tr.a - dt * 2.4
        tr.size = math.max(0.5, tr.size - dt * 5)
        if tr.a <= 0 then
            table.remove(scoreAnim.trail, i)
        end
    end

    -- Update burst particles
    for i=#scoreAnim.particles, 1, -1 do
        local pt = scoreAnim.particles[i]
        pt.life = pt.life + dt
        pt.x = pt.x + pt.vx * dt
        pt.y = pt.y + pt.vy * dt
        pt.vy = pt.vy + 90 * dt
        pt.a = math.max(0, 1 - (pt.life / pt.maxLife))
        pt.size = math.max(0.5, pt.size - dt * 3)
        if pt.life >= pt.maxLife then
            table.remove(scoreAnim.particles, i)
        end
    end

    -- Update shockwaves
    for i=#scoreAnim.shockwaves, 1, -1 do
        local sw = scoreAnim.shockwaves[i]
        sw.life = sw.life + dt
        local prog = sw.life / sw.maxLife
        sw.radius = 6 + (sw.maxRadius - 6) * prog
        sw.a = math.max(0, 0.95 * (1 - prog))
        if sw.life >= sw.maxLife then
            table.remove(scoreAnim.shockwaves, i)
        end
    end

    -- Update floating texts
    for i=#scoreAnim.floatingTexts, 1, -1 do
        local ft = scoreAnim.floatingTexts[i]
        ft.life = ft.life + dt
        ft.y = ft.y + ft.vy * dt
        ft.a = math.max(0, 1 - (ft.life / ft.maxLife))
        if ft.life >= ft.maxLife then
            table.remove(scoreAnim.floatingTexts, i)
        end
    end
end

local function _drawScoreAnim()
    if not scoreAnim.active then return end

    -- Trail
    for i=1, #scoreAnim.trail do
        local tr = scoreAnim.trail[i]
        gc_setColor(tr.r, tr.g, tr.b, tr.a * 0.8)
        gc_circle('fill', tr.x, tr.y, tr.size)
    end

    -- Projectile orb in flight
    if not scoreAnim.impactDone then
        local ox, oy = scoreAnim.curX, scoreAnim.curY
        local col = scoreAnim.winnerIsYou and {0.25, 0.95, 0.55} or {1.0, 0.40, 0.35}

        gc_setColor(col[1], col[2], col[3], 0.25)
        gc_circle('fill', ox, oy, 28)

        gc_setColor(col[1], col[2], col[3], 0.65)
        gc_circle('fill', ox, oy, 15)

        gc_setColor(1, 1, 1, 0.95)
        gc_circle('fill', ox, oy, 8)

        gc_setLineWidth(2)
        gc_setColor(1, 1, 1, 0.85)
        gc_line(ox - 18, oy, ox + 18, oy)
        gc_line(ox, oy - 18, ox, oy + 18)
    end

    -- Shockwaves
    for i=1, #scoreAnim.shockwaves do
        local sw = scoreAnim.shockwaves[i]
        gc_setColor(sw.r, sw.g, sw.b, sw.a)
        gc_setLineWidth(3 * (1 - sw.life / sw.maxLife) + 1)
        gc_circle('line', sw.x, sw.y, sw.radius)
    end

    -- Burst Particles
    for i=1, #scoreAnim.particles do
        local pt = scoreAnim.particles[i]
        gc_setColor(pt.r, pt.g, pt.b, pt.a)
        gc_circle('fill', pt.x, pt.y, pt.size)
    end

    -- Floating text
    for i=1, #scoreAnim.floatingTexts do
        local ft = scoreAnim.floatingTexts[i]
        setFont(14)
        gc_setColor(ft.r, ft.g, ft.b, ft.a)
        gc_printf(ft.text, ft.x - 60, ft.y, 120, 'center')
    end
end

function scene.onRoundFinish(data)
    roundState='round_over'
    roundOverTimer=2.5

    local prevMyWins = myWins
    local prevOppWins = oppWins

    if data and type(data.scores)=='table' then
        if USER and USER.uid and data.scores[USER.uid] then
            myWins = data.scores[USER.uid]
        end
        if NET.matchFoundOppId and data.scores[NET.matchFoundOppId] then
            oppWins = data.scores[NET.matchFoundOppId]
        end
    end

    local rwId = data and data.roundWinner
    local winnerIsYou = false
    if rwId then
        if rwId == USER.uid then
            winnerIsYou = true
            roundWinnerName = "YOU"
        else
            winnerIsYou = false
            roundWinnerName = NET.matchFoundOppName or "OPPONENT"
        end
    else
        if myWins > prevMyWins then
            winnerIsYou = true
            roundWinnerName = "YOU"
        elseif oppWins > prevOppWins then
            winnerIsYou = false
            roundWinnerName = NET.matchFoundOppName or "OPPONENT"
        elseif PLAYERS[1] and PLAYERS[1].alive and (not PLAYERS[2] or not PLAYERS[2].alive) then
            winnerIsYou = true
            roundWinnerName = "YOU"
        else
            winnerIsYou = false
            roundWinnerName = NET.matchFoundOppName or "OPPONENT"
        end
    end

    if winnerIsYou then
        SFX.play('reach')
    else
        SFX.play('warn_1')
    end

    -- 1. Shrink both boards a bit and slide down smoothly (Lower base position: y=215)
    if PLAYERS[1] and PLAYERS[1].movePosition then
        PLAYERS[1]:movePosition(190, 215, 0.68)
    end
    if PLAYERS[2] and PLAYERS[2].movePosition then
        PLAYERS[2]:movePosition(650, 215, 0.68)
    end

    -- 2. Trigger point scoring presentation animation
    local winPlayer = winnerIsYou and PLAYERS[1] or PLAYERS[2]
    local sX = winPlayer and winPlayer.centerX or (winnerIsYou and 290 or 750)
    local sY = winPlayer and winPlayer.centerY or 410

    local winCount = winnerIsYou and myWins or oppWins
    local pipIdx = math.max(1, math.min(targetWins, winCount))

    -- Destination is the winner's win pip on their nameplate
    local pw = 250
    local pX = (winPlayer and winPlayer.centerX or (winnerIsYou and 290 or 750)) - pw / 2
    local pY = (winPlayer and winPlayer.fieldY or 215) - 86
    local tX = pX + 160 + (pipIdx - 1) * 26
    local tY = pY + 30

    scoreAnim.active = true
    scoreAnim.timer = 0
    scoreAnim.duration = 0.85
    scoreAnim.startX = sX
    scoreAnim.startY = sY
    scoreAnim.targetX = tX
    scoreAnim.targetY = tY
    scoreAnim.curX = sX
    scoreAnim.curY = sY
    scoreAnim.winnerIsYou = winnerIsYou
    scoreAnim.impactDone = false
    scoreAnim.pipPulse = 1.0
    scoreAnim.particles = {}
    scoreAnim.trail = {}
    scoreAnim.shockwaves = {}
    scoreAnim.floatingTexts = {}

    -- Initial blast at starting board
    local cCol = winnerIsYou and {0.25, 0.95, 0.55} or {1.0, 0.40, 0.35}
    for _=1, 16 do
        local a = math.random() * math.pi * 2
        local s = math.random(40, 150)
        table.insert(scoreAnim.particles, {
            x = sX, y = sY,
            vx = math.cos(a) * s, vy = math.sin(a) * s,
            size = math.random(3, 6),
            r = cCol[1], g = cCol[2], b = cCol[3], a = 1.0,
            life = 0, maxLife = 0.5
        })
    end
end

function scene.onNextRound(data)
    if data and data.round then
        currentRound = data.round
    else
        currentRound = currentRound + 1
    end

    if data and type(data.scores)=='table' then
        if USER and USER.uid and data.scores[USER.uid] then
            myWins = data.scores[USER.uid]
        end
        if NET.matchFoundOppId and data.scores[NET.matchFoundOppId] then
            oppWins = data.scores[NET.matchFoundOppId]
        end
    end

    local seed = (data and data.seed) or NET.seed or math.random(1046101471)
    NET.seed = seed

    roundState='playing'
    roundOverTimer=0

    TASK.lock('netPlaying')
    resetGameData('n', seed)

    -- Smoothly slide boards back up to lowered comfortable gameplay scale (170, 155, 0.80) and (630, 155, 0.80)
    if PLAYERS[1] and PLAYERS[1].movePosition then
        PLAYERS[1]:movePosition(170, 155, 0.80)
    end
    if PLAYERS[2] and PLAYERS[2].movePosition then
        PLAYERS[2]:movePosition(630, 155, 0.80)
    end

    lastUpstreamTime=0
    upstreamProgress=1

    for i=1,#NETPLY.list do
        local p=NETPLY.list[i]
        if p.playMode=='Gamer' then
            p.readyMode='Playing'
            p.place=1
        else
            p.place=1e99
        end
    end

    NET.spectate = PLAYERS[1] and (PLAYERS[1].uid ~= USER.uid)
    SFX.play('ready', 0.8)

    -- Trigger "ROUND N - FIGHT!" flare banner
    roundStartBanner.timer = 1.4
    roundStartBanner.round = currentRound
end

function scene.enter()
    GAME.net=true
    noTouch=not SETTING.VKSwitch
    playing=true
    forfeitModalOpen=false
    lastUpstreamTime=0
    upstreamProgress=1
    currentRound=1
    targetWins=3
    myWins=0
    oppWins=0
    roundState='playing'
    roundOverTimer=0
    roundWinnerName=""

    scoreAnim.active=false
    scoreAnim.particles={}
    scoreAnim.trail={}
    scoreAnim.shockwaves={}
    scoreAnim.floatingTexts={}

    REPORT.close()
    AC.reset()

    TASK.lock('netPlaying')
    local matchSeed = NET.seed or NET.matchFoundSeed or math.random(1046101471)
    NET.seed = matchSeed
    resetGameData('n', matchSeed)

    -- Initial position of both boards (Lowered to y=155 so there is ample breathing room from top header)
    if PLAYERS[1] and PLAYERS[1].setPosition then
        PLAYERS[1]:setPosition(170, 155, 0.80)
    end
    if PLAYERS[2] and PLAYERS[2].setPosition then
        PLAYERS[2]:setPosition(630, 155, 0.80)
    end

    for i=1,#NETPLY.list do
        local p=NETPLY.list[i]
        if p.playMode=='Gamer' then
            p.readyMode='Playing'
            p.place=1
        else
            p.place=1e99
        end
    end

    NET.spectate = PLAYERS[1] and (PLAYERS[1].uid ~= USER.uid)

    if NET.storedStream then
        for i=1,#NET.storedStream do
            NET.pumpStream(NET.storedStream[i])
        end
        NET.storedStream=false
    end

    DiscordRPC.update("Ranked 1v1 Arena")
    SFX.play('ready', 0.8)

    roundStartBanner.timer = 1.4
    roundStartBanner.round = 1
end

function scene.leave()
    TASK.unlock('netPlaying')
    playing=false
    forfeitModalOpen=false
    REPORT.close()
end

function scene.update(dt)
    REPORT.update(dt)
    AC.update(dt)

    if WS.status('game')~='running' then
        TASK.unlock('netPlaying')
        NET.ws_close()
        MES.new('warn', "Connection lost to game server", 5)
        SCN.go('net_ranked')
        return
    end

    if roundState == 'round_over' then
        roundOverTimer = math.max(0, roundOverTimer - dt)
    end

    if roundStartBanner.timer > 0 then
        roundStartBanner.timer = math.max(0, roundStartBanner.timer - dt)
    end

    _updateScoreAnim(dt)

    if playing then
        touchMoveLastFrame=false
        VK.update(dt)

        if #PLAYERS>0 then
            _stepPlayers(dt)

            local P1=PLAYERS[1]
            if P1 then
                checkWarning(P1,dt)

                -- Upload stream
                local streamInterval=4
                if not NET.spectate and P1.frameRun-lastUpstreamTime>streamInterval then
                    local stream
                    if not GAME.rep[upstreamProgress] then
                        GAME.repAdd(P1.frameRun)
                        GAME.repAdd(0)
                    end
                    stream,upstreamProgress=DATA.dumpRecording(GAME.rep,upstreamProgress)
                    if #stream%3==1 then
                        stream=stream.."\0\0"
                    elseif #stream%3==2 then
                        stream=stream.."\0\0\0\0"
                    end
                    NET.player_stream(stream)
                    lastUpstreamTime=P1.alive and P1.frameRun or 1e99
                end
            end
        end
    end

    if NET.shakeStr and NET.shakeStr>0 then
        NET.shakeStr=math.max(0,NET.shakeStr-dt*16)
    end
end

function scene.draw()
    -- Warning FX
    drawWarning()

    -- Boards
    for p=1,#PLAYERS do
        if PLAYERS[p] then
            PLAYERS[p]:draw()
        end
    end

    -- Virtual Keys
    VK.draw()

    -- Player Nameplates above boards with Round Win Badges, APM, PPS, and Threat Meter
    for p=1,#PLAYERS do
        local P=PLAYERS[p]
        if P and P.fieldY and P.centerX then
            local isYou = P.uid == USER.uid
            local label = isYou and "YOU" or (P.username or NET.matchFoundOppName or "OPPONENT")
            local eloVal = isYou and (STAT.elo or 1200) or (NET.matchFoundOppElo or 1200)
            local tierColor, tierName = _getRankTier(eloVal)
            local wins = isYou and myWins or oppWins

            local pw, ph = 250, 48
            local px = P.centerX - pw / 2
            local py = (P.fieldY or 155) - 86

            -- Match Point Tag if this player has 2 wins
            if wins == (targetWins - 1) and roundState ~= 'round_over' then
                local mpPulse = 0.75 + 0.25 * math.sin(love.timer.getTime() * 6)
                gc_setColor(1.0, 0.82, 0.22, mpPulse)
                setFont(11)
                gc_printf("⚡ MATCH POINT ⚡", px, py - 18, pw, 'center')
            end

            -- Glass Plate
            gc_setColor(0.04, 0.06, 0.13, 0.90)
            gc_rectangle('fill', px, py, pw, ph, 8)
            gc_setColor(isYou and {.25, .85, .50, .85} or {.95, .32, .30, .85})
            gc_setLineWidth(1.6)
            gc_rectangle('line', px, py, pw, ph, 8)

            -- Player Label & Rank Tier Badge
            setFont(15)
            gc_setColor(isYou and COLOR.lG or COLOR.lR)
            gc_printf(label, px + 10, py + 4, 135, 'left')

            -- Micro Stats: Live PPS & APM
            local stat = P.stat
            local pps = (stat and stat.time and stat.time > 0) and (stat.piece / stat.time) or 0
            local apm = (stat and stat.time and stat.time > 0) and (stat.atk / stat.time * 60) or 0
            setFont(11)
            gc_setColor(0.72, 0.80, 0.94, 0.85)
            gc_printf(string.format("%d ELO • %.1f PPS", eloVal, pps), px + 10, py + 26, 145, 'left')

            -- Custom Rendered Diamond Win Pips (3 pips)
            local pipBaseX = px + 160
            local pipY = py + 30
            local pipCol = isYou and {0.25, 0.95, 0.55} or {0.95, 0.35, 0.35}

            for w=1,targetWins do
                local pipX = pipBaseX + (w - 1) * 26
                local isEarned = w <= wins
                local isCurrentAnimating = scoreAnim.active and (scoreAnim.winnerIsYou == isYou) and (w == wins) and scoreAnim.impactDone
                local currentScale = isCurrentAnimating and scoreAnim.pipPulse or 1.0

                local dSize = 7.5 * currentScale
                local poly = {
                    pipX, pipY - dSize,
                    pipX + dSize, pipY,
                    pipX, pipY + dSize,
                    pipX - dSize, pipY
                }

                if isEarned then
                    -- Outer glow
                    gc_setColor(pipCol[1], pipCol[2], pipCol[3], 0.30)
                    gc_circle('fill', pipX, pipY, dSize + 4)

                    -- Filled glowing diamond
                    gc_setColor(pipCol[1], pipCol[2], pipCol[3], 0.95)
                    gc_polygon('fill', poly)

                    -- Crisp inner diamond border
                    gc_setColor(1, 1, 1, 0.85)
                    gc_setLineWidth(1.2)
                    gc_polygon('line', poly)
                else
                    -- Unearned empty diamond outline
                    gc_setColor(0.35, 0.45, 0.60, 0.50)
                    gc_setLineWidth(1.4)
                    gc_polygon('line', poly)
                end
            end

            -- Incoming Garbage Threat Warning Meter
            if P.atkBufferSum and P.atkBufferSum > 0 and roundState == 'playing' then
                local dangerPulse = 0.80 + 0.20 * math.sin(love.timer.getTime() * 8)
                local tw, th = 140, 20
                local tx = P.centerX - tw / 2
                local ty = py + ph + 6
                gc_setColor(0.32, 0.05, 0.08, 0.88 * dangerPulse)
                gc_rectangle('fill', tx, ty, tw, th, 6)
                gc_setColor(1.0, 0.30, 0.25, 0.92 * dangerPulse)
                gc_setLineWidth(1.2)
                gc_rectangle('line', tx, ty, tw, th, 6)
                setFont(11)
                gc_setColor(1.0, 0.90, 0.90, 1.0)
                gc_printf(string.format("▲ +%d TRASH INCOMING", P.atkBufferSum), tx, ty + 3, tw, 'center')
            end
        end
    end

    -- Floating Top Series Score (Esports Tournament HUD Pill — NO FULL TOP BAR)
    local hudW, hudH = 360, 48
    local hudX, hudY = 460, 12
    gc_setColor(0.04, 0.06, 0.13, 0.88)
    gc_rectangle('fill', hudX, hudY, hudW, hudH, 10)
    
    local anyMatchPoint = (myWins == targetWins - 1 or oppWins == targetWins - 1)
    if anyMatchPoint and roundState ~= 'round_over' then
        local goldPulse = 0.75 + 0.25 * math.sin(love.timer.getTime() * 6)
        gc_setColor(1.0, 0.82, 0.22, 0.85 * goldPulse)
        gc_setLineWidth(1.8)
    else
        gc_setColor(0.20, 0.30, 0.50, 0.70)
        gc_setLineWidth(1.4)
    end
    gc_rectangle('line', hudX, hudY, hudW, hudH, 10)

    setFont(11)
    gc_setColor(0.72, 0.82, 0.96, 0.85)
    gc_printf(string.format("ROUND %d  •  FIRST TO %d WINS", currentRound, targetWins), hudX, hudY + 5, hudW, 'center')

    setFont(22)
    gc_setColor(COLOR.lY)
    gc_printf(string.format("%d   —   %d", myWins, oppWins), hudX, hudY + 19, hudW, 'center')

    -- Subtle Minimalist Corner Action Badges (Floating, no bar)
    local mx, my = love.mouse.getPosition()
    if SCR and SCR.xOy then
        mx, my = SCR.xOy:inverseTransformPoint(mx, my)
    end

    -- Top-Left Forfeit Pill
    local btnSurrenderHov = mx >= 14 and mx <= 120 and my >= 10 and my <= 38
    gc_setColor(0.15, 0.06, 0.08, btnSurrenderHov and 0.85 or 0.50)
    gc_rectangle('fill', 14, 10, 106, 28, 6)
    gc_setColor(0.95, 0.35, 0.30, btnSurrenderHov and 0.90 or 0.45)
    gc_setLineWidth(1)
    gc_rectangle('line', 14, 10, 106, 28, 6)
    setFont(12)
    gc_setColor(1.0, 0.85, 0.85, btnSurrenderHov and 1.0 or 0.70)
    gc_printf("⚑ Forfeit [Esc]", 14, 16, 106, 'center')

    -- Top-Right Report Pill
    local btnReportHov = mx >= 1160 and mx <= 1266 and my >= 10 and my <= 38
    gc_setColor(0.12, 0.08, 0.18, btnReportHov and 0.85 or 0.50)
    gc_rectangle('fill', 1160, 10, 106, 28, 6)
    gc_setColor(0.75, 0.45, 0.95, btnReportHov and 0.90 or 0.45)
    gc_setLineWidth(1)
    gc_rectangle('line', 1160, 10, 106, 28, 6)
    setFont(12)
    gc_setColor(0.92, 0.85, 1.0, btnReportHov and 1.0 or 0.70)
    gc_printf("Report [F1]", 1160, 16, 106, 'center')

    -- Draw Point Scoring Presentation (Trails, Orbs, Shockwaves, Burst Particles)
    _drawScoreAnim()

    -- Round Start Banner Flare
    if roundStartBanner.timer > 0 and roundState ~= 'round_over' then
        local alpha = math.min(1.0, roundStartBanner.timer / 0.4)
        gc_setColor(0, 0, 0, 0.50 * alpha)
        gc_rectangle('fill', 440, 290, 400, 80, 10)
        gc_setColor(0.30, 0.85, 1.0, 0.80 * alpha)
        gc_setLineWidth(1.6)
        gc_rectangle('line', 440, 290, 400, 80, 10)

        setFont(26)
        gc_setColor(1, 1, 1, alpha)
        gc_printf(string.format("ROUND %d", roundStartBanner.round), 440, 302, 400, 'center')

        setFont(14)
        gc_setColor(0.30, 0.85, 1.0, alpha)
        gc_printf("READY — FIGHT!", 440, 338, 400, 'center')
    end

    -- Round Intermission Presentation Overlay
    if roundState == 'round_over' then
        local cardW, cardH = 540, 160
        local cardX, cardY = 370, 250

        -- Backdrop Frost Glass
        gc_setColor(0.04, 0.06, 0.14, 0.94)
        gc_rectangle('fill', cardX, cardY, cardW, cardH, 12)

        local isYouWin = (roundWinnerName == "YOU")
        local borderCol = isYouWin and {0.25, 0.95, 0.55} or {0.95, 0.35, 0.35}
        gc_setColor(borderCol[1], borderCol[2], borderCol[3], 0.85)
        gc_setLineWidth(2)
        gc_rectangle('line', cardX, cardY, cardW, cardH, 12)

        -- Top Header Tag
        setFont(12)
        gc_setColor(0.70, 0.80, 0.95, 0.85)
        gc_printf(string.format("ROUND %d COMPLETE  •  FIRST TO %d WINS", currentRound, targetWins), cardX, cardY + 14, cardW, 'center')

        -- Winner Announcement
        setFont(26)
        gc_setColor(isYouWin and COLOR.lG or COLOR.lR)
        gc_printf(isYouWin and "ROUND VICTORY!" or "ROUND DEFEAT", cardX, cardY + 36, cardW, 'center')

        -- Series Score Pill
        setFont(18)
        gc_setColor(COLOR.lY)
        gc_printf(string.format("Series Score:   YOU  %d   —   %d  %s", myWins, oppWins, (NET.matchFoundOppName or "OPPONENT")), cardX, cardY + 74, cardW, 'center')

        -- Countdown Text & Depleting Progress Bar
        local cdProg = math.max(0, math.min(1.0, roundOverTimer / 2.5))
        setFont(13)
        gc_setColor(0.80, 0.88, 1.0, 0.85)
        gc_printf(string.format("Next round starting in %.1fs...", roundOverTimer), cardX, cardY + 108, cardW, 'center')

        -- Progress bar track
        local barX, barY, barW, barH = cardX + 50, cardY + 134, cardW - 100, 6
        gc_setColor(0.12, 0.16, 0.28, 0.80)
        gc_rectangle('fill', barX, barY, barW, barH, 3)

        -- Progress bar fill
        gc_setColor(borderCol[1], borderCol[2], borderCol[3], 0.90)
        gc_rectangle('fill', barX, barY, barW * cdProg, barH, 3)
    end

    -- Forfeit Modal
    if forfeitModalOpen then
        gc_setColor(0, 0, 0, 0.75)
        gc_rectangle('fill', 0, 0, 1280, 720)

        local mX, mY, mW, mH = 430, 240, 420, 240
        gc_setColor(0.08, 0.10, 0.18, 0.98)
        gc_rectangle('fill', mX, mY, mW, mH, 12)
        gc_setColor(0.95, 0.35, 0.30, 0.90)
        gc_setLineWidth(2)
        gc_rectangle('line', mX, mY, mW, mH, 12)

        setFont(24)
        gc_setColor(1.0, 0.40, 0.35, 1.0)
        gc_printf("FORFEIT MATCH?", mX, mY + 24, mW, 'center')

        setFont(14)
        gc_setColor(0.85, 0.88, 0.95, 0.90)
        gc_printf("Surrendering will forfeit the entire series immediately\nand count as a defeat with rating loss.", mX + 24, mY + 70, mW - 48, 'center')

        -- Confirm Button
        local cBtnHov = mx >= mX + 30 and mx <= mX + 180 and my >= mY + 160 and my <= mY + 204
        gc_setColor(0.85, 0.20, 0.25, cBtnHov and 1.0 or 0.85)
        gc_rectangle('fill', mX + 30, mY + 160, 150, 44, 8)
        gc_setColor(1, 1, 1, 1)
        setFont(14)
        gc_printf("CONFIRM FORFEIT", mX + 30, mY + 174, 150, 'center')

        -- Cancel Button
        local kBtnHov = mx >= mX + 240 and mx <= mX + 390 and my >= mY + 160 and my <= mY + 204
        gc_setColor(0.20, 0.30, 0.45, kBtnHov and 1.0 or 0.85)
        gc_rectangle('fill', mX + 240, mY + 160, 150, 44, 8)
        gc_setColor(1, 1, 1, 1)
        setFont(14)
        gc_printf("RESUME [ESC]", mX + 240, mY + 174, 150, 'center')
    end
end

function scene.overDraw()
    REPORT.draw()
end

function scene.keyDown(key, isRep)
    if REPORT.isOpen() then
        return REPORT.keyDown(key, isRep)
    end

    if forfeitModalOpen then
        if key == 'escape' then
            forfeitModalOpen = false
            return true
        elseif key == 'return' or key == 'kpenter' then
            _forfeitMatch()
            return true
        end
        return true
    end

    if key == 'f1' then
        _openReport()
        return true
    elseif key == 'escape' then
        forfeitModalOpen = true
        return true
    end

    if playing and not NET.spectate and not noKey then
        local k = KEY_MAP.keyboard[key]
        if k and k > 0 and PLAYERS[1] then
            PLAYERS[1]:pressKey(k)
            VK.press(k)
        end
    end
end

function scene.keyUp(key)
    if not playing or NET.spectate or noKey then return end
    local k = KEY_MAP.keyboard[key]
    if k and k > 0 and PLAYERS[1] then
        PLAYERS[1]:releaseKey(k)
        VK.release(k)
    end
end

function scene.gamepadDown(key)
    if key == 'back' then
        scene.keyDown('escape')
    else
        if not playing or NET.spectate then return end
        local k = KEY_MAP.joystick[key]
        if k and k > 0 and PLAYERS[1] then
            PLAYERS[1]:pressKey(k)
            VK.press(k)
        end
    end
end

function scene.gamepadUp(key)
    if not playing or NET.spectate then return end
    local k = KEY_MAP.joystick[key]
    if k and k > 0 and PLAYERS[1] then
        PLAYERS[1]:releaseKey(k)
        VK.release(k)
    end
end

function scene.mouseDown(x, y)
    if REPORT.isOpen() then
        return REPORT.mouseDown(x, y)
    end

    if forfeitModalOpen then
        local mX, mY, mW, mH = 430, 240, 420, 240
        if x >= mX + 30 and x <= mX + 180 and y >= mY + 160 and y <= mY + 204 then
            _forfeitMatch()
            return true
        end
        if x >= mX + 240 and x <= mX + 390 and y >= mY + 160 and y <= mY + 204 then
            forfeitModalOpen = false
            return true
        end
        return true
    end

    -- Corner Action Badges
    if x >= 14 and x <= 120 and y >= 10 and y <= 38 then
        forfeitModalOpen = true
        return true
    end
    if x >= 1160 and x <= 1266 and y >= 10 and y <= 38 then
        _openReport()
        return true
    end
end

function scene.touchDown(x, y)
    if REPORT.isOpen() then
        return REPORT.mouseDown(x, y)
    end
    if forfeitModalOpen then
        return scene.mouseDown(x, y)
    end

    if x >= 14 and x <= 120 and y >= 10 and y <= 38 then
        forfeitModalOpen = true
        return true
    end
    if x >= 1160 and x <= 1266 and y >= 10 and y <= 38 then
        _openReport()
        return true
    end

    if not playing or NET.spectate or noTouch then return end
    local t = VK.on(x, y)
    if t and PLAYERS[1] then
        PLAYERS[1]:pressKey(t)
        VK.touch(t, x, y)
    end
end

function scene.touchUp(x, y)
    if not playing or NET.spectate or noTouch then return end
    local n = VK.on(x, y)
    if n and PLAYERS[1] then
        PLAYERS[1]:releaseKey(n)
        VK.release(n)
    end
end

function scene.touchMove()
    if touchMoveLastFrame or not playing or noTouch then return end
    touchMoveLastFrame = true

    local L = tc.getTouches()
    for i = #L, 1, -1 do
        L[2 * i - 1], L[2 * i] = SCR.xOy:inverseTransformPoint(tc.getPosition(L[i]))
    end
    local keys = VK.keys
    for n = 1, #keys do
        local B = keys[n]
        if B.ava then
            local nextKey
            for i = 1, #L, 2 do
                if (L[i] - B.x)^2 + (L[i + 1] - B.y)^2 <= B.r^2 then
                    nextKey = true
                    break
                end
            end
            if not nextKey and PLAYERS[1] then
                PLAYERS[1]:releaseKey(n)
                VK.release(n)
            end
        end
    end
end

function scene.textInput(t)
    if REPORT.isOpen() and REPORT.textInput(t) then return true end
end

return scene
