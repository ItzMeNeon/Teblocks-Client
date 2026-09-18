-- Hyperdrive: Hyperspace Warp Speed Trails & Relativistic Tunnel
local gc=love.graphics
local sin,cos,min,max=math.sin,math.cos,math.min,math.max
local rnd=math.random

local back={}

local t=0
local warpBoost=0
local stars
local warpRings

function back.init()
    t=rnd()*1000
    warpBoost=0
    stars={}
    warpRings={}
    back.resize(SCR.w,SCR.h)
end

function back.resize(w,h)
    w=w or SCR.w
    h=h or SCR.h

    stars={}
    for i=1,180 do
        local angle=rnd()*6.28318
        local speed=rnd()*0.7+0.6
        stars[i]={
            ang=angle,
            z=rnd(),               -- Depth from 0 (at vanishing point) to 1 (at screen boundary)
            speed=speed,
            rSpeed=(rnd()-0.5)*0.3,-- Rotational swirl
            size=(rnd()*1.8+1.2)*SCR.k,
            seed=rnd(),
        }
    end

    warpRings={}
    for i=1,4 do
        warpRings[i]={
            r=(i/4)*min(w,h)*0.5,
            speed=rnd()*80+60,
            alpha=0.2,
        }
    end
end

function back.update(dt)
    dt=min(dt,0.1)
    if warpBoost>0 then
        warpBoost=max(0,warpBoost-dt*1.6)
    end

    local currentSpeed=(1.0+warpBoost*2.5)
    t=t+dt*currentSpeed

    -- Update warp stars
    for i=1,#stars do
        local S=stars[i]
        -- Accelerate towards camera exponentially
        S.z=S.z+dt*(S.speed*0.45+S.z*S.speed*1.8)*currentSpeed
        S.ang=S.ang+S.rSpeed*dt*0.3

        -- If reached camera view, reset to center
        if S.z>=1.0 then
            S.z=rnd()*0.08
            S.ang=rnd()*6.28318
            S.speed=rnd()*0.7+0.6
        end
    end

    -- Update warp distortion rings
    local maxR=((SCR.w*0.5)^2+(SCR.h*0.5)^2)^0.5
    for i=1,#warpRings do
        local R=warpRings[i]
        R.r=R.r+dt*R.speed*currentSpeed*SCR.k
        if R.r>maxR then
            R.r=10
        end
    end
end

function back.draw()
    local w,h=SCR.w,SCR.h
    local cx=w*0.5+sin(t*0.5)*15*SCR.k
    local cy=h*0.5+cos(t*0.4)*10*SCR.k
    local maxDist=((w*0.5)^2+(h*0.5)^2)^0.5

    -- Deep hyperspace void clear
    gc.clear(0.01,0.015,0.035)

    -- Hyperspace tunnel rings
    for i=1,#warpRings do
        local R=warpRings[i]
        local frac=R.r/maxDist
        local alpha=max(0,(1-frac)*0.25*(0.4+warpBoost*0.4))
        gc.setLineWidth(max(1,2.5*SCR.k*frac))
        gc.setColor(0.1,0.85,1.0,alpha)
        gc.circle('line',cx,cy,R.r)
    end

    -- Central warp focal core (the vanishing point flare)
    local coreAlpha=0.18+warpBoost*0.4
    gc.setColor(0.3,0.7,1.0,coreAlpha*0.4)
    gc.circle('fill',cx,cy,40*SCR.k*(1+warpBoost*0.8))
    gc.setColor(1.0,1.0,1.0,coreAlpha)
    gc.circle('fill',cx,cy,8*SCR.k*(1+warpBoost*0.5))

    -- Warp speed light trails
    for i=1,#stars do
        local S=stars[i]
        local z=S.z
        local dist=z*z*maxDist
        local trailLen=min(dist*0.7, (40+z*160+warpBoost*220)*SCR.k)

        local rad=S.ang
        local headX=cx+cos(rad)*dist
        local headY=cy+sin(rad)*dist

        local tailDist=max(0,dist-trailLen)
        local tailX=cx+cos(rad)*tailDist
        local tailY=cy+sin(rad)*tailDist

        local alpha=min(1,z*1.8)*(0.5+warpBoost*0.5)
        local lw=max(1,(1+z*3.5+warpBoost*2.0)*SCR.k)

        -- Chromatic Aberration: Cyan leading fringe & Magenta trailing fringe
        gc.setLineWidth(lw*1.4)
        gc.setColor(0.1,0.9,1.0,alpha*0.35)
        gc.line(headX-1,headY-1,tailX-1,tailY-1)

        gc.setColor(1.0,0.2,0.7,alpha*0.35)
        gc.line(headX+1,headY+1,tailX+1,tailY+1)

        -- White-hot star beam core
        gc.setLineWidth(lw)
        gc.setColor(0.9,0.95,1.0,alpha*0.95)
        gc.line(headX,headY,tailX,tailY)

        -- Star head glow
        gc.setColor(1,1,1,alpha)
        gc.circle('fill',headX,headY,lw*0.8)
    end
end

function back.event(power)
    -- Hyperspace jump surge on game events
    warpBoost=min(2.0,warpBoost+(tonumber(power) or 1)*0.5)
end

function back.discard()
    stars=nil
    warpRings=nil
end

return back
