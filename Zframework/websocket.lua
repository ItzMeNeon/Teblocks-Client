local host='127.0.0.1'
local port='80'
local path=''

-- lua + LÖVE threading websocket client
-- Original pure lua ver. by flaribbit and Particle_G
-- Threading version by MrZ

local type=type
local timer=love.timer.getTime

local WS={}
local wsList=setmetatable({},{
    __index=function(l,k)
        local ws={
            real=false,
            status='dead',
            lastPongTime=timer(),
            lastPingSentTime=false,
            ping=false,
            sendTimer=0,
            alertTimer=0,
            pongTimer=0,
        }
        l[k]=ws
        return ws
    end
})

function WS.switchHost(_1,_2,_3)
    for k in next,wsList do
        WS.close(k)
    end
    host=_1
    port=_2 or port
    path=_3 or path
end

function WS.connect(name,subPath,head,timeout)
    if head then
        local l=""
        for k,v in next,head do
            l=l..(k..": "..v..'\r\n')
        end
        head=l
    else
        head=""
    end
    if wsList[name] and wsList[name].thread then
        wsList[name].thread:release()
    end
    local ws={
        real=true,
        thread=love.thread.newThread('Zframework/websocket_thread.lua'),
        triggerCHN=love.thread.newChannel(),
        sendCHN=love.thread.newChannel(),
        readCHN=love.thread.newChannel(),
        lastPingTime=0,
        lastPongTime=timer(),
        lastPingSentTime=false,
        ping=false,
        pingInterval=6,
        status='connecting',-- 'connecting', 'running', 'dead'
        sendTimer=0,
        alertTimer=0,
        pongTimer=0,
    }
    wsList[name]=ws
    ws.thread:start(ws.triggerCHN,ws.sendCHN,ws.readCHN)
    ws.sendCHN:push(host)
    ws.sendCHN:push(port)
    ws.sendCHN:push(path..subPath)
    ws.sendCHN:push(head)
    ws.sendCHN:push(timeout or 2.6)
end

function WS.status(name)
    local ws=wsList[name]
    return ws.status or 'dead'
end

function WS.getPing(name)
    local ws=wsList[name]
    return ws and ws.ping or false
end

function WS.getTimers(name)
    local ws=wsList[name]
    return ws.pongTimer,ws.sendTimer,ws.alertTimer
end

function WS.setPingInterval(name,time)
    local ws=wsList[name]
    ws.pingInterval=math.max(time or 2.6,2.6)
end

function WS.alert(name)
    local ws=wsList[name]
    ws.alertTimer=2.6
end

local OPcode={
    continue=0,
    text=1,
    binary=2,
    close=8,
    ping=9,
    pong=10,
}
local OPname={
    [0]='continue',
    [1]='text',
    [2]='binary',
    [8]='close',
    [9]='ping',
    [10]='pong',
}
function WS.send(name,message,op)
    if type(message)=='string' then
        local ws=wsList[name]
        if ws.real and ws.status=='running' then
            ws.sendCHN:push(op and OPcode[op] or 2)-- 2=binary
            ws.sendCHN:push(message)
            if ws.triggerCHN:getCount()==0 then
                ws.triggerCHN:push(0)
            end
            ws.lastPingTime=timer()
            ws.sendTimer=1
        end
    else
        MES.new('error',"Attempt to send non-string value!")
        MES.traceback()
    end
end

function WS.read(name)
    local ws=wsList[name]
    if ws.real and ws.status~='connecting' and ws.readCHN:getCount()>=2 then
        local op,message=ws.readCHN:pop(),ws.readCHN:pop()
        local now=timer()
        if op==8 then-- 8=close
            ws.status='dead'
        elseif op==9 then-- 9=ping
            WS.send(name,message or "",'pong')
        elseif op==10 then-- 10=pong
            if ws.lastPingSentTime then
                local rtt=math.floor((now-ws.lastPingSentTime)*1000)
                if rtt>=0 and rtt<10000 then
                    ws.ping=rtt
                end
            end
        end
        ws.lastPongTime=now
        ws.pongTimer=1
        return message,OPname[op] or op
    end
end

function WS.close(name)
    local ws=wsList[name]
    if ws.real then
        ws.sendCHN:push(8)-- 8=close
        ws.sendCHN:push("")
        ws.status='dead'
    end
end

function WS.update(dt)
    local time=timer()
    for name,ws in next,wsList do
        if ws.real and ws.status~='dead' then
            if ws.thread:isRunning() then
                if ws.triggerCHN:getCount()==0 then
                    ws.triggerCHN:push(0)
                end
                if ws.status=='connecting' then
                    local mes=ws.readCHN:pop()
                    if mes then
                        if mes=='success' then
                            ws.status='running'
                            ws.lastPingTime=time
                            ws.lastPongTime=time
                            ws.pongTimer=1
                            if NET then NET.serverDown=false end
                        else
                            ws.status='dead'
                            local isDown=false
                            local reasonStr=""
                            if type(mes)=='table' then
                                if mes.serverDown or (mes.code and (mes.code==530 or mes.code>=500 or mes.code~=200)) then
                                    isDown=true
                                end
                                reasonStr=mes.reason or tostring(mes.code or "failed")
                            elseif type(mes)=='string' then
                                if mes:find("530") or mes:find("serverDown") or mes:find("refused") or mes:find("unreachable") or mes:find("50%d") then
                                    isDown=true
                                end
                                reasonStr=mes:gsub(".-:%d+:%s*","")
                            end
                            if isDown then
                                if NET then NET.serverDown=true end
                                if not ws.silent and (USER and (USER.oToken or USER.aToken)) then
                                    local t=love.timer.getTime()
                                    if t-(ws.lastDownAlert or 0)>4.5 then
                                        ws.lastDownAlert=t
                                        MES.new('warn',text.serverDown or "Server is down",5)
                                    end
                                end
                            else
                                if not ws.silent and (USER and (USER.oToken or USER.aToken)) then
                                    MES.new('warn',text.wsFailed:repD(reasonStr),5)
                                end
                            end
                        end
                    end
                elseif ws.status=='running' then
                    if time-ws.lastPingTime>ws.pingInterval then
                        ws.lastPingSentTime=time
                        WS.send(name,"",'ping')
                    end
                    if time-ws.lastPongTime>6+2*ws.pingInterval then
                        WS.close(name)
                    end
                end
                if ws.sendTimer>0 then ws.sendTimer=ws.sendTimer-dt end
                if ws.pongTimer>0 then ws.pongTimer=ws.pongTimer-dt end
                if ws.alertTimer>0 then ws.alertTimer=ws.alertTimer-dt end
            else
                ws.status='dead'
                local err=ws.thread:getError()
                if err then
                    if LOG then LOG("[WS] "..tostring(name).." thread died: "..tostring(err)) end
                    if not ws.silent and (USER and (USER.oToken or USER.aToken)) and name ~= 'game' then
                        MES.new('warn',text.wsClose:repD(err:match(":.-:(.-)\n") or err))
                        WS.alert(name)
                    end
                end
            end
        end
    end
end

return WS
