local scene={}

local gc=love.graphics
local gc_setColor,gc_setLineWidth=gc.setColor,gc.setLineWidth
local gc_rectangle=gc.rectangle
local gc_print,gc_printf=gc.print,gc.printf
local gc_push,gc_pop=gc.push,gc.pop
local gc_translate=gc.translate
local gc_line=gc.line
local setFont=FONT.set

function scene.enter()
    BG.set()
    DiscordRPC.update("Match Found!")
end

function scene.leave()
end

function scene.keyDown(key,rep)
    if key=='escape' and not rep then
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
        return true
    end
    return false
end

function scene.update(dt)
    if NET.matchFoundPending and NET.matchFoundCountdown>0 then
        NET.updateMatchFoundCountdown(dt)
    end
    if NET.shakeStr>0 then
        NET.shakeStr=math.max(0,NET.shakeStr-dt*16)
    end
    if NET.matchFoundPending and NET.matchFoundCountdown>0 then
        WIDGET.locked=true
    else
        WIDGET.locked=false
    end

    if not NET.matchFoundPending and SCN.cur=='net_matchFound' then
        SCN.go('net_game')
    end
end

function scene.draw()
    if NET.matchFoundPending and NET.matchFoundCountdown>0 then
        gc_setColor(0,0,0,1)
        gc_rectangle('fill',0,0,1280,720)

        local elapsed = love.timer.getTime() - (NET.matchFoundTime or 0)

        local shakeX=NET.shakeStr>0 and (math.random()-.5)*NET.shakeStr*2.5 or 0
        local shakeY=NET.shakeStr>0 and (math.random()-.5)*NET.shakeStr*2.5 or 0
        gc_push('transform')
        gc_translate(shakeX, shakeY)

        gc_setColor(.06,.06,.06,1)
        for i=0,1280,80 do
            gc.line(i,0,i,720)
        end
        for i=0,720,80 do
            gc.line(0,i,1280,i)
        end

        for i=1,3 do
            local t=math.min(math.max(0, elapsed - i*0.12) / 1.4, 1)
            local r=80 + t * 520
            local a=(1-t)*.12
            gc_setLineWidth(2)
            gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], a)
            gc.circle('line', 640, 360, r, 64)
        end

        local flashT=math.min(elapsed/0.25,1)
        local flashA=(1-flashT)*.35
        gc_setColor(1,1,1,flashA)
        gc_rectangle('fill',0,0,1280,720)

        local myName=USERS.getUsername(USER.uid) or "You"
        local oppName="???"
        if NET.matchFoundOppId then
            oppName=USERS.getUsername(NET.matchFoundOppId) or "Player"
        end

        local nameT = math.min(elapsed / 1.4, 1)
        local nameEase = 1 - (1 - nameT)^3
        local mySlide = (1 - nameEase) * -650
        local oppSlide = (1 - nameEase) * 650

        setFont(46)
        gc_setColor(COLOR.lG)
        gc_printf(myName, mySlide, 230, 640, 'center')

        gc_setColor(COLOR.lR)
        gc_printf(oppName, 640 + oppSlide, 410, 640, 'center')

        local vsIntroT = math.min(math.max(0, elapsed - 0.5) / 1.0, 1)
        local vsEase = 1 - (1 - vsIntroT)^3
        local vsScale = (1 + 0.3 * vsEase) * (1 + 0.04 * math.sin(elapsed * 5) * vsEase)
        gc_push('transform')
        gc.translate(640, 330)
        gc.scale(vsScale, vsScale)

        gc.setBlendMode('add')
        for i=5,1,-1 do
            gc.setLineWidth(i * 5)
            gc.setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], 0.07 / i * vsEase)
            gc.line(-220, 0, 220, 0)
        end
        gc.setBlendMode('alpha')

        setFont(80)
        gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], vsEase)
        gc_printf(text.WidgetText.net_ranked.matchFoundVS or "VS", -400, -45, 800, 'center')
        gc.pop()

        local lineAlpha = vsEase * 0.8
        local lineW = 220 * vsEase
        gc_setLineWidth(4)
        gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], lineAlpha)
        gc.line(640 - lineW, 330, 640 + lineW, 330)

        for i=1,2 do
            local ringR = 85 + i*30 + 7 * math.sin(elapsed * (3 + i)) * vsEase
            local ringA = vsEase * (0.35 - i*0.1)
            gc_setLineWidth(3 - i*0.5)
            gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], ringA)
            gc.circle('line', 640, 330, ringR, 48)
        end

        local titleT = math.min(math.max(0, elapsed - 1.0) / 0.5, 1)
        local titleEase = 1 - (1 - titleT)^3
        setFont(30)
        gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], 0.55 + 0.45 * titleEase)
        gc_printf(text.WidgetText.net_ranked.matchFound or "Match Found!", 0, 120, 1280, 'center')

        gc_pop()
        return
    end
end

return scene
