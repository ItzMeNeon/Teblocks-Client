local gc,kb,tc=love.graphics,love.keyboard,love.touch

local gc_setColor=gc.setColor
local gc_setLineWidth=gc.setLineWidth
local gc_print,gc_printf=gc.print,gc.printf
local gc_draw=gc.draw
local gc_rectangle,gc_circle=gc.rectangle,gc.circle
local setFont,mStr=FONT.set,GC.mStr

local ins=table.insert

local SCR,VK,NET,NETPLY=SCR,VK,NET,NETPLY
local PLAYERS,GAME=PLAYERS,GAME
local ROLLBACK=ROLLBACK
local NET_BAR=require 'parts.netTopBar'
local REPORT=require 'parts.reportModal'
local AC=require 'parts.anticheatClient'

local textBox=NET.textBox
local inputBox=NET.inputBox

local TEAM_GROUPS = {
    {g=0, label="FFA", x=495, w=46},
    {g=1, label="1",   x=547, w=36},
    {g=2, label="2",   x=589, w=36},
    {g=3, label="3",   x=631, w=36},
    {g=4, label="4",   x=673, w=36},
    {g=5, label="5",   x=715, w=36},
    {g=6, label="6",   x=757, w=36},
}

local playing
local paused
local abandonCount=0
local lastUpstreamTime
local upstreamProgress

local noTouch,noKey=false,false
local touchMoveLastFrame=false

local function _replayFinished()
    if #PLAYERS<1 then return false end
    local anyStream=false
    for p=1,#PLAYERS do
        local P=PLAYERS[p]
        if P.stream and P.streamProgress then
            anyStream=true
            if P.alive and P.stream[P.streamProgress] then
                return false
            end
        end
    end
    return anyStream
end

-- _stepPlayers runs the per-player fixed-step update loop. When the rollback
-- netcode layer is enabled (NET._rollbackEnabled), it delegates to
-- ROLLBACK.step which adds snapshotting and server reconciliation around the
-- same Player:update calls. Default off — visible behavior is identical to
-- the legacy loop until the integration test (slice 4) flips the flag.
local function _stepPlayers(dt)
    for p=1,#PLAYERS do PLAYERS[p]:update(dt) end
end
local function _replaySeekTo(frame)
    NET.seekReplay(frame)
end
-- Once the replay ends the survivor is laid out at the full-size centred 1P
-- position (its board bottom would sit under the seek bar at y>=664). Scale it
-- down and lift it so it clears the slider instead of overlapping it.
local function _replaySettleLayout()
    local L=#PLY_ALIVE>0 and PLY_ALIVE or PLAYERS
    if #L==0 then return end
    local size=#L==1 and .85 or .7
    for i=1,#L do
        local P=L[i]
        local x=#L==1 and (640-300*size) or P.x
        local y=664-600*size-36
        P:movePosition(x,y,size)
    end
end
local function _replayUpdate(dt)
    -- Apply pending seek immediately
    if NET._replaySeekPending then
        NET.seekReplay(NET._replaySeekFrame)
        NET._replaySeekPending=false
    end

    if not paused then
        local steps=GAME.replaySpeed or 1
        local SNAPSHOT=require('parts.player.snapshot')
        for s=1,steps do
            _stepPlayers(dt)
            local curF=PLAYERS[1] and PLAYERS[1].frameRun
            if curF and curF%60==0 and NET._replayKeyframes and not NET._replayKeyframes[curF] then
                local kSnap={players={}}
                for p=1,#PLAYERS do
                    kSnap.players[p]=SNAPSHOT.snapshot(PLAYERS[p])
                end
                NET._replayKeyframes[curF]=kSnap
            end
            if _replayFinished() then break end
        end
    end

    -- Track current frame for seek bar
    NET._replayCur=0
    for p=1,#PLAYERS do
        if PLAYERS[p].frameRun>NET._replayCur then NET._replayCur=PLAYERS[p].frameRun end
    end

    -- The REPLAY banner fades out once replay ends
    NET._replayBannerAlpha=MATH.expApproach(NET._replayBannerAlpha,_replayFinished() and 0 or 1,dt*4)

    -- When replay ends, snapshot end positions
    if _replayFinished() and not NET._replayEndPos then
        NET._replayEndPos={}
        for p=1,#PLAYERS do
            local P=PLAYERS[p]
            if P.uid then NET._replayEndPos[P.uid]={P.x,P.y,P.size} end
        end
        if not NET._replaySettled then
            NET._replaySettled=true
            _replaySettleLayout()
        end
    end
end

local function _setCancel()
    local myP = NETPLY.map[USER.uid]
    if myP and myP.playMode=='Gamer' then
        NET.player_setReady(false)
    else
        NET.player_setPlayMode('Gamer')
    end
end
local function _setReady()
    NET.player_setReady(true)
end
local function _setSpectate()
    NET.player_setPlayMode('Spectator')
end

local function _gotoSetting()
    GAME.prevBG=BG.cur
    SCN.go('setting_game')
end
local function _updatePlayToggleIcon()
    if scene and scene.widgetList then
        for _,w in ipairs(scene.widgetList) do
            if w.name=='replayPlayToggle' and w.obj and w.obj.set then
                w.obj:set(paused and CHAR.icon.play or CHAR.icon.pause)
                break
            end
        end
    end
end

local function _quit()
    if GAME.replaying then
        GAME.playing=false
        SCN.back()
        return
    end
    if tryBack() then
        NET.room_leave()
        GAME.playing=false
        SCN.back()
    end
end
local function _switchChat()
    if inputBox.hide then

        textBox.hide=false
        inputBox.hide=false
        WIDGET.focus(inputBox)
    else
        textBox.hide=true
        inputBox.hide=true
        WIDGET.unFocus(true)
    end
end

local scene={}

function scene.enter()
    noTouch=not SETTING.VKSwitch
    playing=false
    paused=false
    abandonCount=0
    lastUpstreamTime=0
    upstreamProgress=1
    REPORT.close()
    AC.reset()

    if SCN.prev=='setting_game' then
        NET.player_updateConf()
    end
    if GAME.prevBG then
        BG.set(GAME.prevBG)
        GAME.prevBG=false
    end
    DiscordRPC.update("Playing Multiplayer")
