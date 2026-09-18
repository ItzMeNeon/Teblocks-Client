local gc = love.graphics
local gc_setColor, gc_setLineWidth = gc.setColor, gc.setLineWidth
local gc_rectangle, gc_circle = gc.rectangle, gc.circle
local setFont = FONT.set

local ROOMENV = ROOMENV
local NET_BAR = require 'parts.netTopBar'

local activeTab = 1 -- 1: Timings, 2: Combat, 3: Rules

local roomNameBox = WIDGET.newInputBox{
    x = 56, y = 138, w = 410, h = 40,
    font = 18, limit = 64
}
local passwordBox = WIDGET.newInputBox{
    x = 56, y = 208, w = 410, h = 40,
    font = 18, limit = 64
}
local descriptionBox = WIDGET.newInputBox{
    x = 56, y = 278, w = 410, h = 60,
    font = 16, limit = 256
}

local function getMousePos()
    if SCR and SCR.xOy then
        return SCR.xOy:inverseTransformPoint(love.mouse.getPosition())
    end
    return love.mouse.getPosition()
end

local function _createRoom()
    if WS.status('game') ~= 'running' then
        MES.new('error', text.serverDown)
        return
    end
    if legalGameTime() then
        local pw = passwordBox.value
        if pw == "" then pw = nil end
        local roomname = STRING.trim(roomNameBox.value)
        if #roomname == 0 then
            roomname = (USERS.getUsername(USER.uid) or "Player") .. "'s Room"
        end
        NET.room_create{
            capacity = ROOMENV.capacity or 4,
            info = {
                name = roomname,
                type = "normal",
                version = VERSION.room,
                description = descriptionBox.value,
            },
            data = ROOMENV,
            password = pw,
        }
    end
end

local sList = {
    visible = {"show", "easy", "slow", "medium", "fast", "none"},
    freshLimit = {0, 1, 2, 4, 6, 8, 10, 12, 15, 30, 1e99},
    life = {0, 1, 2, 3, 5, 10, 15, 26, 42, 87, 500},
    pushSpeed = {1, 2, 3, 5, 15},
    fieldH = {1, 2, 4, 6, 8, 10, 15, 20, 30, 50, 100},
    heightLimit = {2, 3, 4, 6, 8, 10, 15, 20, 30, 40, 70, 100, 150, 200, 1e99},
    bufferLimit = {4, 6, 10, 15, 20, 40, 100, 1e99},
    sequence = {'bag', 'bagES', 'his', 'hisPool', 'c2', 'bagP1inf', 'rnd', 'mess', 'reverb'},
    drop = {0, .125, .25, .5, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20, 25, 30, 40, 60, 180, 1e99},
    lock = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 25, 30, 40, 60, 180, 1e99},
    wait = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 60},
    fall = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 60},
    hang = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 60},
    hurry = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1e99},
    eventSet = EVENTSETS,
    holdMode = {'hold', 'swap', 'skip'},
    nextCount = {0, 1, 2, 3, 4, 5, 6},
    capacity = {2, 3, 4, 5, 7, 10, 17, 31, 49, 99},
}

-- In newSelector: D.x is horizontal center, D.y is vertical center.
-- Left card center = 261. Right card Col 1 center = 670, Col 2 center = 1010.
local w_capacity = WIDGET.newSelector{name='capacity', x=261, y=398, w=410, color='lY', fText="", list=sList.capacity, disp=ROOMval('capacity'), code=ROOMsto('capacity')}

-- Tab 1: Timings & Speed Widgets (4 in Col 1, 4 in Col 2)
local w_drop     = WIDGET.newSelector{name='drop',       x=670,  y=185, w=300, color='O',  list=sList.drop,       disp=ROOMval('drop'),       code=ROOMsto('drop')}
local w_lock     = WIDGET.newSelector{name='lock',       x=670,  y=275, w=300, color='O',  list=sList.lock,       disp=ROOMval('lock'),       code=ROOMsto('lock')}
local w_wait     = WIDGET.newSelector{name='wait',       x=670,  y=365, w=300, color='G',  list=sList.wait,       disp=ROOMval('wait'),       code=ROOMsto('wait')}
local w_fall     = WIDGET.newSelector{name='fall',       x=670,  y=455, w=300, color='G',  list=sList.fall,       disp=ROOMval('fall'),       code=ROOMsto('fall')}

