local scene={}

local CARD=require'parts.userCard'
local AUTH=require'parts.authModal'
local LOBBY=require'parts.lobbyPanel'
local REPORT=require'parts.reportModal'

local gc=love.graphics
local gc_setColor,gc_setLineWidth=gc.setColor,gc.setLineWidth
local gc_rectangle,gc_circle,gc_line=gc.rectangle,gc.circle,gc.line
local gc_print,gc_printf=gc.print,gc.printf
local setFont=FONT.set
local mStr=GC.mStr

local R=false
local animTimer=0

local function _fmtDelta(d)
    if d>0 then return "+"..d end
    return tostring(d)
end

local function _name(uid)
    if uid==USER.uid then return "You" end
    local n=USERS.getUsername(uid)
    return n and #n>0 and n or "Player"
end

local function getTierInfo(elo)
    elo = tonumber(elo) or 1200
    if elo >= 2200 then
        return "Master Division", { .85, .35, 1.0 }, "Tier I"
    elseif elo >= 1900 then
        return "Diamond Division", { .35, .85, 1.0 }, "Tier II"
    elseif elo >= 1600 then
        return "Platinum Division", { .35, 1.0, .75 }, "Tier III"
    elseif elo >= 1300 then
        return "Gold Division", { 1.0, .80, .25 }, "Tier IV"
    elseif elo >= 1000 then
        return "Silver Division", { .85, .90, 1.0 }, "Tier V"
    else
        return "Bronze Division", { .85, .55, .35 }, "Tier VI"
    end
end

function scene.enter()
    CARD.reset()
    CARD.enter()
    BG.set()
    LOBBY.reset()
    REPORT.close()
    R=NET.rankedResult or false
    animTimer=0

    local won = R and R.winnerId==USER.uid
    if won then
        SFX.play('win')
    else
        SFX.play('fail')
    end
    DiscordRPC.update("Ranked Results")
end

function scene.leave()
    CARD.leave()
    AUTH.close()
    REPORT.close()
    NET.rankedResult=false
end

function scene.keyDown(key,rep)
    if REPORT.isOpen() then return REPORT.keyDown(key,rep) end
    if AUTH.isOpen() then return AUTH.keyDown(key,rep) end
    if LOBBY.keyDown(key) then return true end

    if (key=='escape' or key=='back') and not rep then
        if LOBBY.isAnyOpen() then
            if LOBBY.chat and LOBBY.chat.visible then LOBBY.chat:toggle() end
            if LOBBY.playerList and LOBBY.playerList.visible then LOBBY.playerList:toggle() end
        else
            SCN.go('net_ranked')
        end
        return true
    elseif (key=='return' or key=='kpenter') and not rep then
        SCN.go('net_ranked')
        return true
    elseif key=='r' and not rep then
        if NET.watchRankedReplay then
            NET.watchRankedReplay()
        end
        return true
    elseif key=='f1' and not rep then
        if R and R.oppId and R.oppId ~= USER.uid then
            REPORT.open(R.oppId, _name(R.oppId), "Ranked 1v1", R.matchId or "")
        end
        return true
    end
end

function scene.textInput(t)
    if REPORT.isOpen() and REPORT.textInput(t) then return true end
    if AUTH.isOpen() and AUTH.textInput(t) then return true end
    if LOBBY.textInput(t) then return true end
end

function scene.mouseDown(x,y)
    if REPORT.isOpen() then
        return REPORT.mouseDown(x,y)
    end
    if AUTH.isOpen() then
        AUTH.mouseClick(x,y)
        return true
    end
    if CARD.mouseClick(x,y) then return true end
    if LOBBY.mouseClick(x,y) then return true end

    -- Custom Bottom Button Clicks
    -- Play Again (x=490..790, y=600..660)
    if x>=490 and x<=790 and y>=600 and y<=660 then
        SCN.go('net_ranked')
        return true
    end
    -- Watch Replay (x=240..460, y=606..654)
    if x>=240 and x<=460 and y>=606 and y<=654 then
        if NET.watchRankedReplay then NET.watchRankedReplay() end
        return true
    end
    -- Report (x=820..1040, y=606..654)
    if x>=820 and x<=1040 and y>=606 and y<=654 then
        if R and R.oppId and R.oppId ~= USER.uid then
            REPORT.open(R.oppId, _name(R.oppId), "Ranked 1v1", R.matchId or "")
        end
        return true
    end
    -- Back to Lobby (x=60..180, y=606..654)
    if x>=60 and x<=180 and y>=606 and y<=654 then
        SCN.go('net_ranked')
        return true
    end
end
scene.touchDown = scene.mouseDown

function scene.update(dt)
    animTimer = animTimer + dt
    REPORT.update(dt)
    CARD.update(dt)
    AUTH.update(dt)
    LOBBY.update(dt)
end