end
function scene.leave()
    TASK.unlock('netPlaying')
    REPORT.close()
    -- A ranked replay borrows the live net_game/netBattle machinery and replaces
    -- the room state with a throwaway one. Restore the real (post-match) room if
    -- we had one, otherwise clear it so ranked matchmaking isn't left pointing at
    -- the replay's fake "Playing" room (which would block starting a new search).
    if GAME.replaying then
        if NET._replayRoomState~=nil then
            NET.roomState=NET._replayRoomState
        else
            NET.roomState=nil
        end
        NET._replayRoomState=nil
        NETPLY.clear()
        GAME.replaySetup=false
        GAME.replaying=false
    end
end

local function getMousePos()
    if SCR and SCR.xOy then
        return SCR.xOy:inverseTransformPoint(love.mouse.getPosition())
    end
    return love.mouse.getPosition()
end

function scene.mouseDown(x,y)
    if REPORT.isOpen() then
        REPORT.mouseDown(x, y)
        return true
    end

    if not playing and not GAME.replaying then
        -- Top bar: check back (leave room) + persistent queue pill
        local barAct = NET_BAR.mouseDown(x, y)
        if barAct == 'back' then
            _quit()
            return true
        elseif barAct then
            return true
        end

        local isMatchPlaying = NET.roomState and NET.roomState.state == 'Playing'
        local myP = NETPLY.map[USER.uid]

        -- Check if player card clicked to report
        local ply = NETPLY.getPlayerAt and NETPLY.getPlayerAt(x, y)
        if ply and ply.uid and ply.uid ~= USER.uid then
            REPORT.open(ply.uid, ply.name or ply.username or ("Player " .. ply.uid), NET.room and NET.room.name or "", NET.matchId or "")
            SFX.play('click')
            return true
        end

        -- Group / Team selector buttons (x=495..793, y=78..112)
        if y >= 78 and y <= 112 then
            for _, grp in ipairs(TEAM_GROUPS) do
                if x >= grp.x and x <= grp.x + grp.w then
                    NET.player_joinGroup(grp.g)
                    SFX.play('click')
                    return true
                end
            end
        end

        -- Ready / Cancel button (x=920..1220, y=386..440)
        if x >= 920 and x <= 1220 and y >= 386 and y <= 440 then
            if isMatchPlaying then
                MES.new('info', "Match in progress — waiting for next round")
            elseif myP and (myP.playMode == 'Spectator' or myP.readyMode == 'Ready') then
                _setCancel()
                SFX.play('click')
            else
                _setReady()
                SFX.play('click')
            end
            return true
        end

        -- Spectate / Participate button (x=920..1220, y=448..490)
        if x >= 920 and x <= 1220 and y >= 448 and y <= 490 then
            if myP and myP.playMode == 'Spectator' then
                _setCancel()
            else
                _setSpectate()
            end
            SFX.play('click')
            return true
        end

        -- Game Settings button (x=920..1220, y=498..540)
        if x >= 920 and x <= 1220 and y >= 498 and y <= 540 then
            SFX.play('click')
            _gotoSetting()
            return true
        end

        -- Chat Toggle button (x=920..1220, y=548..590)
        if x >= 920 and x <= 1220 and y >= 548 and y <= 590 then
            _switchChat()
            SFX.play('click')
            return true
        end

        -- Leave Room button (x=920..1220, y=598..640)
        if x >= 920 and x <= 1220 and y >= 598 and y <= 640 then
            _quit()
            return true
        end
    end
end
function scene.mouseMove(x,y) NETPLY.mouseMove(x,y) end
function scene.touchDown(x,y)
    if not playing or GAME.replaying then NETPLY.mouseMove(x,y) return end
    if NET.spectate or noTouch or not textBox.hide or paused then return end

    local t=VK.on(x,y)
    if t then
        PLAYERS[1]:pressKey(t)
        VK.touch(t,x,y)
    end
end
function scene.touchUp(x,y)
    if not playing or GAME.replaying or NET.spectate or noTouch or not textBox.hide then return end
    local n=VK.on(x,y)
    if n then
        PLAYERS[1]:releaseKey(n)
        VK.release(n)
    end
end
function scene.touchMove()
    if touchMoveLastFrame or not playing or noTouch or GAME.replaying then return end
    touchMoveLastFrame=true

    local L=tc.getTouches()
    for i=#L,1,-1 do
        L[2*i-1],L[2*i]=SCR.xOy:inverseTransformPoint(tc.getPosition(L[i]))
    end
    local keys=VK.keys
    for n=1,#keys do
        local B=keys[n]
        if B.ava then
            local nextKey
            for i=1,#L,2 do
                if (L[i]-B.x)^2+(L[i+1]-B.y)^2<=B.r^2 then
                    nextKey=true
                    break-- goto CONTINUE_nextKey
                end
            end
            if not nextKey then
                PLAYERS[1]:releaseKey(n)
                VK.release(n)
            end
            -- ::CONTINUE_nextKey::
        end
    end
