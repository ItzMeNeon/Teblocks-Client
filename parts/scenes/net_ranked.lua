local scene = {}

local CARD = require 'parts.userCard'
local AUTH = require 'parts.authModal'
local LOBBY = require 'parts.lobbyPanel'
local NET_BAR = require 'parts.netTopBar'

local gc = love.graphics
local gc_setColor, gc_setLineWidth = gc.setColor, gc.setLineWidth
local gc_rectangle, gc_circle = gc.rectangle, gc.circle
local setFont = FONT.set

local function getMousePos()
    if SCR and SCR.xOy then
        return SCR.xOy:inverseTransformPoint(love.mouse.getPosition())
    end
    return love.mouse.getPosition()
end

local function _startMatchmaking()
    if not (USER and USER.uid and USER.uid ~= false) then
        MES.new('warn', "Please log in to participate in Ranked matchmaking")
        AUTH.open('login')
        return
    end
    NET.matchmaking = true
    NET.searchTimer = 0
    NET.ranked_join()
    SFX.play('reach')
end

local function _cancelMatchmaking()
    NET.matchmaking = false
    NET.searchTimer = 0
    NET.ranked_leave()
    SFX.play('click')
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
    NET_BAR.initBG()
    if not NET.matchmaking then
        NET.searchTimer = 0
    end
    DiscordRPC.update("Ranked Arena")
end

function scene.leave()
    CARD.leave()
    AUTH.close()
end

function scene.keyDown(key, rep)
    if AUTH.isOpen() then return AUTH.keyDown(key, rep) end
    if LOBBY.keyDown(key) then return true end

    if (key == 'escape' or key == 'back') and not rep then
        if LOBBY.isAnyOpen() then
            if LOBBY.chat and LOBBY.chat.visible then LOBBY.chat:toggle() end
            if LOBBY.playerList and LOBBY.playerList.visible then LOBBY.playerList:toggle() end
        else
            SCN.backTo('lobby')
        end
        return false
    elseif (key == 'return' or key == 'kpenter') and not rep then
        if not NET.matchFoundPending then
            if NET.matchmaking then
                _cancelMatchmaking()
            else
                _startMatchmaking()
            end
        end
        return false
    end
    return true
end

function scene.textInput(t)
    if AUTH.isOpen() and AUTH.textInput(t) then return true end
    if LOBBY.textInput(t) then return true end
end

function scene.mouseDown(x, y)
    if AUTH.isOpen() then
        if AUTH.mouseClick(x, y) then return true end
        return true
    end
    if CARD.mouseClick(x, y) then return true end
    if LOBBY.mouseClick(x, y) then return true end

    -- Top bar (Back button + persistent matchmaking pill)
    local barAct = NET_BAR.mouseDown(x, y)
    if barAct == 'back' then
        SFX.play('back')
        SCN.backTo('lobby')
        return true
    elseif barAct == 'cancel_matchmaking' then
        _cancelMatchmaking()
        return true
    elseif barAct then
        return true
    end

    -- Matchmaking CTA Button / Cancel Button (x=140..590, y=525..585)
    if x >= 140 and x <= 590 and y >= 525 and y <= 585 and not NET.matchFoundPending then
        if NET.matchmaking then
            _cancelMatchmaking()
        else
            _startMatchmaking()
        end
        return true
    end

    -- Right Card: Chat Drawer button (x=690..1140, y=370..418)
    if x >= 690 and x <= 1140 and y >= 370 and y <= 418 then
        if LOBBY.chat then LOBBY.chat:toggle() end
        SFX.play('click')
        return true
    end

    -- Right Card: Players Drawer button (x=690..1140, y=430..478)
    if x >= 690 and x <= 1140 and y >= 430 and y <= 478 then
        if LOBBY.playerList then LOBBY.playerList:toggle() end
        SFX.play('click')
        return true
    end

    -- Bottom Bar: Back to Lobby (x=110..270, y=624..672)
    if x >= 110 and x <= 270 and y >= 624 and y <= 672 then
        SFX.play('back')
        SCN.backTo('lobby')
        return true
    end
end
scene.touchDown = scene.mouseDown

function scene.update(dt)
    CARD.update(dt)
    AUTH.update(dt)
    LOBBY.update(dt)
    NET_BAR.update(dt)

    if NET.matchmaking then
        NET.searchTimer = NET.searchTimer + dt
    end

    if NET.shakeStr and NET.shakeStr > 0 then
        NET.shakeStr = math.max(0, NET.shakeStr - dt * 16)
    end
