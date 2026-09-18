local scene = {}

local CARD = require 'parts.userCard'
local AUTH = require 'parts.authModal'
local LOBBY = require 'parts.lobbyPanel'
local NET_BAR = require 'parts.netTopBar'

local gc = love.graphics
local gc_setColor, gc_setLineWidth = gc.setColor, gc.setLineWidth
local gc_draw, gc_rectangle, gc_circle = gc.draw, gc.rectangle, gc.circle
local gc_print, gc_printf = gc.print, gc.printf
local setFont = FONT.set

local NET = NET
local fetchTimer = 0

local function getMousePos()
    if SCR and SCR.xOy then
        return SCR.xOy:inverseTransformPoint(love.mouse.getPosition())
    end
    return love.mouse.getPosition()
end

local function fitText(str, maxW, fontSz)
    if not str then return "" end
    setFont(fontSz or 14)
    local font = gc.getFont()
    if not font or font:getWidth(str) <= maxW then return str end
    local s = str
    while #s > 1 and font:getWidth(s .. "…") > maxW do
        s = s:sub(1, -2)
    end
    return s .. "…"
end

local roomList = WIDGET.newListBox{
    name  = 'roomList',
    x     = 52,
    y     = 124,
    w     = 756,
    h     = 405,
    lineH = 58,
    drawF = function(item, id, ifSel)
        local rowW, rowH = 756, 52
        local mx, my = getMousePos()
        -- ListBox items are drawn in relative coordinates to the row (x=0..rowW, y=0..rowH)
        
        -- Row Card Background
        if ifSel then
            gc_setColor(.18, .28, .62, .95)
            gc_rectangle('fill', 0, 0, rowW, rowH, 6)
            gc_setColor(.45, .75, 1.0, 1)
            gc_setLineWidth(1.5)
            gc_rectangle('line', 0, 0, rowW, rowH, 6)
            -- Highlight pill on left
            gc_setColor(.4, .8, 1.0, 1)
            gc_rectangle('fill', 0, 2, 4, rowH - 4, 2)
        else
            gc_setColor(.07, .10, .24, .75)
            gc_rectangle('fill', 0, 0, rowW, rowH, 6)
            gc_setColor(.18, .24, .45, .5)
            gc_setLineWidth(1)
            gc_rectangle('line', 0, 0, rowW, rowH, 6)
        end

        -- Room Number / ID badge
        gc_setColor(.14, .20, .42, .8)
        gc_rectangle('fill', 14, 10, 52, 32, 4)
        gc_setColor(.45, .65, 1.0, .7)
        gc_setLineWidth(1)
        gc_rectangle('line', 14, 10, 52, 32, 4)
        setFont(13)
        gc_setColor(.85, .92, 1.0, .95)
        gc_printf("#" .. tostring(id), 14, 18, 52, 'center')

        if type(item) == 'table' then
            -- Lock icon if password-protected
            local nameStartX = 78
            if item.private then
                gc_setColor(1.0, .80, .25, 1)
                setFont(15)
                gc_print("🔒", 74, 16)
                nameStartX = 98
            end

            -- Room Name
            setFont(16)
            gc_setColor(ifSel and 1 or .92, ifSel and 1 or .95, 1, 1)
            local rName = item.name or ("Room " .. tostring(id))
            gc_print(fitText(rName, 360, 16), nameStartX, 16)

            -- State Badge
            local stateX = 490
            local stateStr = item.state or "Standby"
            if stateStr == 'Standby' then
                gc_setColor(.12, .32, .55, .85)
                gc_rectangle('fill', stateX, 12, 90, 28, 4)
                gc_setColor(.35, .80, 1.0, 1)
                gc_setLineWidth(1)
                gc_rectangle('line', stateX, 12, 90, 28, 4)
                gc_setColor(1, 1, 1, 1)
                setFont(11)
                gc_printf("● STANDBY", stateX, 19, 90, 'center')
            elseif stateStr == 'Ready' then
                gc_setColor(.15, .25, .65, .85)
                gc_rectangle('fill', stateX, 12, 90, 28, 4)
                gc_setColor(.45, .65, 1.0, 1)
                gc_setLineWidth(1)
                gc_rectangle('line', stateX, 12, 90, 28, 4)
                gc_setColor(1, 1, 1, 1)
                setFont(11)
                gc_printf("● READY", stateX, 19, 90, 'center')
            elseif stateStr == 'Playing' then
                gc_setColor(.12, .45, .25, .85)
                gc_rectangle('fill', stateX, 12, 90, 28, 4)
                gc_setColor(.35, 1.0, .55, 1)
                gc_setLineWidth(1)
                gc_rectangle('line', stateX, 12, 90, 28, 4)
                gc_setColor(1, 1, 1, 1)
                setFont(11)
                gc_printf("● PLAYING", stateX, 19, 90, 'center')
            end

            -- Players Count Badge
            if item.count then
                local gamers = item.count.Gamer or '?'
                local cap = item.capacity or '?'
                local specs = item.count.Spectator
                local countText = ("👥 %s/%s"):format(gamers, cap)
                if type(specs) == 'number' and specs > 0 then
                    countText = countText .. (" (+%s)"):format(specs)
                end

                gc_setColor(.12, .16, .35, .8)
                gc_rectangle('fill', 600, 12, 140, 28, 4)
                gc_setColor(.35, .50, .85, .6)
                gc_setLineWidth(1)
                gc_rectangle('line', 600, 12, 140, 28, 4)

                setFont(12)
                gc_setColor(.85, .92, 1.0, .95)
                gc_printf(countText, 600, 19, 140, 'center')
            end
        end
    end
}