end
function scene.keyDown(key,isRep)
    if REPORT.isOpen() then
        return REPORT.keyDown(key, isRep)
    end

    if not playing and not GAME.replaying and inputBox.hide then
        if key == 'space' then
            local isMatchPlaying = NET.roomState and NET.roomState.state == 'Playing'
            if isMatchPlaying then
                MES.new('info', "Match in progress — waiting for next round")
            else
                local myP = NETPLY.map[USER.uid]
                if myP and (myP.playMode == 'Spectator' or myP.readyMode == 'Ready') then
                    _setCancel()
                else
                    _setReady()
                end
                SFX.play('click')
            end
            return true
        elseif key == 's' then
            SFX.play('click')
            _gotoSetting()
            return true
        end
    end

    if GAME.replaying then
        if key=='space' or key=='p' then
            paused=not paused
            _updatePlayToggleIcon()
            return
        elseif key=='left' then
            local step=love.keyboard.isDown('lshift','rshift') and 60 or 300
            NET.seekReplay(NET._replayCur - step)
            return
        elseif key=='right' then
            local step=love.keyboard.isDown('lshift','rshift') and 60 or 300
            NET.seekReplay(NET._replayCur + step)
            return
        elseif key=='home' then
            NET.seekReplay(0)
            return
        elseif key=='end' then
            NET.seekReplay(NET._replayTotal or NET._replayCur)
            return
        elseif key=='up' then
            local spds={1,2,5,10}
            for _,s in ipairs(spds) do
                if s>(GAME.replaySpeed or 1) then GAME.replaySpeed=s break end
            end
            return
        elseif key=='down' then
            local spds={10,5,2,1}
            for _,s in ipairs(spds) do
                if s<(GAME.replaySpeed or 1) then GAME.replaySpeed=s break end
            end
            return
        elseif key=='escape' then
            paused=not paused
            _updatePlayToggleIcon()
            return
        elseif key=='q' then
            _quit()
            return
        end
    end
    if key=='escape' then
        if NET.matchFoundPending and NET.matchFoundCountdown>0 then
            NET.matchFoundPending=false
            NET.matchFoundCountdown=0
            NET.matchFoundSeed=nil
            NET.matchFoundTime=nil
            NET.matchFoundOppId=nil
            NET.matchFoundMatchId=nil
            NET._pendingMatchFoundScene=false
            NET.ranked_leave()
            NET.matchmaking=false
            NET.searchTimer=0
            NET.shakeStr=0
            SCN.go('net_ranked')
        elseif not inputBox.hide then
            _switchChat()
        elseif NET.roomState and NET.roomState.info and NET.roomState.info.type=='ranked' and playing then
            -- Require several ESC taps so a ranked match can't be abandoned by
            -- accident. The third tap sends player_finish, which the server
            -- treats as this player leaving the match and settles a win for the
            -- opponent still in the game.
            abandonCount=abandonCount+1
            if abandonCount>=3 then
                abandonCount=0
                MES.new('warn',"Abandoning match — you forfeit the win")
                NET.player_finish()
            else
                MES.new('warn',"Press ESC "..(3-abandonCount).." more time(s) to abandon this match")
            end
        else
            _quit()
        end
    elseif key=='/' then
        if inputBox.hide then
            _switchChat()
            local mes=STRING.trim(inputBox:getText())
            if #mes==0 then
                inputBox:setText("/")
            end
        end
    elseif key=='return' or key=='kpenter' then
        local mes=STRING.trim(inputBox:getText())
        if not inputBox.hide and #mes>0 then
            if mes:sub(1,1)=='/' then
                local cmd=STRING.split(mes,' ')

                -- Common commands
                if cmd[1]=='/kick' then
                    if tonumber(cmd[2]) then NET.room_kick(tonumber(cmd[2])) end
                elseif cmd[1]=='/pw' then
                    if cmd[2] then NET.room_setPW(cmd[2]) end
                elseif cmd[1]=='/host' then
                    if tonumber(cmd[2]) then NET.player_setHost(tonumber(cmd[2])) end
                elseif cmd[1]=='/group' then
                    if tonumber(cmd[2]) and tonumber(cmd[2])%1==0 and tonumber(cmd[2])>=0 and tonumber(cmd[2])<=6 then
                        NET.player_joinGroup(tonumber(cmd[2]))
                    end
                elseif cmd[1]=='/exit' or cmd[1]=='/quit' then
                    _quit()

                elseif cmd[1]=='/report' then
                    local targetName = cmd[2]
                    if targetName and #targetName > 0 then
                        local foundUid, foundName
                        if NETPLY.list then
                            for _, p in ipairs(NETPLY.list) do
                                if p.name == targetName or tostring(p.uid) == targetName then
                                    foundUid = p.uid
                                    foundName = p.name
                                    break
                                end
                            end
                        end
                        if foundUid then
                            REPORT.open(foundUid, foundName, NET.room and NET.room.name or "", NET.matchId or "")
                        else
                            REPORT.open(targetName, targetName, NET.room and NET.room.name or "", NET.matchId or "")
                        end
                        _switchChat()
                    else
                        NET.textBox:push{COLOR.Y, 'Usage: /report <username or uid>'}
                    end

                -- Admin commands
                elseif cmd[1]=='/fkick' then
                    if tonumber(cmd[2]) then NET.room_kick(tonumber(cmd[2]),NET.roomState.roomId) end
                elseif cmd[1]=='/fpw' then
                    if cmd[2] then NET.room_setPW(cmd[2],NET.roomState.roomId) end
                elseif cmd[1]=='/fexit' or cmd[1]=='/fquit' then
                    NET.room_remove(NET.roomState.roomId)

                else
                    NET.textBox:push{COLOR.R,'Invalid command'}
                end
                inputBox:clear()
            elseif NET.room_chat(mes) then
                inputBox:clear()
            end
        else
            _switchChat()
        end
    elseif #key==1 and key:find("^[0-6]$") and kb.isDown('lctrl','rctrl') then
        NET.player_joinGroup(tonumber(key))
    elseif not inputBox.hide then
        WIDGET.focus(inputBox)
        inputBox:keypress(key)
    elseif playing then
        if NET.spectate or noKey or isRep or GAME.replaying or paused then return end
        local k=KEY_MAP.keyboard[key]
        if k and k>0 then
            PLAYERS[1]:pressKey(k)
            VK.press(k)
        end
    elseif not playing then
        if key=='space' then
            local myP = NETPLY.map[USER.uid]
            if myP and (myP.playMode=='Spectator' or myP.readyMode=='Ready') then
                _setCancel()
            else
                (kb.isDown('lctrl','rctrl','lalt','ralt') and _setSpectate or _setReady)()
            end
        elseif key=='s' then
            _gotoSetting()
        end
    end
end
function scene.keyUp(key)
    if not playing or NET.spectate or noKey or GAME.replaying then return end
    local k=KEY_MAP.keyboard[key]
    if k and k>0 then
        PLAYERS[1]:releaseKey(k)
        VK.release(k)
    end
end
function scene.gamepadDown(key)
    if key=='back' then
        scene.keyDown('escape')
    else
        if not playing or GAME.replaying then return end
        local k=KEY_MAP.joystick[key]
        if k and k>0 then
            PLAYERS[1]:pressKey(k)
            VK.press(k)
        end
    end
end
function scene.gamepadUp(key)
    if not playing or GAME.replaying then return end
    local k=KEY_MAP.joystick[key]
    if k and k>0 then
        PLAYERS[1]:releaseKey(k)
        VK.release(k)
    end
end

