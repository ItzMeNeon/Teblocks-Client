-- Synthwave: 80s Retro Cyber Grid & Neon Sun
local gc=love.graphics
local sin,cos,min,max=math.sin,math.cos,math.min,math.max
local rnd=math.random

local back={}

local t=0
local speed=0.45
local boost=0
local stars
local mountains

function back.init()
    t=rnd()*1000
    boost=0
    stars={}
    mountains={}
    back.resize(SCR.w,SCR.h)
end

function back.resize(w,h)
    w=w or SCR.w
    h=h or SCR.h
    local horizon=h*0.52
    local cx=w*0.5

    -- Distant stars in upper sky
    stars={}
    for i=1,60 do
        stars[i]={
            x=rnd()*w,
            y=rnd()*horizon*0.9,
            s=rnd(1,3)*SCR.k,
            phase=rnd()*6.28,
            freq=rnd()*2+1,
        }
    end

    -- Procedural distant mountain ridges on horizon
    mountains={}
    -- Background ridge (deep indigo)
    local ridge1={{0,horizon}}
    local steps=16
    for i=0,steps do
        local x=w*(i/steps)
        local peak=(sin(i*0.8+1.2)*0.5+cos(i*1.7)*0.3+0.2)*h*0.12
        table.insert(ridge1,{x,horizon-peak})
    end
    table.insert(ridge1,{w,horizon})
    mountains[1]=ridge1

    -- Foreground ridge (dark violet with neon edge)
    local ridge2={{0,horizon}}
    steps=22
    for i=0,steps do
        local x=w*(i/steps)
        local peak=(sin(i*1.1+3.4)*0.45+sin(i*2.3)*0.25+0.2)*h*0.09
        table.insert(ridge2,{x,horizon-peak})
    end
    table.insert(ridge2,{w,horizon})
    mountains[2]=ridge2
end

function back.update(dt)
    dt=min(dt,0.1)
    if boost>0 then
        boost=max(0,boost-dt*2)
    end
    t=t+dt*(speed+boost)
end

