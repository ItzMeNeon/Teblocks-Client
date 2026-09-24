local kb=love.keyboard

local curTab='all'
local allReplaysDisplay={}
local counts={all=0,ranked=0,casual=0,single=0}

local function _formatDuration(d)
    if not d or d==0 then return nil end
    local sec=d
    if d>120 then
        sec=math.floor(d/60)
    else
        sec=math.floor(d)
    end
    local mm=math.floor(sec/60)
    local ss=sec%60
    return ("%02d:%02d"):format(mm,ss)
end

local listBox=WIDGET.newListBox{name='list',x=50,y=75,w=1200,h=545,lineH=68,drawF=function(rep,id,ifSel)
    local w,h=1190,64

    -- Card background
    if ifSel then
        GC.setColor(.18,.36,.72,.55)
        GC.rectangle('fill',5,2,w,h,8)
        GC.setLineWidth(2)
        GC.setColor(.45,.75,1,.9)
        GC.rectangle('line',5,2,w,h,8)
    else
        GC.setColor(0,0,0,.35)
        GC.rectangle('fill',5,2,w,h,8)
        GC.setLineWidth(1)
        GC.setColor(1,1,1,.1)
        GC.rectangle('line',5,2,w,h,8)
    end

    -- ID index
    setFont(24)
    GC.setColor(.6,.65,.75)
    GC.print(id,20,18)

    -- Badges
    local badgeX=65
    if rep.isRanked then
        GC.setColor(1,.75,.1,.25)
        GC.rectangle('fill',badgeX,10,135,24,6)
        GC.setLineWidth(1.5)
        GC.setColor(1,.8,.2,.8)
        GC.rectangle('line',badgeX,10,135,24,6)
        setFont(14)
        GC.setColor(1,.9,.4)
        GC.print("⚡ RANKED 1v1",badgeX+10,13)
        badgeX=badgeX+145
    elseif rep.isCasual then
        GC.setColor(.1,.7,.9,.25)
        GC.rectangle('fill',badgeX,10,145,24,6)
        GC.setLineWidth(1.5)
        GC.setColor(.2,.85,1,.8)
        GC.rectangle('line',badgeX,10,145,24,6)
        setFont(14)
        GC.setColor(.4,.95,1)
        GC.print("👥 CASUAL ROOM",badgeX+10,13)
        badgeX=badgeX+155
    else
        local modeName=text.modes[rep.mode]
        local label=modeName and (modeName[1].." "..(modeName[2] or "")) or (rep.mode or "SOLO")
        local strWid=math.min(180,math.max(100,#label*9+20))
        GC.setColor(.6,.3,.9,.25)
        GC.rectangle('fill',badgeX,10,strWid,24,6)
        GC.setLineWidth(1.5)
        GC.setColor(.75,.45,1,.8)
        GC.rectangle('line',badgeX,10,strWid,24,6)
        setFont(14)
        GC.setColor(.85,.7,1)
        GC.print(label,badgeX+10,13)
        badgeX=badgeX+strWid+10
    end

    if rep.tasUsed then
        GC.setColor(.9,.2,.2,.3)
        GC.rectangle('fill',badgeX,10,48,24,6)
        GC.setColor(1,.3,.3)
        setFont(14)
        GC.print("TAS",badgeX+10,13)
        badgeX=badgeX+56
    end

    -- Match Title
    setFont(22)
    if rep.available then
        if rep.isRanked then
            GC.setColor(1,1,1)
            local p1=rep.player or "Player 1"
            GC.print(p1,badgeX+10,10)
            local p1W=love.graphics.getFont():getWidth(p1)
            setFont(16)
            GC.setColor(1,.75,.2)
            GC.print("VS",badgeX+18+p1W,14)
            setFont(22)
            GC.setColor(.9,.95,1)
            GC.print(rep.opponent or "Player 2",badgeX+46+p1W,10)
        elseif rep.isCasual then
            GC.setColor(1,1,1)
            GC.print(rep.title or (rep.player.." in "..(rep.roomName or "Room")),badgeX+10,10)
        else
            GC.setColor(.95,.95,1)
            local pName=(rep.player and rep.player~="Local Player") and rep.player or "Solo Player"
            GC.print(pName,badgeX+10,10)
        end
    else
        GC.setColor(.6,.6,.6)
        GC.print(rep.fileName or "Broken replay",badgeX+10,10)
    end

    -- Subtitle Info Line: Date, Duration, Seed, Version
    setFont(15)
    local subX=65
    GC.setColor(.7,.75,.8)
    if rep.date and #rep.date>0 then
        GC.print("📅 "..rep.date,subX,39)
        subX=subX+180
    end
    local dur=_formatDuration(rep.duration)
    if dur then
        GC.setColor(1,.85,.3)
        GC.print("⏱️ "..dur,subX,39)
        subX=subX+90
    end
    if rep.seed then
        GC.setColor(.55,.7,.85)
        local seedStr=tostring(rep.seed)
        if #seedStr>10 then seedStr=seedStr:sub(1,10).."..." end
        GC.print("🎲 Seed: "..seedStr,subX,39)
        subX=subX+160
    end
    if rep.version then
        GC.setColor(.5,.6,.7)
        GC.print("Ver: "..rep.version,subX,39)
    end

    -- Right side badges: Result & Score
    if rep.result then
        if rep.result=='win' then
            GC.setColor(.15,.75,.3,.25)
            GC.rectangle('fill',1080,16,95,32,6)
            GC.setLineWidth(1.5)
            GC.setColor(.25,.9,.4,.9)
            GC.rectangle('line',1080,16,95,32,6)
            setFont(16)
            GC.setColor(.4,1,.5)
            GC.print("WIN 🏆",1095,22)
        elseif rep.result=='loss' then
            GC.setColor(.8,.2,.2,.2)
            GC.rectangle('fill',1090,16,85,32,6)
            GC.setLineWidth(1.5)
            GC.setColor(1,.3,.3,.7)
            GC.rectangle('line',1090,16,85,32,6)
            setFont(16)
            GC.setColor(1,.4,.4)
            GC.print("LOSS",1112,22)
        end
    end
end}

local scene={}
local mods={}

-- Ranked net replays are 1v1 and need both players' recordings.
local function _playRankedRep(rep)
    local fileName=type(rep)=='string' and rep or rep.fileName
    local oppFile=type(rep)=='table' and rep.partnerFile
    local myUid=type(rep)=='table' and rep.myUid
    local oppUid=type(rep)=='table' and rep.oppUid

    if not oppFile then
        local m=fileName:match("replay/ranked_(.+)%.rep$") or fileName:match("ranked_(.+)%.rep$")
        if not m then
            MES.new('error',"Invalid ranked replay file")
            LOG("ranked replay: bad filename "..tostring(fileName))
            return
        end
        local matchId,myParsed=m:match("(.+)_(.+)$")
        if not matchId or not myParsed then
            MES.new('error',"Invalid ranked replay file")
            return
        end
        myUid=myParsed
        local escMatch=matchId:gsub("%-","%%-")
        for _,f in next,love.filesystem.getDirectoryItems('replay') do
            local om=f:match("^ranked_"..escMatch.."_(.+)%.rep$")
            if om and ("replay/"..f)~=fileName and f~=fileName then
                oppFile="replay/"..f
                oppUid=om
                break
            end
        end
    end

    local myRep=DATA.parseReplay(fileName,true)
    if not (myRep and myRep.available) then
        MES.new('error',"Replay data corrupted")
        LOG("ranked replay: parse failed for "..tostring(fileName))
        return
    end

    local oppRep
    if oppFile then
        oppRep=DATA.parseReplay(oppFile,true)
    end
    if not (oppRep and oppRep.available) then
        oppRep={data="",seed=myRep.seed,setting=myRep.setting,player="Opponent"}
        oppUid=oppUid or "opp"
    end
    NET.startRankedReplay(myRep,oppRep,myUid,oppUid)
end
scene.playRankedRep=_playRankedRep

local function _playRep(rep)
    if not rep then return end
    if not rep.available then
        MES.new('error',text.replayBroken)
        return
    end

    if rep.isRanked then
        _playRankedRep(rep)
    elseif rep.isCasual then
        local fullRep=DATA.parseReplay(rep.fileName,true)
        if not fullRep or not fullRep.available then
            MES.new('error',text.replayBroken)
            return
        end
        if fullRep.oppStream and #fullRep.oppStream>0 then
            local oppRep={
                data=fullRep.oppStream,
                seed=fullRep.seed,
                setting=fullRep.setting,
                player=fullRep.opponent or "Opponent"
            }
            NET.startRankedReplay(fullRep,oppRep,USER.uid,fullRep.opponentId or 'opp')
        else
            MES.new('error',"Casual replay missing opponent stream")
        end
    elseif rep.mode=='netBattle' then
        _playRankedRep(rep)
    elseif MODES[rep.mode] or FILE.isSafe('parts/modes/'..rep.mode) then
        local fullRep=DATA.parseReplay(rep.fileName,true)
        if not fullRep or not fullRep.available then
            MES.new('error',text.replayBroken)
            return
        end
        NET.startSoloReplay(fullRep)
    else
        MES.new('error',("No mode id: [%s]"):format(rep.mode))
    end
end

local function _buildDisplayList()
    local displayList={}
    local rankedGroups={}
    local cAll=0
    local cRanked=0
    local cCasual=0
    local cSingle=0

    for i=1,#REPLAY do
        local rep=REPLAY[i]
        local fn=rep.fileName or ""
        local rankedMatchId=fn:match("ranked_([^_]+)_")
        if rankedMatchId then
            if not rankedGroups[rankedMatchId] then rankedGroups[rankedMatchId]={} end
            table.insert(rankedGroups[rankedMatchId],rep)
        elseif rep.netType=='casual' or fn:match("casual_") then
            local item=TABLE.copy(rep)
            item.isCasual=true
            item.category='casual'
            table.insert(displayList,item)
            cCasual=cCasual+1
            cAll=cAll+1
        else
            local item=TABLE.copy(rep)
            item.isSingle=true
            item.category='single'
            table.insert(displayList,item)
            cSingle=cSingle+1
            cAll=cAll+1
        end
    end

    -- Pair ranked replays
    for matchId,list in pairs(rankedGroups) do
        if #list>=2 then
            local r1=list[1]
            local r2=list[2]
            local _,u1=(r1.fileName or ""):match("ranked_(.+)_(.+)%.rep$")
            local _,u2=(r2.fileName or ""):match("ranked_(.+)_(.+)%.rep$")
            local myRep,oppRep=r1,r2
            local myUid,oppUid=u1,u2
            if u2==USER.uid or r2.player==USERS.getUsername(USER.uid) then
                myRep,oppRep=r2,r1
                myUid,oppUid=u2,u1
            end

            local paired={
                isRanked=true,
                category='ranked',
                matchId=matchId,
                fileName=myRep.fileName,
                partnerFile=oppRep.fileName,
                myUid=myUid,
                oppUid=oppUid,
                player=myRep.player or "Player 1",
                opponent=oppRep.player or "Player 2",
                title=(myRep.player or "Player 1").."  vs  "..(oppRep.player or "Player 2"),
                date=myRep.date or oppRep.date,
                version=myRep.version or oppRep.version,
                seed=myRep.seed or oppRep.seed,
                setting=myRep.setting,
                result=myRep.result,
                myScore=myRep.myScore,
                oppScore=oppRep.oppScore,
                duration=myRep.duration or oppRep.duration,
                available=myRep.available and oppRep.available,
                tasUsed=myRep.tasUsed or oppRep.tasUsed,
                mode='netBattle',
            }
            table.insert(displayList,paired)
            cRanked=cRanked+1
            cAll=cAll+1
        else
            local r=list[1]
            local _,u=(r.fileName or ""):match("ranked_(.+)_(.+)%.rep$")
            local singleRanked={
                isRanked=true,
                category='ranked',
                matchId=matchId,
                fileName=r.fileName,
                myUid=u,
                player=r.player or "Player",
                title=(r.player or "Player").." (Ranked 1v1)",
                date=r.date,
                version=r.version,
                seed=r.seed,
                setting=r.setting,
                result=r.result,
                duration=r.duration,
                available=r.available,
                tasUsed=r.tasUsed,
                mode='netBattle',
            }
            table.insert(displayList,singleRanked)
            cRanked=cRanked+1
            cAll=cAll+1
        end
    end

    table.sort(displayList,function(a,b)
        local da=a.date or ""
        local db=b.date or ""
        if da~=db then return da>db end
        return (a.fileName or "")>(b.fileName or "")
    end)

    return displayList,{all=cAll,ranked=cRanked,casual=cCasual,single=cSingle}
end

local function _refreshList()
    local allList,c=_buildDisplayList()
    allReplaysDisplay=allList
    counts=c

    local filtered={}
    for i=1,#allList do
        local it=allList[i]
        if curTab=='all' or it.category==curTab then
            table.insert(filtered,it)
        end
    end
    listBox:setList(filtered)

    -- Update tab button labels with counts
    if scene.widgetList then
        local wAll=scene.widgetList[2]
        local wRanked=scene.widgetList[3]
        local wCasual=scene.widgetList[4]
        local wSingle=scene.widgetList[5]
        if wAll and wAll.setText then wAll:setText(("All (%d)"):format(counts.all)) end
        if wRanked and wRanked.setText then wRanked:setText(("⚡ Ranked (%d)"):format(counts.ranked)) end
        if wCasual and wCasual.setText then wCasual:setText(("👥 Casual (%d)"):format(counts.casual)) end
        if wSingle and wSingle.setText then wSingle:setText(("🎯 Solo (%d)"):format(counts.single)) end

        wAll.color=curTab=='all' and COLOR.lB or COLOR.D
        wRanked.color=curTab=='ranked' and COLOR.lY or COLOR.D
        wCasual.color=curTab=='casual' and COLOR.lC or COLOR.D
        wSingle.color=curTab=='single' and COLOR.lP or COLOR.D
    end
end

local function _updateButtonVisibility()
    local hide=listBox:getLen()==0
    if scene.widgetList then
        for i=7,9 do
            if scene.widgetList[i] then scene.widgetList[i].hide=hide end
        end
    end
end

function scene.enter()
    BG.set()
    _refreshList()
    _updateButtonVisibility()
    DiscordRPC.update("Finding replay")
end

function scene.leave()
    if #mods>0 then
        GAME.mod,mods=mods,{}
    end
end

function scene.keyDown(key)
    if key=='return' or key=='kpenter' then
        local rep=listBox:getSel()
        if rep then
            _playRep(rep)
        end
    elseif (key=='c' and kb.isDown('lctrl','rctrl')) or key=='cC' then
        local rep=listBox:getSel()
        if rep then
            if rep.available and rep.fileName then
                local repStr=loadFile(rep.fileName,'-string')
                if repStr then
                    CLIPBOARD.set(love.data.encode('string','base64',repStr))
                    MES.new('info',text.exportSuccess)
                else
                    MES.new('error',text.replayBroken)
                end
            else
                MES.new('error',text.replayBroken)
            end
        end
    elseif (key=='v' and kb.isDown('lctrl','rctrl')) or key=='cV' then
        local repStr=CLIPBOARD.get()
        local res,fileData=pcall(love.data.decode,'string','base64',repStr)
        if res then
            local fileName=os.date("replay/%Y_%m_%d_%H%M%S_import.rep")
            local rep=DATA.parseReplayData(fileName,fileData,false)
            if rep.available then
                if saveFile(fileData,fileName,'-d') then
                    table.insert(REPLAY,1,rep)
                    _refreshList()
                    _updateButtonVisibility()
                    MES.new('info',text.importSuccess)
                end
            else
                MES.new('error',text.dataCorrupted)
            end
        else
            MES.new('error',text.dataCorrupted)
        end
    elseif key=='delete' then
        local rep=listBox:getSel()
        if rep then
            if tryDelete() then
                love.filesystem.remove(rep.fileName)
                if rep.partnerFile then
                    love.filesystem.remove(rep.partnerFile)
                end
                for i=#REPLAY,1,-1 do
                    if REPLAY[i].fileName==rep.fileName or (rep.partnerFile and REPLAY[i].fileName==rep.partnerFile) then
                        table.remove(REPLAY,i)
                    end
                end
                _refreshList()
                _updateButtonVisibility()
                SFX.play('finesseError',.7)
            end
        end
    elseif key=='up' or key=='down' then
        listBox:arrowKey(key)
    else
        return true
    end
end

local function _setTab(tab)
    curTab=tab
    _refreshList()
    _updateButtonVisibility()
end

scene.widgetList={
    listBox,
    -- Filter tabs at top
    WIDGET.newButton{name='tabAll',    x=120,y=40,w=140,h=42,font=18,color='lB',fText="All",          code=function() _setTab('all') end},
    WIDGET.newButton{name='tabRanked', x=280,y=40,w=180,h=42,font=18,color='D', fText="⚡ Ranked",   code=function() _setTab('ranked') end},
    WIDGET.newButton{name='tabCasual', x=480,y=40,w=180,h=42,font=18,color='D', fText="👥 Casual",   code=function() _setTab('casual') end},
    WIDGET.newButton{name='tabSingle', x=680,y=40,w=180,h=42,font=18,color='D', fText="🎯 Solo",     code=function() _setTab('single') end},

    -- Bottom action buttons
    WIDGET.newButton{name='import',x=180, y=650,w=140,h=65,color='lB',code=pressKey'cV',font=45,fText=CHAR.icon.import},
    WIDGET.newButton{name='export',x=350, y=650,w=140,h=65,color='lR',code=pressKey'cC',font=45,fText=CHAR.icon.export},
    WIDGET.newButton{name='play',  x=640, y=650,w=170,h=65,color='lY',code=pressKey'return',font=55,fText=CHAR.icon.play},
    WIDGET.newButton{name='delete',x=860, y=650,w=80, h=65,color='lR',code=pressKey'delete',font=45,fText=CHAR.icon.trash},
    WIDGET.newButton{name='back',  x=1140,y=650,w=170,h=65,sound='back',font=55,fText=CHAR.icon.back,code=backScene},
}

return scene
