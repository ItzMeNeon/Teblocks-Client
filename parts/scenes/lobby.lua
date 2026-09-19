local scene = {}

local CARD = require 'parts.userCard'
local AUTH = require 'parts.authModal'
local LOBBY = require 'parts.lobbyPanel'
local NET_BAR = require 'parts.netTopBar'
local REPORT = require 'parts.reportModal'

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

local function _goCasual()
    CARD.leave()
    SCN.go('net_rooms')
end

local function _goRanked()
    CARD.leave()
    SCN.go('net_ranked')
end

local function _refreshOnline()
    NET.online_getPlayers()
end

function scene.enter()
    CARD.reset()
    CARD.enter()
    BG.set()
    LOBBY.reset()
    NET_BAR.initBG()
    NET.online_getPlayers()
    DiscordRPC.update("Multiplayer Hub")
end

function scene.leave()
    CARD.leave()
    AUTH.close()
end

function scene.keyDown(key, rep)
    if REPORT.isOpen() then return REPORT.keyDown(key, rep) end
    if AUTH.isOpen() then return AUTH.keyDown(key, rep) end
    if LOBBY.keyDown(key) then return true end

    if (key == 'escape' or key == 'back') and not rep then
        if LOBBY.isAnyOpen() then
            if LOBBY.chat and LOBBY.chat.visible then LOBBY.chat:toggle() end
            if LOBBY.playerList and LOBBY.playerList.visible then LOBBY.playerList:toggle() end
        else
            SCN.backTo('main')
        end
        return false
    elseif (key == '1' or key == 'c') and not rep then
        _goCasual()
        return false
    elseif (key == '2' or key == 'r') and not rep then
        _goRanked()
        return false
    elseif key == 'return' or key == 'kpenter' then
        CARD.openMenu()
    elseif key == 'f5' or (key == 'r' and love.keyboard.isDown('lctrl', 'rctrl')) then
        _refreshOnline()
    else
        return true
    end
end

function scene.textInput(t)
    if REPORT.isOpen() and REPORT.textInput(t) then return true end
    if AUTH.isOpen() and AUTH.textInput(t) then return true end
    if LOBBY.textInput(t) then return true end
end

function scene.mouseDown(x, y)
    if REPORT.isOpen() then
        if REPORT.mouseClick(x, y) then return true end
        return true
    end
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
        SCN.backTo('main')
        return true
    elseif barAct then
        return true
    end

    -- Casual Card (x=135..605, y=100..590)
    if x >= 135 and x <= 605 and y >= 100 and y <= 590 then
        SFX.play('click')
        _goCasual()
        return true
    end

    -- Ranked Card (x=675..1145, y=100..590)
    if x >= 675 and x <= 1145 and y >= 100 and y <= 590 then
        SFX.play('click')
        _goRanked()
        return true
    end

    -- Bottom Bar: Chat Toggle button (x=135..275, y=615..665)
    if x >= 135 and x <= 275 and y >= 615 and y <= 665 then
        if LOBBY.chat then LOBBY.chat:toggle() end
        SFX.play('click')
        return true
    end

    -- Bottom Bar: Player List Toggle button (x=290..450, y=615..665)
    if x >= 290 and x <= 450 and y >= 615 and y <= 665 then
        if LOBBY.playerList then LOBBY.playerList:toggle() end
        SFX.play('click')
        return true
    end
end
scene.touchDown = scene.mouseDown

function scene.update(dt)
    CARD.update(dt)
    AUTH.update(dt)
    LOBBY.update(dt)
    NET_BAR.update(dt)
    REPORT.update(dt)

    if NET.matchFoundPending and NET.matchFoundCountdown > 0 then
        NET.updateMatchFoundCountdown(dt)
    end
end