local w_hang     = WIDGET.newSelector{name='hang',       x=1010, y=185, w=300, color='G',  list=sList.hang,       disp=ROOMval('hang'),       code=ROOMsto('hang')}
local w_hurry    = WIDGET.newSelector{name='hurry',      x=1010, y=275, w=300, color='G',  list=sList.hurry,      disp=ROOMval('hurry'),      code=ROOMsto('hurry')}
local w_visible  = WIDGET.newSelector{name='visible',    x=1010, y=365, w=300, color='lB', list=sList.visible,   disp=ROOMval('visible'),    code=ROOMsto('visible')}
local w_freshLim = WIDGET.newSelector{name='freshLimit', x=1010, y=455, w=300, color='lB', list=sList.freshLimit,disp=ROOMval('freshLimit'), code=ROOMsto('freshLimit')}

-- Tab 2: Combat & Garbage Widgets (4 selectors in Col 1, 4 switches in Col 2)
local w_life     = WIDGET.newSelector{name='life',        x=670,  y=185, w=300, color='R',  list=sList.life,       disp=ROOMval('life'),        code=ROOMsto('life')}
local w_pushSpd  = WIDGET.newSelector{name='pushSpeed',   x=670,  y=275, w=300, color='V',  list=sList.pushSpeed,  disp=ROOMval('pushSpeed'),   code=ROOMsto('pushSpeed')}
local w_garbSpd  = WIDGET.newSelector{name='garbageSpeed',x=670,  y=365, w=300, color='V',  list=sList.pushSpeed,  disp=ROOMval('garbageSpeed'),code=ROOMsto('garbageSpeed')}
local w_buffer   = WIDGET.newSelector{name='bufferLimit', x=670,  y=455, w=300, color='B',  list=sList.bufferLimit,disp=ROOMval('bufferLimit'), code=ROOMsto('bufferLimit')}

local w_b2bKill  = WIDGET.newSwitch{name='b2bKill',  x=1140, y=185, lim=240, disp=ROOMval('b2bKill'), code=ROOMrev('b2bKill')}
local w_fineKill = WIDGET.newSwitch{name='fineKill', x=1140, y=275, lim=240, disp=ROOMval('fineKill'),code=ROOMrev('fineKill')}
local w_ospin    = WIDGET.newSwitch{name='ospin',    x=1140, y=365, lim=240, disp=ROOMval('ospin'),   code=ROOMrev('ospin')}
local w_bone     = WIDGET.newSwitch{name='bone',     x=1140, y=455, lim=240, disp=ROOMval('bone'),    code=ROOMrev('bone')}

-- Tab 3: Rules & Board Widgets
local w_seq      = WIDGET.newSelector{name='sequence',   x=670,  y=185, w=300, color='F',  list=sList.sequence,   disp=ROOMval('sequence'),   code=ROOMsto('sequence')}
local w_fieldH   = WIDGET.newSelector{name='fieldH',     x=670,  y=275, w=300, color='N',  list=sList.fieldH,     disp=ROOMval('fieldH'),     code=ROOMsto('fieldH')}
local w_heightL  = WIDGET.newSelector{name='heightLimit',x=670,  y=365, w=300, color='S',  list=sList.heightLimit,disp=ROOMval('heightLimit'),code=ROOMsto('heightLimit')}
local w_holdMode = WIDGET.newSelector{name='holdMode',   x=670,  y=455, w=300, color='lY', list=sList.holdMode,   disp=ROOMval('holdMode'),   code=ROOMsto('holdMode')}
local w_nextCnt  = WIDGET.newSelector{name='nextCount',  x=670,  y=545, w=300, color='C',  list=sList.nextCount,  disp=ROOMval('nextCount'),  code=ROOMsto('nextCount')}
local w_eventSet = WIDGET.newSelector{name='eventSet',   x=670,  y=635, w=300, color='H',  list=sList.eventSet,   disp=ROOMval('eventSet'),   code=ROOMsto('eventSet')}