function scene.textInput(t)
    if REPORT.isOpen() and REPORT.textInput(t) then return true end
end

function scene.update(dt)
    REPORT.update(dt)
    AC.update(dt)
    if not GAME.replaying and WS.status('game')~='running' then
        TASK.unlock('netPlaying')
        NET.ws_close()
        SCN.back()
        return
    end
    if playing then
        if paused and not GAME.replaying then return end
        if not TASK.getLock('netPlaying') then
            playing=false
            BG.set()
            for i=1,#NETPLY.list do
                NETPLY.list[i].readyMode='Standby'
            end
            NETPLY.freshPos()
            NET.freshRoomAllReady()
            return
        else
            touchMoveLastFrame=false
            VK.update(dt)

            if #PLAYERS>0 then
                -- Update players
                if GAME.replaying then
                    _replayUpdate(dt)
                else
                    _stepPlayers(dt)
                end

                local P1=PLAYERS[1]

                -- Warning check
                checkWarning(P1,dt)

                -- Upload stream
                local streamInterval=4
                if not GAME.replaying and not NET.spectate and P1.frameRun-lastUpstreamTime>streamInterval then
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
                    lastUpstreamTime=PLAYERS[1].alive and P1.frameRun or 1e99
                end
            end
        end
    else
        if not TASK.getLock('netPlaying') then
            if NET.matchFoundPending and NET.matchFoundCountdown>0 then
                NET.updateMatchFoundCountdown(dt)
            end
            NETPLY.update(dt)
            if not GAME.replaying then
                NET_BAR.update(dt)
            end
        else
            playing=true
            TASK.lock('netPlaying')
            lastUpstreamTime=0
            upstreamProgress=1
            resetGameData('n',NET.seed)
            NETPLY.mouseMove(0,0)

            for i=1,#NETPLY.list do
                local p=NETPLY.list[i]
                if p.playMode=='Gamer' then
                    p.readyMode='Playing'
                    p.place=1
                else
                    p.place=1e99
                end
            end
            NET.spectate=PLAYERS[1] and (PLAYERS[1].uid~=USER.uid)
            if GAME.replaying then
                NET._initReplayStreams()
            end
            if NET.storedStream then
                for i=1,#NET.storedStream do
                    NET.pumpStream(NET.storedStream[i])
                end
                NET.storedStream=false
            end
        end
    end
    if NET.shakeStr>0 then
        NET.shakeStr=math.max(0,NET.shakeStr-dt*16)
    end
    if NET.matchFoundPending and NET.matchFoundCountdown>0 then
        WIDGET.locked=true
    else
        WIDGET.locked=false
    end
end