end

function scene.draw()
    local t = love.timer.getTime()
    local mx, my = getMousePos()

    -- 1. Background Particles
    NET_BAR.drawBG()

    local elo = (USER and USER.uid and STAT.elo) or 1200
    local rank = (USER and USER.uid and STAT.globalRank) or 0
    local rankStr = rank > 0 and ("#" .. rank .. " Global") or "Unranked"
    local tierName, tierCol, tierSub = getTierInfo(elo)

    -- 2. Left Card: Competitive Standing & Matchmaking (x=110, y=80, w=510, h=530)
    local c1X, c1Y, c1W, c1H = 110, 80, 510, 530
    gc_setColor(.10, .08, .05, .90)
    gc_rectangle('fill', c1X, c1Y, c1W, c1H, 10)
    gc_setColor(.75, .55, .18, .75)
    gc_setLineWidth(1.5)
    gc_rectangle('line', c1X, c1Y, c1W, c1H, 10)

    -- Top glowing banner
    gc_setColor(.70, .45, .12, .8)
    gc_rectangle('fill', c1X, c1Y, c1W, 76, 10)
    gc_rectangle('fill', c1X, c1Y + 56, c1W, 20)

    gc_setColor(1.0, .80, .25, .85)
    gc_rectangle('fill', c1X + 2, c1Y + 74, c1W - 4, 3)

    setFont(24)
    gc_setColor(1, 1, 1, 1)
    gc.print("⚡ COMPETITIVE STANDING", c1X + 24, c1Y + 16)

    setFont(13)
    gc_setColor(1.0, .92, .75, .95)
    gc.print("Official 1v1 Skill Rating & Ladder", c1X + 26, c1Y + 48)

    -- Tier Emblem & Rating Display
    local tierBoxY = c1Y + 96
    gc_setColor(.16, .12, .06, .8)
    gc_rectangle('fill', c1X + 24, tierBoxY, c1W - 48, 140, 8)
    gc_setColor(tierCol[1], tierCol[2], tierCol[3], .6)
    gc_setLineWidth(1)
    gc_rectangle('line', c1X + 24, tierBoxY, c1W - 48, 140, 8)

    -- Division Badge
    gc_setColor(tierCol[1], tierCol[2], tierCol[3], .85)
    setFont(14)
    gc.print("★ " .. tierName .. " (" .. tierSub .. ")", c1X + 42, tierBoxY + 16)

    -- Big ELO display
    setFont(44)
    gc_setColor(1.0, .88, .35, 1)
    gc.print(tostring(elo), c1X + 42, tierBoxY + 38)

    setFont(16)
    gc_setColor(.85, .75, .50, .85)
    gc.print("ELO", c1X + 42 + FONT.get(44):getWidth(tostring(elo)) + 8, tierBoxY + 58)

    -- Global Rank Badge
    local rkX = c1X + 310
    gc_setColor(.22, .18, .10, .9)
    gc_rectangle('fill', rkX, tierBoxY + 36, 150, 48, 6)
    gc_setColor(.65, .50, .20, .7)
    gc_setLineWidth(1)
    gc_rectangle('line', rkX, tierBoxY + 36, 150, 48, 6)

    setFont(11)
    gc_setColor(.85, .78, .60, .8)
    gc.printf("LEADERBOARD", rkX, tierBoxY + 42, 150, 'center')

    setFont(16)
    gc_setColor(1, 1, 1, 1)
    gc.printf(rankStr, rkX, tierBoxY + 58, 150, 'center')

    -- Progress hint
    setFont(12)
    gc_setColor(.75, .70, .60, .8)
    local subTip = (USER and USER.uid) and "Win matches to earn ELO and advance to higher divisions." or "Log in to track rating and climb the leaderboards."
    gc.print(subTip, c1X + 42, tierBoxY + 110)

    -- Matchmaking Status / Active Queue Radar
    local statusY = c1Y + 256
    if NET.matchmaking then
        -- Pulsing searching box
        local pulseAlpha = 0.7 + 0.3 * math.sin(t * 4)
        gc_setColor(.20, .14, .05, .9)
        gc_rectangle('fill', c1X + 24, statusY, c1W - 48, 155, 8)
        gc_setColor(1.0, .75, .20, pulseAlpha)
        gc_setLineWidth(1.5)
        gc_rectangle('line', c1X + 24, statusY, c1W - 48, 155, 8)

        local dots = string.rep('.', math.floor(NET.searchTimer * 2) % 4)
        setFont(22)
        gc_setColor(1.0, .85, .30, 1)
        gc.printf("Searching for Opponent" .. dots, c1X + 24, statusY + 28, c1W - 48, 'center')

        local secs = math.floor(NET.searchTimer or 0)
        local timeStr = ("Elapsed: %02d:%02d"):format(math.floor(secs / 60), secs % 60)
        setFont(18)
        gc_setColor(1, 1, 1, .95)
        gc.printf(timeStr, c1X + 24, statusY + 65, c1W - 48, 'center')

        setFont(12)
        gc_setColor(.80, .72, .55, .8)
        gc.printf("Expanding search MMR radius based on queue activity...", c1X + 24, statusY + 105, c1W - 48, 'center')

        -- Big Cancel Button
        local isCancelHov = (mx >= c1X + 30 and mx <= c1X + c1W - 30 and my >= c1Y + c1H - 85 and my <= c1Y + c1H - 25)
        gc_setColor(isCancelHov and .75 or .60, isCancelHov and .18 or .12, isCancelHov and .22 or .15, .95)
        gc_rectangle('fill', c1X + 30, c1Y + c1H - 85, c1W - 60, 60, 8)
        gc_setColor(1.0, .45, .50, 1)
        gc_setLineWidth(1.5)
        gc_rectangle('line', c1X + 30, c1Y + c1H - 85, c1W - 60, 60, 8)

        setFont(18)
        gc_setColor(1, 1, 1, 1)
        gc.printf("✕  CANCEL SEARCH  [Esc]", c1X + 30, c1Y + c1H - 66, c1W - 60, 'center')
    else
        -- Idle box
        gc_setColor(.12, .10, .06, .7)
        gc_rectangle('fill', c1X + 24, statusY, c1W - 48, 155, 8)
        gc_setColor(.40, .32, .15, .5)
        gc_setLineWidth(1)
        gc_rectangle('line', c1X + 24, statusY, c1W - 48, 155, 8)

        setFont(16)
        gc_setColor(1, 1, 1, .95)
        gc.printf("Ready for Matchmaking", c1X + 24, statusY + 24, c1W - 48, 'center')

        setFont(13)
        gc_setColor(.80, .75, .65, .8)
        gc.printf("Click below or press [Enter] to queue into the 1v1 ranked pool.", c1X + 34, statusY + 58, c1W - 68, 'center')
        gc.printf("Matches are standard 1v1 first-to-two wins with authoritative server timing.", c1X + 34, statusY + 86, c1W - 68, 'center')

        -- Big Find Match CTA Button
        local isMatchHov = (mx >= c1X + 30 and mx <= c1X + c1W - 30 and my >= c1Y + c1H - 85 and my <= c1Y + c1H - 25)
        if isMatchHov then
            gc_setColor(.18, .75, .38, .95)
            gc_rectangle('fill', c1X + 30, c1Y + c1H - 85, c1W - 60, 60, 8)
            gc_setColor(.45, 1.0, .65, 1)
            gc_setLineWidth(1.5)
            gc_rectangle('line', c1X + 30, c1Y + c1H - 85, c1W - 60, 60, 8)
        else
            gc_setColor(.14, .60, .30, .9)
            gc_rectangle('fill', c1X + 30, c1Y + c1H - 85, c1W - 60, 60, 8)
            gc_setColor(.35, .88, .50, .8)
            gc_setLineWidth(1)
            gc_rectangle('line', c1X + 30, c1Y + c1H - 85, c1W - 60, 60, 8)
        end
        setFont(19)
        gc_setColor(1, 1, 1, 1)
        gc.printf("⚔  FIND 1v1 MATCH  [Enter]", c1X + 30, c1Y + c1H - 66, c1W - 60, 'center')
    end

    -- 3. Right Card: Arena Rules & Live Social (x=660, y=80, w=510, h=530)
    local c2X, c2Y, c2W, c2H = 660, 80, 510, 530
    gc_setColor(.05, .08, .18, .90)
    gc_rectangle('fill', c2X, c2Y, c2W, c2H, 10)
    gc_setColor(.20, .32, .60, .6)
    gc_setLineWidth(1.5)
    gc_rectangle('line', c2X, c2Y, c2W, c2H, 10)

    -- Top glowing banner
    gc_setColor(.16, .35, .75, .75)
    gc_rectangle('fill', c2X, c2Y, c2W, 76, 10)
    gc_rectangle('fill', c2X, c2Y + 56, c2W, 20)

    gc_setColor(.40, .75, 1.0, .85)
    gc_rectangle('fill', c2X + 2, c2Y + 74, c2W - 4, 3)

    setFont(24)
    gc_setColor(1, 1, 1, 1)
    gc.print("📜 ARENA RULES & FAIR PLAY", c2X + 24, c2Y + 16)

    setFont(13)
    gc_setColor(.80, .92, 1.0, .95)
    gc.print("Standardized Competitive Format & Guidelines", c2X + 26, c2Y + 48)

    -- Rules List Box
    local rBoxY = c2Y + 96
    gc_setColor(.08, .12, .26, .7)
    gc_rectangle('fill', c2X + 24, rBoxY, c2W - 48, 230, 8)
    gc_setColor(.22, .32, .58, .5)
    gc_setLineWidth(1)
    gc_rectangle('line', c2X + 24, rBoxY, c2W - 48, 230, 8)

    local arenaRules = {
        { icon = "⚔", title = "Match Format: 1v1 First to 2 Wins", desc = "Best of 3 rounds. Both players start with identical random seeds." },
        { icon = "⏱", title = "Standard 7-Bag Randomizer", desc = "Uniform piece generation with standard SRS rotation guidelines." },
        { icon = "🛡", title = "Authoritative Server Validation", desc = "Every drop and line clear is verified server-side against tampering." },
        { icon = "📈", title = "Dynamic ELO Stakes", desc = "Earn +15 to +35 rating on victory; defeat costs -15 to -30 ELO." },
    }

    for i, rl in ipairs(arenaRules) do
        local ry = rBoxY + 14 + (i - 1) * 52
        gc_setColor(.35, .80, 1.0, .95)
        setFont(16)
        gc.print(rl.icon, c2X + 38, ry)

        gc_setColor(1, 1, 1, .98)
        setFont(13)
        gc.print(rl.title, c2X + 64, ry)

        gc_setColor(.65, .75, .92, .8)
        setFont(11)
        gc.print(rl.desc, c2X + 64, ry + 18)
    end

    -- Quick Drawers Access Buttons
    local isChatHov = (mx >= c2X + 30 and mx <= c2X + c2W - 30 and my >= c2Y + 360 and my <= c2Y + 412)
    gc_setColor(isChatHov and .18 or .10, isChatHov and .26 or .15, isChatHov and .50 or .30, .85)
    gc_rectangle('fill', c2X + 30, c2Y + 360, c2W - 60, 52, 6)
    gc_setColor(.30, .45, .75, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', c2X + 30, c2Y + 360, c2W - 60, 52, 6)
    setFont(15)
    gc_setColor(1, 1, 1, .95)
    gc.printf("💬 Open Global Lobby Chat", c2X + 30, c2Y + 376, c2W - 60, 'center')

    local isListHov = (mx >= c2X + 30 and mx <= c2X + c2W - 30 and my >= c2Y + 426 and my <= c2Y + 478)
    gc_setColor(isListHov and .18 or .10, isListHov and .26 or .15, isListHov and .50 or .30, .85)
    gc_rectangle('fill', c2X + 30, c2Y + 426, c2W - 60, 52, 6)
    gc_setColor(.30, .45, .75, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', c2X + 30, c2Y + 426, c2W - 60, 52, 6)
    setFont(15)
    gc_setColor(1, 1, 1, .95)
    gc.printf("👥 View Online Players", c2X + 30, c2Y + 442, c2W - 60, 'center')

    -- 4. Bottom Navigation Bar
    local isBackHov = (mx >= 110 and mx <= 270 and my >= 624 and my <= 672)
    gc_setColor(isBackHov and .22 or .12, isBackHov and .18 or .10, isBackHov and .30 or .18, .85)
    gc_rectangle('fill', 110, 624, 160, 48, 6)
    gc_setColor(.55, .35, .60, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', 110, 624, 160, 48, 6)
    gc_setColor(1, 1, 1, .9)
    setFont(14)
    gc.printf("← Lobby [Esc]", 110, 638, 160, 'center')

    setFont(12)
    gc_setColor(.55, .65, .85, .75)
    gc.printf("Ranked Controls: [Enter] Start / Cancel Match  •  [Esc] Back to Lobby", 300, 640, 870, 'right')

    -- 5. Top Bar
    NET_BAR.draw("RANKED 1v1 ARENA", "← Lobby")
end

function scene.overDraw()
    LOBBY.draw()
    LOBBY.drawToggleButtons()
    CARD.draw()
    AUTH.draw()
end

scene.widgetList = {}

return scene