function scene.draw()
    local t = love.timer.getTime()
    local mx, my = getMousePos()

    -- 1. Ambient Particle Background
    NET_BAR.drawBG()

    -- 2. Two Main Mode Cards
    local cY = 100
    local cW = 470
    local cH = 490

    -- ─── LEFT CARD: CASUAL ROOMS (x = 135) ───────────────
    local c1X = 135
    local isHov1 = (mx >= c1X and mx <= c1X + cW and my >= cY and my <= cY + cH)

    -- Card Base
    if isHov1 then
        gc_setColor(.08, .13, .30, .92)
        gc_rectangle('fill', c1X, cY, cW, cH, 10)
        gc_setColor(.35, .65, 1.0, .95)
        gc_setLineWidth(2)
        gc_rectangle('line', c1X, cY, cW, cH, 10)
    else
        gc_setColor(.05, .08, .20, .85)
        gc_rectangle('fill', c1X, cY, cW, cH, 10)
        gc_setColor(.20, .32, .60, .6)
        gc_setLineWidth(1.5)
        gc_rectangle('line', c1X, cY, cW, cH, 10)
    end

    -- Top glowing banner
    gc_setColor(.18, .45, .85, isHov1 and .85 or .6)
    gc_rectangle('fill', c1X, cY, cW, 80, 10)
    gc_rectangle('fill', c1X, cY + 60, cW, 20) -- square out bottom corners of banner

    -- Accent indicator line
    gc_setColor(.45, .78, 1.0, isHov1 and 1 or .7)
    gc_rectangle('fill', c1X + 2, cY + 78, cW - 4, 3)

    -- Header Icon & Title
    setFont(28)
    gc_setColor(1, 1, 1, 1)
    gc.print("🎮 CASUAL ROOMS", c1X + 24, cY + 16)

    setFont(13)
    gc_setColor(.80, .92, 1.0, .95)
    gc.print("Custom Lobbies, Rulesets & Free Play", c1X + 26, cY + 52)

    -- Body Description
    setFont(14)
    gc_setColor(.85, .90, 1.0, .9)
    gc.printf("Play custom games with friends or community players. Join existing public lobbies or host your own private rooms.", c1X + 26, cY + 106, cW - 52)

    -- Features Showcase Box
    local fBoxY = cY + 180
    gc_setColor(.08, .12, .26, .7)
    gc_rectangle('fill', c1X + 24, fBoxY, cW - 48, 175, 8)
    gc_setColor(.22, .32, .58, .5)
    gc_setLineWidth(1)
    gc_rectangle('line', c1X + 24, fBoxY, cW - 48, 175, 8)

    local casualFeatures = {
        { icon = "✦", title = "Custom Rule Sets", desc = "Adjust gravity, speeds, garbage, and piece sets" },
        { icon = "✦", title = "Spectator Slots", desc = "Watch ongoing matches in real time with live chat" },
        { icon = "✦", title = "Private Room Passwords", desc = "Secure your room for private friends or tournaments" },
    }

    for i, feat in ipairs(casualFeatures) do
        local fy = fBoxY + 14 + (i - 1) * 52
        gc_setColor(.35, .80, 1.0, .95)
        setFont(16)
        gc.print(feat.icon, c1X + 38, fy)

        gc_setColor(1, 1, 1, .98)
        setFont(14)
        gc.print(feat.title, c1X + 62, fy)

        gc_setColor(.65, .75, .92, .8)
        setFont(11)
        gc.print(feat.desc, c1X + 62, fy + 18)
    end

    -- Bottom CTA Action Button
    local btn1Y = cY + cH - 76
    local isBtn1Hov = (mx >= c1X + 24 and mx <= c1X + cW - 24 and my >= btn1Y and my <= btn1Y + 54)
    if isBtn1Hov or isHov1 then
        gc_setColor(.20, .55, 1.0, .95)
        gc_rectangle('fill', c1X + 24, btn1Y, cW - 48, 54, 8)
        gc_setColor(.75, .90, 1.0, 1)
        gc_setLineWidth(1.5)
        gc_rectangle('line', c1X + 24, btn1Y, cW - 48, 54, 8)
    else
        gc_setColor(.14, .38, .80, .9)
        gc_rectangle('fill', c1X + 24, btn1Y, cW - 48, 54, 8)
        gc_setColor(.45, .68, 1.0, .8)
        gc_setLineWidth(1)
        gc_rectangle('line', c1X + 24, btn1Y, cW - 48, 54, 8)
    end
    gc_setColor(1, 1, 1, 1)
    setFont(17)
    gc.printf("BROWSE CASUAL ROOMS  →", c1X + 24, btn1Y + 16, cW - 48, 'center')

    -- ─── RIGHT CARD: RANKED 1v1 ARENA (x = 675) ──────────
    local c2X = 675
    local isHov2 = (mx >= c2X and mx <= c2X + cW and my >= cY and my <= cY + cH)

    -- Card Base
    if isHov2 then
        gc_setColor(.18, .15, .08, .92)
        gc_rectangle('fill', c2X, cY, cW, cH, 10)
        gc_setColor(.95, .75, .25, .95)
        gc_setLineWidth(2)
        gc_rectangle('line', c2X, cY, cW, cH, 10)
    else
        gc_setColor(.11, .09, .06, .85)
        gc_rectangle('fill', c2X, cY, cW, cH, 10)
        gc_setColor(.60, .45, .18, .6)
        gc_setLineWidth(1.5)
        gc_rectangle('line', c2X, cY, cW, cH, 10)
    end

    -- Top glowing banner
    gc_setColor(.75, .50, .12, isHov2 and .85 or .65)
    gc_rectangle('fill', c2X, cY, cW, 80, 10)
    gc_rectangle('fill', c2X, cY + 60, cW, 20)

    -- Accent indicator line
    gc_setColor(1.0, .82, .30, isHov2 and 1 or .75)
    gc_rectangle('fill', c2X + 2, cY + 78, cW - 4, 3)

    -- Header Icon & Title
    setFont(28)
    gc_setColor(1, 1, 1, 1)
    gc.print("⚡ RANKED 1v1 ARENA", c2X + 24, cY + 16)

    setFont(13)
    gc_setColor(1.0, .92, .75, .95)
    gc.print("Competitive Ladder & Skill-Based Matchmaking", c2X + 26, cY + 52)

    -- Player Standing Overview Box
    local eloBoxY = cY + 98
    gc_setColor(.18, .14, .07, .75)
    gc_rectangle('fill', c2X + 24, eloBoxY, cW - 48, 76, 8)
    gc_setColor(.65, .50, .18, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', c2X + 24, eloBoxY, cW - 48, 76, 8)

    local elo = (USER and USER.uid and STAT.elo) or 1200
    local rank = (USER and USER.uid and STAT.globalRank) or 0
    local rankStr = rank > 0 and ("#" .. rank) or "Unranked"

    setFont(11)
    gc_setColor(.85, .75, .50, .85)
    gc.print("CURRENT RATING", c2X + 42, eloBoxY + 14)
    gc.print("LEADERBOARD RANK", c2X + 250, eloBoxY + 14)

    setFont(26)
    gc_setColor(1.0, .85, .35, 1)
    gc.print(tostring(elo) .. " ELO", c2X + 42, eloBoxY + 32)

    gc_setColor(1, 1, 1, .95)
    gc.print(rankStr, c2X + 250, eloBoxY + 32)

    -- Features Showcase Box
    local rBoxY = cY + 188
    gc_setColor(.16, .12, .06, .7)
    gc_rectangle('fill', c2X + 24, rBoxY, cW - 48, 167, 8)
    gc_setColor(.55, .40, .15, .5)
    gc_setLineWidth(1)
    gc_rectangle('line', c2X + 24, rBoxY, cW - 48, 167, 8)

    local rankedFeatures = {
        { icon = "⚔", title = "Standard 1v1 Format", desc = "First to 2 wins (Best of 3) with standard 7-bag" },
        { icon = "🛡", title = "Anti-Cheat Verification", desc = "Authoritative server-side piece validation" },
        { icon = "🏆", title = "MMR Rating & Leaderboard", desc = "Climb the global ladder with win/loss ELO stakes" },
    }

    for i, feat in ipairs(rankedFeatures) do
        local fy = rBoxY + 12 + (i - 1) * 50
        gc_setColor(1.0, .80, .25, .95)
        setFont(16)
        gc.print(feat.icon, c2X + 38, fy)

        gc_setColor(1, 1, 1, .98)
        setFont(14)
        gc.print(feat.title, c2X + 64, fy)

        gc_setColor(.85, .78, .65, .8)
        setFont(11)
        gc.print(feat.desc, c2X + 64, fy + 18)
    end

    -- Bottom CTA Action Button
    local btn2Y = cY + cH - 76
    local isBtn2Hov = (mx >= c2X + 24 and mx <= c2X + cW - 24 and my >= btn2Y and my <= btn2Y + 54)
    if isBtn2Hov or isHov2 then
        gc_setColor(.95, .65, .15, .95)
        gc_rectangle('fill', c2X + 24, btn2Y, cW - 48, 54, 8)
        gc_setColor(1.0, .92, .65, 1)
        gc_setLineWidth(1.5)
        gc_rectangle('line', c2X + 24, btn2Y, cW - 48, 54, 8)
    else
        gc_setColor(.80, .50, .10, .9)
        gc_rectangle('fill', c2X + 24, btn2Y, cW - 48, 54, 8)
        gc_setColor(.95, .75, .30, .8)
        gc_setLineWidth(1)
        gc_rectangle('line', c2X + 24, btn2Y, cW - 48, 54, 8)
    end
    gc_setColor(1, 1, 1, 1)
    setFont(17)
    gc.printf("ENTER RANKED ARENA  →", c2X + 24, btn2Y + 16, cW - 48, 'center')

    -- 3. Bottom Utility Bar
    local isChatHov = (mx >= 135 and mx <= 275 and my >= 615 and my <= 665)
    gc_setColor(isChatHov and .18 or .08, isChatHov and .26 or .12, isChatHov and .50 or .24, .85)
    gc_rectangle('fill', 135, 615, 140, 48, 6)
    gc_setColor(.30, .45, .75, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', 135, 615, 140, 48, 6)
    gc_setColor(1, 1, 1, .9)
    setFont(14)
    gc.printf("💬 Chat", 135, 629, 140, 'center')

    local isListHov = (mx >= 290 and mx <= 450 and my >= 615 and my <= 665)
    gc_setColor(isListHov and .18 or .08, isListHov and .26 or .12, isListHov and .50 or .24, .85)
    gc_rectangle('fill', 290, 615, 160, 48, 6)
    gc_setColor(.30, .45, .75, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', 290, 615, 160, 48, 6)
    gc_setColor(1, 1, 1, .9)
    setFont(14)
    gc.printf("👥 Player List", 290, 629, 160, 'center')

    -- Keyboard Hints (Bottom Right)
    setFont(12)
    gc_setColor(.55, .65, .85, .75)
    gc.printf("Keyboard Shortcuts: [1] Casual  •  [2] Ranked  •  [Esc] Main Menu", 500, 632, 645, 'right')

    -- 4. Top Bar
    NET_BAR.draw("ONLINE MULTIPLAYER HUB", "← Main Menu")
end

function scene.overDraw()
    LOBBY.draw()
    LOBBY.drawToggleButtons()
    CARD.draw()
    AUTH.draw()
    REPORT.draw()
end

scene.widgetList = {}

return scene