local w_easyFrsh = WIDGET.newSwitch{name='easyFresh', x=1140, y=185, lim=240, disp=ROOMval('easyFresh'),code=ROOMrev('easyFresh')}
local w_lockout  = WIDGET.newSwitch{name='lockout',   x=1140, y=275, lim=240, disp=ROOMval('lockout'),  code=ROOMrev('lockout')}
local w_deepDrop = WIDGET.newSwitch{name='deepDrop',  x=1140, y=365, lim=240, disp=ROOMval('deepDrop'), code=ROOMrev('deepDrop')}
local w_infHold  = WIDGET.newSwitch{name='infHold',   x=1140, y=455, lim=240, disp=ROOMval('infHold'),  code=ROOMrev('infHold')}
local w_phyHold  = WIDGET.newSwitch{name='phyHold',   x=1140, y=545, lim=240, disp=ROOMval('phyHold'),  code=ROOMrev('phyHold')}

local scene = {}

local function updateTabVisibility()
    w_drop.hide     = activeTab ~= 1
    w_lock.hide     = activeTab ~= 1
    w_wait.hide     = activeTab ~= 1
    w_fall.hide     = activeTab ~= 1
    w_hang.hide     = activeTab ~= 1
    w_hurry.hide    = activeTab ~= 1
    w_visible.hide  = activeTab ~= 1
    w_freshLim.hide = activeTab ~= 1

    w_life.hide     = activeTab ~= 2
    w_pushSpd.hide  = activeTab ~= 2
    w_garbSpd.hide  = activeTab ~= 2
    w_buffer.hide   = activeTab ~= 2
    w_b2bKill.hide  = activeTab ~= 2
    w_fineKill.hide = activeTab ~= 2
    w_ospin.hide    = activeTab ~= 2
    w_bone.hide     = activeTab ~= 2

    w_seq.hide      = activeTab ~= 3
    w_fieldH.hide   = activeTab ~= 3
    w_heightL.hide  = activeTab ~= 3
    w_holdMode.hide = activeTab ~= 3
    w_nextCnt.hide  = activeTab ~= 3
    w_eventSet.hide = activeTab ~= 3
    w_easyFrsh.hide = activeTab ~= 3
    w_lockout.hide  = activeTab ~= 3
    w_deepDrop.hide = activeTab ~= 3
    w_infHold.hide  = activeTab ~= 3
    w_phyHold.hide  = activeTab ~= 3
end

local function refreshAllWidgets()
    if scene.widgetList then
        for _, w in ipairs(scene.widgetList) do
            if w.reset then w:reset() end
        end
    end
end