local function _hidePW()
    local R = roomList:getSel()
    return not R or not R.private
end

local passwordBox = WIDGET.newInputBox{
    name   = 'password',
    x      = 52,
    y      = 542,
    w      = 756,
    h      = 46,
    secret = true,
    hideF  = _hidePW,
    limit  = 64
}

local function _fetchRoom()
    fetchTimer = 10
    NET.room_fetch()
end

local function _enterSelectedRoom()
    local R = roomList:getSel()
    if R and not TASK.getLock('fetchRoom') and not TASK.getLock('enterRoom') then
        if R.info and R.info.version == VERSION.room then
            local pw = (not _hidePW() and passwordBox:getText()) or nil
            NET.room_enter(R.roomId, pw)
        else
            MES.new('error', text.versionNotMatch or "Room engine version mismatch")
        end
    end
end

function scene.enter()
    CARD.reset()
    CARD.enter()
    BG.set()
    LOBBY.reset()
    NET_BAR.initBG()
    _fetchRoom()
    DiscordRPC.update("Checking room list")
end

function scene.leave()
    CARD.leave()
    AUTH.close()
end

function scene.keyDown(key, rep)
    if AUTH.isOpen() then return AUTH.keyDown(key, rep) end
    if LOBBY.keyDown(key) then return true end
    if TASK.getLock('enterRoom') then return true end

    if (key == 'escape' or key == 'back') and not rep then
        if LOBBY.isAnyOpen() then
            if LOBBY.chat and LOBBY.chat.visible then LOBBY.chat:toggle() end
            if LOBBY.playerList and LOBBY.playerList.visible then LOBBY.playerList:toggle() end
        else
            SCN.backTo('lobby')
        end
        return false
    elseif key == 'r' and not rep then
        if fetchTimer <= 8 then
            SFX.play('rotate')
            _fetchRoom()
        end
        return false
    elseif key == 'return' or key == 'kpenter' then
        if not WIDGET.isFocus(passwordBox) then
            _enterSelectedRoom()
            return false
        end
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
    elseif barAct then
        return true
    end

    -- Join Button inside right detail card (x=860..1220, y=536..588)
    local R = roomList:getSel()
    if R and x >= 860 and x <= 1220 and y >= 536 and y <= 588 then
        SFX.play('reach')
        _enterSelectedRoom()
        return true
    end

    -- Bottom Bar: Refresh button (x=40..190, y=622..670)
    if x >= 40 and x <= 190 and y >= 622 and y <= 670 then
        if fetchTimer <= 8 then
            SFX.play('rotate')
            _fetchRoom()
        end
        return true
    end

    -- Bottom Bar: Create New Room (x=205..415, y=622..670)
    if x >= 205 and x <= 415 and y >= 622 and y <= 670 then
        SFX.play('click')
        SCN.go('net_newRoom', 'swipeL')
        return true
    end

    -- Bottom Bar: Join Room (x=430..630, y=622..670)
    if x >= 430 and x <= 630 and y >= 622 and y <= 670 then
        _enterSelectedRoom()
        return true
    end

    -- Bottom Bar: Room Settings (x=645..795, y=622..670)
    if x >= 645 and x <= 795 and y >= 622 and y <= 670 then
        SFX.play('click')
        SCN.go('setting_game')
        return true
    end

    -- Bottom Bar: Back button (x=1090..1240, y=622..670)
    if x >= 1090 and x <= 1240 and y >= 622 and y <= 670 then
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

    if not TASK.getLock('fetchRoom') then
        fetchTimer = fetchTimer - dt
        if fetchTimer <= 0 and _hidePW() then
            _fetchRoom()
        end
    end