function back.draw()
    local w,h=SCR.w,SCR.h
    local horizon=h*0.52
    local cx=w*0.5

    -- Sky gradient background (dark cosmic purple to magenta horizon)
    gc.clear(0.04,0.02,0.09)

    -- Upper atmosphere glow
    local bands=12
    for i=1,bands do
        local frac=i/bands
        local y=(horizon*0.3)+(horizon*0.7)*frac
        local bh=horizon/bands+1
        local alpha=0.08+0.22*frac
        gc.setColor(0.35*frac+0.1,0.03,0.38*frac+0.05,alpha)
        gc.rectangle('fill',0,y-bh,w,bh+1)
    end

    -- Twinkling stars
    for i=1,#stars do
        local s=stars[i]
        local lum=0.3+0.4*sin(t*s.freq+s.phase)
        gc.setColor(0.9,0.7,1.0,lum)
        gc.rectangle('fill',s.x,s.y,s.s,s.s)
    end

    -- Retro Neon Sun
    local sunR=min(w,h)*0.16
    local sunY=horizon-sunR*0.42

    -- Sun outer aura
    gc.setColor(1.0,0.15,0.6,0.06+boost*0.05)
    gc.circle('fill',cx,sunY,sunR*1.4)
    gc.setColor(1.0,0.3,0.3,0.12+boost*0.08)
    gc.circle('fill',cx,sunY,sunR*1.18)

    -- Sliced Sun body
    local sunSlices=24
    for i=1,sunSlices do
        local frac=(i-0.5)/sunSlices
        local sy=sunY-sunR+frac*(sunR*2)
        local dy=sy-sunY
        if dy*dy<sunR*sunR then
            local halfW=(sunR*sunR-dy*dy)^0.5
            -- Cutout gap expands towards the bottom of the sun
            local gapFrac=max(0,(dy/sunR))
            local sliceH=(sunR*2/sunSlices)*(1-gapFrac*0.65)
            if sliceH>1 then
                -- Color gradient from bright warm yellow at top to vivid hot pink/magenta at bottom
                local r=1.0
                local g=max(0.1,0.95-frac*0.85)
                local b=min(0.7,frac*0.65)
                gc.setColor(r,g,b,0.92)
                gc.rectangle('fill',cx-halfW,sy-sliceH*0.5,halfW*2,sliceH)
            end
        end
    end

    -- Mountain Ridge 1 (Distant)
    if mountains and mountains[1] then
        local r1=mountains[1]
        local flat={}
        for i=1,#r1 do
            table.insert(flat,r1[i][1])
            table.insert(flat,r1[i][2])
        end
        table.insert(flat,w)
        table.insert(flat,horizon)
        table.insert(flat,0)
        table.insert(flat,horizon)
        gc.setColor(0.08,0.02,0.15,0.9)
        gc.polygon('fill',flat)
        gc.setColor(0.4,0.15,0.55,0.4)
        gc.setLineWidth(1.5)
        for i=1,#r1-1 do
            gc.line(r1[i][1],r1[i][2],r1[i+1][1],r1[i+1][2])
        end
    end

    -- Mountain Ridge 2 (Mid-ground with neon cyan/magenta edges)
    if mountains and mountains[2] then
        local r2=mountains[2]
        local flat={}
        for i=1,#r2 do
            table.insert(flat,r2[i][1])
            table.insert(flat,r2[i][2])
        end
        table.insert(flat,w)
        table.insert(flat,horizon)
        table.insert(flat,0)
        table.insert(flat,horizon)
        gc.setColor(0.04,0.01,0.08,0.95)
        gc.polygon('fill',flat)
        gc.setColor(0.85,0.1,0.65,0.7)
        gc.setLineWidth(2)
        for i=1,#r2-1 do
            gc.line(r2[i][1],r2[i][2],r2[i+1][1],r2[i+1][2])
        end
    end

    -- Ground base (deep cyber black/purple)
    gc.setColor(0.03,0.01,0.06,1)
    gc.rectangle('fill',0,horizon,w,h-horizon)

    -- Horizon neon glow line
    gc.setColor(1.0,0.2,0.75,0.3+boost*0.2)
    gc.setLineWidth(6)
    gc.line(0,horizon,w,horizon)
    gc.setColor(0.2,0.95,1.0,0.7)
    gc.setLineWidth(2)
    gc.line(0,horizon,w,horizon)

    -- 3D Perspective Rolling Ground Grid
    local gridHeight=h-horizon

    -- Horizontal perspective lines (scrolling towards viewer exponentially)
    local numHorizLines=18
    local scroll=(t*1.2)%1
    for i=1,numHorizLines do
        local p=(i-scroll)/numHorizLines
        if p>0 and p<=1 then
            -- Exponential perspective spacing
            local y=horizon+(p*p*p)*gridHeight
            local alpha=min(1,(p^1.5)*0.85+0.05)
            local lw=max(1,p*3.5*SCR.k)

            gc.setLineWidth(lw)
            -- Blend from neon magenta near horizon to brilliant cyan in foreground
            local r=1.0-p*0.8
            local g=0.2+p*0.75
            local b=0.7+p*0.3
            gc.setColor(r,g,b,alpha)
            gc.line(0,y,w,y)
        end
    end

    -- Vertical perspective lines radiating from vanishing point
    local numVertLines=24
    for i=-numVertLines,numVertLines do
        local normX=i/numVertLines
        -- Non-linear spread at screen bottom for wide-angle perspective feel
        local sign=normX>=0 and 1 or -1
        local bottomX=cx+sign*(math.abs(normX)^0.85)*w*0.85
        local alpha=max(0.12,0.65-math.abs(normX)*0.4)

        gc.setLineWidth(1.8*SCR.k)
        gc.setColor(0.1,0.85,1.0,alpha*0.6)
        gc.line(cx,horizon,bottomX,h)
    end
end

function back.event(power)
    -- Trigger momentary speed burst or neon pulse on game event (e.g. line clear)
    boost=min(1.5,boost+(tonumber(power) or 1)*0.3)
end

function back.discard()
    stars=nil
    mountains=nil
end

return back
