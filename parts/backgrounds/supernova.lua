-- Supernova: Black Hole Singularity & Relativistic Accretion Disk
local gc=love.graphics
local sin,cos,min,max=math.sin,math.cos,math.min,math.max
local rnd=math.random

local back={}

local t=0
local flare=0
local stars
local diskParticles

function back.init()
    t=rnd()*1000
    flare=0
    stars={}
    diskParticles={}
    back.resize(SCR.w,SCR.h)
end

function back.resize(w,h)
    w=w or SCR.w
    h=h or SCR.h
    local cx,cy=w*0.5,h*0.5

    -- Background stars that orbit/warp around the center
    stars={}
    for i=1,75 do
        local angle=rnd()*6.283
        local dist=rnd()*(max(w,h)*0.6)+40
        stars[i]={
            ang=angle,
            dist=dist,
            s=(rnd()*2+1)*SCR.k,
            speed=(120/max(60,dist))*(rnd()*0.4+0.8),
            alpha=rnd()*0.5+0.3,
        }
    end

    -- Swirling particles in the accretion disk
    diskParticles={}
    for i=1,120 do
        local r=rnd()*(min(w,h)*0.28)+min(w,h)*0.08
        diskParticles[i]={
            r=r,
            ang=rnd()*6.283,
            speed=(2.5+min(w,h)*0.08/r)*0.6,
            s=(rnd()*2.5+1.5)*SCR.k,
            seed=rnd(),
        }
    end
end

function back.update(dt)
    dt=min(dt,0.1)
    t=t+dt
    if flare>0 then
        flare=max(0,flare-dt*1.8)
    end

    -- Update orbiting background stars
    for i=1,#stars do
        local S=stars[i]
        S.ang=S.ang+S.speed*dt*0.1
    end

    -- Update accretion particles
    for i=1,#diskParticles do
        local P=diskParticles[i]
        P.ang=P.ang+P.speed*dt
    end
end

function back.draw()
    local w,h=SCR.w,SCR.h
    local cx,cy=w*0.5,h*0.5
    local bhRadius=min(w,h)*0.075

    -- Deep cosmic abyss clear
    gc.clear(0.015,0.015,0.03)

    -- Gravitational lensing background stars
    for i=1,#stars do
        local S=stars[i]
        local sx=cx+cos(S.ang)*S.dist
        local sy=cy+sin(S.ang)*S.dist
        local lum=S.alpha*(0.7+0.3*sin(t*2+S.dist))
        gc.setColor(0.75,0.85,1.0,lum)
        gc.circle('fill',sx,sy,S.s)
    end

    -- Relativistic Polar Jets (vertical plasma columns)
    local jetAlpha=0.12+flare*0.25+0.04*sin(t*4)
    local jetW=bhRadius*0.45
    -- Top Jet (cyan/blue energy beam)
    gc.setColor(0.2,0.75,1.0,jetAlpha*0.8)
    gc.polygon('fill',cx-jetW*0.5,cy,cx+jetW*0.5,cy,cx+jetW*2.0,0,cx-jetW*2.0,0)
    -- Bottom Jet
    gc.setColor(0.3,0.6,1.0,jetAlpha*0.7)
    gc.polygon('fill',cx-jetW*0.5,cy,cx+jetW*0.5,cy,cx+jetW*2.0,h,cx-jetW*2.0,h)
    -- Core jet line
    gc.setLineWidth(2*SCR.k)
    gc.setColor(0.8,0.95,1.0,jetAlpha*1.5)
    gc.line(cx,0,cx,h)

    -- Back half of gravitationally lensed accretion disk (bent above the black hole)
    local lensedR=bhRadius*1.55
    local haloAlpha=0.25+flare*0.35+0.05*sin(t*2.5)
    gc.setLineWidth(bhRadius*0.6)
    gc.setColor(1.0,0.55,0.15,haloAlpha*0.5)
    gc.circle('line',cx,cy-bhRadius*0.25,lensedR)
    gc.setLineWidth(bhRadius*0.25)
    gc.setColor(1.0,0.85,0.4,haloAlpha*0.9)
    gc.circle('line',cx,cy-bhRadius*0.25,lensedR)

    -- Accretion Disk - Swirling Elliptical Ring (tilted perspective)
    local diskR_X=min(w,h)*0.32
    local diskR_Y=diskR_X*0.32

    -- Outer diffuse gas glow
    local numRings=10
    for r=numRings,1,-1 do
        local frac=r/numRings
        local rx=diskR_X*(0.4+frac*0.6)
        local ry=diskR_Y*(0.4+frac*0.6)
        local a=(0.04+flare*0.06)*(1-frac*0.5)
        gc.setColor(1.0,0.4+frac*0.3,0.1,a)
        gc.setLineWidth(14*SCR.k)
        gc.ellipse('line',cx,cy,rx,ry)
    end

    -- Accretion Disk Particles with Relativistic Doppler Beaming
    for i=1,#diskParticles do
        local P=diskParticles[i]
        local a=P.ang
        local px=cx+cos(a)*P.r
        local py=cy+sin(a)*P.r*0.32

        -- Relativistic beaming: approaching side (cos < 0 / left side) is blue-shifted & brighter
        local doppler=-cos(a) -- ranges -1 to +1
        local r,g,b,alpha
        if doppler>0 then
            -- Approaching: hot cyan/white, boosted intensity
            r=max(0.4,1.0-doppler*0.6)
            g=min(1.0,0.7+doppler*0.3)
            b=min(1.0,0.3+doppler*0.7)
            alpha=(0.5+doppler*0.5)*(0.5+flare*0.5)
        else
            -- Receding: redshifted deep orange/amber, dimmer
            r=1.0
            g=max(0.2,0.55+doppler*0.3)
            b=max(0.05,0.15+doppler*0.1)
            alpha=(0.4+doppler*0.2)*(0.5+flare*0.5)
        end

        gc.setColor(r,g,b,alpha)
        gc.circle('fill',px,py,P.s*(1+doppler*0.3))
    end

    -- Event Horizon / Black Hole Singularity (Pure black sphere in foreground)
    gc.setColor(0.005,0.005,0.01,1)
    gc.circle('fill',cx,cy,bhRadius)

    -- Photon Sphere (intense razor-sharp ring of trapped photons around black hole edge)
    gc.setLineWidth(2.5*SCR.k)
    gc.setColor(1.0,0.95,0.85,0.85+flare*0.15)
    gc.circle('line',cx,cy,bhRadius)

    -- Foreground half of accretion disk (crossing in front of lower half of black hole)
    gc.setLineWidth(bhRadius*0.22)
    gc.setColor(1.0,0.65,0.2,0.75+flare*0.25)
    gc.arc('line','open',cx,cy,diskR_X*0.6,0.1,3.04)
    gc.setLineWidth(bhRadius*0.08)
    gc.setColor(1.0,0.95,0.8,0.95)
    gc.arc('line','open',cx,cy,diskR_X*0.6,0.15,2.99)
end

function back.event(power)
    -- Trigger sudden relativistic flare on line clears
    flare=min(1.5,flare+(tonumber(power) or 1)*0.4)
end

function back.discard()
    stars=nil
    diskParticles=nil
end

return back