end

function scene.draw()
    local t = love.timer.getTime()
    local mx, my = getMousePos()

    -- 1. Ambient Background Particles
    NET_BAR.drawBG()

    -- 2. Left Panel: Available Rooms Directory (x=40, y=74, w=780, h=530)
    local p1X, p1Y, p1W, p1H = 40, 74, 780, 530
    gc_setColor(.05, .08, .18, .92)
    gc_rectangle('fill', p1X, p1Y, p1W, p1H, 8)
    gc_setColor(.20, .32, .60, .6)
    gc_setLineWidth(1.5)
    gc_rectangle('line', p1X, p1Y, p1W, p1H, 8)

    -- Left Header
    setFont(20)
    gc_setColor(1, 1, 1, .98)
    gc_print("ACTIVE LOBBIES", p1X + 20, p1Y + 16)

    local roomCount = roomList:getLen()
    setFont(13)
    gc_setColor(.45, .75, 1.0, .9)
    gc_print(("• %d Available"):format(roomCount), p1X + 175, p1Y + 22)

    -- Auto-refresh timer ring / label
    local refX = p1X + p1W - 170
    gc_setColor(.10, .15, .32, .8)
    gc_rectangle('fill', refX, p1Y + 14, 150, 28, 4)
    gc_setColor(.25, .40, .75, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', refX, p1Y + 14, 150, 28, 4)

    -- Mini animated pie
    if fetchTimer > 0 then
        gc_setColor(.35, .75, 1.0, .85)
        GC.arc('fill', 'pie', refX + 16, p1Y + 28, 7, -math.pi / 2, -math.pi / 2 + (fetchTimer / 10) * math.pi * 2)
    end
    setFont(11)
    gc_setColor(.80, .90, 1.0, .9)
    gc_print(("Auto-refresh: %ds"):format(math.max(0, math.ceil(fetchTimer))), refX + 28, p1Y + 21)

    -- Password Hint when password box is visible
    if not _hidePW() then
        setFont(12)
        gc_setColor(.95, .75, .25, .9)
        gc_print("🔒 This room requires a password. Type it below before joining:", p1X + 20, p1Y + 448)
    elseif roomCount == 0 and not TASK.getLock('fetchRoom') then
        setFont(14)
        gc_setColor(.55, .68, .90, .75)
        gc_printf("No active rooms right now. Click \"Create New Room\" below to host one!", p1X + 20, p1Y + 220, p1W - 40, 'center')
    end

    -- 3. Right Panel: Room Detail & Inspection (x=840, y=74, w=400, h=530)
    local p2X, p2Y, p2W, p2H = 840, 74, 400, 530
    gc_setColor(.05, .08, .18, .92)
    gc_rectangle('fill', p2X, p2Y, p2W, p2H, 8)
    gc_setColor(.20, .32, .60, .6)
    gc_setLineWidth(1.5)
    gc_rectangle('line', p2X, p2Y, p2W, p2H, 8)

    local R = roomList:getSel()
    if R then
        -- Header
        setFont(20)
        gc_setColor(1, 1, 1, 1)
        gc_print(fitText(R.name or "Unnamed Room", p2W - 40, 20), p2X + 20, p2Y + 16)

        setFont(13)
        gc_setColor(.45, .75, 1.0, .9)
        gc_print("Room Type: " .. tostring(R.type or "Custom VS"), p2X + 20, p2Y + 44)

        -- Description
        local descY = p2Y + 74
        gc_setColor(.08, .12, .26, .7)
        gc_rectangle('fill', p2X + 16, descY, p2W - 32, 70, 6)
        gc_setColor(.22, .32, .58, .5)
        gc_setLineWidth(1)
        gc_rectangle('line', p2X + 16, descY, p2W - 32, 70, 6)

        setFont(12)
        gc_setColor(.80, .88, 1.0, .85)
        gc_printf(R.description or "No special description provided for this room.", p2X + 24, descY + 10, p2W - 48)

        -- Specifications Grid
        local specY = p2Y + 160
        gc_setColor(.35, .55, .90, .35)
        gc.line(p2X + 16, specY, p2X + p2W - 16, specY)

        setFont(13)
        gc_setColor(1, 1, 1, .95)
        gc_print("Match Specifications", p2X + 20, specY + 10)

        local specs = {
            { label = "Current Status", val = R.start and "● In Match" or "● In Lobby" },
            { label = "Players Count", val = (R.count and R.count.Gamer or "?") .. " / " .. (R.capacity or "?") },
            { label = "Spectators",   val = (R.count and R.count.Spectator or "0") .. " Spectating" },
            { label = "Privacy",       val = R.private and "Password Protected" or "Public Open" },
            { label = "Room ID",       val = tostring(R.roomId or "N/A") },
            { label = "Engine Ver.",   val = tostring(R.version or "Unknown") },
        }

        for i, sp in ipairs(specs) do
            local sy = specY + 38 + (i - 1) * 36
            gc_setColor(.10, .14, .30, .6)
            gc_rectangle('fill', p2X + 16, sy, p2W - 32, 30, 4)

            setFont(12)
            gc_setColor(.60, .72, .92, .8)
            gc_print(sp.label, p2X + 24, sy + 7)

            gc_setColor(1, 1, 1, .98)
            gc_printf(sp.val, p2X + 16, sy + 7, p2W - 40, 'right')
        end

        -- Big Join Button inside Right Inspection Card
        local isJoinHov = (mx >= p2X + 20 and mx <= p2X + p2W - 20 and my >= p2Y + p2H - 68 and my <= p2Y + p2H - 16)
        if isJoinHov then
            gc_setColor(.18, .70, .38, .95)
            gc_rectangle('fill', p2X + 20, p2Y + p2H - 68, p2W - 40, 52, 8)
            gc_setColor(.45, 1.0, .65, 1)
            gc_setLineWidth(1.5)
            gc_rectangle('line', p2X + 20, p2Y + p2H - 68, p2W - 40, 52, 8)
        else
            gc_setColor(.14, .55, .30, .9)
            gc_rectangle('fill', p2X + 20, p2Y + p2H - 68, p2W - 40, 52, 8)
            gc_setColor(.35, .85, .50, .8)
            gc_setLineWidth(1)
            gc_rectangle('line', p2X + 20, p2Y + p2H - 68, p2W - 40, 52, 8)
        end
        setFont(17)
        gc_setColor(1, 1, 1, 1)
        gc_printf("🚀 JOIN ROOM  [Enter]", p2X + 20, p2Y + p2H - 52, p2W - 40, 'center')
    else
        -- Empty Selection State
        setFont(20)
        gc_setColor(.60, .72, .95, .8)
        gc_printf("📁 No Room Selected", p2X + 20, p2Y + 120, p2W - 40, 'center')

        setFont(13)
        gc_setColor(.50, .60, .82, .75)
        gc_printf("Select a casual lobby from the directory on the left to inspect rules, view players, or enter the game.", p2X + 30, p2Y + 160, p2W - 60, 'center')
        gc_printf("Want to host your own ruleset? Click \"Create New Room\" below to start a private or public match.", p2X + 30, p2Y + 230, p2W - 60, 'center')
    end

    -- 4. Bottom Action Bar (y=622..670)
    -- Button 1: Refresh [R]
    local isRefHov = (mx >= 40 and mx <= 190 and my >= 622 and my <= 670)
    gc_setColor(isRefHov and .18 or .08, isRefHov and .26 or .12, isRefHov and .50 or .24, .85)
    gc_rectangle('fill', 40, 622, 150, 48, 6)
    gc_setColor(.30, .45, .75, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', 40, 622, 150, 48, 6)
    gc_setColor(1, 1, 1, .9)
    setFont(14)
    gc_printf("🔄 Refresh [R]", 40, 636, 150, 'center')

    -- Button 2: Create New Room
    local isNewHov = (mx >= 205 and mx <= 415 and my >= 622 and my <= 670)
    gc_setColor(isNewHov and .22 or .14, isNewHov and .45 or .32, isNewHov and .85 or .65, .9)
    gc_rectangle('fill', 205, 622, 210, 48, 6)
    gc_setColor(.45, .75, 1.0, 1)
    gc_setLineWidth(1.5)
    gc_rectangle('line', 205, 622, 210, 48, 6)
    gc_setColor(1, 1, 1, 1)
    setFont(14)
    gc_printf("➕ Create New Room", 205, 636, 210, 'center')

    -- Button 3: Join Room
    local isJoinBottomHov = (mx >= 430 and mx <= 630 and my >= 622 and my <= 670)
    if R then
        gc_setColor(isJoinBottomHov and .18 or .12, isJoinBottomHov and .65 or .50, isJoinBottomHov and .35 or .25, .9)
        gc_rectangle('fill', 430, 622, 200, 48, 6)
        gc_setColor(.35, 1.0, .55, 1)
        gc_setLineWidth(1)
        gc_rectangle('line', 430, 622, 200, 48, 6)
        gc_setColor(1, 1, 1, 1)
    else
        gc_setColor(.08, .12, .20, .5)
        gc_rectangle('fill', 430, 622, 200, 48, 6)
        gc_setColor(.18, .25, .40, .4)
        gc_setLineWidth(1)
        gc_rectangle('line', 430, 622, 200, 48, 6)
        gc_setColor(.45, .55, .70, .6)
    end
    setFont(14)
    gc_printf("🚀 Join Room", 430, 636, 200, 'center')

    -- Button 4: Game Settings
    local isSetHov = (mx >= 645 and mx <= 795 and my >= 622 and my <= 670)
    gc_setColor(isSetHov and .18 or .08, isSetHov and .26 or .12, isSetHov and .50 or .24, .85)
    gc_rectangle('fill', 645, 622, 150, 48, 6)
    gc_setColor(.30, .45, .75, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', 645, 622, 150, 48, 6)
    gc_setColor(1, 1, 1, .9)
    setFont(14)
    gc_printf("⚙ Settings", 645, 636, 150, 'center')

    -- Button 5: Back to Lobby [Esc]
    local isBackHov = (mx >= 1090 and mx <= 1240 and my >= 622 and my <= 670)
    gc_setColor(isBackHov and .22 or .12, isBackHov and .18 or .10, isBackHov and .30 or .18, .85)
    gc_rectangle('fill', 1090, 622, 150, 48, 6)
    gc_setColor(.55, .35, .60, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', 1090, 622, 150, 48, 6)
    gc_setColor(1, 1, 1, .9)
    setFont(14)
    gc_printf("← Lobby [Esc]", 1090, 636, 150, 'center')

    -- 5. Top Bar
    NET_BAR.draw("CASUAL ROOM BROWSER", "← Lobby")
end

function scene.overDraw()
    LOBBY.draw()
    LOBBY.drawToggleButtons()
    CARD.draw()
    AUTH.draw()
end

scene.widgetList = {
    roomList,
    passwordBox,
}

return scene
