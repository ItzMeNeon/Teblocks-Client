local GAME,SCR=GAME,SCR
local sin,log,abs,floor,min,max=math.sin,math.log10,math.abs,math.floor,math.min,math.max
local GC=GC

local scene={}

local modUsed
local page
local timer1,timer2-- Animation timer
local form-- Form of clear & spins
local radar-- Radar chart
local radarOrgTouchPos-- For storing the first touch position in radar area
local val-- Radar chart normalizer
local standard-- Standard hexagon
local chartColor-- Color of radar chart
local rank-- Current rank
local trophy-- Current trophy
local trophyColor-- Current trophy color

local MISSION_NAMES={
    _1="Single Clear",
    _2="Double Clear",
    _3="Triple Clear",
    _4="Quad (Tetris)",
    A1="Any-Spin Single",
    A2="Any-Spin Double",
    A3="Any-Spin Triple",
    A4="Any-Spin Quad",
    PC="Perfect Clear",
}
local PIECE_NAMES={"Z","S","J","L","T","O","I"}
local SPIN_NAMES={"Single","Double","Triple","Quad"}

local function getMissionName(code)
    local tag=ENUM_MISSION[code]
    if not tag then return "Mission #"..tostring(code) end
    if MISSION_NAMES[tag] then return MISSION_NAMES[tag] end
    if type(code)=='number' and code>=11 and code<90 then
        local pIdx=floor(code/10)
        local sIdx=code%10
        local pName=PIECE_NAMES[pIdx] or "?"
        local sName=SPIN_NAMES[sIdx] or tostring(sIdx)
        return pName.."-Spin "..sName
    end
    return tostring(tag)
end

local editCustomTexts={
    en="Edit Setup (E)",
    zh="编辑配置 (E)",
    zh_trad="編輯配置 (E)",
    ja="設定変更 (E)",
    ru="Настройки (E)",
    es="Editar config. (E)",
    fr="Modifier (E)",
    vi="Chỉnh sửa (E)",
    pt="Editar (E)",
    id="Ubah (E)",
}
local function getEditCustomText()
    local loc=SETTING.locale or 'en'
    return editCustomTexts[loc] or editCustomTexts[loc:sub(1,2)] or "Edit Setup (E)"
end

local function isCustomGame()
    local M=GAME.curMode
    return (M and (M.isCustom or (type(M.name)=='string' and M.name:sub(1,7)=='custom_')))
        or (GAME.modeEnv and GAME.modeEnv.isCustom)
end

local function hasMissions()
    return GAME.modeEnv and GAME.modeEnv.mission and #GAME.modeEnv.mission>0
end

