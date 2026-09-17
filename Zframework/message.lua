local ins,rem=table.insert,table.remove
local max=math.max

local mesList={}
local mesIcon={
    check=GC.DO{40,40,
        {'setLW',10},
        {'setCL',0,0,0},
        {'line',4,19,15,30,36,9},
        {'setLW',6},
        {'setCL',.7,1,.6},
        {'line',5,20,15,30,35,10},
    },
    info=GC.DO{40,40,
        {'setCL',.2,.25,.85},
        {'fCirc',20,20,15},
        {'setCL',1,1,1},
        {'setLW',2},
        {'dCirc',20,20,15},
        {'fRect',18,11,4,4},
        {'fRect',18,17,4,12},
    },
    broadcast=GC.DO{40,40,
        {'setCL',1,1,1},
        {'fRect',2,4,36,26,3},
        {'fPoly',2,27,2,37,14,25},
        {'setCL',.5,.5,.5},
        {'fRect',6,11,4,4,1},{'fRect',14,11,19,4,1},
        {'fRect',6,19,4,4,1},{'fRect',14,19,19,4,1},
    },
    warn=GC.DO{40,40,
        {'setCL',.95,.83,.4},
        {'fPoly',20.5,1,0,38,40,38},
        {'setCL',0,0,0},
        {'dPoly',20.5,1,0,38,40,38},
        {'fRect',17,10,7,18,2},
        {'fRect',17,29,7,7,2},
        {'setCL',1,1,1},
        {'fRect',18,11,5,16,2},
        {'fRect',18,30,5,5,2},
    },
    error=GC.DO{40,40,
        {'setCL',.95,.3,.3},
        {'fCirc',20,20,19},
        {'setCL',0,0,0},
        {'dCirc',20,20,19},
        {'setLW',6},
        {'line',10.2,10.2,29.8,29.8},
        {'line',10.2,29.8,29.8,10.2},
        {'setLW',4},
        {'setCL',1,1,1},
        {'line',11,11,29,29},
        {'line',11,29,29,11},
    },
    music=GC.DO{40,40,
        {'setLW',2},
        {'dRect',1,3,38,34,3},
        {'setLW',4},
        {'line',21,26,21,10,28,10},
        {'fElps',17,26,6,5},
    },
}

local MES={}
local backColors={
    check={.3,.6,.3,.7},
    broadcast={.3,.3,.6,.8},
    warn={.4,.4,.2,.9},
    error={.4,.2,.2,.9},
    music={.2,.4,.4,.9},
    other={.5,.5,.5,.7},
}
function MES.new(icon,str,time)
    local color=backColors.other
    local iconKey=icon
    if type(icon)=='string' then
        color=backColors[icon] or backColors.other
        iconKey=icon
        icon=mesIcon[icon]
    end
    -- Persist every notification to console and to conf/notifications.log so
    -- the operator/console sees it even if the toast is missed (game crash,
    -- alt-tab, etc). `icon` may be the enum string or a Canvas — only log
    -- the named enum.
    local line=string.format("[%s] %s: %s", os.date("%Y/%m/%d %H:%M:%S"), iconKey or "other", tostring(str))
    print(line)
    if not TEMP_MODE then
        pcall(function()
            love.filesystem.append("conf/notifications.log",line.."\n")
        end)
    end
    local text=GC.newText(FONT.get(30),str)
    local w=math.max(text:getWidth()+(icon and 45 or 5),200)+15
    local h=math.max(text:getHeight(),46)+2
    local k=h>400 and 1/math.min(h/400,2.6) or 1

    ins(mesList,1,{
        startTime=.26,
        endTime=.26,
        time=time or 3,

        color=color,
        text=text,icon=icon,
        w=w,h=h,k=k,
        x=0,
        y=-h-30,
        targetX=0,
        targetY=0,
        rot=0,
        yeeted=false,
        vx=0,vy=0,rotSpeed=0,
    })
end

function MES.yeet(idx, flickVx, flickVy)
    local m = mesList[idx]
    if not m or m.yeeted then return end
    m.yeeted = true
    m.startTime = 0
    m.time = 0
    m.endTime = 0.8

    local vx = flickVx
    if not vx or math.abs(vx) < 50 then
        vx = (math.random() > 0.5 and 1 or -1) * math.random(1100, 1600)
    end
    local vy = flickVy or math.random(-420, -180)
    m.vx = vx
    m.vy = vy
    m.rotSpeed = (vx > 0 and 1 or -1) * math.random(7, 13)

    if SFX and SFX.play then
        pcall(SFX.play, 'reach')
    end
end

local dragToast = nil
local pressX, pressY = 0, 0
local lastMx, lastMy = 0, 0

function MES.mouseDown(rawX, rawY, k)
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = rawX / kScale
    local my = rawY / kScale
    for i = 1, #mesList do
        local m = mesList[i]
        if not m.yeeted and m.startTime <= 0.15 then
            local mw = m.w * m.k
            local mh = m.h * m.k
            if mx >= m.x - 4 and mx <= m.x + mw + 4 and my >= m.y - 4 and my <= m.y + mh + 4 then
                dragToast = i
                pressX, pressY = mx, my
                lastMx, lastMy = mx, my
                return true
            end
        end
    end
    return false
end

function MES.mouseMove(rawX, rawY, dx, dy)
    if dragToast and mesList[dragToast] then
        local kScale = (SCR.k > 0 and SCR.k or 1)
        lastMx = rawX / kScale
        lastMy = rawY / kScale
    end
end

