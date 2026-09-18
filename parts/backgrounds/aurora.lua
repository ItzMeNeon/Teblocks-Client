-- Aurora: Cosmic Northern Lights & Arctic Horizon
local gc=love.graphics
local sin,cos,min,max=math.sin,math.cos,math.min,math.max
local rnd=math.random

local back={}

local t=0
local solarStorm=0
local stars
local shootingStars
local trees

local CURTAINS={
    {baseFrac=0.18,hFrac=0.35,speed=0.25,col1={0.1,0.95,0.55},col2={0.1,0.6,0.9},alpha=0.32},  -- Emerald Green to Cyan
    {baseFrac=0.26,hFrac=0.40,speed=0.32,col1={0.15,0.85,0.95},col2={0.7,0.25,0.95},alpha=0.28}, -- Cyan to Violet
    {baseFrac=0.35,hFrac=0.32,speed=0.20,col1={0.65,0.2,0.9},col2={0.95,0.3,0.6},alpha=0.25},   -- Violet to Pink
}

function back.init()
    t=rnd()*1000
    solarStorm=0
    stars={}
    shootingStars={}
    trees={}
    back.resize(SCR.w,SCR.h)
end

function back.resize(w,h)
    w=w or SCR.w
    h=h or SCR.h

    -- Twinkling arctic stars
    stars={}
    for i=1,70 do
        stars[i]={
            x=rnd()*w,
            y=rnd()*h*0.75,
            s=(rnd()*2+1)*SCR.k,
            phase=rnd()*6.28,
            freq=rnd()*1.5+1.0,
        }
    end

    -- Procedural silhouetted pine tree / mountain horizon at bottom
    trees={}
    local horizonY=h*0.88
    local count=math.floor(w/(18*SCR.k))+4
    local step=w/count
    for i=0,count do
        local x=i*step+(rnd()-0.5)*step*0.6
        local th=(rnd()*28+18)*SCR.k
        local tw=(rnd()*10+8)*SCR.k
        trees[i]={
            x=x,
            y=horizonY,
            h=th,
            w=tw,
        }
    end
end

function back.update(dt)
    dt=min(dt,0.1)
    t=t+dt
    if solarStorm>0 then
        solarStorm=max(0,solarStorm-dt*1.2)
    end

    -- Update shooting stars
    if rnd()<0.015 and #shootingStars<3 then
        local w,h=SCR.w,SCR.h
        table.insert(shootingStars,{
            x=rnd()*w*0.8,
            y=rnd()*h*0.4,
            vx=rnd()*400+300,
            vy=rnd()*200+150,
            life=rnd()*0.4+0.3,
            maxLife=0.7,
        })
    end

    for i=#shootingStars,1,-1 do
        local S=shootingStars[i]
        S.x=S.x+S.vx*dt
        S.y=S.y+S.vy*dt
        S.life=S.life-dt
        if S.life<=0 then
            table.remove(shootingStars,i)
        end
    end
end

function back.draw()
    local w,h=SCR.w,SCR.h
    local horizonY=h*0.88

    -- Arctic deep midnight sky clear
    gc.clear(0.015,0.025,0.055)

    -- Ambient upper glow
    gc.setColor(0.05,0.15,0.18,0.15+solarStorm*0.15)
    gc.rectangle('fill',0,0,w,horizonY)

    -- Stars
    for i=1,#stars do
        local s=stars[i]
        local lum=0.3+0.5*sin(t*s.freq+s.phase)
        gc.setColor(0.85,0.95,1.0,lum)
        gc.rectangle('fill',s.x,s.y,s.s,s.s)
    end

    -- Shooting stars
    for i=1,#shootingStars do
        local S=shootingStars[i]
        local a=min(1,S.life/S.maxLife*1.5)
        gc.setLineWidth(1.8*SCR.k)
        gc.setColor(1.0,1.0,0.9,a)
        gc.line(S.x,S.y,S.x-S.vx*0.04,S.y-S.vy*0.04)
    end

    -- Undulating Aurora Curtains
    local slices=36
    local sliceW=w/slices+2

    for cIdx=1,#CURTAINS do
        local C=CURTAINS[cIdx]
        local curTime=t*C.speed+cIdx*2.1
        local baseH=h*C.baseFrac
        local curH=h*C.hFrac

        local c1=C.col1
        local c2=C.col2
        local alpha=C.alpha+solarStorm*0.25

        for i=0,slices do
            local x=i*(w/slices)
            -- Harmonic wave motion
            local wave1=sin(x*0.003+curTime*1.2)*45*SCR.k
            local wave2=cos(x*0.006-curTime*0.8)*25*SCR.k
            local wave3=sin(x*0.012+curTime*2.0)*15*SCR.k
            local topY=baseH+wave1+wave2+wave3
            local botY=topY+curH*(0.85+0.2*sin(x*0.004+curTime))

            -- Vertical gradient simulation using layered segments
            local segs=4
            for s=1,segs do
                local frac1=(s-1)/segs
                local frac2=s/segs
                local y1=topY+frac1*(botY-topY)
                local y2=topY+frac2*(botY-topY)

                -- Color blend from base to top
                local r=c1[1]*(1-frac1)+c2[1]*frac1
                local g=c1[2]*(1-frac1)+c2[2]*frac1
                local b=c1[3]*(1-frac1)+c2[3]*frac1
                local segAlpha=alpha*sin(frac1*3.14159)

                gc.setColor(r,g,b,segAlpha)
                gc.rectangle('fill',x,y1,sliceW,y2-y1+1)
            end
        end
    end

    -- Arctic snowy ground at horizon
    gc.setColor(0.03,0.06,0.09,1)
    gc.rectangle('fill',0,horizonY,w,h-horizonY)

    -- Soft snow reflection of aurora on ground
    gc.setColor(0.1,0.4,0.3,0.12+solarStorm*0.1)
    gc.rectangle('fill',0,horizonY,w,25*SCR.k)

    -- Silhouetted Pine Trees along the horizon
    gc.setColor(0.01,0.02,0.035,1)
    for i=0,#trees do
        local tr=trees[i]
        if tr then
            -- Draw triangular pine tree
            gc.polygon('fill',
                tr.x,tr.y-tr.h,
                tr.x-tr.w*0.5,tr.y,
                tr.x+tr.w*0.5,tr.y
            )
        end
    end
end

function back.event(power)
    -- Solar flare wave on line clear
    solarStorm=min(1.4,solarStorm+(tonumber(power) or 1)*0.35)
end

function back.discard()
    stars=nil
    shootingStars=nil
    trees=nil
end

return back
