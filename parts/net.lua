local WS=WS
local ins=table.insert

local NET={
    uid=false,
    uid_sid={},
    storedStream=false,

    roomState={-- A copy of room structure on server
        info={
            name=false,
            type=false,
            version=false,
            description=false,
        },
        data={},
        count={
            Gamer=0,
            Spectator=0,
        },
        capacity=false,
        private=false,
        state='Standby',
    },

    spectate=false,-- If player is spectating
    seed=false,

    rankedResult=false,-- Summary of the last ranked match for the results scene

    matchFoundPending=false,
    matchFoundCountdown=0,
    matchFoundSeed=nil,
    matchFoundTime=nil,
    matchFoundOppId=nil,
    matchFoundMatchId=nil,

    matchmaking=false,
    searchTimer=0,

    shakeStr=0,
    shakeTime=0,

    roomAllReady=false,

    onlineCount="0",
    onlinePlayers={},-- List of online players (id, username, elo)
    ping=false,

    textBox=WIDGET.newTextBox{name='texts',x=20,y=110,w=980,h=500},
    inputBox=WIDGET.newInputBox{name='input',x=20,y=630,w=980,h=50,limit=256},
}

function NET.freshRoomAllReady()
    local playCount,readyCount=0,0
    for j=1,#NETPLY.list do
        if NETPLY.list[j].playMode=='Gamer' then playCount=playCount+1 end
        if NETPLY.list[j].readyMode=='Ready' then readyCount=readyCount+1 end
    end

    NET.roomAllReady=playCount>0 and playCount==readyCount

    if playCount>1 and playCount-readyCount==1 then
        local p=NETPLY.map[USER.uid]
        if p.playMode=='Gamer' and p.readyMode~='Ready' and TASK.lock('urgeReady',1) then
            SFX.play('warn_2',.5)
        end
    end
end

function NET.updateMatchFoundCountdown(dt)
    if not NET.matchFoundPending then return end
    if NET.matchFoundCountdown<=0 then return end

    NET.matchFoundCountdown=math.max(0,NET.matchFoundCountdown-dt)
    if NET.matchFoundCountdown<=0 then
        NET.matchFoundPending=false
        NET.matchFoundTime=nil
        TASK.lock('netPlaying')
        if NET.matchFoundSeed then
            NET.seed=NET.matchFoundSeed
        end
        NET.matchFoundSeed=nil
    end
end