function MES.mouseUp(rawX, rawY, k)
    if dragToast then
        local idx = dragToast
        dragToast = nil
        local m = mesList[idx]
        if m and not m.yeeted then
            local kScale = (SCR.k > 0 and SCR.k or 1)
            local mx = rawX / kScale
            local my = rawY / kScale
            local dx = mx - pressX
            local dy = my - pressY
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 15 then
                local vx = dx * 18
                local vy = dy * 18
                if math.abs(vx) < 300 then vx = (vx >= 0 and 1 or -1) * 800 end
                MES.yeet(idx, vx, vy)
            else
                MES.yeet(idx)
            end
            return true
        end
    end
    return false
end

function MES.mouseClick(x, y)
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = love.mouse.getX() / kScale
    local my = love.mouse.getY() / kScale
    for i = 1, #mesList do
        local m = mesList[i]
        if not m.yeeted and m.startTime <= 0.15 then
            local mw = m.w * m.k
            local mh = m.h * m.k
            if mx >= m.x - 4 and mx <= m.x + mw + 4 and my >= m.y - 4 and my <= m.y + mh + 4 then
                MES.yeet(i)
                return true
            end
        end
    end
    return false
end

function MES.update(dt)
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local screenH = SCR.h > 0 and (SCR.h / SCR.k) or 720
    local curY = 62
    for i = #mesList, 1, -1 do
        local m = mesList[i]
        if m.yeeted then
            m.x = m.x + m.vx * dt
            m.vy = m.vy + 2000 * dt
            m.y = m.y + m.vy * dt
            m.rot = m.rot + m.rotSpeed * dt
            m.endTime = m.endTime - dt * 1.5
            if m.endTime <= 0 or m.y > screenH + 300 or m.x < -600 or m.x > screenW + 600 then
                rem(mesList, i)
            end
        else
            if m.startTime > 0 then
                m.startTime = max(m.startTime - dt, 0)
            elseif m.time > 0 then
                m.time = max(m.time - dt, 0)
            elseif m.endTime > 0 then
                m.endTime = m.endTime - dt
            else
                rem(mesList, i)
            end

            local targetX = math.floor((screenW - m.w * m.k) * 0.5)
            local targetY = curY
            curY = curY + m.h * m.k + 8

            m.x = MATH.expApproach(m.x, targetX, dt * 24)
            m.y = MATH.expApproach(m.y, targetY, dt * 24)
            m.rot = MATH.expApproach(m.rot, 0, dt * 24)
        end
    end
end

function MES.draw()
    if #mesList > 0 then
        local kScale = (SCR.k > 0 and SCR.k or 1)
        local mx = love.mouse.getX() / kScale
        local my = love.mouse.getY() / kScale
        GC.setLineWidth(2)
        for i = 1, #mesList do
            local m = mesList[i]
            local a
            if m.yeeted then
                a = math.max(0, math.min(1, m.endTime / 0.8))
            else
                a = 3.846 * (m.endTime - m.startTime)
                a = math.max(0, math.min(1, a))
            end

            local mw = m.w * m.k
            local mh = m.h * m.k
            local isHov = not m.yeeted and (mx >= m.x and mx <= m.x + mw and my >= m.y and my <= m.y + mh)

            GC.push('transform')
            if m.rot ~= 0 then
                GC.translate(m.x + mw * 0.5, m.y + mh * 0.5)
                GC.rotate(m.rot)
                GC.translate(-mw * 0.5, -mh * 0.5)
            else
                GC.translate(m.x, m.y)
            end
            GC.scale(m.k)

            -- Shadow / glow
            if isHov then
                GC.setColor(0, 0, 0, 0.45 * a)
                GC.rectangle('fill', -2, 2, m.w + 4, m.h + 4, 10)
                GC.setColor(m.color[1] * 1.15, m.color[2] * 1.15, m.color[3] * 1.15, 0.96 * a)
            else
                GC.setColor(0, 0, 0, 0.32 * a)
                GC.rectangle('fill', -1, 2, m.w + 2, m.h + 2, 8)
                GC.setColor(m.color[1], m.color[2], m.color[3], m.color[4] * a)
            end
            GC.rectangle('fill', 0, 0, m.w, m.h, 8)

            -- Border
            if isHov then
                GC.setColor(1, 1, 1, 0.85 * a)
                GC.setLineWidth(2)
                GC.rectangle('line', 0, 0, m.w, m.h, 8)
            else
                GC.setColor(.62, .62, .62, a * .626)
                GC.setLineWidth(1.5)
                GC.rectangle('line', 1, 1, m.w - 2, m.h - 2, 8)
            end

            -- Icon
            GC.setColor(1, 1, 1, a)
            if m.icon then
                GC.draw(m.icon, 6, (m.h - 40) * 0.5, nil, 40 / m.icon:getWidth(), 40 / m.icon:getHeight())
            end

            -- Text
            local textX = m.icon and 52 or 14
            GC.simpY(m.text, textX, m.h / 2)

            -- Yeet / Dismiss indicator on right
            local closeX = m.w - 18
            local closeY = m.h * 0.5
            if isHov then
                GC.setColor(1, .3, .4, 0.9 * a)
                GC.circle('fill', closeX, closeY, 8)
                GC.setColor(1, 1, 1, a)
                FONT.set(10)
                GC.mStr("✕", closeX, closeY - 6)
            else
                GC.setColor(1, 1, 1, 0.35 * a)
                FONT.set(9)
                GC.mStr("✕", closeX, closeY - 5)
            end

            GC.pop()
        end
    end
end

function MES.traceback()
    local mes=
        debug.traceback('',1)
        :gsub(': in function',', in')
        :gsub(':',' ')
        :gsub('\t','')
    MES.new('error',mes:sub(
        mes:find("\n",2)+1,
        mes:find("\n%[C%], in 'xpcall'")
    ),5)
end

return MES