function scene.draw()
    if playing then
        -- Warning
        drawWarning()

        -- Players
        for p=1,#PLAYERS do
            PLAYERS[p]:draw()
        end

        -- Virtual keys
        VK.draw()

        -- Board labels: mark which board is yours (shown in live net matches
        -- and replays, mirroring the ranked replay presentation).
        if GAME.net or GAME.replaying then
            setFont(GAME.replaying and 18 or 25)
            for p=1,#PLAYERS do
                local P=PLAYERS[p]
                if P and P.fieldY then
                    local isYou=P.uid==USER.uid
                    local label
                    if GAME.replaying then
                        if #PLAYERS==1 then
                            label=(P.username and #P.username>0) and P.username or (USER.name or "YOU")
                            gc_setColor(COLOR.lY)
                        else
                            label=(P.username and #P.username>0) and P.username or (isYou and "YOU" or ("PLAYER "..p))
                            gc_setColor(p==1 and COLOR.lY or COLOR.lC)
                        end
                    else
                        label=isYou and "YOU" or (P.username or "OPPONENT")
                        gc_setColor(isYou and COLOR.lY or COLOR.lR)
                    end
                    mStr(label, P.centerX or 0, (P.fieldY or 0)-72)
                end
            end
        end

        if NET.roomState and NET.roomState.info and NET.roomState.info.type == 'ranked' and not GAME.replaying then
            setFont(16)
            gc_setColor(.95, .80, .30, .85)
            GC.mStr("⚡ RANKED 1V1 ⚡", 640, 14)
        end

        -- Replay UI
        if GAME.replaying then
            -- Top "REPLAY" banner: fades out when the replay ends and fades
            -- back in when the user seeks away from the end.
            setFont(40)
            gc_setColor(COLOR.Z[1],COLOR.Z[2],COLOR.Z[3],NET._replayBannerAlpha)
            mStr("REPLAY",640,8)

            if #PLAYERS==1 and GAME.curMode then
                local modeName=GAME.curMode.name or GAME.curModeName
                local modeText=text.modes[modeName]
                local dispName=modeText and (modeText[1].." "..(modeText[2] or "")) or ("["..modeName.."]")
                setFont(14)
                gc_setColor(1,1,1,.65*NET._replayBannerAlpha)
                mStr(dispName,640,48)
            end

            -- Media-player style seek bar backdrop, so the slider/buttons don't
            -- clash with the boards behind them.
            gc_setColor(0,0,0,.65)
            gc.rectangle('fill',20,664,1240,56,8)
            gc_setColor(1,1,1,.15)
            gc.rectangle('line',20,664,1240,56,8)

            -- Current / total time and frame readout, right of slider.
            if NET._replayTotal and NET._replayTotal>0 then
                local curS=math.floor((NET._replayCur or 0)/60)
                local totS=math.floor((NET._replayTotal or 0)/60)
                local timeStr=("%02d:%02d / %02d:%02d"):format(math.floor(curS/60),curS%60,math.floor(totS/60),totS%60)
                setFont(18)
                gc_setColor(COLOR.lY)
                gc_print(timeStr,1080,672)
                setFont(13)
                gc_setColor(.7,.8,.9)
                gc_print(("%d / %d f"):format(NET._replayCur or 0,NET._replayTotal or 0),1080,695)
            end

        end

        -- Add dark overlay if chat is open
        if not textBox.hide then
            gc_setColor(0, 0, 0, 0.62-0.26)
            love.graphics.rectangle('fill',0,0,1280,720)
        end

        if NET.spectate and not GAME.replaying then
            setFont(30)
            gc_setColor(.2,1,0,.8)
            gc_print(text.spectating,940,0)
        end
    else
        local t = love.timer.getTime()
        local mx, my = getMousePos()

        -- 1. Ambient Background Particles
        NET_BAR.drawBG()

        local myP = rawget(NETPLY.map, USER.uid)
        local isMatchPlaying = NET.roomState and NET.roomState.state == 'Playing'
        local roomCap = (NET.roomState and NET.roomState.capacity) or 4
        local roomName = (NET.roomState and NET.roomState.info and NET.roomState.info.name) or "CASUAL ROOM"
        local roomId = (NET.roomState and (NET.roomState.id or NET.roomState.roomId)) or ""

        -- 2. Left Panel: Player Roster & Table (x=40, y=72, w=840, h=616)
        local p1X, p1Y, p1W, p1H = 40, 72, 840, 616
        gc_setColor(.06, .09, .18, .92)
        gc_rectangle('fill', p1X, p1Y, p1W, p1H, 10)
        gc_setColor(.22, .40, .75, .75)
        gc_setLineWidth(1.5)
        gc_rectangle('line', p1X, p1Y, p1W, p1H, 10)

        -- Header bar
        gc_setColor(.12, .24, .50, .85)
        gc_rectangle('fill', p1X, p1Y, p1W, 44, 10)
        gc_rectangle('fill', p1X, p1Y + 30, p1W, 14)
        gc_setColor(1, 1, 1, .95)
        setFont(16)
        gc.print("PLAYERS IN ROOM", p1X + 16, p1Y + 12)

        -- Capacity pill
        local capStr = (#NETPLY.list) .. "/" .. roomCap .. " Players"
        setFont(12)
        gc_setColor(.18, .30, .60, .85)
        gc_rectangle('fill', p1X + 180, p1Y + 8, 120, 28, 6)
        gc_setColor(.55, .80, 1.0, .8)
        gc_setLineWidth(1)
        gc_rectangle('line', p1X + 180, p1Y + 8, 120, 28, 6)
        gc_setColor(1, 1, 1, .95)
        gc.printf(capStr, p1X + 180, p1Y + 14, 120, 'center')

        -- Private lock icon
        if NET.roomState and NET.roomState.private and IMG and IMG.lock then
            gc_setColor(1, 1, 1, .9)
            gc_draw(IMG.lock, p1X + 310, p1Y + 12)
        end

        -- Team Pills Header Label
        setFont(11)
        gc_setColor(.65, .78, 1.0, .8)
        gc.print("Team:", 455, p1Y + 15)

        -- Team selector pills
        local myGroup = (myP and myP.group) or 0
        for _, grp in ipairs(TEAM_GROUPS) do
            local isSel = (myGroup == grp.g)
            local isHov = (mx >= grp.x and mx <= grp.x + grp.w and my >= 78 and my <= 112)
            local gCol = GROUP_COLORS[grp.g] or COLOR.Z
            if isSel then
                gc_setColor(gCol[1], gCol[2], gCol[3], 0.95)
                gc_rectangle('fill', grp.x, 80, grp.w, 28, 5)
                gc_setColor(1, 1, 1, 1)
                gc_setLineWidth(2)
                gc_rectangle('line', grp.x, 80, grp.w, 28, 5)
                gc_setColor(0, 0, 0, 1)
            else
                gc_setColor(gCol[1], gCol[2], gCol[3], isHov and 0.45 or 0.20)
                gc_rectangle('fill', grp.x, 80, grp.w, 28, 5)
                gc_setColor(gCol[1], gCol[2], gCol[3], isHov and 0.9 or 0.6)
                gc_setLineWidth(1)
                gc_rectangle('line', grp.x, 80, grp.w, 28, 5)
                gc_setColor(1, 1, 1, isHov and 1 or 0.85)
            end
            setFont(11)
            gc.printf(grp.label, grp.x, 87, grp.w, 'center')
        end

        -- Mid-Game In-Progress Notice Banner
        if isMatchPlaying then
            local pulse = 0.85 + 0.15 * math.sin(t * 4)
            gc_setColor(.85, .50, .10, .92 * pulse)
            gc_rectangle('fill', 50, 122, 820, 46, 8)
            gc_setColor(1.0, .85, .30, 1)
            gc_setLineWidth(1.5)
            gc_rectangle('line', 50, 122, 820, 46, 8)
            gc_setColor(1, 1, 1, 1)
            setFont(15)
            gc.printf("⚔️ MATCH IN PROGRESS — Waiting in room lobby for the current round to conclude", 50, 136, 820, 'center')
        elseif NET.roomAllReady then
            local pulse = 0.80 + 0.20 * math.sin(t * 6)
            gc_setColor(.12, .65, .45, .90 * pulse)
            gc_rectangle('fill', 50, 122, 820, 46, 8)
            gc_setColor(.50, 1.0, .80, 1)
            gc_setLineWidth(2)
            gc_rectangle('line', 50, 122, 820, 46, 8)
            gc_setColor(1, 1, 1, 1)
            setFont(16)
            gc.printf("⚡ ALL PLAYERS READY — STARTING MATCH...", 50, 136, 820, 'center')
        end

        -- Render player cards via NETPLY
        NETPLY.draw()

        -- 3. Right Panel: Room Control & Status (x=900, y=72, w=340, h=616)
        local p2X, p2Y, p2W, p2H = 900, 72, 340, 616
        gc_setColor(.06, .09, .18, .92)
        gc_rectangle('fill', p2X, p2Y, p2W, p2H, 10)
        gc_setColor(.22, .40, .75, .75)
        gc_setLineWidth(1.5)
        gc_rectangle('line', p2X, p2Y, p2W, p2H, 10)

        -- Header
        gc_setColor(.12, .24, .50, .85)
        gc_rectangle('fill', p2X, p2Y, p2W, 44, 10)
        gc_rectangle('fill', p2X, p2Y + 30, p2W, 14)
        gc_setColor(1, 1, 1, .95)
        setFont(16)
        gc.print("ROOM CONTROLS", p2X + 16, p2Y + 12)

        -- Room Overview Card
        gc_setColor(.09, .13, .26, .85)
        gc_rectangle('fill', 916, 126, 308, 130, 8)
        gc_setColor(.25, .40, .75, .6)
        gc_setLineWidth(1)
        gc_rectangle('line', 916, 126, 308, 130, 8)

        setFont(16)
        gc_setColor(1, 1, 1, 1)
        gc.printf(roomName, 924, 134, 292, 'center')

        if #tostring(roomId) > 0 then
            setFont(12)
            gc_setColor(.55, .75, 1.0, .85)
            gc.printf("Room #" .. tostring(roomId), 924, 156, 292, 'center')
        end

        -- Host badge
        local hostName = "Host"
        for i=1,#NETPLY.list do
            if NETPLY.list[i].role == 'Admin' then
                hostName = USERS.getUsername(NETPLY.list[i].uid) or "Host"
                break
            end
        end
        setFont(12)
        gc_setColor(.85, .88, .95, .85)
        gc.printf("👑 Host: " .. hostName, 924, 180, 292, 'center')

        local modeStr = (NET.roomState and NET.roomState.info and NET.roomState.info.type) or "Casual"
        local rData = NET.roomState and NET.roomState.data
        local dropVal = (rData and rData.drop) or "Normal"
        local seqVal = (rData and rData.sequence) or "bag"
        local lifeVal = (rData and rData.life) or 0
        local lifeStr = (lifeVal == 0) and "Endless" or (lifeVal .. " Lives")
        gc_setColor(.65, .75, .90, .75)
        gc.printf("Mode: " .. modeStr:upper() .. " VERSUS", 924, 198, 292, 'center')
        gc.printf(("Gravity: %ss • Sequence: %s"):format(tostring(dropVal), tostring(seqVal)), 924, 216, 292, 'center')
        gc.printf(("Format: %s • Cap: %d Players"):format(lifeStr, roomCap), 924, 234, 292, 'center')

        -- Player Status Card (y=268..376)
        gc_setColor(.09, .13, .26, .85)
        gc_rectangle('fill', 916, 268, 308, 104, 8)
        gc_setColor(.25, .40, .75, .6)
        gc_setLineWidth(1)
        gc_rectangle('line', 916, 268, 308, 104, 8)

        setFont(11)
        gc_setColor(.65, .75, .90, .8)
        gc.print("YOUR STATUS", 930, 278)

        local isReady = myP and myP.readyMode == 'Ready'
        local isSpectator = myP and myP.playMode == 'Spectator'

        if isMatchPlaying then
            gc_setColor(.85, .50, .10, .9)
            gc_rectangle('fill', 930, 300, 280, 34, 6)
            gc_setColor(1, 1, 1, 1)
            setFont(13)
            gc.printf("⏳ WAITING FOR NEXT ROUND", 930, 310, 280, 'center')
        elseif isReady then
            local rGlow = 0.8 + 0.2 * math.sin(t * 4)
            gc_setColor(.12, .65, .35, .9 * rGlow)
            gc_rectangle('fill', 930, 300, 280, 34, 6)
            gc_setColor(.6, 1, .7, 1)
            gc_setLineWidth(1.5)
            gc_rectangle('line', 930, 300, 280, 34, 6)
            gc_setColor(1, 1, 1, 1)
            setFont(13)
            gc.printf("✓ READY TO PLAY", 930, 310, 280, 'center')
        elseif isSpectator then
            gc_setColor(.15, .45, .70, .9)
            gc_rectangle('fill', 930, 300, 280, 34, 6)
            gc_setColor(.5, .8, 1, 1)
            gc_setLineWidth(1)
            gc_rectangle('line', 930, 300, 280, 34, 6)
            gc_setColor(1, 1, 1, 1)
            setFont(13)
            gc.printf("👁 SPECTATOR MODE", 930, 310, 280, 'center')
        else
            gc_setColor(.22, .26, .38, .9)
            gc_rectangle('fill', 930, 300, 280, 34, 6)
            gc_setColor(.45, .50, .65, 1)
            gc_setLineWidth(1)
            gc_rectangle('line', 930, 300, 280, 34, 6)
            gc_setColor(.85, .90, 1, .9)
            setFont(13)
            gc.printf("○ NOT READY", 930, 310, 280, 'center')
        end

        setFont(11)
        gc_setColor(.55, .65, .85, .75)
        gc.printf("Press [Space] to toggle Ready", 920, 346, 300, 'center')

        -- Action Button 1: Ready / Cancel (y=386..440)
        local isBtn1Hov = (mx >= 920 and mx <= 1220 and my >= 386 and my <= 440)
        if isMatchPlaying then
            gc_setColor(.20, .24, .32, .7)
            gc_rectangle('fill', 920, 386, 300, 54, 8)
            gc_setColor(.40, .45, .55, .5)
            gc_setLineWidth(1)
            gc_rectangle('line', 920, 386, 300, 54, 8)
            gc_setColor(.65, .70, .80, .7)
            setFont(15)
            gc.printf("Round In Progress...", 920, 404, 300, 'center')
        elseif isReady or isSpectator then
            gc_setColor(isBtn1Hov and .75 or .55, isBtn1Hov and .22 or .15, isBtn1Hov and .25 or .18, .92)
            gc_rectangle('fill', 920, 386, 300, 54, 8)
            gc_setColor(1.0, .55, .55, isBtn1Hov and 1 or .8)
            gc_setLineWidth(1.5)
            gc_rectangle('line', 920, 386, 300, 54, 8)
            gc_setColor(1, 1, 1, 1)
            setFont(16)
            gc.printf("CANCEL READY", 920, 404, 300, 'center')
        else
            local rPulse = 0.85 + 0.15 * math.sin(t * 4)
            gc_setColor(.12, isBtn1Hov and .75 or .58, .38, .92)
            gc_rectangle('fill', 920, 386, 300, 54, 8)
            gc_setColor(.55, 1.0, .75, isBtn1Hov and 1 or rPulse)
            gc_setLineWidth(2)
            gc_rectangle('line', 920, 386, 300, 54, 8)
            gc_setColor(1, 1, 1, 1)
            setFont(17)
            gc.printf("READY UP  ✓", 920, 402, 300, 'center')
        end

        -- Action Button 2: Spectate / Participate (y=448..490)
        local isBtn2Hov = (mx >= 920 and mx <= 1220 and my >= 448 and my <= 490)
        gc_setColor(isBtn2Hov and .18 or .10, isBtn2Hov and .28 or .16, isBtn2Hov and .50 or .30, .85)
        gc_rectangle('fill', 920, 448, 300, 42, 6)
        gc_setColor(.35, .55, .85, isBtn2Hov and .9 or .6)
        gc_setLineWidth(1)
        gc_rectangle('line', 920, 448, 300, 42, 6)
        gc_setColor(1, 1, 1, isBtn2Hov and 1 or .85)
        setFont(13)
        gc.printf(isSpectator and "SWITCH TO PLAYER" or "SPECTATE MATCH", 920, 460, 300, 'center')

        -- Action Button 3: Settings (y=498..540)
        local isBtn3Hov = (mx >= 920 and mx <= 1220 and my >= 498 and my <= 540)
        gc_setColor(isBtn3Hov and .18 or .10, isBtn3Hov and .28 or .16, isBtn3Hov and .50 or .30, .85)
        gc_rectangle('fill', 920, 498, 300, 42, 6)
        gc_setColor(.35, .55, .85, isBtn3Hov and .9 or .6)
        gc_setLineWidth(1)
        gc_rectangle('line', 920, 498, 300, 42, 6)
        gc_setColor(1, 1, 1, isBtn3Hov and 1 or .85)
        setFont(13)
        gc.printf("⚙ CONTROLS & HANDLING [S]", 920, 510, 300, 'center')

        -- Action Button 4: Chat (y=548..590)
        local isBtn4Hov = (mx >= 920 and mx <= 1220 and my >= 548 and my <= 590)
        gc_setColor(isBtn4Hov and .18 or .10, isBtn4Hov and .28 or .16, isBtn4Hov and .50 or .30, .85)
        gc_rectangle('fill', 920, 548, 300, 42, 6)
        gc_setColor(.35, .55, .85, isBtn4Hov and .9 or .6)
        gc_setLineWidth(1)
        gc_rectangle('line', 920, 548, 300, 42, 6)
        gc_setColor(1, 1, 1, isBtn4Hov and 1 or .85)
        setFont(13)
        gc.printf("💬 ROOM CHAT [/]", 920, 560, 300, 'center')

        -- Action Button 5: Leave Room (y=598..640)
        local isBtn5Hov = (mx >= 920 and mx <= 1220 and my >= 598 and my <= 640)
        gc_setColor(isBtn5Hov and .30 or .18, isBtn5Hov and .12 or .08, isBtn5Hov and .15 or .10, .85)
        gc_rectangle('fill', 920, 598, 300, 42, 6)
        gc_setColor(.65, .25, .30, isBtn5Hov and .9 or .6)
        gc_setLineWidth(1)
        gc_rectangle('line', 920, 598, 300, 42, 6)
        gc_setColor(1.0, .75, .75, isBtn5Hov and 1 or .85)
        setFont(13)
        gc.printf("← LEAVE ROOM [ESC]", 920, 610, 300, 'center')

        -- 4. Top Bar
        NET_BAR.draw(roomName:upper(), "← Leave Room")

        -- 5. Chat Overlay if open
        if not textBox.hide then
            gc_setColor(0, 0, 0, 0.70)
            gc.rectangle('fill', 0, 0, 1280, 720)
        end
    end

    -- New message
    local a=TASK.getLock('receiveMessage')
    if a then
        setFont(40)
        gc_setColor(.3,.7,1,a^2)
        gc_print(CHAR.icon.pencil,430,10)
    end

    -- Replay pause overlay
    if paused then
        gc_setColor(0,0,0,.5)
        gc.rectangle('fill',0,0,1280,720)
        setFont(60)
        gc_setColor(COLOR.Z)
        mStr("PAUSED",640,300)
        setFont(25)
        gc_setColor(COLOR.lY)
        mStr("Press ESC to resume",640,370)
        setFont(20)
        gc_setColor(COLOR.lR)
        mStr("Press Q to quit replay",640,405)
    end
end
local function _hideF_ready() return true end
local function _hideF_standby() return true end
local function _hideF_hideChat() return textBox.hide end
scene.widgetList={
    textBox,
    inputBox,
    WIDGET.newKey{name='setting', x=1200,y=160,w=90,h=90,font=60,fText=CHAR.icon.settings,code=_gotoSetting,hideF=_hideF_ready},
    WIDGET.newKey{name='ready',   x=1060,y=510,w=360,h=90,color='lG',font=35, code=_setReady,hideF=_hideF_ready},
    WIDGET.newKey{name='spectate',x=1060,y=610,w=360,h=90,color='lO',font=35, code=_setSpectate,hideF=_hideF_ready},
    WIDGET.newKey{name='cancel',  x=1060,y=560,w=360,h=120,color='lH',font=40,code=_setCancel,hideF=_hideF_standby},

    WIDGET.newButton{x=320,y=45,w=40,color='Z', fText="",code=function() NET.player_joinGroup(0) end,hideF=_hideF_ready},
    WIDGET.newButton{x=190,y=25,w=30,color='lR',fText="",code=function() NET.player_joinGroup(1) end,hideF=_hideF_ready},
    WIDGET.newButton{x=230,y=25,w=30,color='lG',fText="",code=function() NET.player_joinGroup(2) end,hideF=_hideF_ready},
    WIDGET.newButton{x=270,y=25,w=30,color='lB',fText="",code=function() NET.player_joinGroup(3) end,hideF=_hideF_ready},
    WIDGET.newButton{x=190,y=65,w=30,color='lY',fText="",code=function() NET.player_joinGroup(4) end,hideF=_hideF_ready},
    WIDGET.newButton{x=230,y=65,w=30,color='lM',fText="",code=function() NET.player_joinGroup(5) end,hideF=_hideF_ready},
    WIDGET.newButton{x=270,y=65,w=30,color='lC',fText="",code=function() NET.player_joinGroup(6) end,hideF=_hideF_ready},

    WIDGET.newKey{x=1045,y=135,w=50,font=40,fText=CHAR.zChan.normal     ,code=function() inputBox:addText(CHAR.zChan.normal     ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1110,y=135,w=50,font=40,fText=CHAR.zChan.full       ,code=function() inputBox:addText(CHAR.zChan.full       ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1175,y=135,w=50,font=40,fText=CHAR.zChan.happy      ,code=function() inputBox:addText(CHAR.zChan.happy      ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1240,y=135,w=50,font=40,fText=CHAR.zChan.confused   ,code=function() inputBox:addText(CHAR.zChan.confused   ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1045,y=200,w=50,font=40,fText=CHAR.zChan.grinning   ,code=function() inputBox:addText(CHAR.zChan.grinning   ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1110,y=200,w=50,font=40,fText=CHAR.zChan.frowning   ,code=function() inputBox:addText(CHAR.zChan.frowning   ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1175,y=200,w=50,font=40,fText=CHAR.zChan.tears      ,code=function() inputBox:addText(CHAR.zChan.tears      ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1240,y=200,w=50,font=40,fText=CHAR.zChan.anxious    ,code=function() inputBox:addText(CHAR.zChan.anxious    ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1045,y=265,w=50,font=40,fText=CHAR.zChan.rage       ,code=function() inputBox:addText(CHAR.zChan.rage       ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1110,y=265,w=50,font=40,fText=CHAR.zChan.fear       ,code=function() inputBox:addText(CHAR.zChan.fear       ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1175,y=265,w=50,font=40,fText=CHAR.zChan.question   ,code=function() inputBox:addText(CHAR.zChan.question   ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1240,y=265,w=50,font=40,fText=CHAR.zChan.angry      ,code=function() inputBox:addText(CHAR.zChan.angry      ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1045,y=330,w=50,font=40,fText=CHAR.zChan.shocked    ,code=function() inputBox:addText(CHAR.zChan.shocked    ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1110,y=330,w=50,font=40,fText=CHAR.zChan.ellipses   ,code=function() inputBox:addText(CHAR.zChan.ellipses   ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1175,y=330,w=50,font=40,fText=CHAR.zChan.sweatDrop  ,code=function() inputBox:addText(CHAR.zChan.sweatDrop  ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1240,y=330,w=50,font=40,fText=CHAR.zChan.cry        ,code=function() inputBox:addText(CHAR.zChan.cry        ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1045,y=395,w=50,font=40,fText=CHAR.zChan.cracked    ,code=function() inputBox:addText(CHAR.zChan.cracked    ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1110,y=395,w=50,font=40,fText=CHAR.zChan.qualified  ,code=function() inputBox:addText(CHAR.zChan.qualified  ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1175,y=395,w=50,font=40,fText=CHAR.zChan.unqualified,code=function() inputBox:addText(CHAR.zChan.unqualified) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1240,y=395,w=50,font=40,fText=CHAR.zChan.understand ,code=function() inputBox:addText(CHAR.zChan.understand ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1045,y=460,w=50,font=40,fText=CHAR.zChan.thinking   ,code=function() inputBox:addText(CHAR.zChan.thinking   ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1110,y=460,w=50,font=40,fText=CHAR.zChan.spark      ,code=function() inputBox:addText(CHAR.zChan.spark      ) end,hideF=_hideF_hideChat},
--  WIDGET.newKey{x=1175,y=460,w=50,font=40,fText=CHAR.zChan.           ,code=function() inputBox:addText(                      ) end,hideF=_hideF_hideChat},
    WIDGET.newKey{x=1240,y=460,w=50,font=40,fText=CHAR.zChan.none       ,code=function() inputBox:addText(CHAR.zChan.none       ) end,hideF=_hideF_hideChat},

    WIDGET.newKey{name='chat',    x=390,y=45,w=60,fText="···",                code=_switchChat,hideF=function() return true end},
    WIDGET.newKey{name='quit',    x=890,y=45,w=60,font=30,fText=CHAR.icon.cross_thick,code=_quit,hideF=function() return true end},

    WIDGET.newKey{name='replayQuit',  x=1220,y=50, w=50, font=30, fText=CHAR.icon.cross_thick,code=_quit,                                                                                       hideF=function() return not GAME.replaying end},
    WIDGET.newKey{name='replayPause', x=40, y=50, w=60, font=40, fText=CHAR.icon.pause,   code=function() paused=not paused; _updatePlayToggleIcon() end,                                  hideF=function() return not GAME.replaying end},
    WIDGET.newKey{name='replaySpd1',  x=105,y=50, w=60, font=40, fText=CHAR.icon.speedOne,  code=function() GAME.replaySpeed=1  end,                                                        hideF=function() return not GAME.replaying end},
    WIDGET.newKey{name='replaySpd2',  x=170,y=50, w=60, font=40, fText=CHAR.icon.speedTwo,  code=function() GAME.replaySpeed=2  end,                                                        hideF=function() return not GAME.replaying end},
    WIDGET.newKey{name='replaySpd5',  x=235,y=50, w=60, font=40, fText=CHAR.icon.speedFive, code=function() GAME.replaySpeed=5  end,                                                        hideF=function() return not GAME.replaying end},
    WIDGET.newKey{name='replaySpd10', x=300,y=50, w=60, font=30, fText="10x",               code=function() GAME.replaySpeed=10 end,                                                        hideF=function() return not GAME.replaying end},

    WIDGET.newKey{name='replayBack5', x=35, y=672, w=52, font=20, fText="-5s",              code=function() NET.seekReplay((NET._replayCur or 0)-300) end,                                 hideF=function() return not GAME.replaying end},
    WIDGET.newKey{name='replayPlayToggle',x=95,y=672,w=52,font=32,fText=CHAR.icon.pause,code=function()
        paused=not paused
        _updatePlayToggleIcon()
    end,hideF=function() return not GAME.replaying end},
    WIDGET.newKey{name='replayFwd5',  x=155,y=672, w=52, font=20, fText="+5s",              code=function() NET.seekReplay((NET._replayCur or 0)+300) end,                                 hideF=function() return not GAME.replaying end},
    WIDGET.newSlider{name='replaySeek',x=225,y=683,w=840,axis={0,1,false},disp=function() return (NET._replayTotal and NET._replayTotal>0) and (NET._replayCur or 0)/NET._replayTotal or 0 end,code=function(v) local f=math.floor(v*(NET._replayTotal or 1)); NET.seekReplay(f) end,hideF=function() return not GAME.replaying end},
}

function scene.overDraw()
    if NET.matchFoundPending and NET.matchFoundCountdown>0 then
        gc_setColor(0,0,0,1)
        gc.rectangle('fill',0,0,1280,720)
    end
    REPORT.draw()
end

return scene