-- Preset Configurations
local function applyPreset(presetName)
    if presetName == 'standard' then
        ROOMENV.capacity = 4
        ROOMENV.life = 0
        ROOMENV.drop = 1
        ROOMENV.lock = 5
        ROOMENV.wait = 0
        ROOMENV.fall = 0
        ROOMENV.hang = 5
        ROOMENV.hurry = 1e99
        ROOMENV.pushSpeed = 3
        ROOMENV.garbageSpeed = 3
        ROOMENV.sequence = 'bag'
        ROOMENV.holdMode = 'hold'
        ROOMENV.nextCount = 6
        ROOMENV.b2bKill = false
        ROOMENV.fineKill = false
        ROOMENV.ospin = true
        ROOMENV.easyFresh = true
        ROOMENV.visible = 'show'
        ROOMENV.freshLimit = 15
        MES.new('info', "Applied Standard Versus preset")
    elseif presetName == 'duel' then
        ROOMENV.capacity = 2
        ROOMENV.life = 3
        ROOMENV.drop = 1
        ROOMENV.lock = 5
        ROOMENV.wait = 0
        ROOMENV.fall = 0
        ROOMENV.hang = 5
        ROOMENV.hurry = 1e99
        ROOMENV.pushSpeed = 3
        ROOMENV.garbageSpeed = 3
        ROOMENV.sequence = 'bag'
        ROOMENV.holdMode = 'hold'
        ROOMENV.nextCount = 6
        ROOMENV.b2bKill = false
        ROOMENV.fineKill = false
        ROOMENV.ospin = true
        ROOMENV.easyFresh = true
        ROOMENV.visible = 'show'
        ROOMENV.freshLimit = 15
        MES.new('info', "Applied 1v1 Duel (3 Lives) preset")
    elseif presetName == 'speed' then
        ROOMENV.capacity = 4
        ROOMENV.life = 1
        ROOMENV.drop = 0.25
        ROOMENV.lock = 2
        ROOMENV.wait = 0
        ROOMENV.fall = 0
        ROOMENV.hang = 2
        ROOMENV.hurry = 20
        ROOMENV.pushSpeed = 5
        ROOMENV.garbageSpeed = 5
        ROOMENV.sequence = 'bag'
        ROOMENV.holdMode = 'hold'
        ROOMENV.nextCount = 6
        ROOMENV.b2bKill = false
        ROOMENV.fineKill = false
        ROOMENV.ospin = true
        ROOMENV.easyFresh = true
        ROOMENV.visible = 'show'
        ROOMENV.freshLimit = 10
        MES.new('info', "Applied Speed Battle preset")
    elseif presetName == 'chaos' then
        ROOMENV.capacity = 4
        ROOMENV.life = 0
        ROOMENV.drop = 0.5
        ROOMENV.lock = 3
        ROOMENV.wait = 0
        ROOMENV.pushSpeed = 5
        ROOMENV.garbageSpeed = 5
        ROOMENV.sequence = 'rnd'
        ROOMENV.visible = 'medium'
        ROOMENV.b2bKill = true
        ROOMENV.fineKill = true
        ROOMENV.ospin = true
        ROOMENV.easyFresh = false
        ROOMENV.freshLimit = 4
        MES.new('info', "Applied Chaos Mode preset")
    end
    SFX.play('click')
    refreshAllWidgets()
end

function scene.enter()
    destroyPlayers()
    activeTab = 1
    updateTabVisibility()
    refreshAllWidgets()
    DiscordRPC.update("Creating new room...")

    -- Set initial room name if empty
    if #roomNameBox.value == 0 then
        local myName = USERS.getUsername(USER.uid) or "Player"
        roomNameBox:setText(myName .. "'s Room")
    end
end

function scene.leave()
    BGM.play()
end

function scene.keyDown(key, isRep)
    if key == 'escape' then
        SFX.play('back')
        SCN.backTo('net_rooms')
        return true
    elseif key == 'return' or key == 'kpenter' then
        if not WIDGET.isFocus(roomNameBox) and not WIDGET.isFocus(passwordBox) and not WIDGET.isFocus(descriptionBox) then
            _createRoom()
            return true
        end
    end
end

