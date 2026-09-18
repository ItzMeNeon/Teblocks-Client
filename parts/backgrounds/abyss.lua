-- Abyss: Bioluminescent Deep Sea Jellyfish & Ambient Ocean
local gc=love.graphics
local sin,cos,min,max=math.sin,math.cos,math.min,math.max
local rnd=math.random

local back={}

local t=0
local jellies
local spores
local bubbles
local glowPulse=0

local JELLY_PALETTE={
    {r=0.15,g=0.85,b=0.95}, -- Electric Aqua
    {r=0.65,g=0.40,b=1.00}, -- Bioluminescent Violet
    {r=0.20,g=0.95,b=0.70}, -- Emerald Luminescence
    {r=1.00,g=0.65,b=0.35}, -- Deep-sea Amber
    {r=0.35,g=0.65,b=1.00}, -- Abyssal Azure
}

function back.init()
    t=rnd()*500
    glowPulse=0
    jellies={}
    spores={}
    bubbles={}
    back.resize(SCR.w,SCR.h)
end

function back.resize(w,h)
    w=w or SCR.w
    h=h or SCR.h

    -- Create bioluminescent jellyfish
    jellies={}
    for i=1,6 do
        local pal=JELLY_PALETTE[rnd(#JELLY_PALETTE)]
        local s=(rnd()*25+35)*SCR.k
        local tentacleCount=rnd(4,6)
        local tentacleLengths={}
        for k=1,tentacleCount do
            tentacleLengths[k]=s*(2.0+rnd()*1.5)
        end

        jellies[i]={
            x=rnd()*w,
            y=rnd()*(h+300),
            size=s,
            baseSpeed=rnd()*18+14,
            pulseFreq=rnd()*1.5+1.8,
            phase=rnd()*6.28,
            color=pal,
            tentacleCount=tentacleCount,
            tentacleLengths=tentacleLengths,
            driftX=(rnd()-0.5)*15,
        }
    end

    -- Create floating luminous spores
    spores={}
    for i=1,50 do
        spores[i]={
            x=rnd()*w,
            y=rnd()*h,
            s=rnd(1,3)*SCR.k,
            vy=-(rnd()*15+8),
            vx=(rnd()-0.5)*10,
            freq=rnd()*2+0.8,
            phase=rnd()*6.28,
            pal=JELLY_PALETTE[rnd(#JELLY_PALETTE)],
        }
    end
end

function back.update(dt)
    dt=min(dt,0.1)
    t=t+dt
    local w,h=SCR.w,SCR.h

    if glowPulse>0 then
        glowPulse=max(0,glowPulse-dt*1.5)
    end

    -- Update jellyfish
    for i=1,#jellies do
        local J=jellies[i]
        J.phase=J.phase+dt*J.pulseFreq

        -- Pulse thrust: power stroke when sin(phase) > 0
        local stroke=max(0,sin(J.phase))^2.5
        local speed=(J.baseSpeed+stroke*45*SCR.k)
        J.y=J.y-speed*dt
        J.x=J.x+sin(t*0.7+J.phase*0.5)*J.driftX*dt

        -- Wrap around screen
        if J.y<-J.size*3.5 then
            J.y=h+J.size*1.5+rnd()*100
            J.x=rnd()*w
            J.color=JELLY_PALETTE[rnd(#JELLY_PALETTE)]
        end
    end

    -- Update ambient spores
    for i=1,#spores do
        local S=spores[i]
        S.y=S.y+S.vy*dt
        S.x=S.x+(S.vx+sin(t*0.5+S.phase)*8)*dt

        if S.y<-10 then
            S.y=h+10
            S.x=rnd()*w
        elseif S.x<-20 then
            S.x=w+20
        elseif S.x>w+20 then
            S.x=-20
        end
    end

    -- Update event bubbles
    for i=#bubbles,1,-1 do
        local B=bubbles[i]
        B.y=B.y-B.vy*dt
        B.x=B.x+sin(t*3+B.phase)*B.wobble*dt
        B.life=B.life-dt
        if B.life<=0 or B.y<-20 then
            table.remove(bubbles,i)
        end
    end
end

function back.draw()
    local w,h=SCR.w,SCR.h

    -- Abyssal deep navy clear
    gc.clear(0.015,0.03,0.065)

    -- Soft undulating oceanic light rays / caustics
    local numRays=5
    for i=1,numRays do
        local rayX=w*(0.15+0.18*i)+sin(t*0.4+i)*60
        local rayW=w*0.12
        local alpha=0.03+0.02*sin(t*0.6+i*1.5)+glowPulse*0.04
        gc.setColor(0.1,0.5,0.8,alpha)
        gc.polygon('fill',rayX-rayW*0.3,0,rayX+rayW*0.3,0,rayX+rayW*0.8,h,rayX-rayW*0.8,h)
    end

    -- Draw ambient spores
    for i=1,#spores do
        local S=spores[i]
        local lum=0.25+0.55*(sin(t*S.freq+S.phase)*0.5+0.5)+glowPulse*0.3
        gc.setColor(S.pal.r,S.pal.g,S.pal.b,min(1,lum))
        gc.circle('fill',S.x,S.y,S.s)
    end

    -- Draw rising event bubbles
    for i=1,#bubbles do
        local B=bubbles[i]
        local a=min(1,B.life*0.8)
        gc.setColor(0.3,0.85,1.0,a*0.3)
        gc.circle('fill',B.x,B.y,B.r)
        gc.setColor(0.7,0.95,1.0,a*0.7)
        gc.setLineWidth(1)
        gc.circle('line',B.x,B.y,B.r)
    end

    -- Draw Jellyfish
    for i=1,#jellies do
        local J=jellies[i]
        local c=J.color
        local stroke=max(0,sin(J.phase))^2.5
        -- Contraction factor: bell becomes narrower and taller during power stroke
        local contractX=1.0-stroke*0.3
        local contractY=1.0+stroke*0.35
        local bw=J.size*contractX
        local bh=J.size*0.75*contractY

        -- Draw tentacles
        local count=J.tentacleCount
        for k=1,count do
            local txFrac=(k-0.5)/count
            local rootX=J.x+(txFrac-0.5)*(bw*1.4)
            local rootY=J.y+bh*0.2
            local tLen=J.tentacleLengths[k]

            local segs=8
            local pts={rootX,rootY}
            for s=1,segs do
                local segFrac=s/segs
                local wave=sin(t*3.5+k*0.8-segFrac*4.0)*(12*segFrac*SCR.k)
                local px=rootX+wave+J.driftX*segFrac*0.5
                local py=rootY+tLen*segFrac
                table.insert(pts,px)
                table.insert(pts,py)
            end

            local tentAlpha=(0.28+stroke*0.2+glowPulse*0.2)*(1-k%2*0.1)
            gc.setLineWidth(max(1,2.2*SCR.k*(1-0.5*(count>5 and 1 or 0))))
            gc.setColor(c.r,c.g,c.b,tentAlpha)
            gc.line(pts)
        end

        -- Outer luminous halo
        gc.setColor(c.r,c.g,c.b,0.07+glowPulse*0.06)
        gc.ellipse('fill',J.x,J.y,bw*1.6,bh*1.5)

        -- Outer translucent bell body
        gc.setColor(c.r*0.8+0.1,c.g*0.8+0.1,c.b*0.8+0.2,0.24+glowPulse*0.15)
        gc.ellipse('fill',J.x,J.y,bw,bh)

        -- Inner radiant bell core
        gc.setColor(c.r,c.g,c.b,0.45+glowPulse*0.25)
        gc.ellipse('fill',J.x,J.y-bh*0.15,bw*0.62,bh*0.58)

        -- Glowing bioluminescent nucleus
        gc.setColor(1,1,1,0.65+glowPulse*0.2)
        gc.circle('fill',J.x,J.y-bh*0.18,bw*0.22)

        -- Rim highlight arc
        gc.setLineWidth(1.8*SCR.k)
        gc.setColor(c.r*1.1,c.g*1.1,c.b*1.1,0.7+glowPulse*0.2)
        gc.arc('line','open',J.x,J.y,bw,-3.14,0)
    end
end

function back.event(power)
    -- Triggered on line clear or game events
    glowPulse=min(1.2,glowPulse+(tonumber(power) or 1)*0.4)

    -- Spawn a cluster of rising bubbles
    local w,h=SCR.w,SCR.h
    for _=1,rnd(6,12) do
        table.insert(bubbles,{
            x=rnd()*w,
            y=h+rnd()*20,
            r=(rnd()*3+2)*SCR.k,
            vy=rnd()*80+60,
            wobble=rnd()*15+8,
            phase=rnd()*6.28,
            life=rnd()*2.5+2.0,
        })
    end
end

function back.discard()
    jellies=nil
    spores=nil
    bubbles=nil
end

return back
