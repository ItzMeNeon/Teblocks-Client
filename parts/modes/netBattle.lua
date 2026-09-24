local yield=coroutine.yield
local function marginTask(P)
    local S=P.stat
    while true do yield() if S.frame>90*60 then P.strength=1;P:setFrameColor(1)break end end
    while true do yield() if S.frame>135*60 then P.strength=2;P:setFrameColor(2)break end end
    while true do yield() if S.frame>180*60 then P.strength=3;P:setFrameColor(3)break end end
    while true do yield() if S.frame>260*60 then P.strength=4;P:setFrameColor(4)break end end
end
return {
    env={
        bg={'synthwave','abyss','nexus','supernova','aurora','hyperdrive','cybercity'},
        bgm={'battle','beat5th','cruelty','distortion','echo','far','final','here','hope','memory','moonbeam','push','rectification','secret7th remix','secret7th','secret8th remix','secret8th','shift','shining terminal','storm','super7th','there','truth','vapor','waterfall'},
    },
    load=function()
        for k,v in next,NET.roomState.data do
            GAME.modeEnv[k]=v
        end
        GAME.modeEnv.allowMod=false
        GAME.modeEnv.task=marginTask

        if GAME.replaying then
            -- Deterministic setup for multiplayer replay mode:
            -- Boards are created in order with their exact recorded settings.
            TABLE.clear(NET.uid_sid)
            for i=1,#NETPLY.list do
                local p=NETPLY.list[i]
                NET.uid_sid[p.uid]=i
                PLY.newRemotePlayer(i,false,p)
                local curP=PLAYERS[i]
                if NET._replayReps then
                    if tostring(p.uid)==tostring(NET._replayReps.myUid) and NET._replayReps.myRep then
                        curP.username=NET._replayReps.myRep.player
                    elseif tostring(p.uid)==tostring(NET._replayReps.oppUid) and NET._replayReps.oppRep then
                        curP.username=NET._replayReps.oppRep.player
                    end
                end
            end
            if PLAYERS[1] then PLAYERS[1].sound=true end
            for i=1,#PLAYERS do
                local selfSid=PLAYERS[i].sid
                local otherSid=selfSid
                for j=1,#PLAYERS do if j~=i then otherSid=PLAYERS[j].sid break end end
                PLAYERS[i].sidMap={[1]=selfSid,[2]=otherSid}
            end
            return
        end

        local L=TABLE.shift(NETPLY.list,0)
        table.sort(L,function(a,b) return a.uid<b.uid end)
        math.randomseed(tonumber(GAME.seed) or 0)
        for i=#L,1,-1 do
            table.insert(NETPLY.list,table.remove(NETPLY.list,math.random(i)))
        end
        if #L>0 then
            TABLE.clear(NET.uid_sid)
            for i=1,#L do NET.uid_sid[L[i].uid]=i end
        end

        local N=1
        for i,p in next,L do
            if tostring(p.uid)==tostring(USER.uid) then
                local mode = tostring(p.playMode or 'Gamer'):lower()
                if mode=='gamer' then
                    PLY.newPlayer(1,false,p)
                    N=2
                end
                table.remove(L,i)
                break
            end
        end
    -- Iterate NETPLY for real players only.
    for _,p in next,L do
        local mode = tostring(p.playMode or 'Gamer'):lower()
        if mode=='gamer' then
            PLY.newRemotePlayer(N,false,p)
            N=N+1
        end
    end

    -- Recordings (and live opponent streams) are client-relative: each player
    -- records themselves as sid 1 and the opponent as sid 2. Map every net
    -- player's stream sids onto the canonical NET.uid_sid values so attacks
    -- route to the correct board in both live play and replays.
    for i=1,#PLAYERS do
        local selfSid=PLAYERS[i].sid
        local otherSid=selfSid
        for j=1,#PLAYERS do if j~=i then otherSid=PLAYERS[j].sid break end end
        PLAYERS[i].sidMap={[1]=selfSid,[2]=otherSid}
    end
end,
}