function scene.mouseDown(x, y)
    -- Top bar (Back + persistent matchmaking queue)
    local barAct = NET_BAR.mouseDown(x, y)
    if barAct == 'back' then
        SFX.play('back')
        SCN.backTo('net_rooms')
        return true
    elseif barAct then
        return true
    end

    -- Tab Bar Buttons (y=76..114)
    if y >= 76 and y <= 114 then
        if x >= 520 and x <= 746 then
            activeTab = 1
            updateTabVisibility()
            SFX.play('click')
            return true
        elseif x >= 762 and x <= 988 then
            activeTab = 2
            updateTabVisibility()
            SFX.play('click')
            return true
        elseif x >= 1004 and x <= 1230 then
            activeTab = 3
            updateTabVisibility()
            SFX.play('click')
            return true
        end
    end

    -- Quick Preset Buttons (y=458..498)
    if y >= 458 and y <= 498 then
        if x >= 56 and x <= 154 then
            applyPreset('standard')
            return true
        elseif x >= 160 and x <= 258 then
            applyPreset('duel')
            return true
        elseif x >= 264 and x <= 362 then
            applyPreset('speed')
            return true
        elseif x >= 368 and x <= 466 then
            applyPreset('chaos')
            return true
        end
    end

    -- Create Room CTA Button (x=56..466, y=614..678)
    if x >= 56 and x <= 466 and y >= 614 and y <= 678 then
        SFX.play('enter')
        _createRoom()
        return true
    end
end
scene.touchDown = scene.mouseDown

function scene.update(dt)
    NET_BAR.update(dt)
end