--------------------------<NEW HTTP API>
local ignoreError={
    ["Techrater.PlayerStream.notAvailable"]=true,
    ["Techrater.PlayerManager.invalidAccessToken"]=true,
    ["Techrater.PlayerManager.invalidRefreshToken"]=true,
}
local availableErrorTextType={info=1,warn=1,error=1}
local function parseError(pathStr)
    if ignoreError[pathStr] then return end
    LOG(pathStr)
    if type(pathStr)~='string' then
        MES.new('error',"<"..tostring(pathStr)..">",5)
        return
    end

    -- Clean up raw HTTP status codes
    if pathStr:find("^HTTP[ .]%d%d%d") then
        local code = tonumber(pathStr:match("%d%d%d"))
        if code == 400 then
            pathStr = "Invalid request or incorrect credentials"
        elseif code == 401 then
            pathStr = "Incorrect username or password"
        elseif code == 403 then
            pathStr = "Please verify your account before logging in"
        elseif code == 404 then
            pathStr = "Requested resource not found"
        elseif code == 409 then
            pathStr = "Username or email is already registered"
        elseif code == 500 then
            pathStr = "Server error occurred, please try again"
        elseif code == 502 or code == 503 or code == 504 then
            pathStr = "Game server is currently unreachable"
        end
    end

    -- Check Techrater i18n tree
    if pathStr:find("^Techrater%.") then
        local mesPath=STRING.split(pathStr,'.')
        local curText=text.Techrater
        for i=2,#mesPath do
            if type(curText)~='table' then break end
            curText=curText[mesPath[i]]
        end
        if not curText then
            curText=text.Techrater[mesPath[#mesPath]]
        end

        if type(curText)=='table' then
            if availableErrorTextType[curText[1]] and type(curText[2])=='string' and type(curText[3])=='number' then
                MES.new(curText[1],curText[2],math.min(curText[3],5))
                return
            end
        elseif type(curText)=='string' and #curText>0 then
            MES.new('warn',curText,5)
            return
        end
    end

    -- Show clean message directly without bracket encapsulation
    MES.new('error',pathStr,5)
end
local function getMsg(request,timeout)
    timeout=timeout or 6.26
    HTTP(request)
    local totalTime=0
    while true do
        local msg=HTTP.pollMsg(request.pool)
        if msg then
            if type(msg.body)=='string' and #msg.body>0 then
                local ok,body=pcall(JSON._decode,msg.body)
                if ok and type(body)=='table' then
                    body.code=body.code or msg.code
                    if tostring(body.code):sub(1,1)~='2' then
                        local errMsg = body.message or body.error
                        if not errMsg and msg and msg.body then
                            errMsg = tostring(msg.body)
                        elseif not errMsg then
                            errMsg = "HTTP "..tostring(msg and msg.code or "?")
                        end
                        if not request.silentError then
                            parseError(errMsg)
                        end
                    end
                    return body
                end
                if msg.code and tostring(msg.code):sub(1,1)~='2' then
                    local errMsg = "HTTP "..tostring(msg.code)
                    local stripped=msg.body:gsub('^%s*<[^>]*>',''):gsub('</[^>]+>%s*',' ')
                    if #stripped>0 and stripped~=msg.body then
                        errMsg=errMsg..": "..stripped:sub(1,100)
                    end
                    if not request.silentError then
                        parseError(errMsg)
                    end
                    return {code=msg.code, message=errMsg}
                else
                    if not request.silentError then
                        MES.new('info',text.serverDown)
                    end
                    return
                end
            else
                if not request.silentError then
                    MES.new('info',text.serverDown)
                end
                return
            end
        else
            totalTime=totalTime+coroutine.yield()
            if totalTime>timeout then
                return
            end
        end
    end
end

function NET.login(auto)
    if not TASK.lock('login') then return end
    TASK.new(function()
        WAIT{
            quit=function()
                TASK.unlock('login')
                HTTP.deletePool('login')
            end,
            timeout=12.6,
        }

        local token = USER.aToken or USER.oToken
        if token then
            local res=getMsg({
                pool='login',
                url=AUTHHOST,
                path='/api/auth/check',
                headers={["x-access-token"]=token},
            },6.26)

            if res and res.code and math.floor(res.code/100)==2 then
                USER.uid=res.data.playerId
                if res.data.accessToken then
                    USER.aToken=res.data.accessToken
                    USER.oToken=res.data.accessToken
                end
                if res.data.username then
                    USERS.updateUsername(USER.uid,res.data.username)
                end
                saveUser()
                NET.ws_connect(true)
                NET.getUserInfo(USER.uid)
                local CARD=require'parts.userCard'
                CARD.reset()
                if not auto then-- Quit login menu
                    SCN.pop()
                end
                if auto and SCN.cur ~= 'main' then
                    SCN.go('lobby')
                end
                WAIT.interrupt()
                return
            end
        end
        if auto and SCN.cur ~= 'main' then
            SCN.go('lobby')
        end

        WAIT.interrupt()
    end)
end
function NET.loginWithPassword(username,password)
    if not TASK.lock('login') then return end
    TASK.new(function()
        WAIT{
            quit=function()
                TASK.unlock('login')
                HTTP.deletePool('loginPW')
            end,
            timeout=12.6,
        }

        local res=getMsg({
            pool='loginPW',
            url=AUTHHOST,
            path='/api/login',
            body={username=username,password=password},
            silentError=true,
        },6.26)

        if res and res.code and math.floor(res.code/100)==2 and res.data and res.data.token then
            USER.oToken=res.data.token
            USER.aToken=res.data.token
            if res.data.playerId then
                USER.uid=res.data.playerId
                if res.data.username then
                    USERS.updateUsername(USER.uid,res.data.username)
                end
            end
            saveUser()
            NET.ws_connect(true)
            NET.getUserInfo(USER.uid)
            local CARD=require'parts.userCard'
            CARD.reset()
            MES.new('check',"Logged in as "..(res.data.username or username))
            if SCN.cur == 'login' then
                SCN.go('main')
            end
            WAIT.interrupt()
            return
        elseif res then
            if res.code == 401 or res.error == 'invalid_credentials' or (res.message and res.message:lower():find('incorrect')) then
                MES.new('error', "Incorrect username or password", 5)
            elseif res.code == 403 or res.error == 'unverified' or (res.message and res.message:lower():find('verify')) then
                MES.new('warn', "Account is not verified! Please verify your account first.", 6)
                local AUTH = require 'parts.authModal'
                local uid = res.playerId or res.user_id or username
                AUTH.openVerify(uid, res.username or username)
            else
                local errMsg = res.message or res.error or 'Login failed'
                if errMsg:find("^HTTP[ .]400") then
                    errMsg = "Incorrect username or password"
                end
                MES.new('error', errMsg, 5)
            end
        else
            MES.new('error', "Cannot connect to game server. Retrying in background...", 5)
            NET.triggerReconnect()
        end

        WAIT.interrupt()
    end)
end

function NET.verifyAccount(userOrId, code, cb)
    TASK.new(function()
        local res = getMsg({
            pool = 'verifyAcc',
            url = AUTHHOST,
            path = '/api/auth/verify',
            body = {user_id = userOrId, code = code},
            silentError = true,
        }, 6.26)
        if res and (res.code == 200 or res.status == 'verified') then
            if cb then cb(true, "Account verified successfully!") end
        else
            local err = res and (res.message or res.error) or "Invalid or expired verification code"
            if cb then cb(false, err) end
        end
    end)
end

function NET.sendVerificationCode(userOrId, cb)
    TASK.new(function()
        local res = getMsg({
            pool = 'sendVerifyCode',
            url = AUTHHOST,
            path = '/api/auth/send-verification',
            body = {user_id = userOrId},
            silentError = true,
        }, 6.26)
        if res and (res.code == 200 or res.status == 'sent') then
            if cb then cb(true, "Verification code sent!") end
        else
            local err = res and (res.message or res.error) or "Failed to send code"
            if cb then cb(false, err) end
        end
    end)
end
function NET.getUserInfo(uid)
    TASK.new(function()
        local res=getMsg({
            pool='getInfo',
            url=AUTHHOST,
            path='/api/player/info?playerId='..uid,
        },6.26)

        if res and res.code==200 and type(res.data)=='table' then
            USERS.updateUserData(res.data)
            -- When this is our own profile, sync the competitive elo and rank
            -- so the lobby/card reflect the values persisted on the server
            -- (otherwise they reset to the defaults after a client restart).
            if uid==USER.uid then
                if type(res.data.elo)=='number' then STAT.elo=res.data.elo end
                if type(res.data.globalRank)=='number' then STAT.globalRank=res.data.globalRank end
            end
        end
    end)
end
function NET.getAvatar(uid)
    TASK.new(function()
        local res=getMsg({
            pool='getInfo',
            url=AUTHHOST,
            path='/api/player/avatar?playerId='..uid..'&size=128',
        },6.26)

        if res and res.code==200 and type(res.data)=='string' then
            USERS.updateAvatar(uid,res.data)
        end
    end)
end

local noticeLang={
    en='en_us',
    fr='en_us', -- fr_fr
    es='en_us', -- es_es
    id='en_us', -- id_id
    pt='en_us', -- pt_pt
    ru='en_us', -- ru_ru
    ja='en_us', -- ja_jp
    vi='en_us', -- vi_vn
    zh='zh_cn',
    zh_trad='zh_tw',
    zh_code='zh_cn',
}
function NET.launchNotice()
    TASK.new(function()
        local res=getMsg({
            pool='getNotice',
            url=AUTHHOST,
            path='/api/notice?language='..noticeLang[SETTING.locale]..'&lastCount=1',
        },6.26)

        if res and res.code==200 then
            local opt=res.data.contents[1]
            if opt then
                MES.new('info',opt.content,12.6)
            else
                MES.new('info',text.Techrater.NoticeManager.noticeNotFound)
            end
        end
    end)
end
function NET.getNotice(count)
    WAIT{timeout=6.26}
    TASK.new(function()
        local res=getMsg({
            pool='getNotice',
            url=AUTHHOST,
            path='/api/notice?language='..noticeLang[SETTING.locale]..'&lastCount='..(count or 5),
        },6.26)

        if res and res.code==200 then
            WAIT.interrupt()
            SCN.go('notice',nil,noticeLang[SETTING.locale],res.data.contents)
        end
    end)
end
--------------------------<NEW WS API>
local actMap={
    global_getOnlineCount= 1000,
    match_finish=          1100,
    match_ready=           1101,
    match_start=           1102,
    player_updateConf=     1200,
    player_finish=         1201,
    player_joinGroup=      1202,
    player_setReadyMode=   1203,
    player_setHost=        1204,
    player_setState=       1205,
    player_stream=         1206,
    player_setPlayMode=    1207,
    room_create=           1301,
    room_getData=          1302,
    room_setData=          1303,
    room_getInfo=          1304,
    room_setInfo=          1305,
    room_enter=            1306,
    room_kick=             1307,
    room_playerJoin=       1319,  -- S->C: a player joined mid-game
    room_playerLeave=      1320,  -- S->C: a player left mid-game
    room_leave=            1308,
    room_fetch=            1309,
    room_setPW=            1310,
    room_remove=           1311,
    online_getPlayers=      1312,
    online_playerJoin=      1313,
    online_playerLeave=     1314,
    player_updateElo=       1315,
    global_chat=            1316,
    match_join=             1400,
    match_leave=            1401,
    match_found=            1402,
    match_start_ranked=      1403,
    match_finish_ranked=     1404,
    match_cancel=            1405,
    match_uploadReplay=      1406,
    round_finish=            1407,
    -- Server-authoritative sim + rollback (plan Component 2/3)
    auth_snapshot=           1410, -- S->C: authoritative world snapshot
    input_ack=               1411, -- S->C: ack of last received input frame
    rollback_trigger=        1412, -- S->C: server detected divergence
    input_submit=            1413, -- C->S: client submits local input frame(s)
    input_hash=              1414, -- C->S: client local sim hash at frame F
    save_upload=            1500, -- C->S: upload cloud save
    save_download=          1501, -- C->S: request cloud save download
    } for k,v in next,actMap do actMap[v]=k end

local function wsSend(act,data)
    WS.send('game',JSON.encode{
        action=assert(act),
        data=data,
    })
end

local function _getFullName(uid)
    local name=USERS.getUsername(uid)
    if name and #name>0 then return name end
    return tostring(uid)
end

--Remove player when leave
local function _playerLeaveRoom(uid)
    if SCN.cur~='net_game' and SCN.cur~='net_rankedGame' then return end
    for i=1,#PLAYERS do if PLAYERS[i].uid==uid then table.remove(PLAYERS,i) break end end
    for i=1,#PLY_ALIVE do if PLY_ALIVE[i].uid==uid then table.remove(PLY_ALIVE,i) break end end
    if uid==USER.uid then
        GAME.playing=false
        if SCN.cur=='net_rankedGame' then
            SCN.go('net_ranked')
        else
            SCN.backTo('lobby')
        end
    else
        NETPLY.remove(uid)
    end
end

--Push stream data to players
function NET.pumpStream(d)
    if not d or d.playerId==USER.uid then return end
    for _,P in next,PLAYERS do
        if tostring(P.uid)==tostring(d.playerId) then
            local res,stream=pcall(love.data.decode,'string','base64',d.data)
            if res then
                DATA.pumpRecording(stream,P.stream)
            else
                MES.new('error',"Bad stream from ".._getFullName(P.uid),.1)
            end
            return
        end
    end
    -- Buffer early stream packets until players are spawned
    if not NET.storedStream then NET.storedStream={} end
    if #NET.storedStream < 120 then
        table.insert(NET.storedStream, d)
    end
end

-- Global
function NET.global_getOnlineCount()
    wsSend(actMap.global_getOnlineCount)
end

-- Global
function NET.global_chat(text)
    if not TASK.lock('chatLimit',1.26) then
        MES.new('warn',text.tooFrequent)
    elseif #text>0 then
        wsSend(actMap.global_chat,{message=text})
        return true
    end
end

-- Room
function NET.room_chat(msg,rid)
    if not TASK.lock('chatLimit',1.26) then
        MES.new('warn',text.tooFrequent)
    elseif #msg>0 then
        wsSend(1300,{
            message=msg,
            roomId=rid,-- Admin
        })
        return true
    end
end
function NET.room_create(data)
    if not TASK.lock('createRoom',10) then MES.new('warn',text.tooFrequent) return end
    if not NET.roomState then
        NET.roomState={
            info={name=false,type=false,version=false,description=false},
            data={},
            count={Gamer=0,Spectator=0},
            capacity=false,
            private=false,
            state='Standby',
        }
    end
    TABLE.coverR(data,NET.roomState)
    WAIT{timeout=12}
    wsSend(actMap.room_create,data)
end
function NET.room_getData(rid)
    wsSend(actMap.room_getData,{
        roomId=rid,-- Admin
    })
end
function NET.room_setData(data,rid)
    wsSend(actMap.room_setData,{
        data=data,
        roomId=rid,-- Admin
    })
end
function NET.room_getInfo(rid)
    wsSend(actMap.room_getInfo,{
        roomId=rid,-- Admin
    })
end
function NET.room_setInfo(info,rid)
    wsSend(actMap.room_setInfo,{
        info=info,
        roomId=rid,-- Admin
    })
end
function NET.room_enter(rid,password)
    if not TASK.lock('enterRoom',6) then return end
    SFX.play('reach',.6)
    wsSend(actMap.room_enter,{
        roomId=rid,
        password=password,
    })
end
function NET.room_kick(pid,rid)
    wsSend(actMap.room_kick,{
        playerId=pid,-- Host
        roomId=rid,-- Admin
    })
end

function NET.room_leave()
    wsSend(actMap.room_leave)
end
function NET.room_fetch()
    if not TASK.lock('fetchRoom',3) then return end
    wsSend(actMap.room_fetch,{
        pageIndex=0,
        pageSize=26,
    })
end
function NET.room_setPW(pw,rid)
    if not TASK.lock('setRoomPW',2) then return end
    wsSend(actMap.room_setPW,{
        password=pw,
        roomId=rid,-- Admin
    })
end
function NET.room_remove(rid)
    wsSend(actMap.room_remove,{
        roomId=rid-- Admin
    })
end

-- Player
function NET.player_updateConf()
    wsSend(actMap.player_updateConf,dumpBasicConfig())
end
function NET.player_finish(msg)
    wsSend(actMap.player_finish,msg)
end
function NET.player_joinGroup(gid)
    wsSend(actMap.player_joinGroup,gid)
end
function NET.player_setReady(isReady)
    wsSend(actMap.player_setReadyMode,isReady)
end
function NET.player_setHost(pid)
    wsSend(actMap.player_setHost,{
        playerId=pid,
        role='Admin',
    })
end
function NET.player_setState(state)-- not used
    wsSend(actMap.player_setState,state)
end
function NET.player_stream(stream)
    wsSend(actMap.player_stream,love.data.encode('string','base64',stream))
end
function NET.player_setPlayMode(mode)
    wsSend(actMap.player_setPlayMode,mode)
end
function NET.online_getPlayers()
    wsSend(actMap.online_getPlayers)
end
function NET.player_updateElo()
    wsSend(actMap.player_updateElo)
end

-- Server-authoritative sim (plan Component 3) — protocol layer.
--
-- The local player's inputs are pushed into NET._inputSubmitBuf by
-- Player:pressKey/releaseKey (ranked rooms only). net_game.lua flushes the
-- buffer to the server periodically via NET.flushInputs(); the server applies
-- them to its authoritative sim and replies with 1411 (inputAck). This slice
-- ships only the wire layer; snapshot/rollback consumption is a later step.
--
-- Buffer entry shape: {frame=integer, keyID=1..12, isRelease=boolean}.
NET._inputSubmitBuf={}
function NET._pushInput(frame,keyID,isRelease)
    if type(frame)~='number' or type(keyID)~='number' then return end
    if keyID<1 or keyID>12 then return end
    ins(NET._inputSubmitBuf,{frame=frame,keyID=keyID,isRelease=isRelease and true or false})
end
function NET.flushInputs()
    local buf=NET._inputSubmitBuf
    if #buf==0 then return end
    -- Send the whole batch in one frame; server coalesces by frameRun.
    wsSend(actMap.input_submit,{frames=buf})
    NET._inputSubmitBuf={}
end
function NET.submitInputs(frames)
    if type(frames)~='table' or #frames==0 then return end
    wsSend(actMap.input_submit,{frames=frames})
end

-- Rollback netcode control surface (plan Component 3). These are off by default
-- — the integration test in slice 4 sets _rollbackEnabled=true and feeds
-- confirmed inputs via NET._recordConfirmedInputs. Setting either has no effect
-- outside ranked rooms, since Rollback.step only runs the legacy loop unless
-- the flag is on.
-- Rollback netcode is now the default. The client predicts locally
-- (zero perceived input lag) and reconciles to server snapshots via
-- Rollback._reconcile in parts/player/rollback.lua. The server-side
-- authoritative sim (TEBLOCKS_SIM_AUTHORITATIVE=1) requires this — it
-- rejects ranked-queue joins from clients that have never submitted a
-- 1413 (handleMatchJoin in ws.go), so a client with rollback disabled
-- cannot play ranked matches when the server is in authoritative mode.
--
-- Rollback netcode is disabled in favor of lightweight deterministic stream relay.
-- This eliminates deep-copy GC pauses and frame drops while keeping full multiplayer compatibility.
NET._rollbackEnabled=false
function NET.setRollbackEnabled(b) NET._rollbackEnabled=b and true or false end
-- NET._confirmedInputs[uid] = list of {frame, keyID, isRelease} the server has
-- acked. Slice 4's resim loop drains these when rebuilding a frame.
NET._confirmedInputs={}
function NET._recordConfirmedInput(uid, frame, keyID, isRelease)
    if not NET._confirmedInputs[uid] then NET._confirmedInputs[uid]={} end
    ins(NET._confirmedInputs[uid], {frame=frame, keyID=keyID, isRelease=isRelease and true or false})
end

-- Ranked 1v1 matchmaking
function NET.ranked_join()
    if WS.status('game')=='dead' then NET.ws_connect() end
    wsSend(actMap.match_join)
end
function NET.ranked_leave()
    wsSend(actMap.match_leave)
end

-- Build the local player's .rep bytes (zlib-compressed metadata + recording)
-- from the in-memory GAME.rep. Returns the raw bytes string, or false.
local function _buildLocalRepBytes()
    if not GAME.rep or #GAME.rep==0 then return false end
    local metadata={
        date=os.date("%Y/%m/%d %H:%M:%S"),
        mode=GAME.curModeName,
        version=VERSION.string,
        player=USERS.getUsername(USER.uid),
        -- Store the exact seed string (NET.seed) rather than the numeric
        -- GAME.seed: a 64-bit match seed cannot survive JSON number round-trips
        -- as a double, and a lossy seed would make the replay's piece sequence
        -- diverge from the live match.
        seed=NET.seed,
        setting=GAME.setting,
        mod={},
        tasUsed=GAME.tasUsed,
    }
    local ok,content=pcall(love.data.compress,'string','zlib',
        JSON.encode(metadata).."\n"..DATA.dumpRecording(GAME.rep))
    if not ok or not content then return false end
    return content
end

-- Upload the local player's replay for a finished ranked match. The server
-- stores it under replays/<matchId>/<playerId>.rep so both participants' runs
-- live in the same match folder. Fire-and-forget (best effort).
function NET.uploadRankedReplay(matchId)
    if not matchId or not USER.uid then return end
    local content=_buildLocalRepBytes()
    if not content then return end
    TASK.new(function()
        wsSend(actMap.match_uploadReplay,{
            matchId=matchId,
            playerId=USER.uid,
            data=love.data.encode('string','base64',content),
        })
    end)
end

-- Save both players' replays locally (under replay/ranked_<matchId>_<uid>.rep)
-- so they appear in the replay list and can be watched later. The local file
-- is built from GAME.rep directly; the opponent's is fetched from the server.
function NET.saveRankedReplays(matchId,oppId)
    if not matchId or not USER.uid then return end
    TASK.new(function()
        local content=_buildLocalRepBytes()
        if content then
            love.filesystem.write(("replay/ranked_%s_%s.rep"):format(matchId,USER.uid),content)
        end
        if oppId then
            local oppRaw=_fetchRankedReplayRaw(matchId,oppId)
            if oppRaw then
                love.filesystem.write(("replay/ranked_%s_%s.rep"):format(matchId,oppId),oppRaw)
            end
        end
    end)
end

-- Fetch a stored ranked replay's raw bytes from the server. Returns the body
-- string (zlib-compressed .rep) or false on failure/timeout.
local function _fetchRankedReplayRaw(matchId,playerId)
    HTTP{
        pool='repDL',
        url=AUTHHOST,
        path=("/api/match/replay?matchId=%s&playerId=%s"):format(matchId,playerId),
        headers={['x-access-token']=USER.oToken},
    }
    local totalTime=0
    while true do
        local msg=HTTP.pollMsg('repDL')
        if msg then
            if type(msg.body)=='string' and #msg.body>0 then
                return msg.body
            end
            return false
        else
            totalTime=totalTime+coroutine.yield()
            if totalTime>6.26 then return false end
        end
    end
end

-- Download both players' replays for a finished ranked match, save them
-- locally (so they persist in the replay list), and play the match back as a
-- combined 1v1 net replay. Both clients only record their own placements, so
-- the combined replay needs both files to be complete; we wait/poll until the
-- opponent's replay has finished uploading before playing, so we never watch a
-- truncated/corrupt replay.
function NET.watchRankedReplay()
    local R=NET.rankedResult
    if not R or not R.matchId or not R.oppId then
        MES.new('error',"No replay available")
        return
    end
    TASK.new(function()
        local ok,err=pcall(function()
            MES.new('info',"Waiting for replay...")
            local myRaw,oppRaw
            -- Poll until both replays are available (the opponent may still be
            -- uploading their recording when the results screen appears).
            local waited=0
            while true do
                myRaw=_fetchRankedReplayRaw(R.matchId,USER.uid)
                oppRaw=_fetchRankedReplayRaw(R.matchId,R.oppId)
                if myRaw and oppRaw then break end
                waited=waited+coroutine.yield()
                if waited>15.26 then
                    MES.new('error',"Replay not ready yet")
                    return
                end
            end
            -- Persist both original replays locally.
            love.filesystem.write(("replay/ranked_%s_%s.rep"):format(R.matchId,USER.uid),myRaw)
            love.filesystem.write(("replay/ranked_%s_%s.rep"):format(R.matchId,R.oppId),oppRaw)

            -- Register them in the replay list (if not already) so they can also
            -- be watched later through the standard replay scene's buttons.
            for _,uid in next,{USER.uid,R.oppId} do
                local fn=("replay/ranked_%s_%s.rep"):format(R.matchId,uid)
                local exists=false
                for _,r in next,REPLAY do
                    if r.fileName==fn then exists=true break end
                end
                if not exists then
                    local rep=DATA.parseReplay(fn)
                    if rep and rep.available then table.insert(REPLAY,1,rep) end
                end
            end

            local myRep=DATA.parseReplayData("ranked",myRaw,true)
            local oppRep=DATA.parseReplayData("ranked",oppRaw,true)
            if not (myRep and myRep.available and oppRep and oppRep.available) then
                MES.new('error',"Replay data corrupted")
                return
            end
            NET.startRankedReplay(myRep,oppRep,USER.uid,R.oppId)
        end)
        if not ok then
            MES.new('error',"Replay playback failed")
            LOG("watchRankedReplay error: "..tostring(err))
            LOG(debug.traceback())
        end
    end)
end

-- Start a combined 1v1 net replay: player 1 is driven by `myRep`'s recording
-- and player 2 (remote) by `oppRep`'s recording, reusing the live net_game
-- streaming path. Does not affect live matchmaking.
-- Scan a recording list for its final timestamp (the replay's total frame
-- count). Layout per event: [frameTime, eventID, ...]; key events are 2
-- entries, the 'attack' extra event is 8 (frameTime + eventID + sourceSid +
-- 5 attack params).
local function _replayStreamLength(list)
    if not list then return 0 end
    local i=1; local last=0
    while list[i]~=nil do
        last=list[i]
        local ev=list[i+1]
        if ev==nil then break end
        if ev<=64 then i=i+2
        elseif ev<=128 then i=i+8
        else i=i+2 end
    end
    return last
end

-- Restart the ranked replay from frame 0 and fast-forward to `frame`, used by
-- the seek bar. Rebuilds the players/streams from the stored recordings, then
-- lets net_game drive the simulation up to the target frame.
function NET.seekRankedReplay(frame)
    local reps=NET._replayReps
    if not reps then return end
    -- Capture where each board currently sits so a backward seek animates it
    -- back into place instead of popping in from the center at scale 0. Prefer
    -- the end-of-replay snapshot (covers boards that had already dropped out
    -- and been removed from PLAYERS), falling back to the live positions.
    local oldPos=NET._replayEndPos or {}
    if not next(oldPos) then
        for p=1,#PLAYERS do
            local P=PLAYERS[p]
            if P.uid then oldPos[P.uid]={P.x,P.y,P.size} end
        end
    end
    NET._replayEndPos=nil
    resetGameData('n',NET.seed)
    GAME.replaying=true
    GAME.replaySetup=false
    GAME.recording=false
    local myList={}  DATA.pumpRecording(reps.myRep.data,myList)
    local oppList={} DATA.pumpRecording(reps.oppRep.data,oppList)
    GAME.rep=myList
    if PLAYERS[1] and PLAYERS[2] then
        PLAYERS[1]:startStreaming(myList)
        PLAYERS[2]:startStreaming(oppList)
    end
    -- Re-lay the rebuilt boards out from their previous (end-of-replay)
    -- positions, smoothly moving and scaling them into the new layout.
    for p=1,#PLAYERS do
        local o=oldPos[PLAYERS[p].uid]
        if o then PLAYERS[p]:setPosition(o[1],o[2],o[3]) end
    end
    freshPlayerPosition('update')
    NET._replayFF=true
    NET._replayFFTarget=frame or 0
    NET._replayCur=0
    NET._replayBannerAlpha=1
end

function NET.startRankedReplay(myRep,oppRep,myUid,oppUid)
    myUid=myUid or USER.uid
    oppUid=oppUid or (NET.rankedResult and NET.rankedResult.oppId)
    if not myUid or not oppUid then
        MES.new('error',"Missing replay player info")
        LOG("startRankedReplay: missing player uids")
        return
    end
    if not MODES.netBattle then
        MODES.netBattle=require('parts.modes.netBattle')
        MODES.netBattle.name='netBattle'
    end

    GAME.net=true
    GAME.replaying=true
    GAME.replaySetup=true
    GAME.fromRepMenu=false
    GAME.init=false
    GAME.seed=myRep.seed or oppRep.seed
    GAME.setting=myRep.setting or GAME.setting
    GAME.curModeName='netBattle'
    GAME.curMode=MODES.netBattle
    GAME.modeEnv=GAME.curMode.env
    GAME.rep={}

    NET._replayReps={myRep=myRep,oppRep=oppRep}
    NET._replayTotal=0
    NET._replayCur=0
    NET._replayFF=false
    NET._replayFFTarget=0
    NET._replaySeekPending=false
    NET._replaySeekFrame=0
    NET._replayBannerAlpha=1
    NET._replayEndPos=nil
    NET._replaySettled=false
    GAME.replaySpeed=1

    NET.roomState={
        info={name="Ranked Replay",type="ranked",version="",description=""},
        data={},
        count={Gamer=2,Spectator=0},
        capacity=2,
        private=true,
        state="Playing",
    }
    -- Remember the real post-match room so we can restore it once the replay
    -- ends, instead of leaving the fake replay room cached on the client
    -- (which would otherwise keep the matchmaking state polluted).
    NET._replayRoomState=NET.roomState
    NETPLY.clear()
    -- Feed each side its own match settings as the config so the remote-env
    -- loader has a real (non-empty) config. An empty string makes
    -- _loadRemoteEnv emit a "Bad conf" warning (and the ZFramework error
    -- collector then dumps the loadremoteenv/newRemotePlayer/resetGameData
    -- stack) even though this is just a local replay with no live opponent.
    NETPLY.add{uid=myUid,  group=0,role='Admin', playMode='Gamer',readyMode='Playing',config=JSON.encode(myRep.setting or {})}
    NETPLY.add{uid=oppUid,group=0,role='Normal',playMode='Gamer',readyMode='Playing',config=JSON.encode(oppRep.setting or {})}

    NET.seed=GAME.seed
    -- This is a local replay, not a live room: suppress the chat box/overlay
    -- and the networking-only widgets so the replay doesn't look or behave
    -- like an active net session.
    NET.textBox.hide=true
    NET.inputBox.hide=true
    TASK.lock('netPlaying')
    SCN.go('net_game','fade')

    -- After net_game builds the players, feed both recordings as streams.
    TASK.new(function()
        while #PLAYERS<2 do coroutine.yield() end
        local myList={}  DATA.pumpRecording(myRep.data,myList)
        local oppList={} DATA.pumpRecording(oppRep.data,oppList)
        GAME.rep=myList
        GAME.replaying=true
        GAME.replaySetup=false
        GAME.recording=false
        -- Stream sids are mapped onto this replay's canonical NET.uid_sid values
        -- in netBattle.load (same as live net play), so attacks route correctly.
        PLAYERS[1]:startStreaming(myList)
        PLAYERS[2]:startStreaming(oppList)
        NET._replayTotal=math.max(_replayStreamLength(myList),_replayStreamLength(oppList))
    end)
end



-- WS
NET.wsCallBack={}
function NET.wsCallBack.global_getOnlineCount(body)
    NET.onlineCount=tonumber(body.data) or "_"
end
function NET.wsCallBack.global_chat(body)
    USERS.getAvatar(body.data.playerId)
    local name=USERS.getUsername(body.data.playerId)
    if not name or #name==0 then
        name=tostring(body.data.playerId)
    end
    local msg=body.data.message
    if CHAT and CHAT.receiveMessage then
        CHAT.receiveMessage(name,msg)
    end
end
function NET.wsCallBack.room_chat(body)
    if SCN.cur~='net_game' then return end
    TASK.unlock('receiveMessage')
    TASK.lock('receiveMessage',1)
    USERS.getAvatar(body.data.playerId)

    local name=_getFullName(body.data.playerId).." "
    -- P/s: we need to wrap both name and message, not just only message
    local _,msgWrapped=FONT.get(NET.inputBox.font):getWrap(name..body.data.message,950)
    -- We don't want to see the name repeat twice :skull:
    msgWrapped[1]=string.gsub(msgWrapped[1],name,"",1)
    -- Push the name in white and first line of message in blue first
    NET.textBox:push{COLOR.Z,name,COLOR.N,msgWrapped[1]}
    for i, line in ipairs(msgWrapped) do
        if i ~= 1 then
            NET.textBox:push{COLOR.N,msgWrapped[i]}
        end
    end
end
function NET.wsCallBack.room_create(body)
    MES.new('check',text.createRoomSuccessed)
    SCN.pop()
    NET.wsCallBack.room_enter(body)
    WAIT.interrupt()
end
function NET.wsCallBack.room_getData(body)
    NET.roomState.data=body.data
end
function NET.wsCallBack.room_setData(body)
    NET.wsCallBack.room_getData(body)
end
function NET.wsCallBack.room_getInfo(body)
    NET.roomState.info=body.info
end
function NET.wsCallBack.room_setInfo(body)
    NET.wsCallBack.room_getInfo(body)
end
function NET.wsCallBack.room_enter(body)
    TASK.unlock('enterRoom')

    if body.data.players then
        NET.textBox.hide=true
        NET.inputBox.hide=true
        NET.textBox:clear()
        NET.inputBox:clear()

        NET.roomState=body.data
        NETPLY.clear()
        destroyPlayers()
        local isRanked = (body.data.info and body.data.info.type == 'ranked') or NET.matchFoundPending
        loadGame('netBattle',true,isRanked and 'none' or true)
        for _,p in next,body.data.players do
            NETPLY.add{
                uid=p.playerId,
                group=p.group,
                role=p.role,
                playMode=p.type,
                readyMode=p.state,
                config=p.config,
            }
            USERS.getAvatar(p.playerId)
        end
        TABLE.clear(NET.uid_sid)
        for i=1,#NETPLY.list do NET.uid_sid[NETPLY.list[i].uid]=i end
        for i=1,#PLAYERS do
            local P=PLAYERS[i]
            if P.uid then
                local sid=NET.uid_sid[P.uid]
                if sid then P.sid=sid end
            end
        end
        if NET.roomState.state=='Playing' and NET.roomState.info.type~='ranked' then
            -- Joined while a game is already in progress.
            -- Do NOT start netPlaying or feed stored streams; leave the player in
            -- the room lobby so they don't get thrown into an active match mid-game (which desyncs).
            NET.storedStream=nil
            TASK.unlock('netPlaying')
            if NETPLY.map[USER.uid] then
                NETPLY.map[USER.uid].playMode='Spectator'
                NETPLY.map[USER.uid].readyMode='Standby'
            end
            MES.new('info', "Match in progress — waiting in room lobby for next round")
            NET.freshRoomAllReady()
        else
            TASK.unlock('netPlaying')
            NET.freshRoomAllReady()
        end
    else
        local p=body.data
        if NETPLY.exist(p.playerId) then _playerLeaveRoom(p.playerId) end
        NETPLY.add{
            uid=p.playerId,
            group=p.group,
            role=p.role,
            playMode=p.type,
            readyMode=p.state,
            config=p.config,
        }
        USERS.getAvatar(p.playerId)
        NET.textBox:push{COLOR.Y,text.joinRoom:repD(_getFullName(p.playerId))}
        if not TASK.getLock('netPlaying') then
            SFX.play('connected')
            NET.freshRoomAllReady()
        end
    end
end
function NET.wsCallBack.room_kick(body)
    MES.new('info',text.playerKicked:repD(_getFullName(body.data.executorId),_getFullName(body.data.playerId)))
    _playerLeaveRoom(body.data.playerId)
end
function NET.wsCallBack.room_addBot(body)
end
function NET.wsCallBack.room_playerJoin(body)
    if not body.data or not body.data.playerId then return end
    local p=body.data
    if NETPLY.exist(p.playerId) then return end
    NETPLY.add{
        uid=p.playerId,
        group=p.group or 0,
        role=p.role or 'Normal',
        playMode=p.type or 'Gamer',
        readyMode=p.state or 'Standby',
    }
    USERS.getAvatar(p.playerId)
end
function NET.wsCallBack.room_removeBot(body)
end
function NET.wsCallBack.room_playerLeave(body)
    if not body.data or not body.data.playerId then return end
    _playerLeaveRoom(body.data.playerId)
end
function NET.wsCallBack.room_leave(body)
    local uid=body.data and body.data.playerId or USER.uid
    if body.data then
        NET.textBox:push{COLOR.Y,text.leaveRoom:repD(_getFullName(uid))}
    end
    _playerLeaveRoom(uid)
    NET.freshRoomAllReady()
end
function NET.wsCallBack.room_fetch(body)
    TASK.unlock('fetchRoom')
    if not body.data then body.data={} end
    SCN.scenes.net_rooms.widgetList.roomList:setList(body.data)
end
function NET.wsCallBack.room_setPW()
    if SCN.cur~='net_game' then return end
    MES.new(text.roomPasswordChanged)
end
function NET.wsCallBack.room_remove()
    if SCN.cur~='net_game' then return end
    MES.new('info',text.roomRemoved)
    _playerLeaveRoom(USER.uid)
end
function NET.wsCallBack.player_updateConf(body)
    if SCN.cur~='net_game' and SCN.cur~='net_rankedGame' then return end
    if type(body.data)=='table' then
        NETPLY.map[body.data.playerId].config=body.data.config
    end
end
function NET.wsCallBack.player_finish(body)
    if SCN.cur~='net_game' and SCN.cur~='net_rankedGame' then return end
    for _,P in next,PLY_ALIVE do
        if P.uid==body.data.playerId then
            NETPLY.setPlace(P.uid,#PLY_ALIVE)
            P.loseTimer=26
            break
        end
    end
end
function NET.wsCallBack.player_joinGroup(body)
    if SCN.cur~='net_game' then return end
    NETPLY.map[body.data.playerId].group=body.data.group
end
function NET.wsCallBack.player_setHost(body)
    if SCN.cur~='net_game' then return end
    if body.data.role=='Admin' then
        MES.new('info',text.becomeHost:repD(_getFullName(body.data.playerId)))
    end
    NETPLY.map[body.data.playerId].role=body.data.role
end
function NET.wsCallBack.player_setState(body)-- not used
end
function NET.wsCallBack.player_stream(body)
    if SCN.cur~='net_game' and SCN.cur~='net_rankedGame' then
        if not NET.storedStream then NET.storedStream={} end
        if #NET.storedStream < 120 and body.data then
            table.insert(NET.storedStream, body.data)
        end
        return
    end
    NET.pumpStream(body.data)
end
function NET.wsCallBack.player_setPlayMode(body)
    if SCN.cur~='net_game' then return end
    NETPLY.map[body.data.playerId].playMode=body.data.type
    NET.freshRoomAllReady()
end
function NET.wsCallBack.player_setReadyMode(body)
    if SCN.cur~='net_game' then return end
    NETPLY.map[body.data.playerId].readyMode=body.data.isReady and 'Ready' or 'Standby'
    NET.freshRoomAllReady()
end
function NET.wsCallBack.online_getPlayers(body)
    if type(body.data)=='table' then
        NET.onlinePlayers=body.data
    end
end
function NET.wsCallBack.online_playerJoin(body)
    if type(body.data)=='table' then
        table.insert(NET.onlinePlayers,body.data)
    end
end
function NET.wsCallBack.online_playerLeave(body)
    if type(body.data)=='table' and NET.onlinePlayers then
        for i=#NET.onlinePlayers,1,-1 do
            if NET.onlinePlayers[i].id==body.data.id then
                table.remove(NET.onlinePlayers,i)
                break
            end
        end
    end
end
function NET.wsCallBack.player_updateElo(body)
    if type(body.data)=='table' then
        if type(body.data.elo)=='number' then
            STAT.elo=body.data.elo
        end
        if type(body.data.globalRank)=='number' then
            STAT.globalRank=body.data.globalRank
        end
    end
end

function NET.wsCallBack.match_finish()
    if SCN.cur~='net_game' then return end
    -- Ranked matches are finalized by match_finish_ranked, which keeps the
    -- game on screen until the finish animation completes and then drives the
    -- transition to the results screen. Skip the casual waiting-room flow here
    -- so netPlaying is not unlocked early (which would briefly flash the
    -- net_game waiting room before the results scene).
    if NET.roomState.info and NET.roomState.info.type=='ranked' then return end
    for _,P in next,PLAYERS do
        NETPLY.setStat(P.uid,P.stat)
    end
    local lp=PLAYERS[1]
    if lp and lp.type=='human' then
        NET.reportHistory({
            mode=NET.roomState.info.type or NET.roomState.info.name or 'casual',
            roomId=NET.roomState.id,
            score=lp.stat.score or 0,
            lines=lp.stat.row or 0,
            time=lp.stat.time or 0,
            result='play',
        })
    end
    -- Briefly hold the finished view (~1s) so the losing player's top-out
    -- animation plays, then drop back to the in-room lobby (playing=false →
    -- scene.draw renders NETPLY + ready/spectate widgets). The lobby widgets
    -- are hidden while the match is showing (textBox.hide=false during play,
    -- true in the lobby) so once playing=false the user sees the standard
    -- waiting-room UI of net_game.
    TASK.new(function()
        TEST.yieldT(1)
        TASK.unlock('netPlaying')
    end)
end
function NET.wsCallBack.match_ready()-- not used
end
function NET.wsCallBack.match_start(body)
    local s = body.data and body.data.seed
    if s then
        NET.seed=s
    end
    if NET.matchFoundPending and NET.matchFoundCountdown>0 then
        NET.matchFoundSeed=NET.seed
        return
    end
    -- Note: we must set the lock/seed even if the scene hasn't finished
    -- transitioning into net_game yet. The server sends room_enter (1306) and
    -- match_start (1102) back-to-back, and the scene switch is applied at the
    -- frame boundary, so a SCN.cur guard here would drop the lock and the
    -- match would never start. net_game.update only consumes the lock once it
    -- is actually the active scene, so this is safe.
    TASK.lock('netPlaying')
    if not NET.seed then
        NET.seed=0
        MES.new("error",'No seed received')
    end
end
function NET.wsCallBack.match_found(body)
    local oppId=body.data and body.data.opponentId
    if not oppId then
        for i=1,#NETPLY.list do
            if NETPLY.list[i].uid and NETPLY.list[i].uid~=USER.uid then
                oppId=NETPLY.list[i].uid
                break
            end
        end
    end

    local oppName = body.data and body.data.opponentName
    if oppName and oppId then
        if USERS and USERS.setUsername then USERS.setUsername(oppId, oppName) end
    end
    if not oppName and oppId then
        oppName = USERS.getUsername(oppId)
    end
    oppName = oppName or "Opponent"

    NET.matchFoundMatchId=body.data and body.data.matchId
    NET.matchFoundOppId=oppId
    NET.matchFoundOppName=oppName
    NET.matchFoundOppElo=body.data and body.data.opponentRating or 1200
    NET.matchFoundCountdown=10.0
    NET.matchFoundPending=true
    NET.matchFoundTime=love.timer.getTime()
    NET._pendingMatchFoundScene=true
    NET.matchmaking=false
    NET.searchTimer=0
    NET.storedStream={}

    if oppId then NET.getUserInfo(oppId) end
    SFX.play('connected')
    MES.new('info', "Ranked match found vs " .. oppName .. "!", 3)

    if SCN.cur ~= 'net_matchFound' and SCN.cur ~= 'net_game' and SCN.cur ~= 'net_rankedGame' then
        SCN.go('net_matchFound')
    end
end
function NET.wsCallBack.round_finish(body)
    if SCN.cur == 'net_rankedGame' and SCN.scenes.net_rankedGame and SCN.scenes.net_rankedGame.onRoundFinish then
        SCN.scenes.net_rankedGame.onRoundFinish(body.data)
    end
end
function NET.wsCallBack.match_start_ranked(body)
    local s = body.data and body.data.seed
    if s then
        NET.seed=s
    end
    if NET.matchFoundPending and NET.matchFoundCountdown>0 then
        NET.matchFoundSeed=NET.seed
        return
    end
    TASK.lock('netPlaying')
    if not NET.seed then
        NET.seed=0
        MES.new("error",'No seed received')
    end
    if SCN.cur == 'net_rankedGame' and SCN.scenes.net_rankedGame and SCN.scenes.net_rankedGame.onNextRound then
        SCN.scenes.net_rankedGame.onNextRound(body.data)
    end
end
function NET.wsCallBack.match_finish_ranked(body)
    if SCN.cur~='net_game' and SCN.cur~='net_rankedGame' then return end
    for _,P in next,PLAYERS do
        NETPLY.setStat(P.uid,P.stat)
    end
    if body.data then
        local d=body.data
        local matchId=type(d.matchId)=='string' and d.matchId or false
        local myDelta=type(d.ratingChange)=='number' and d.ratingChange or 0
        local myNew=type(d.ratingAfter)=='number' and d.ratingAfter or (STAT.elo or 1200)
        local myOld=myNew-myDelta
        if type(d.globalRank)=='number' then STAT.globalRank=d.globalRank end
        STAT.elo=myNew

        local opp=d.opponent or {}
        local oppId=type(opp.playerId)=='string' and opp.playerId or false
        local oppDelta=type(opp.ratingChange)=='number' and opp.ratingChange or 0
        local oppNew=type(opp.ratingAfter)=='number' and opp.ratingAfter or 0
        local oppOld=oppNew-oppDelta

        -- Cache the opponent's profile so their name shows on the results
        -- screen even if we never fetched it during the match.
        if oppId then NET.getUserInfo(oppId) end

        -- Stash the summary now so the results scene has it ready.
        NET.rankedResult={
            matchId=matchId,
            winnerId=type(d.winnerId)=='string' and d.winnerId or USER.uid,
            myOld=myOld, myNew=myNew, myDelta=myDelta, myRank=STAT.globalRank,
            oppId=oppId, oppOld=oppOld, oppNew=oppNew, oppDelta=oppDelta, oppRank=type(opp.globalRank)=='number' and opp.globalRank or 0,
            myScore=type(d.myScore)=='number' and d.myScore or 0,
            oppScore=type(d.oppScore)=='number' and d.oppScore or 0,
            targetWins=type(d.targetWins)=='number' and d.targetWins or 3,
        }

        -- Best-effort: upload this player's replay into the match folder.
        if matchId then NET.uploadRankedReplay(matchId) end

        -- Report this match to the history endpoint so it shows on the profile.
        NET.reportHistory({
            mode='ranked',
            matchId=matchId,
            score=PLAYERS[1].stat.score or 0,
            lines=PLAYERS[1].stat.row or 0,
            time=PLAYERS[1].stat.time or 0,
            result=NET.rankedResult.winnerId==USER.uid and 'win' or 'loss',
            opponent={user_id=oppId, username=''},
        })
    end
    -- Let the finish animation (e.g. the opponent's top-out) play out before
    -- showing results. Keep netPlaying locked so the game scene does not briefly drop
    -- to the waiting room, and only then transition.
    TASK.new(function()
        TEST.yieldT(2.6)
        if SCN.cur=='net_game' or SCN.cur=='net_rankedGame' then
            NET.roomState=nil
            NETPLY.clear()
            NET.matchmaking=false
            NET.searchTimer=0
            NET.matchFoundPending=false
            NET.matchFoundCountdown=0
            NET.matchFoundSeed=nil
            NET.matchFoundTime=nil
            NET.matchFoundOppId=nil
            NET.matchFoundMatchId=nil
            SCN.go('net_rankedResult','fade')
        end
    end)
end
function NET.wsCallBack.match_cancel()
    NET.matchFoundPending=false
    NET.matchFoundCountdown=0
    NET.matchFoundSeed=nil
    NET.matchFoundTime=nil
    NET.matchFoundOppId=nil
    NET.matchFoundMatchId=nil
    NET._pendingMatchFoundScene=false
    if SCN.cur~='net_ranked' and SCN.cur~='net_matchFound' and SCN.cur~='net_rankedGame' then return end
    NET.matchmaking=false
    NET.searchTimer=0
    MES.new('info',"Matchmaking cancelled")
    if SCN.cur=='net_matchFound' or SCN.cur=='net_rankedGame' then
        SCN.go('net_ranked')
    end
end

-- Inbound handlers for the authoritative-sim protocol (plan Component 2/3).
-- These are passive consumers: they update the rollback anchor (1411), queue
-- the latest snapshot for the next step-loop tick (1410), and log divergence
-- (1412). The actual reconcile/resim lives in Rollback.step, wired in slice 4.
-- Defining them now means flipping TEBLOCKS_SIM_AUTHORITATIVE in staging will
-- not crash the client; we'll just be *not yet* consuming the data for prediction
-- correction.
NET._pendingSnapshot=false
function NET.wsCallBack.input_ack(body)
    if not body or type(body.data)~='table' then return end
    local f=body.data.frame
    if type(f)=='number' and ROLLBACK then
        ROLLBACK.recordAck(f)
    end
end
function NET.wsCallBack.auth_snapshot(body)
    if not body or type(body.data)~='table' then return end
    -- Cache for Rollback.step to consume next frame. Deep copy is unnecessary:
    -- Rollback.step reads frameRun + per-player state and immediately turns
    -- it into a SNAPSHOT.restore call.
    NET._pendingSnapshot=body.data
end
function NET.wsCallBack.rollback_trigger(body)
    if not body or type(body.data)~='table' then return end
    -- Slice 4 (Rollback.step) will handle the resim. For now, advance the
    -- anchor so we don't try to re-rollback past this frame, and log so the
    -- event is observable from the console.
    local f=body.data.frame
    if type(f)=='number' and ROLLBACK then
        ROLLBACK.recordAck(f)
    end
    if body.data.reason then
        print("[rollback] server trigger frame="..tostring(f).." reason="..tostring(body.data.reason))
    end
end
function NET.wsCallBack.input_hash()
    -- Server -> client is not expected; this is a C->S message only. Ignore.
end

local reconnectAttempts = 0
local reconnectMaxDelay = 10
local isReconnecting = false

function NET.triggerReconnect()
    local tok = USER and (USER.oToken or USER.aToken)
    if not tok or tok == '' then
        NET._isReconnecting = false
        NET._connecting = false
        return
    end
    if isReconnecting or WS.status('game') == 'running' then return end
    isReconnecting = true
    reconnectAttempts = reconnectAttempts + 1
    local delay = math.min(1.5 * (1.4 ^ (reconnectAttempts - 1)), reconnectMaxDelay)
    NET._isReconnecting = true
    NET._reconnectCountdown = delay

    TASK.new(function()
        while NET._reconnectCountdown and NET._reconnectCountdown > 0 do
            TEST.yieldT(0.25)
            NET._reconnectCountdown = math.max(0, NET._reconnectCountdown - 0.25)
        end
        NET._reconnectCountdown = nil
        isReconnecting = false
        if WS.status('game') ~= 'running' then
            NET.ws_connect(true)
        else
            NET._isReconnecting = false
            reconnectAttempts = 0
        end
    end)
end

function NET.startupConnect()
    TASK.new(function()
        if USER.aToken and not USER.oToken then
            USER.oToken = USER.aToken
        elseif USER.oToken and not USER.aToken then
            USER.aToken = USER.oToken
        end
        local tok = USER and (USER.oToken or USER.aToken)
        if tok and tok ~= '' then
            NET.ws_connect()
        end
    end)
end

function NET.ws_connect(force)
    local tok = USER and (USER.oToken or USER.aToken)
    if not tok or tok == '' then
        NET._connecting = false
        NET._isReconnecting = false
        return
    end
    if force or WS.status('game')=='dead' then
        if WS.status('game')~='dead' then
            WS.close('game')
        end
        NET._connecting = true
        WS.connect('game','',{['x-access-token']=tok},6)
        TASK.removeTask_code(NET.ws_update)
        TASK.new(NET.ws_update)
    end
end
function NET.ws_close()
    NET._connecting = false
    NET._isReconnecting = false
    WS.close('game')
end
function NET.ws_update()
    -- Wait until connected
    while true do
        TEST.yieldT(1/26)
        if WS.status('game')=='dead' then
            NET._connecting = false
            if (SCN.cur == 'net_game' or SCN.cur == 'net_rankedGame') and TASK.getLock('netPlaying') then
                TEST.yieldUntilNextScene()
                GAME.playing=false
                MES.new('warn', "Connection lost during match", 5)
                if SCN.cur == 'net_rankedGame' then
                    SCN.go('net_ranked')
                else
                    SCN.backTo('lobby')
                end
            end
            NET.triggerReconnect()
            return
        elseif WS.status('game')=='running' then
            NET._connecting = false
            NET._isReconnecting = false
            reconnectAttempts = 0
            break
        end
    end

    local token = USER.oToken or USER.aToken
    if token then
        local res=getMsg({
            pool='getUID',
            url=AUTHHOST,
            path='/api/auth/check',
            headers={["x-access-token"]=token},
        },6.26)

        if res and res.code and math.floor(res.code/100)==2 then
            USER.uid=res.data.playerId
            if res.data.accessToken then
                USER.oToken=res.data.accessToken
                USER.aToken=res.data.accessToken
            end
            if res.data.username then
                USERS.updateUsername(USER.uid,res.data.username)
            end
            saveUser()
            -- Initialize player setting
            NET.player_updateConf()
            -- Sync our competitive elo/rank from the server (persists across restarts).
            NET.getUserInfo(USER.uid)
            local CARD=require'parts.userCard'
            CARD.reset()
        elseif res and res.code==401 then
            USER.aToken=false
            USER.oToken=false
            USER.uid=false
            saveUser()
            local CARD=require'parts.userCard'
            CARD.reset()
            if SCN.cur and (SCN.cur:sub(1,3)=='net' or SCN.cur=='lobby') then
                TEST.yieldUntilNextScene()
                GAME.playing=false
                SCN.backTo('main')
                return
            end
        end
    end

    -- Websocket main loop
    local updateOnlineCD=0
    while true do
        TEST.yieldT(.01)-- Network messages, max 126 FPS is enough

        if WS.status('game')=='dead' then
            if (SCN.cur == 'net_game' or SCN.cur == 'net_rankedGame') and TASK.getLock('netPlaying') then
                TEST.yieldUntilNextScene()
                GAME.playing=false
                MES.new('warn', "Connection lost during match", 5)
                if SCN.cur == 'net_rankedGame' then
                    SCN.go('net_ranked')
                else
                    SCN.backTo('lobby')
                end
            end
            NET.triggerReconnect()
            return
        end

        updateOnlineCD=updateOnlineCD%626+1
        if updateOnlineCD==1 then NET.global_getOnlineCount() end
        if updateOnlineCD%125==0 and not (SCN.cur == 'net_game' or SCN.cur == 'net_rankedGame') then
            NET.online_getPlayers()
        end

        local readLimit=100
        while readLimit>0 do
            local rawMsg,op=WS.read('game')
            if not rawMsg then break end
            readLimit=readLimit-1

            NET.ping=WS.getPing('game')

            if op=='ping' then
                -- Handled in WS.read
            elseif op=='pong' then
                -- Handled in WS.read
            elseif op=='close' then
                local ok,msg=pcall(JSON.decode,rawMsg)
                if not ok or type(msg)~='table' then msg={message=tostring(rawMsg)} end
                if msg and msg.message then LOG("[WS Close] " .. tostring(msg.message)) end
                if (SCN.cur == 'net_game' or SCN.cur == 'net_rankedGame') and TASK.getLock('netPlaying') then
                    MES.new('info',text.wsClose:repD(msg and msg.message or rawMsg))
                    TEST.yieldUntilNextScene()
                    GAME.playing=false
                    if SCN.cur == 'net_rankedGame' then
                        SCN.go('net_ranked')
                    else
                        SCN.backTo('lobby')
                    end
                end
                NET.triggerReconnect()
                return
            elseif type(rawMsg)=='string' then
                local ok,msg=pcall(JSON.decode,rawMsg)
                if ok and type(msg)=='table' then
                    if msg.errno and msg.errno~=0 then
                        local errMsg=msg.message
                        if not errMsg and msg.data and type(msg.data)=='table' and msg.data.reason then
                            errMsg=msg.data.reason
                        end
                        parseError(errMsg~=nil and errMsg or ('err '..tostring(msg.action)..'/'..tostring(msg.errno)))
                    else
                        local f=NET.wsCallBack[actMap[msg.action]]
                        if f then f(msg) end
                    end
                else
                    MES.new('warn',"Wrong json: "..tostring(rawMsg),5)
                    WS.alert('user')
                end
            end
        end
    end
end

--------------------------<OLD ONLINE API>
-- Save
-- Submit a Quick Play score to the server. Fire-and-forget: the result (best
-- score + leaderboard rank) is surfaced as a message if the request succeeds.
function NET.submitQuickPlayScore(mode,score)
    if not USER.aToken or (type(mode)=='string' and mode:sub(1,7)=='custom_') then return end
    TASK.new(function()
        local res=getMsg({
            pool='score',
            url=AUTHHOST,
            path='/api/score',
            headers={['x-access-token']=USER.aToken},
            body={mode=mode,score=score},
        },6.26)
        if res and res.code and math.floor(res.code/100)==2 and res.data then
            if res.data.rank and res.data.rank>0 then
                MES.new('check',("Score submitted! Best %d · Rank #%d"):format(res.data.best or score,res.data.rank))
            else
                MES.new('check',"Score submitted!")
            end
        elseif res then
            MES.new('warn',"Score not submitted")
        end
    end)
end

function NET.reportHistory(data)
    if not USER.aToken or (data and type(data.mode)=='string' and data.mode:sub(1,7)=='custom_') then return end
    TASK.new(function()
        local body={
            mode=data.mode,
            score=math.floor(data.score or 0),
            lines=math.floor(data.lines or 0),
            duration=math.floor(data.time or 0),
            result=data.result or 'play',
        }
        if data.matchId then body.match_id=data.matchId end
        if data.roomId then body.room_id=data.roomId end
        if data.opponent and data.opponent.user_id then
            body.opponent={user_id=data.opponent.user_id,username=data.opponent.username or ''}
        end
        getMsg({
            pool='history',
            url=AUTHHOST,
            path='/api/match/history',
            headers={['x-access-token']=USER.aToken},
            body=body,
        },6.26)
    end)
end

function NET.uploadSave()
    if not TASK.lock('uploadSave',8) then return end
    wsSend(actMap.save_upload,{data={sections={
        {section=1,data=STRING.packTable(STAT)},
        {section=2,data=STRING.packTable(RANKS)},
        {section=3,data=STRING.packTable(SETTING)},
        {section=4,data=STRING.packTable(KEY_MAP)},
        {section=5,data=STRING.packTable(VK_ORG)},
        {section=6,data=STRING.packTable(loadFile('conf/vkSave1','-canSkip') or{})},
        {section=7,data=STRING.packTable(loadFile('conf/vkSave2','-canSkip') or{})},
    }}})
    MES.new('info',"Uploading")
end
function NET.downloadSave()
    if not TASK.lock('downloadSave',8) then return end
    wsSend(actMap.save_download,{data={sections={1,2,3,4,5,6,7}}})
    MES.new('info',"Downloading")
end
function NET.loadSavedData(sections)
    local cloudData={}
    local secNameList={'STAT','RANKS','SETTING','keyMap','VK_org','vkSave1','vkSave2'}
    for _,sec in next,sections do
        cloudData[secNameList[sec.section]]=STRING.unpackTable(sec.data)
    end

    local fail
    repeat
        if cloudData.STAT then
            TABLE.cover(cloudData.STAT,STAT)
            if not saveStats() then fail=true end
        end

        if cloudData.RANKS then
            TABLE.cover(cloudData.RANKS,RANKS)
            if not saveProgress() then fail=true end
        end

        if cloudData.SETTING then
            TABLE.cover(cloudData.SETTING,SETTING)
            if not saveSettings() then fail=true end
        end
        applySettings()

        if cloudData.keyMap then
            TABLE.cover(cloudData.keyMap,KEY_MAP)
            if not saveFile(KEY_MAP,'conf/key') then fail=true end
        end

        if cloudData.VK_org then
            TABLE.cover(cloudData.VK_org,VK_ORG)
            if not saveFile(VK_ORG,'conf/virtualkey') then fail=true end
        end

        if #cloudData.vkSave1[1] and not saveFile(cloudData.vkSave1,'conf/vkSave1') then fail=true end
        if #cloudData.vkSave2[1] and not saveFile(cloudData.vkSave2,'conf/vkSave2') then fail=true end
    until true

    if fail then
        MES.new('error',text.dataCorrupted)
    else
        MES.new('check',text.saveDone)
    end
end

function NET.reportPlayer(data, cb)
    if not data or not data.reported_uid then
        if cb then cb(false, "missing target") end
        return
    end

    -- Priority 1: WebSocket if game connection is active
    if WS.status('game') == 'running' then
        WS.send('game', {
            action = 1321, -- actionReportPlayer
            data = {
                reported_uid = tostring(data.reported_uid),
                reported_username = tostring(data.reported_username or ""),
                reason = tostring(data.reason or "other"),
                details = tostring(data.details or ""),
                room_id = tostring(data.room_id or ""),
                match_id = tostring(data.match_id or ""),
                client_meta = {
                    reporter_uid = tostring(USER and USER.uid or ""),
                    client_version = tostring(VERSION and VERSION.room or ""),
                    time = os.time(),
                }
            }
        })
        if cb then cb(true, "sent_via_ws") end
        return
    end

    -- Priority 2: HTTP POST /api/report
    local baseWeb = (AUTHURL and AUTHURL:find("^http")) and AUTHURL or "https://teblocks.my.id"
    local headers = {
        ["Content-Type"] = "application/json",
    }
    if USER and USER.aToken then
        headers["x-access-token"] = USER.aToken
    end

    HTTP({
        pool = 'report',
        type = 'post',
        url = baseWeb .. "/api/report",
        header = headers,
        body = JSON._encode({
            reported_uid = tostring(data.reported_uid),
            reported_username = tostring(data.reported_username or ""),
            reason = tostring(data.reason or "other"),
            details = tostring(data.details or ""),
            room_id = tostring(data.room_id or ""),
            match_id = tostring(data.match_id or ""),
            client_meta = {
                reporter_uid = tostring(USER and USER.uid or ""),
                client_version = tostring(VERSION and VERSION.room or ""),
                time = os.time(),
            }
        }),
    })

    if cb then cb(true, "queued_http") end
end

return NET
