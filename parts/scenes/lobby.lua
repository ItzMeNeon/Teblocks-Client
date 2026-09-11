local scene={}

local CARD=require'parts.userCard'
local AUTH=require'parts.authModal'
local LOBBY=require'parts.lobbyPanel'

local gc=love.graphics
local gc_setColor=gc.setColor
local gc_print,gc_printf=gc.print,gc.printf
local setFont=FONT.set

local popupY=720
local popupTargetY=720

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
    NET.online_getPlayers()
end

function scene.leave()
    CARD.leave()
    AUTH.close()
end

function scene.keyDown(key,rep)
    if AUTH.isOpen() and AUTH.keyDown(key,rep) then return true end
    if LOBBY.keyDown(key) then return true end
    if key=='escape' and not rep then
        if LOBBY.isAnyOpen() then
            if LOBBY.chat and LOBBY.chat.visible then LOBBY.chat:toggle() end
            if LOBBY.playerList and LOBBY.playerList.visible then LOBBY.playerList:toggle() end
        else
            SCN.backTo('main')
        end
    elseif key=='return' or key=='kpenter' then
        CARD.openMenu()
    elseif key=='r' and love.keyboard.isDown('lctrl','rctrl') then
        _refreshOnline()
    else
        return true
    end
end

function scene.textInput(t)
    if AUTH.isOpen() and AUTH.textInput(t) then return true end
    if LOBBY.textInput(t) then return true end
end

function scene.mouseClick(x,y)
    if CARD.mouseClick(x,y) then return true end
    if AUTH.mouseClick(x,y) then return true end
    if LOBBY.mouseClick(x,y) then return true end
    if NET.matchmaking and popupY<700 then
        local pw,ph=340,72
        local px=640-pw/2
        local py=popupY
        local cancelX=px+pw-28
        local cancelY=py+22
        if (x-cancelX)^2+(y-cancelY)^2<=16*16 then
            NET.matchmaking=false
            NET.searchTimer=0
            NET.matchFoundPending=false
            NET.matchFoundCountdown=0
            NET.matchFoundSeed=nil
            NET.ranked_leave()
            popupTargetY=720
            return true
        end
    end
end

function scene.update(dt)
    CARD.update(dt)
    AUTH.update(dt)
    LOBBY.update(dt)

    if NET.matchmaking then
        NET.searchTimer=NET.searchTimer+dt
    end
    if NET.matchFoundPending and NET.matchFoundCountdown>0 then
        NET.updateMatchFoundCountdown(dt)
    end

    if NET.matchFoundPending then
        popupTargetY=-100
    elseif NET.matchmaking then
        popupTargetY=620
    else
        popupTargetY=720
    end
    popupY=MATH.expApproach(popupY,popupTargetY,dt*12)
end

function scene.draw()
    setFont(50)
    gc_setColor(COLOR.Z)
    gc_printf("Teblocks",0,70,1280,'center')
    
    setFont(25)
    gc_setColor(COLOR.lH)
    gc_printf("Select a game mode to play",0,140,1280,'center')
end

function scene.overDraw()
    LOBBY.draw()
    LOBBY.drawToggleButtons()
    CARD.draw()
    AUTH.draw()

    if popupY<700 then
        local alpha=math.min(1,math.max(0,(720-popupY)/80))
        local pw,ph=340,72
        local px=640-pw/2
        local py=popupY

        gc_setColor(.12,.12,.12,.9*alpha)
        gc.rectangle('fill',px,py,pw,ph,8)
        gc_setColor(1,1,1,.5*alpha)
        gc.setLineWidth(2)
        gc.rectangle('line',px,py,pw,ph,8)

        setFont(20)
        gc_setColor(COLOR.lY[1],COLOR.lY[2],COLOR.lY[3],alpha)
        gc_printf("Ranked match searching...",px,py+10,pw,'center')

        if NET.searchTimer then
            gc_setColor(COLOR.lH[1],COLOR.lH[2],COLOR.lH[3],alpha)
            gc_printf(("Elapsed: %.1fs"):format(NET.searchTimer),px,py+36,pw,'center')
        end

        local cancelX=px+pw-28
        local cancelY=py+22
        gc.setLineWidth(2)
        gc.setColor(1,1,1,.6*alpha)
        gc.circle('line',cancelX,cancelY,14)
        gc.setColor(1,1,1,.9*alpha)
        gc.setLineWidth(3)
        gc.line(cancelX-6,cancelY-6,cancelX+6,cancelY+6)
        gc.line(cancelX+6,cancelY-6,cancelX-6,cancelY+6)
    end
end

scene.widgetList={
    WIDGET.newKey{name='Casual Mode',   x=490, y=420,w=260,h=90,font=35,color='lG',code=_goCasual},
    WIDGET.newKey{name='Ranked Mode',    x=790, y=420,w=260,h=90,font=35,color='lY',code=_goRanked},
    WIDGET.newButton{name='back',       x=1140,y=640,w=170,h=80,sound='back',font=60,fText=CHAR.icon.back,code=pressKey'escape'},
}

return scene