function scene.draw()
    local t = love.timer.getTime()
    local mx, my = getMousePos()

    -- 1. Ambient Background Particles
    NET_BAR.drawBG()

    -- 2. Left Panel: Room Profile & Presets (x=36, y=66, w=450, h=636)
    local p1X, p1Y, p1W, p1H = 36, 66, 450, 636
    gc_setColor(.06, .09, .18, .92)
    gc_rectangle('fill', p1X, p1Y, p1W, p1H, 10)
    gc_setColor(.22, .40, .75, .75)
    gc_setLineWidth(1.5)
    gc_rectangle('line', p1X, p1Y, p1W, p1H, 10)

    -- Left Card Header
    gc_setColor(.12, .24, .50, .85)
    gc_rectangle('fill', p1X, p1Y, p1W, 42, 10)
    gc_rectangle('fill', p1X, p1Y + 30, p1W, 12)
    gc_setColor(1, 1, 1, .95)
    setFont(16)
    gc.print("ROOM CONFIGURATION", p1X + 16, p1Y + 11)

    -- Labels for Inputs
    setFont(12)
    gc_setColor(.75, .88, 1.0, .9)
    gc.print("Room Name", 56, 118)
    gc.print("Password (Optional - leave empty for public)", 56, 188)
    gc.print("Description / Rules Note", 56, 258)
    gc.print("Player Capacity (2 - 99 Players)", 56, 350)
    gc.print("Quick Presets", 56, 438)

    -- Preset Buttons Row (y=458..498)
    local presets = {
        {name="Standard", x=56,  w=98,  tag='standard'},
        {name="1v1 Duel", x=160, w=98,  tag='duel'},
        {name="Speed",    x=264, w=98,  tag='speed'},
        {name="Chaos",    x=368, w=98,  tag='chaos'},
    }
    for _, pr in ipairs(presets) do
        local isHov = (mx >= pr.x and mx <= pr.x + pr.w and my >= 458 and my <= 498)
        gc_setColor(isHov and .22 or .12, isHov and .36 or .20, isHov and .65 or .40, .85)
        gc_rectangle('fill', pr.x, 458, pr.w, 40, 6)
        gc_setColor(.35, .55, .90, isHov and .9 or .6)
        gc_setLineWidth(1)
        gc_rectangle('line', pr.x, 458, pr.w, 40, 6)
        gc_setColor(1, 1, 1, isHov and 1 or .85)
        setFont(12)
        gc.printf(pr.name, pr.x, 471, pr.w, 'center')
    end

    -- Config Overview Badge (y=512..598)
    local ovX, ovY, ovW, ovH = 56, 512, 410, 86
    gc_setColor(.08, .12, .24, .85)
    gc_rectangle('fill', ovX, ovY, ovW, ovH, 6)
    gc_setColor(.24, .38, .70, .6)
    gc_setLineWidth(1)
    gc_rectangle('line', ovX, ovY, ovW, ovH, 6)

    setFont(11)
    gc_setColor(.55, .78, 1.0, .85)
    gc.print("CURRENT CONFIG SUMMARY", ovX + 12, ovY + 8)

    local capVal = ROOMENV.capacity or 4
    local dropVal = ROOMENV.drop or 1
    local lockVal = ROOMENV.lock or 5
    local lifeVal = ROOMENV.life or 0
    local seqVal = ROOMENV.sequence or 'bag'
    local lifeStr = (lifeVal == 0) and "Endless Knockout" or (lifeVal .. " Lives")

    gc_setColor(.85, .92, 1.0, .95)
    setFont(12)
    gc.print(("• Capacity: %d Players  • Format: %s"):format(capVal, lifeStr), ovX + 12, ovY + 28)
    gc.print(("• Gravity: %ss Drop, %ss Lock Delay"):format(tostring(dropVal), tostring(lockVal)), ovX + 12, ovY + 46)
    gc.print(("• Sequence: %s  • Attacks: Push x%s, Speed x%s"):format(tostring(seqVal), tostring(ROOMENV.pushSpeed or 3), tostring(ROOMENV.garbageSpeed or 3)), ovX + 12, ovY + 64)

    -- Create Room CTA Button (y=614..678)
    local isCreateHov = (mx >= 56 and mx <= 466 and my >= 614 and my <= 678)
    local cGlow = 0.85 + 0.15 * math.sin(t * 4)
    if isCreateHov then
        gc_setColor(.15, .75, .55, .95)
        gc_rectangle('fill', 56, 614, 410, 64, 8)
        gc_setColor(.70, 1.0, .85, 1)
        gc_setLineWidth(2)
        gc_rectangle('line', 56, 614, 410, 64, 8)
    else
        gc_setColor(.10, .50, .40, .88)
        gc_rectangle('fill', 56, 614, 410, 64, 8)
        gc_setColor(.30, .85, .65, cGlow)
        gc_setLineWidth(1.5)
        gc_rectangle('line', 56, 614, 410, 64, 8)
    end
    gc_setColor(1, 1, 1, 1)
    setFont(18)
    gc.printf("CREATE & ENTER ROOM  ✦", 56, 634, 410, 'center')

    -- 3. Right Panel: Game Rules & Tuning (x=506, y=66, w=738, h=636)
    local p2X, p2Y, p2W, p2H = 506, 66, 738, 636
    gc_setColor(.06, .09, .18, .92)
    gc_rectangle('fill', p2X, p2Y, p2W, p2H, 10)
    gc_setColor(.22, .40, .75, .75)
    gc_setLineWidth(1.5)
    gc_rectangle('line', p2X, p2Y, p2W, p2H, 10)

    -- Tab Switcher Bar (y=76..114)
    local tabs = {
        {id=1, label="⏱ TIMINGS & GRAVITY", x=520,  w=226},
        {id=2, label="⚔ COMBAT & ATTACKS",  x=762,  w=226},
        {id=3, label="🧩 RULES & MATRIX",    x=1004, w=226},
    }
    for _, tb in ipairs(tabs) do
        local isActive = (activeTab == tb.id)
        local isHov = (mx >= tb.x and mx <= tb.x + tb.w and my >= 76 and my <= 114)
        if isActive then
            gc_setColor(.22, .48, .90, .95)
            gc_rectangle('fill', tb.x, 76, tb.w, 38, 6)
            gc_setColor(.65, .85, 1.0, 1)
            gc_setLineWidth(1.5)
            gc_rectangle('line', tb.x, 76, tb.w, 38, 6)
            gc_setColor(1, 1, 1, 1)
        else
            gc_setColor(isHov and .14 or .08, isHov and .22 or .12, isHov and .42 or .24, .85)
            gc_rectangle('fill', tb.x, 76, tb.w, 38, 6)
            gc_setColor(.28, .42, .75, isHov and .8 or .5)
            gc_setLineWidth(1)
            gc_rectangle('line', tb.x, 76, tb.w, 38, 6)
            gc_setColor(.75, .85, 1, isHov and 1 or .75)
        end
        setFont(12)
        gc.printf(tb.label, tb.x, 88, tb.w, 'center')
    end

    -- Tab Content Subtitle & Help Box
    gc_setColor(.45, .65, .95, .8)
    setFont(12)
    if activeTab == 1 then
        gc.print("Customize fall speed, lock delay, line clear pauses, and visibility", 526, 126)

        -- Explanatory card at bottom
        local hX, hY, hW, hH = 520, 520, 710, 140
        gc_setColor(.08, .12, .24, .8)
        gc_rectangle('fill', hX, hY, hW, hH, 8)
        gc_setColor(.22, .35, .65, .6)
        gc_setLineWidth(1)
        gc_rectangle('line', hX, hY, hW, hH, 8)

        setFont(11)
        gc_setColor(.55, .78, 1.0, .85)
        gc.print("TIMING MECHANICS GUIDE", hX + 16, hY + 10)
        setFont(12)
        gc_setColor(.80, .88, .98, .85)
        gc.print("• Drop Delay: Lower numbers accelerate falling speed (0 = instantaneous 20G).", hX + 16, hY + 34)
        gc.print("• Lock Delay: Number of frames / seconds before a landed piece permanently solidifies.", hX + 16, hY + 56)
        gc.print("• Entry Delay (ARE) & Line Delay: Spawn pause after locking or clearing lines.", hX + 16, hY + 78)
        gc.print("• Lock Reset Limit: Max movements/rotations allowed to reset lock delay before forced lock.", hX + 16, hY + 100)
    elseif activeTab == 2 then
        gc.print("Tune lives, garbage push velocity, buffering, and attack modifiers", 526, 126)

        -- Explanatory card at bottom
        local hX, hY, hW, hH = 520, 520, 710, 140
        gc_setColor(.08, .12, .24, .8)
        gc_rectangle('fill', hX, hY, hW, hH, 8)
        gc_setColor(.22, .35, .65, .6)
        gc_setLineWidth(1)
        gc_rectangle('line', hX, hY, hW, hH, 8)

        setFont(11)
        gc_setColor(.55, .78, 1.0, .85)
        gc.print("COMBAT & SURVIVAL GUIDE", hX + 16, hY + 10)
        setFont(12)
        gc_setColor(.80, .88, .98, .85)
        gc.print("• Lives: Set to 0 for endless versus knockout, or set life stock for last-man-standing.", hX + 16, hY + 34)
        gc.print("• Garbage & Push Speed: Rates at which incoming attacks rise into the matrix.", hX + 16, hY + 56)
        gc.print("• Buffer Limit: Maximum incoming garbage lines that can queue before overflowing.", hX + 16, hY + 78)
        gc.print("• Hardcore Modifiers: Enable '100% Finesse' or 'No B2B Breaks' for lethal competitive play.", hX + 16, hY + 100)
    else
        gc.print("Configure piece generator, matrix dimensions, hold mechanics, and lockout", 526, 126)

        -- Rules Column 2 Header
        setFont(11)
        gc_setColor(.55, .75, 1.0, .8)
        gc.print("SPECIAL RULES & TOGGLES", 900, 155)
    end

    -- 4. Top Bar
    NET_BAR.draw("CREATE CASUAL ROOM", "← Rooms")
end

scene.widgetList = {
    roomNameBox,
    passwordBox,
    descriptionBox,
    w_capacity,

    -- Tab 1: Timings & Speed
    w_drop, w_lock, w_wait, w_fall,
    w_hang, w_hurry, w_visible, w_freshLim,

    -- Tab 2: Combat & Attacks
    w_life, w_pushSpd, w_garbSpd, w_buffer,
    w_b2bKill, w_fineKill, w_ospin, w_bone,

    -- Tab 3: Rules & Board
    w_seq, w_fieldH, w_heightL, w_holdMode, w_nextCnt, w_eventSet,
    w_easyFrsh, w_lockout, w_deepDrop, w_infHold, w_phyHold,
}

return scene