function scene.draw()
    local won=R and R.winnerId==USER.uid
    local t=animTimer

    -- Ambient Glow Background
    if won then
        gc_setColor(.04, .18, .10, .35)
        gc_rectangle('fill', 0, 0, 1280, 720)
    else
        gc_setColor(.18, .04, .06, .35)
        gc_rectangle('fill', 0, 0, 1280, 720)
    end

    -- Header Banner
    local pulse = 0.90 + 0.10 * math.sin(t * 3.5)
    setFont(56)
    if won then
        gc_setColor(COLOR.lG[1] * pulse, COLOR.lG[2] * pulse, COLOR.lG[3] * pulse, 1)
        mStr("VICTORY!", 640, 36)
    else
        gc_setColor(COLOR.lR[1] * pulse, COLOR.lR[2] * pulse, COLOR.lR[3] * pulse, 1)
        mStr("DEFEAT", 640, 36)
    end

    setFont(15)
    gc_setColor(0.75, 0.85, 1.0, 0.85)
    gc_printf("RANKED 1v1  •  FIRST TO 3 WINS SERIES", 0, 104, 1280, 'center')

    if not R then
        setFont(24)
        gc_setColor(COLOR.Z)
        gc_printf("No match data recorded", 0, 320, 1280, 'center')
        return
    end

    -- Center Series Score Pill (y=132..192)
    local myScore = R.myScore or (won and 3 or 0)
    local oppScore = R.oppScore or (won and 0 or 3)
    local targetWins = R.targetWins or 3

    local pillW, pillH = 340, 60
    local pillX = 640 - pillW / 2
    local pillY = 132
    gc_setColor(0.06, 0.09, 0.18, 0.95)
    gc_rectangle('fill', pillX, pillY, pillW, pillH, 10)
    gc_setColor(won and COLOR.lG or COLOR.lR)
    gc_setLineWidth(1.8)
    gc_rectangle('line', pillX, pillY, pillW, pillH, 10)

    setFont(11)
    gc_setColor(0.70, 0.80, 0.95, 0.85)
    gc_printf("FINAL SERIES SCORE", pillX, pillY + 6, pillW, 'center')

    setFont(28)
    gc_setColor(1, 1, 1, 1)
    local scoreText = string.format("%d   —   %d", myScore, oppScore)
    gc_printf(scoreText, pillX, pillY + 22, pillW, 'center')

    -- Two Showcase Cards (Left: You, Right: Opponent)
    local cardW, cardH = 440, 340
    local cardY = 216
    local gap = 40
    local leftX = 640 - cardW - gap / 2
    local rightX = 640 + gap / 2

    local myElo = R.myNew or (STAT.elo or 1200)
    local oppElo = R.oppNew or 1200
    local myTierName, myTierCol, myTierSub = getTierInfo(myElo)
    local oppTierName, oppTierCol, oppTierSub = getTierInfo(oppElo)

    local function _drawCard(x, name, oldE, newE, delta, rank, isYou, score, tierName, tierCol, tierSub)
        -- Glass body
        gc_setColor(0.06, 0.09, 0.18, 0.94)
        gc_rectangle('fill', x, cardY, cardW, cardH, 12)
        gc_setColor(isYou and (delta >= 0 and {.25, .85, .50, .85} or {.95, .32, .30, .85}) or {.30, .45, .75, .65})
        gc_setLineWidth(1.8)
        gc_rectangle('line', x, cardY, cardW, cardH, 12)

        -- Top Header Banner
        local headColor = isYou and (delta >= 0 and {.10, .30, .18, .95} or {.30, .10, .12, .95}) or {.14, .18, .30, .95}
        gc_setColor(headColor[1], headColor[2], headColor[3], headColor[4])
        gc_rectangle('fill', x, cardY, cardW, 48, 12)
        gc_rectangle('fill', x, cardY + 32, cardW, 16)
        gc_setColor(isYou and (delta >= 0 and COLOR.lG or COLOR.lR) or COLOR.lB)
        gc_setLineWidth(1)
        gc_line(x, cardY + 48, x + cardW, cardY + 48)

        setFont(16)
        gc_setColor(1, 1, 1, 1)
        local roleBadge = isYou and "PLAYER 1 (YOU)" or "PLAYER 2 (OPPONENT)"
        gc_printf(roleBadge, x + 20, cardY + 14, cardW - 40, 'left')

        setFont(14)
        gc_setColor(COLOR.lY)
        local winPips = ""
        for w=1,targetWins do
            winPips = winPips .. (w <= score and "◆ " or "◇ ")
        end
        gc_printf(winPips, x + 20, cardY + 16, cardW - 40, 'right')

        -- Username
        setFont(30)
        gc_setColor(1, 1, 1, 1)
        gc_printf(name, x + 20, cardY + 66, cardW - 40, 'center')

        -- Tier & Division
        setFont(14)
        gc_setColor(tierCol[1], tierCol[2], tierCol[3], 1)
        gc_printf(tierSub .. "  •  " .. tierName, x + 20, cardY + 104, cardW - 40, 'center')

        -- Rating Progression Box
        local rBoxY = cardY + 134
        gc_setColor(0.04, 0.07, 0.14, 0.90)
        gc_rectangle('fill', x + 24, rBoxY, cardW - 48, 100, 8)
        gc_setColor(0.25, 0.40, 0.70, 0.50)
        gc_setLineWidth(1)
        gc_rectangle('line', x + 24, rBoxY, cardW - 48, 100, 8)

        setFont(13)
        gc_setColor(0.70, 0.80, 0.95, 0.85)
        gc_printf("RATING ADJUSTMENT", x + 24, rBoxY + 10, cardW - 48, 'center')

        setFont(26)
        gc_setColor(1, 1, 1, 1)
        gc_printf(string.format("%d  ➔  %d", oldE, newE), x + 24, rBoxY + 32, cardW - 48, 'center')

        -- Delta badge
        setFont(18)
        gc_setColor(delta >= 0 and COLOR.lG or COLOR.lR)
        local deltaStr = string.format("%s ELO", _fmtDelta(delta))
        gc_printf(deltaStr, x + 24, rBoxY + 68, cardW - 48, 'center')

        -- Standing & Stats
        setFont(14)
        gc_setColor(0.80, 0.88, 1.0, 0.85)
        local rankStr = rank > 0 and ("Global Rank #" .. rank) or "Unranked"
        gc_printf(rankStr, x + 20, cardY + 252, cardW - 40, 'center')

        setFont(12)
        gc_setColor(0.65, 0.75, 0.90, 0.75)
        local matchStat = string.format("Series Score: %d/%d Wins", score, targetWins)
        gc_printf(matchStat, x + 20, cardY + 280, cardW - 40, 'center')
    end

    _drawCard(leftX, "You", R.myOld or 1200, R.myNew or 1200, R.myDelta or 0, R.myRank or 0, true, myScore, myTierName, myTierCol, myTierSub)
    _drawCard(rightX, _name(R.oppId), R.oppOld or 1200, R.oppNew or 1200, R.oppDelta or 0, R.oppRank or 0, false, oppScore, oppTierName, oppTierCol, oppTierSub)

    -- Bottom Call-to-Action Bar (y=600..664)
    local mx, my = love.mouse.getPosition()
    if SCR and SCR.xOy then
        mx, my = SCR.xOy:inverseTransformPoint(mx, my)
    end

    -- Return to Lobby [Esc] (x=60..180, y=606..654)
    local isBackHov = mx >= 60 and mx <= 180 and my >= 606 and my <= 654
    gc_setColor(0.12, 0.16, 0.26, isBackHov and 0.95 or 0.75)
    gc_rectangle('fill', 60, 606, 120, 48, 6)
    gc_setColor(0.35, 0.50, 0.75, isBackHov and 0.95 or 0.60)
    gc_setLineWidth(1)
    gc_rectangle('line', 60, 606, 120, 48, 6)
    setFont(13)
    gc_setColor(1, 1, 1, isBackHov and 1 or 0.85)
    gc_printf("← Lobby [Esc]", 60, 622, 120, 'center')

    -- Watch Replay [R] (x=240..460, y=606..654)
    local isRepHov = mx >= 240 and mx <= 460 and my >= 606 and my <= 654
    gc_setColor(0.12, 0.22, 0.40, isRepHov and 0.95 or 0.75)
    gc_rectangle('fill', 240, 606, 220, 48, 6)
    gc_setColor(0.40, 0.70, 1.0, isRepHov and 0.95 or 0.60)
    gc_setLineWidth(1)
    gc_rectangle('line', 240, 606, 220, 48, 6)
    setFont(14)
    gc_setColor(1, 1, 1, isRepHov and 1 or 0.85)
    gc_printf("▶ Watch Replay [R]", 240, 621, 220, 'center')

    -- Big Play Again [Enter] (x=490..790, y=600..660)
    local isPlayHov = mx >= 490 and mx <= 790 and my >= 600 and my <= 660
    gc_setColor(0.14, 0.65, 0.35, isPlayHov and 1.0 or 0.85)
    gc_rectangle('fill', 490, 600, 300, 60, 8)
    gc_setColor(0.45, 1.0, 0.65, 1)
    gc_setLineWidth(1.8)
    gc_rectangle('line', 490, 600, 300, 60, 8)
    setFont(20)
    gc_setColor(1, 1, 1, 1)
    gc_printf("⚔  PLAY AGAIN  [Enter]", 490, 618, 300, 'center')

    -- Report Opponent [F1] (x=820..1040, y=606..654)
    local isRepOpHov = mx >= 820 and mx <= 1040 and my >= 606 and my <= 654
    gc_setColor(0.24, 0.10, 0.14, isRepOpHov and 0.95 or 0.75)
    gc_rectangle('fill', 820, 606, 220, 48, 6)
    gc_setColor(0.95, 0.35, 0.40, isRepOpHov and 0.95 or 0.60)
    gc_setLineWidth(1)
    gc_rectangle('line', 820, 606, 220, 48, 6)
    setFont(14)
    gc_setColor(1.0, 0.85, 0.85, isRepOpHov and 1 or 0.85)
    gc_printf("Report Opponent [F1]", 820, 621, 220, 'center')
end

function scene.overDraw()
    LOBBY.draw()
    LOBBY.drawToggleButtons()
    CARD.draw()
    AUTH.draw()
    REPORT.draw()
end

scene.widgetList={}

return scene