local function hasPuzzle()
    return (GAME.curMode and GAME.curMode.name=='custom_puzzle') or (FIELD and #FIELD>1 and PLAYERS[1] and PLAYERS[1].modeData and PLAYERS[1].modeData.finished)
end

local function hasAIOpponent()
    return GAME.modeEnv and GAME.modeEnv.opponent and GAME.modeEnv.opponent~='X'
end

local function hasObjectives()
    return hasMissions() or hasPuzzle() or hasAIOpponent()
end

local function getMaxPages()
    return hasObjectives() and 3 or 2
end

function scene.enter()
    modUsed=usingMod()
    page=0
    if type(SCN.prev)=='string' and SCN.prev:find("setting") then
        TEXT.show(text.needRestart,640,410,50,'fly',.6)
    end
    local P1=PLAYERS[1]
    local S=P1 and P1.stat or {
        time=0,frame=0,key=0,rotate=0,hold=0,piece=0,row=0,dig=0,
        atk=0,digatk=0,pend=0,recv=0,clears={0,0,0,0},spins={0,0,0,0},
        b2b=0,b3b=0,pc=0,hpc=0,extraPiece=0,maxFinesseCombo=0,finesseRate=0,
        off=0,send=0,
    }

    timer1=(SCN.prev=='game' or SCN.prev=='depause') and 0 or 1
    timer2=timer1

    local safeTime=max(S.time,0.001)
    local frameLostRate=S.time>0 and ((S.frame/safeTime/60-1)*100) or 0
    form={
        {COLOR.Z,STRING.time(S.time),frameLostRate>10 and COLOR.R or frameLostRate>3 and COLOR.Y or COLOR.H,(" (%.2f%%)"):format(frameLostRate)},
        ("%d/%d/%d"):format(S.key,S.rotate,S.hold),
        ("%d  %.2fPPS"):format(S.piece,S.piece/safeTime),
        ("%d(%d)  %.2fLPM"):format(S.row,S.dig,S.row/safeTime*60),
        ("%d(%d)  %.2fAPM"):format(S.atk,S.digatk,S.atk/safeTime*60),
        ("%d(%d-%d)"):format(S.pend,S.recv,S.recv-S.pend),
        ("[1] %-7d[2] %-7d[3] %-7d[4] %-7d"):format(S.clears[1],S.clears[2],S.clears[3],S.clears[4]),
        (CHAR.icon.num0InSpin.." %-8d"..CHAR.icon.num1InSpin.." %-8d"..CHAR.icon.num2InSpin.." %-8d"..CHAR.icon.num3InSpin.." %-8d"):format(S.spins[1],S.spins[2],S.spins[3],S.spins[4]),
        ("%d/%d ; %d/%d"):format(S.b2b,S.b3b,S.pc,S.hpc),
        ("%d/%dx/%.2f%%"):format(S.extraPiece,S.maxFinesseCombo,S.piece>0 and S.finesseRate*20/S.piece or 0),
    }

    radar={
        (S.off+S.dig)/safeTime*60,
        (S.atk+S.dig)/safeTime*60,
        S.atk/safeTime*60,
        S.send/safeTime*60,
        S.piece/safeTime*24,
        S.dig/safeTime*60,
    }
    val={1/80,1/160,1/120,1/80,1/100,1/40}

    for i=1,6 do
        val[i]=val[i]*radar[i]
        if val[i]>1.26 then val[i]=1.26+log(val[i]-.26) end
    end

    for i=1,6 do
        radar[i]=("%.2f%s"):format(radar[i],text.radarData[i])
    end
    local f=1
    for i=1,6 do
        if val[i]>.5 then f=2 end
        if val[i]>1 then f=3 break end
    end
    if f==1 then chartColor,f={.4,.9,.5},1.25
    elseif f==2 then chartColor,f={.4,.7,.9},1
    elseif f==3 then chartColor,f={1,.3,.3},.626
    end
    standard={
        120*.5*f, 120*3^.5*.5*f,
        120*-.5*f,120*3^.5*.5*f,
        120*-1*f, 120*0*f,
        120*-.5*f,120*-3^.5*.5*f,
        120*.5*f, 120*-3^.5*.5*f,
        120*1*f,  120*0*f,
    }

    for i=6,1,-1 do
        val[2*i-1],val[2*i]=val[i]*standard[2*i-1],val[i]*standard[2*i]
    end

    if P1 and (P1.result=='win' or P1.result=='torikan') and P1.stat.piece>4 then
        local acc=P1.stat.finesseRate*.2/P1.stat.piece
        rank=CHAR.icon['rank'..(
            acc==1. and "Z" or
            acc>.97 and "S" or
            acc>.94 and "A" or
            acc>.87 and "B" or
            acc>.70 and "C" or
            acc>.50 and "D" or
            acc>.30 and "E" or
            "F"
        )]
        if acc==1 then
            trophy=text.finesse_ap
            trophyColor=COLOR.Y
        elseif P1.stat.maxFinesseCombo==P1.stat.piece then
            trophy=text.finesse_fc
            trophyColor=COLOR.lC
        else
            trophy=nil
        end
    else
        rank,trophy=nil
    end
    if GAME.prevBG then
        BG.set(GAME.prevBG)
        GAME.prevBG=false
    end

    -- Update custom edit button label
    for _,W in next,scene.widgetList do
        if W.name=='edit_custom' then
            W.fText=getEditCustomText()
            W.obj=GC.newText(FONT.get(W.font or 30),W.fText)
        end
    end
end

function scene.leave()
    trySave()
end

function scene.keyDown(key,isRep)
    if isRep then return true end
    if key=='q' then
        GAME.playing=false
        SCN.back()
    elseif key=='escape' then
        if GAME.result then
            GAME.playing=false
            SCN.back()
        else
            SCN.swapTo('depause','none')
        end
    elseif key=='space' then
        if GAME.result then
            scene.keyDown('r')
        else
            scene.keyDown('escape')
        end
    elseif key=='s' then
        if not GAME.fromRepMenu then
            GAME.prevBG=BG.cur
            SCN.go('setting_sound')
        end
    elseif key=='r' then
        if not GAME.fromRepMenu then
            resetGameData()
            SCN.swapTo('game','none')
        end
    elseif key=='e' then
        if isCustomGame() and not GAME.fromRepMenu then
            GAME.playing=false
            SCN.swapTo('customGame','none')
        end
    elseif key=='p' then
        if (GAME.result or GAME.replaying) and GAME.initPlayerCount==1 then
            local repData=DATA.dumpRecording(GAME.rep)
            local fullRep={
                mode=GAME.curModeName or (GAME.curMode and GAME.curMode.name) or "sprint_40l",
                seed=GAME.seed,
                setting=GAME.setting,
                data=repData,
                player=USER.name or "Player",
                available=true,
                tasUsed=GAME.tasUsed,
            }
            NET.startSoloReplay(fullRep)
        end
    elseif key=='o' then
        if (GAME.result or GAME.replaying) and GAME.initPlayerCount==1 and not GAME.saved then
            if DATA.saveReplay() then
                GAME.saved=true
                SFX.play('connected')
            end
        end
    elseif key=='tab' or key=='Stab' then
        local maxP=getMaxPages()
        if love.keyboard.isDown('lshift','rshift') or key=='Stab' then
            page=(page-1+maxP)%maxP
        else
            page=(page+1)%maxP
        end
        timer2=0
    elseif key=='t' then
        if SETTING.allowTAS and not (GAME.result or GAME.replaying) then
            GAME.tasUsed=true
            SFX.play('ren_mega')
            SFX.play('clear_3')
            SYSFX.newShade(1.2,555,200,620,380,.6,.6,.6)
        end
    elseif KEY_MAP.keyboard[key]==0 then
        scene.keyDown('r')
    else
        return true
    end
end

function scene.touchDown(x,y)
    -- Clickable Tab Bar at top of right frame: x=560..1180, y=205..245
    if y>=205 and y<=245 and x>=560 and x<=1180 then
        local maxP=getMaxPages()
        if maxP==3 then
            if x<=760 and page~=0 then page=0 timer2=0 SFX.play('click') return
            elseif x>760 and x<=970 and page~=1 then page=1 timer2=0 SFX.play('click') return
            elseif x>970 and page~=2 then page=2 timer2=0 SFX.play('click') return
            end
        else
            if x<=870 and page~=0 then page=0 timer2=0 SFX.play('click') return
            elseif x>870 and page~=1 then page=1 timer2=0 SFX.play('click') return
            end
        end
    end
    if 535<x and x<1195 and 245<y and y<580 then
        radarOrgTouchPos={x,y}
    end
end

function scene.touchUp(x1,y1)
    if not (535<x1 and x1<1195 and 245<y1 and y1<580) or not radarOrgTouchPos then return end
    local x=radarOrgTouchPos[1]
    if abs(x1-x)<50 then return end
    scene.keyDown(x1-x>=50 and 'tab' or 'Stab')
    radarOrgTouchPos=nil
end
scene.mouseUp=scene.touchUp
scene.mouseDown=scene.touchDown

function scene.gamepadDown(key)
    if key=='back' then
        scene.keyDown('escape')
    elseif KEY_MAP.joystick[key]==0 then
        scene.keyDown('r')
    end
end

function scene.update(dt)
    if not (GAME.result or GAME.replaying) then
        GAME.pauseTime=GAME.pauseTime+dt
    end
    timer1=min(timer1+dt*60*.02,1)
    timer2=min(timer2+dt*60*.04,1)
end

local hexList={1,0,.5,1.732*.5,-.5,1.732*.5}
for i=1,6 do hexList[i]=hexList[i]*150 end
local textPos={90,131,-90,131,-200,-25,-90,-181,90,-181,200,-25}
local dataPos={90,143,-90,143,-200,-13,-90,-169,90,-169,200,-13}
local tasText=GC.newText(getFont(100),"TAS")

function scene.draw()
    if timer1<1 or GAME.result then
        SCN.scenes.game.draw()
    end

    -- Dark obsidian glass backdrop with subtle vignette
    local bgAlpha = timer1 * (GAME.result and 0.85 or 0.90)
    GC.replaceTransform(SCR.origin)
    GC.setColor(0.02, 0.04, 0.08, bgAlpha)
    GC.rectangle('fill',0,0,SCR.w,SCR.h)
    GC.replaceTransform(SCR.xOy)

    local res=GAME.result
    local isCustom=isCustomGame()
    local hasObj=hasObjectives()

    -- Result Header / Status Banner (TETR.IO / osu! hybrid glowing pill badge)
    local headerY=70-10*(5-timer1*5)^1.5
    local pulse=0.85+0.15*sin(TIME()*5)
    if not res then
        -- Sleek PAUSED glowing pill
        local pw,ph=260,52
        local px=640-pw/2
        local py=headerY-ph/2
        GC.setColor(0.04,0.07,0.15,timer1*0.90)
        GC.rectangle('fill',px,py,pw,ph,10)
        GC.setColor(0.25,0.65,1.0,timer1*0.85)
        GC.setLineWidth(1.6)
        GC.rectangle('line',px,py,pw,ph,10)
        GC.setColor(1,1,1,timer1*0.08)
        GC.rectangle('fill',px+2,py+2,pw-4,ph*0.38,8)

        GC.setColor(1,1,1,timer1)
        mDraw(TEXTOBJ.pause,640,headerY)
    elseif res=='win' or res=='gamewin' or res=='finish' then
        -- Glowing gold & lime victory banner
        local pw,ph=420,56
        local px=640-pw/2
        local py=headerY-ph/2
        GC.setColor(0.04,0.14,0.09,timer1*0.92)
        GC.rectangle('fill',px,py,pw,ph,12)
        GC.setColor(0.25*pulse,0.95*pulse,0.55*pulse,timer1)
        GC.setLineWidth(2)
        GC.rectangle('line',px,py,pw,ph,12)
        GC.setColor(0.25,0.95,0.55,timer1*0.18)
        GC.rectangle('fill',px-4,py-4,pw+8,ph+8,14)

        FONT.set(44)
        if hasMissions() and (not PLAYERS[1] or PLAYERS[1].curMission==false) then
            GC.setColor(0,0,0,timer1*0.8)
            GC.mStr("ALL MISSIONS CLEARED!",641,headerY-21)
            GC.setColor(1.0,0.88,0.25,timer1)
            GC.mStr("ALL MISSIONS CLEARED!",640,headerY-22)
        elseif hasPuzzle() and (not PLAYERS[1] or not PLAYERS[1].modeData or PLAYERS[1].modeData.finished==#FIELD) then
            GC.setColor(0,0,0,timer1*0.8)
            GC.mStr("PUZZLE COMPLETED!",641,headerY-21)
            GC.setColor(0.35,1.0,0.65,timer1)
            GC.mStr("PUZZLE COMPLETED!",640,headerY-22)
        else
            GC.setColor(1.0,0.88,0.25,timer1*pulse)
            mDraw(TEXTOBJ.gamewin or TEXTOBJ.win,640,headerY)
        end
    elseif res=='gameover' or res=='lose' then
        -- Glowing crimson defeat banner
        local pw,ph=380,56
        local px=640-pw/2
        local py=headerY-ph/2
        GC.setColor(0.16,0.04,0.07,timer1*0.92)
        GC.rectangle('fill',px,py,pw,ph,12)
        GC.setColor(1.0*pulse,0.28*pulse,0.35*pulse,timer1)
        GC.setLineWidth(2)
        GC.rectangle('line',px,py,pw,ph,12)
        GC.setColor(1.0,0.25,0.35,timer1*0.16)
        GC.rectangle('fill',px-4,py-4,pw+8,ph+8,14)

        FONT.set(44)
        if hasMissions() then
            GC.setColor(0,0,0,timer1*0.8)
            GC.mStr("MISSION FAILED",641,headerY-21)
            GC.setColor(1.0,0.35,0.40,timer1)
            GC.mStr("MISSION FAILED",640,headerY-22)
        elseif hasPuzzle() then
            GC.setColor(0,0,0,timer1*0.8)
            GC.mStr("PUZZLE FAILED",641,headerY-21)
            GC.setColor(1.0,0.35,0.40,timer1)
            GC.mStr("PUZZLE FAILED",640,headerY-22)
        else
            GC.setColor(1.0,0.32,0.38,timer1)
            mDraw(TEXTOBJ.gameover or TEXTOBJ.lose,640,headerY)
        end
    elseif res=='torikan' then
        local pw,ph=360,56
        local px=640-pw/2
        local py=headerY-ph/2
        GC.setColor(0.18,0.09,0.03,timer1*0.92)
        GC.rectangle('fill',px,py,pw,ph,12)
        GC.setColor(1.0,0.65,0.20,timer1)
        GC.setLineWidth(2)
        GC.rectangle('line',px,py,pw,ph,12)
        FONT.set(40)
        GC.setColor(1,0.70,0.25,timer1)
        GC.mStr("TIME EXPIRED",640,headerY-20)
    else
        GC.setColor(0.97,0.97,0.97,timer1)
        if TEXTOBJ[res] then mDraw(TEXTOBJ[res],640,headerY) else GC.mStr(tostring(res):upper(),640,headerY-30) end
    end

    -- Mode Info & Custom Play Badge
    local modeW=TEXTOBJ.modeName:getWidth()
    local pW=modeW+32
    local pX=745-modeW-16
    GC.setColor(0.04,0.07,0.15,timer1*0.85)
    GC.rectangle('fill',pX,137,pW,36,8)
    GC.setColor(0.25,0.55,0.95,timer1*0.65)
    GC.setLineWidth(1.2)
    GC.rectangle('line',pX,137,pW,36,8)
    GC.setColor(1,1,1,timer1*0.95)
    GC.draw(TEXTOBJ.modeName,745-modeW,143)

    if isCustom then
        GC.push('transform')
        GC.translate(760,140)
        GC.setColor(0.04,0.07,0.15,timer1*0.90)
        GC.rectangle('fill',0,0,265,30,6)
        GC.setLineWidth(1.5)
        GC.setColor(.3,.9,.7,timer1*.85)
        GC.rectangle('line',0,0,265,30,6)
        FONT.set(16)
        GC.setColor(.4,1,.8,timer1)
        GC.mStr("CUSTOM PLAY • LOCAL ONLY",132,6)
        GC.pop()
    end

    -- Level rank
    if RANK_CHARS[GAME.rank] then
        GC.push('transform')
        GC.translate(1050,5)
        FONT.set(80)
        GC.setColor(0,0,0,timer1*.7)
        GC.print(RANK_CHARS[GAME.rank],-5,-4,nil,1.5)
        local L=RANK_COLORS[GAME.rank]
        GC.setColor(L[1],L[2],L[3],timer1)
        GC.print(RANK_CHARS[GAME.rank],0,0,nil,1.5)
        GC.pop()
    end

    if GAME.tasUsed then
        GC.setColor(.97,.97,.97,timer1*.08)
        mDraw(tasText,870,395,.3,2.6)
    end

    -- Right Info Frame
    if PLAYERS[1] then
        GC.push('transform')
        GC.translate(560,205)
        GC.setLineWidth(2)

        -- Pause info outside bottom
        FONT.set(22)
        if GAME.pauseCount>0 then
            GC.setColor(0.05,0.08,0.16,timer1*0.85)
            GC.rectangle('fill',-5,390,620,36,8)
            GC.setColor(1.0,0.75,0.25,timer1*0.75)
            GC.setLineWidth(1.2)
            GC.rectangle('line',-5,390,620,36,8)
            GC.setColor(1.0,0.85,0.40,timer1)
            GC.mStr(("%s: [%d]  •  %.2fs"):format(text.pauseCount,GAME.pauseCount,GAME.pauseTime),305,394)
        end

        -- Main Container Frame (Obsidian glass with glowing neon border)
        GC.setColor(0.03,0.06,0.14,timer2*0.92)
        GC.rectangle('fill',-5,-5,620,380,10)
        GC.setColor(0.20,0.55,0.95,timer2*0.85)
        GC.setLineWidth(1.8)
        GC.rectangle('line',-5,-5,620,380,10)
        GC.setColor(1,1,1,timer2*0.05)
        GC.rectangle('fill',-3,-3,616,44,8)

        -- Top Navigation Tabs
        local maxP=getMaxPages()
        local tabW=maxP==3 and 196 or 298
        local tabNames=maxP==3 and {"🎯 Objectives","📊 Statistics","⚡ Radar"} or {"📊 Statistics","⚡ Radar"}
        FONT.set(16)
        for i=0,maxP-1 do
            local tx=5+i*(tabW+6)
            local isActive=page==i
            if isActive then
                GC.setColor(0.08,0.18,0.36,timer2*0.95)
                GC.rectangle('fill',tx,6,tabW,30,6)
                GC.setColor(0.30,0.70,1.0,timer2)
                GC.setLineWidth(1.4)
                GC.rectangle('line',tx,6,tabW,30,6)
                GC.setColor(0.40,0.90,1.0,timer2)
                GC.rectangle('fill',tx+8,33,tabW-16,3,2)
                GC.setColor(1,1,1,timer2)
            else
                GC.setColor(0.04,0.07,0.14,timer2*0.65)
                GC.rectangle('fill',tx,6,tabW,30,6)
                GC.setColor(0.22,0.32,0.50,timer2*0.45)
                GC.setLineWidth(1)
                GC.rectangle('line',tx,6,tabW,30,6)
                GC.setColor(0.65,0.75,0.88,timer2*0.75)
            end
            GC.mStr(tabNames[i+1],tx+tabW*0.5,12)
        end

        -- Page 0 (Objectives / Custom Play Dashboard)
        if hasObj and page==0 then
            local P1=PLAYERS[1]
            local curY=46

            if hasMissions() then
                local mList=GAME.modeEnv.mission
                local mTotal=#mList
                local mCleared=(P1.curMission==false or res=='win' or res=='gamewin' or res=='finish') and mTotal or max(0,(P1.curMission or 1)-1)
                local pct=floor(mCleared/mTotal*100)

                -- Progress Bar
                GC.setColor(0.04,0.07,0.14,0.85)
                GC.rectangle('fill',5,curY,600,24,6)
                local barCol=mCleared==mTotal and {0.25,0.95,0.55} or {0.25,0.65,1.0}
                if mCleared>0 then
                    GC.setColor(barCol[1],barCol[2],barCol[3],0.85)
                    GC.rectangle('fill',5,curY,floor(600*(mCleared/mTotal)),24,6)
                end
                GC.setLineWidth(1.2)
                GC.setColor(barCol[1],barCol[2],barCol[3],0.7)
                GC.rectangle('line',5,curY,600,24,6)
                FONT.set(15)
                GC.setColor(0,0,0,timer2*0.8)
                GC.mStr(("Missions Cleared: %d / %d  (%d%%)"):format(mCleared,mTotal,pct),306,curY+5)
                GC.setColor(1,1,1,timer2)
                GC.mStr(("Missions Cleared: %d / %d  (%d%%)"):format(mCleared,mTotal,pct),305,curY+4)
                curY=curY+32

                -- Mission Checklist
                FONT.set(15)
                local showMax=min(mTotal,5)
                for i=1,showMax do
                    local mCode=mList[i]
                    local mName=getMissionName(mCode)
                    local mTag=ENUM_MISSION[mCode] or tostring(mCode)
                    local isDone=i<=mCleared
                    local isCur=i==mCleared+1

                    GC.setLineWidth(1)
                    if isDone then
                        GC.setColor(0.05,0.18,0.10,timer2*0.8)
                        GC.rectangle('fill',5,curY,600,24,5)
                        GC.setColor(0.25,0.90,0.50,timer2*0.6)
                        GC.rectangle('line',5,curY,600,24,5)
                        GC.setColor(0.35,1.0,0.55,timer2)
                        GC.print("  [✓]  #"..i.."  "..mTag.."  —  "..mName,10,curY+3)
                    elseif isCur then
                        if res=='lose' or res=='gameover' then
                            GC.setColor(0.22,0.06,0.08,timer2*0.85)
                            GC.rectangle('fill',5,curY,600,24,5)
                            GC.setColor(1.0,0.30,0.35,timer2*0.8)
                            GC.rectangle('line',5,curY,600,24,5)
                            GC.setColor(1.0,0.40,0.45,timer2)
                            GC.print("  [✗]  #"..i.."  "..mTag.."  —  "..mName.."  (FAILED)",10,curY+3)
                        else
                            GC.setColor(0.20,0.16,0.04,timer2*0.85)
                            GC.rectangle('fill',5,curY,600,24,5)
                            GC.setColor(1.0,0.82,0.25,timer2*0.8)
                            GC.rectangle('line',5,curY,600,24,5)
                            GC.setColor(1.0,0.88,0.35,timer2)
                            GC.print("  [►]  #"..i.."  "..mTag.."  —  "..mName.."  (CURRENT)",10,curY+3)
                        end
                    else
                        GC.setColor(0.04,0.07,0.14,timer2*0.5)
                        GC.rectangle('fill',5,curY,600,24,5)
                        GC.setColor(0.25,0.35,0.50,timer2*0.4)
                        GC.rectangle('line',5,curY,600,24,5)
                        GC.setColor(0.65,0.72,0.82,timer2*0.8)
                        GC.print("  [ ]  #"..i.."  "..mTag.."  —  "..mName,10,curY+3)
                    end
                    curY=curY+26
                end
                if mTotal>5 then
                    FONT.set(13)
                    GC.setColor(0.60,0.75,0.90,timer2*0.8)
                    GC.mStr(("... and %d more mission%s"):format(mTotal-5,mTotal>6 and "s" or ""),305,curY+2)
                    curY=curY+20
                end
            elseif hasPuzzle() then
                local pTotal=#FIELD
                local pSolved=(res=='win' or res=='finish') and pTotal or (P1.modeData and P1.modeData.finished or 0)
                local pct=floor(pSolved/pTotal*100)

                -- Progress Bar
                GC.setColor(0.04,0.07,0.14,0.85)
                GC.rectangle('fill',5,curY,600,26,6)
                local barCol=pSolved==pTotal and {0.25,0.95,0.55} or {0.25,0.65,1.0}
                if pSolved>0 then
                    GC.setColor(barCol[1],barCol[2],barCol[3],0.85)
                    GC.rectangle('fill',5,curY,floor(600*(pSolved/pTotal)),26,6)
                end
                GC.setLineWidth(1.2)
                GC.setColor(barCol[1],barCol[2],barCol[3],0.7)
                GC.rectangle('line',5,curY,600,26,6)
                FONT.set(16)
                GC.setColor(1,1,1,timer2)
                GC.mStr(("Puzzles Solved: %d / %d  (%d%%)"):format(pSolved,pTotal,pct),305,curY+4)
                curY=curY+42

                -- Puzzle Detail Box
                GC.setColor(0.04,0.07,0.15,timer2*0.85)
                GC.rectangle('fill',5,curY,600,90,8)
                GC.setColor(0.25,0.55,0.95,timer2*0.65)
                GC.setLineWidth(1.2)
                GC.rectangle('line',5,curY,600,90,8)
                FONT.set(18)
                if pSolved==pTotal then
                    GC.setColor(0.35,1.0,0.55,timer2)
                    GC.mStr("★ All Puzzle Challenges Completed!",305,curY+15)
                elseif res=='lose' or res=='gameover' then
                    GC.setColor(1.0,0.35,0.40,timer2)
                    GC.mStr(("Stopped on Puzzle #%d of %d"):format(pSolved+1,pTotal),305,curY+15)
                else
                    GC.setColor(0.40,0.85,1.0,timer2)
                    GC.mStr(("Current Puzzle: #%d of %d"):format(pSolved+1,pTotal),305,curY+15)
                end
                FONT.set(15)
                GC.setColor(0.85,0.90,1.0,timer2*0.85)
                GC.mStr(("Pieces: %d   •   Time: %.2fs   •   PPS: %.2f"):format(P1.stat.piece,P1.stat.time,P1.stat.piece/max(P1.stat.time,0.001)),305,curY+52)
                curY=curY+102
            end

            -- AI Duel Outcome Card
            if hasAIOpponent() then
                local aiName=GAME.modeEnv.opponent
                GC.setColor(0.05,0.08,0.16,timer2*0.90)
                GC.rectangle('fill',5,curY,600,56,8)
                GC.setLineWidth(1.4)
                GC.setColor(0.60,0.40,0.95,timer2*0.75)
                GC.rectangle('line',5,curY,600,56,8)
                FONT.set(17)
                GC.setColor(0.85,0.75,1.0,timer2)
                GC.print("  DUEL: VS  "..aiName,12,curY+6)
                if res=='win' or res=='gamewin' or res=='finish' then
                    GC.setColor(0.35,1.0,0.55,timer2)
                    GC.printf("VICTORIOUS  ✓",350,curY+6,240,'right')
                elseif res=='lose' or res=='gameover' then
                    GC.setColor(1.0,0.35,0.40,timer2)
                    GC.printf("DEFEATED  ✗",350,curY+6,240,'right')
                else
                    GC.setColor(1.0,0.85,0.25,timer2)
                    GC.printf("IN PROGRESS  ►",350,curY+6,240,'right')
                end
                if PLAYERS[2] then
                    FONT.set(14)
                    local P2=PLAYERS[2]
                    local t=max(P1.stat.time,0.001)
                    GC.setColor(0.82,0.88,0.98,timer2*0.85)
                    GC.print(("  P1: %.1f LPM / %.1f APM   vs   AI: %.1f LPM / %.1f APM"):format(
                        P1.stat.row/t*60,P1.stat.atk/t*60,
                        P2.stat.row/t*60,P2.stat.atk/t*60
                    ),12,curY+32)
                end
                curY=curY+62
            end

            -- Local Play Footer Notice
            if isCustom then
                FONT.set(13)
                GC.setColor(0.50,0.75,0.90,timer2*0.75)
                GC.mStr("Local Custom Mode: Scores and stats are saved locally (No network submission)",305,355)
            end

        -- Statistics Page (TETR.IO / osu! alternating dark glass cards)
        elseif (hasObj and page==1) or (not hasObj and page==0) then
            GC.push('transform')
            GC.translate(0,40)
            GC.scale(.82)
            GC.setLineWidth(2)

            _=form
            FONT.set(26)
            for i=1,10 do
                local rowY=38*(i-1)
                if i%2==1 then
                    GC.setColor(0.06,0.11,0.22,timer2*0.45)
                else
                    GC.setColor(0.04,0.07,0.14,timer2*0.30)
                end
                GC.rectangle('fill',4,rowY,730,34,5)

                -- Left mini cyan accent strip
                GC.setColor(0.25,0.65,1.0,timer2*0.75)
                GC.rectangle('fill',8,rowY+8,3,18,1)

                -- Stat label
                GC.setColor(0.60,0.80,1.0,timer2*0.90)
                GC.print(text.pauseStat[i],18,rowY+3)

                -- Stat value with drop shadow
                GC.setColor(0,0,0,timer2*0.75)
                GC.printf(_[i],211,rowY+4,515,'right')
                GC.setColor(1,1,1,timer2)
                GC.printf(_[i],210,rowY+3,515,'right')
            end

            -- Finesse rank & trophy (osu! rank badge style)
            if rank then
                GC.setColor(0.06,0.10,0.20,timer2*0.85)
                GC.rectangle('fill',390,376,344,46,8)
                GC.setColor(0.30,0.65,1.0,timer2*0.75)
                GC.setLineWidth(1.4)
                GC.rectangle('line',390,376,344,46,8)

                FONT.set(38)
                GC.setColor(1,1,1,timer2)
                GC.print(rank,410,378)
                if trophy then
                    FONT.set(24)
                    GC.setColor(trophyColor[1],trophyColor[2],trophyColor[3],timer2*2-1)
                    GC.printf(trophy,450,386,270,'right')
                end
            end
            GC.pop()

        -- Radar Page (TETR.IO cyber radar with concentric grid & glowing polygon)
        elseif (hasObj and page==2) or (not hasObj and page==1) then
            GC.push('transform')
            GC.translate(305,210)

            -- Concentric Hexagon radar web guides
            GC.setLineWidth(1)
            for ring=1,4 do
                local rScale=ring/4
                GC.setColor(0.20,0.40,0.65,timer2*(ring==4 and 0.45 or 0.20))
                GC.regRoundPolygon('line',0,0,120*rScale,6,4)
            end
            -- Spokes
            GC.setColor(0.20,0.40,0.65,timer2*0.25)
            for i=1,6 do
                local a=(i-1)*math.pi/3
                GC.line(0,0,120*math.cos(a),120*math.sin(a))
            end

            -- Filled polygon
            GC.push('transform')
                GC.scale((3-2*timer2)*timer2)
                GC.setColor(chartColor[1],chartColor[2],chartColor[3],timer2*0.35)
                for i=1,9,2 do
                    GC.polygon('fill',0,0,val[i],val[i+1],val[i+2],val[i+3])
                end
                GC.polygon('fill',0,0,val[11],val[12],val[1],val[2])

                GC.setColor(chartColor[1],chartColor[2],chartColor[3],timer2)
                GC.setLineWidth(2)
                for i=1,9,2 do
                    GC.line(val[i],val[i+1],val[i+2],val[i+3])
                end
                GC.line(val[11],val[12],val[1],val[2])

                -- Pulsing vertex pips
                for i=1,6 do
                    local vx=val[2*i-1]
                    local vy=val[2*i]
                    GC.setColor(1,1,1,timer2*0.95)
                    GC.circle('fill',vx,vy,3.5)
                    GC.setColor(chartColor[1],chartColor[2],chartColor[3],timer2*0.60)
                    GC.circle('line',vx,vy,5.5)
                end
            GC.pop()

            -- Texts
            local C
            _=TIME()%MATH.tau
            if _>3.142 then
                FONT.set(32)
                C,_=text.radar,textPos
                local a=-timer2*sin(_)
                for i=1,6 do
                    GC.setColor(0,0,0,a*0.8)
                    GC.mStr(C[i],_[2*i-1]+1,_[2*i]+1)
                    GC.setColor(0.40,0.85,1.0,a)
                    GC.mStr(C[i],_[2*i-1],_[2*i])
                end
            else
                FONT.set(19)
                C,_=radar,dataPos
                local a=timer2*sin(_)
                for i=1,6 do
                    GC.setColor(0,0,0,a*0.8)
                    GC.mStr(C[i],_[2*i-1]+1,_[2*i]+1)
                    GC.setColor(1,1,1,a)
                    GC.mStr(C[i],_[2*i-1],_[2*i])
                end
            end
            GC.pop()
        end

        GC.pop()
    end

    -- Mods
    GC.push('transform')
    GC.translate(131,600)
    GC.scale(.65)
    if modUsed then
        GC.setLineWidth(2)
        if scoreValid() then
            GC.setColor(0.20,0.55,0.95,timer1*0.8)
            GC.rectangle('line',-5,-5,500,150,8)
            GC.setColor(0.04,0.07,0.15,timer1*0.85)
            GC.rectangle('fill',-5,-5,500,150,8)
        else
            GC.setColor(1.0,0.25,0.35,timer1*0.8)
            GC.rectangle('line',-5,-5,500,150,8)
            GC.setColor(0.18,0.04,0.07,timer1*0.85)
            GC.rectangle('fill',-5,-5,500,150,8)
        end
        FONT.set(35)
        for number,M in next,MODOPT do
            if GAME.mod[number]>0 then
                _=M.color
                GC.setColor(_[1],_[2],_[3],timer1)
                GC.mStr(M.id,35+M.no%8*60,floor(M.no/8)*45)
            end
        end
    end
    GC.pop()
end

scene.widgetList={
    -- Paused menu (GAME.result == nil)
    WIDGET.newKey{name='resume',     x=290,y=240,w=300,h=70,color='G',code=pressKey'escape',hideF=function() return GAME.result end},
    WIDGET.newKey{name='restart',    x=290,y=330,w=300,h=70,color='lY',code=pressKey'r',hideF=function() return GAME.fromRepMenu or GAME.result end},
    WIDGET.newKey{name='setting',    x=290,y=420,w=300,h=70,color='lB',code=pressKey's',hideF=function() return GAME.fromRepMenu or GAME.result end},
    WIDGET.newKey{name='quit',       x=290,y=510,w=300,h=70,color='R',code=pressKey'q',hideF=function() return GAME.result end},
    WIDGET.newKey{name='tas',        x=290,y=600,w=240,h=50,color='lM',code=pressKey't',hideF=function() return not SETTING.allowTAS or GAME.tasUsed or GAME.result or GAME.replaying end},

    -- Game Over / Finished menu (GAME.result ~= nil)
    WIDGET.newKey{name='restart',    x=290,y=240,w=300,h=70,color='lY',code=pressKey'r',hideF=function() return GAME.fromRepMenu or not GAME.result end},
    WIDGET.newKey{name='edit_custom',x=290,y=330,w=300,h=70,color='lC',fText="Edit Setup (E)",code=pressKey'e',hideF=function() return not (GAME.result and isCustomGame() and not GAME.fromRepMenu) end},
    WIDGET.newKey{name='setting',    x=290,y=420,w=300,h=70,color='lB',code=pressKey's',hideF=function() return not GAME.result or GAME.fromRepMenu end},
    WIDGET.newKey{name='quit',       x=290,y=510,w=300,h=70,color='R',code=pressKey'q',hideF=function() return not GAME.result end},

    -- Navigation and replay widgets
    WIDGET.newKey{name='page_prev',  x=500,y=390,w=70,color='lB',code=pressKey'tab',
        fText=GC.DO{70,70,{'setLW',2},{'dRRPol',33,35,32,3,6,3.142},{'dRRPol',45,35,32,3,6,3.142}},
        fShade=GC.DO{70,70,{'setCL',1,1,1,.4},{'draw',GC.DO{70,70,{'setCL',1,1,1,1},{'fRRPol',33,35,32,3,6,3.142},{'fRRPol',45,35,32,3,6,3.142}}}},
        hideF=function() return not PLAYERS[1] end,
    },
    WIDGET.newKey{name='page_next',  x=1230,y=390,w=70,color='lB',code=pressKey'Stab',
        fText=GC.DO{70,70,{'setLW',2},{'dRRPol',37,35,32,3,6},{'dRRPol',25,35,32,3,6}},
        fShade=GC.DO{70,70,{'setCL',1,1,1,.4},{'draw',GC.DO{70,70,{'setCL',1,1,1,1},{'fRRPol',37,35,32,3,6},{'fRRPol',25,35,32,3,6}}}},
        hideF=function() return not PLAYERS[1] end,
    },
    WIDGET.newKey{name='replay',     x=865,y=165,w=200,h=40,color='lC',font=25,code=pressKey'p',hideF=function() return not (GAME.result or GAME.replaying) or GAME.initPlayerCount>1 end},
    WIDGET.newKey{name='save',       x=1075,y=165,w=200,h=40,color='lY',font=25,code=pressKey'o',hideF=function() return not (GAME.result or GAME.replaying) or GAME.initPlayerCount>1 or GAME.saved end},
}

return scene
