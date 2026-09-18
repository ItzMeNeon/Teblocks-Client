-- Nexus: Quantum Cyber Grid & Hexagonal Neural Network
local gc=love.graphics
local sin,cos,min,max=math.sin,math.cos,math.min,math.max
local rnd=math.random

local back={}

local t=0
local shockwaveR=0
local shockwaveMax=1000
local shockwaveAlpha=0
local nodes
local traces
local pulses
local hexR=48

local function makeHex(cx,cy,r)
    local pts={}
    for i=0,5 do
        local a=i*1.047197551 -- pi/3
        table.insert(pts,cx+r*cos(a))
        table.insert(pts,cy+r*sin(a))
    end
    return pts
end

function back.init()
    t=rnd()*500
    shockwaveR=0
    shockwaveAlpha=0
    nodes={}
    traces={}
    pulses={}
    back.resize(SCR.w,SCR.h)
end

function back.resize(w,h)
    w=w or SCR.w
    h=h or SCR.h
    shockwaveMax=((w*0.5)^2+(h*0.5)^2)^0.5+100

    -- Generate a network of circuit nodes
    nodes={}
    local cols=math.floor(w/(hexR*1.732))+2
    local rows=math.floor(h/(hexR*1.5))+2
    local r=hexR*SCR.k
    local dx=r*1.7320508
    local dy=r*1.5

    local gridNodes={}
    for row=1,rows do
        gridNodes[row]={}
        for col=1,cols do
            local cx=(col-1)*dx+((row%2==0) and dx*0.5 or 0)
            local cy=(row-1)*dy
            local isKeyNode=rnd()<0.22
            local node={
                x=cx,
                y=cy,
                r=r,
                isKey=isKeyNode,
                keyColor=rnd()<0.65 and {0.05,0.95,0.9} or {0.95,0.75,0.15},
                glow=0,
                pulseTimer=rnd()*5,
            }
            gridNodes[row][col]=node
            if isKeyNode then
                table.insert(nodes,node)
            end
        end
    end

    -- Build interconnected circuit traces between adjacent key nodes
    traces={}
    for i=1,#nodes do
        local n1=nodes[i]
        for j=i+1,#nodes do
            local n2=nodes[j]
            local dist=((n1.x-n2.x)^2+(n1.y-n2.y)^2)^0.5
            if dist<r*4.2 and rnd()<0.45 then
                -- Circuit trace with elbow/corner
                local midX,midY
                if rnd()<0.5 then
                    midX=n2.x
                    midY=n1.y
                else
                    midX=n1.x
                    midY=n2.y
                end
                table.insert(traces,{
                    x1=n1.x,y1=n1.y,
                    mx=midX,my=midY,
                    x2=n2.x,y2=n2.y,
                    dist=dist,
                    active=0,
                })
            end
        end
    end

    -- Spawn traveling data packets
    pulses={}
    for _=1,24 do
        if #traces>0 then
            local tr=traces[rnd(#traces)]
            table.insert(pulses,{
                trace=tr,
                progress=rnd(),
                speed=rnd()*0.4+0.35,
                dir=rnd()<0.5 and 1 or -1,
                color=rnd()<0.7 and {0.1,1.0,0.85} or {1.0,0.8,0.2},
                size=(rnd()*2+2.5)*SCR.k,
            })
        end
    end
end

function back.update(dt)
    dt=min(dt,0.1)
    t=t+dt

    -- Periodic autonomous quantum shockwave
    if shockwaveAlpha<=0 then
        if t%8<0.1 then
            shockwaveR=0
            shockwaveAlpha=0.8
        end
    else
        shockwaveR=shockwaveR+dt*450*SCR.k
        shockwaveAlpha=max(0,shockwaveAlpha-dt*0.45)
    end

    -- Update nodes and key pulsing
    local cx,cy=SCR.w*0.5,SCR.h*0.5
    for i=1,#nodes do
        local N=nodes[i]
        N.glow=max(0,N.glow-dt*1.2)

        -- If hit by shockwave
        if shockwaveAlpha>0 then
            local d=((N.x-cx)^2+(N.y-cy)^2)^0.5
            if math.abs(d-shockwaveR)<40*SCR.k then
                N.glow=min(1,N.glow+shockwaveAlpha*0.7)
            end
        end
    end

    -- Update traveling data packets
    for i=1,#pulses do
        local P=pulses[i]
        P.progress=P.progress+P.speed*P.dir*dt
        if P.progress>1 then
            P.progress=0
            if #traces>0 then P.trace=traces[rnd(#traces)] end
        elseif P.progress<0 then
            P.progress=1
            if #traces>0 then P.trace=traces[rnd(#traces)] end
        end
    end
end

function back.draw()
    local w,h=SCR.w,SCR.h
    local cx,cy=w*0.5,h*0.5

    -- Deep carbon dark background
    gc.clear(0.025,0.035,0.06)

    -- Background rotating telemetry reticle
    gc.push('transform')
    gc.translate(cx,cy)
    gc.rotate(t*0.05)
    gc.setLineWidth(1)
    gc.setColor(0.1,0.5,0.7,0.06)
    gc.circle('line',0,0,min(w,h)*0.32)
    gc.setColor(0.1,0.8,0.6,0.04)
    gc.circle('line',0,0,min(w,h)*0.45)

    -- Reticle tick marks
    local ticks=24
    for i=1,ticks do
        local a=i*(6.28318/ticks)
        local r1=min(w,h)*0.30
        local r2=min(w,h)*0.33
        gc.setColor(0.2,0.7,0.9,0.07)
        gc.line(r1*cos(a),r1*sin(a),r2*cos(a),r2*sin(a))
    end
    gc.pop()

    -- Draw circuit traces
    for i=1,#traces do
        local tr=traces[i]
        gc.setLineWidth(1.2*SCR.k)
        gc.setColor(0.08,0.35,0.48,0.22)
        gc.line(tr.x1,tr.y1,tr.mx,tr.my,tr.x2,tr.y2)
    end

    -- Draw quantum shockwave ring
    if shockwaveAlpha>0 and shockwaveR<shockwaveMax then
        gc.setLineWidth(3*SCR.k)
        gc.setColor(0.1,0.9,1.0,shockwaveAlpha*0.35)
        gc.circle('line',cx,cy,shockwaveR)
        gc.setLineWidth(1*SCR.k)
        gc.setColor(0.4,1.0,0.8,shockwaveAlpha*0.55)
        gc.circle('line',cx,cy,shockwaveR*0.98)
    end

    -- Draw data pulses with glowing trails
    for i=1,#pulses do
        local P=pulses[i]
        local tr=P.trace
        if tr then
            local px,py
            if P.progress<0.5 then
                local frac=P.progress*2
                px=tr.x1+(tr.mx-tr.x1)*frac
                py=tr.y1+(tr.my-tr.y1)*frac
            else
                local frac=(P.progress-0.5)*2
                px=tr.mx+(tr.x2-tr.mx)*frac
                py=tr.my+(tr.y2-tr.my)*frac
            end

            local c=P.color
            -- Glow halo
            gc.setColor(c[1],c[2],c[3],0.2)
            gc.circle('fill',px,py,P.size*2.2)
            -- Solid core
            gc.setColor(1,1,1,0.9)
            gc.circle('fill',px,py,P.size*0.7)
            gc.setColor(c[1],c[2],c[3],0.85)
            gc.circle('fill',px,py,P.size)
        end
    end

    -- Draw network nodes
    for i=1,#nodes do
        local N=nodes[i]
        local c=N.keyColor
        local glow=N.glow
        local baseR=5*SCR.k

        -- Node outer ring
        gc.setLineWidth(1.5*SCR.k)
        gc.setColor(c[1],c[2],c[3],0.3+glow*0.6)
        gc.circle('line',N.x,N.y,baseR*(1.5+glow*0.8))

        -- Node inner dot
        gc.setColor(c[1],c[2],c[3],0.5+glow*0.5)
        gc.circle('fill',N.x,N.y,baseR)

        -- Extra highlight when pulsing
        if glow>0.1 then
            gc.setColor(1,1,1,glow*0.7)
            gc.circle('fill',N.x,N.y,baseR*0.5)
        end
    end
end

function back.event(power)
    -- Trigger high-intensity quantum wave and light up nodes
    local p=tonumber(power) or 1
    shockwaveR=0
    shockwaveAlpha=min(1.2,0.6+p*0.2)

    for i=1,#nodes do
        if rnd()<0.4 then
            nodes[i].glow=min(1,nodes[i].glow+0.6*p)
        end
    end
end

function back.discard()
    nodes=nil
    traces=nil
    pulses=nil
end

return back
