-- Cybercity: Neon Cyberpunk Metropolis Skyline & Digital Rain
local gc=love.graphics
local sin,cos,min,max=math.sin,math.cos,math.min,math.max
local rnd=math.random

local back={}

local t=0
local glitchFlash=0
local bgBuildings
local fgBuildings
local rain
local beacons

function back.init()
    t=rnd()*1000
    glitchFlash=0
    bgBuildings={}
    fgBuildings={}
    rain={}
    beacons={}
    back.resize(SCR.w,SCR.h)
end

function back.resize(w,h)
    w=w or SCR.w
    h=h or SCR.h

    -- Background distant towers
    bgBuildings={}
    local curX=-20
    while curX<w+50 do
        local bw=(rnd()*40+35)*SCR.k
        local bh=(rnd()*h*0.35+h*0.25)
        local windows={}
        local winCols=math.max(2,math.floor(bw/(8*SCR.k)))
        local winRows=math.max(4,math.floor(bh/(14*SCR.k)))
        for r=1,winRows do
            for c=1,winCols do
                if rnd()<0.35 then
                    table.insert(windows,{
                        x=c*(bw/(winCols+1)),
                        y=r*(bh/(winRows+1)),
                        col=rnd()<0.6 and {0.2,0.8,0.9} or {1.0,0.7,0.2},
                    })
                end
            end
        end

        table.insert(bgBuildings,{
            x=curX,
            y=h-bh,
            w=bw,
            h=bh,
            windows=windows,
        })
        curX=curX+bw+rnd()*10
    end

    -- Foreground mega-towers
    fgBuildings={}
    curX=-30
    while curX<w+80 do
        local bw=(rnd()*70+55)*SCR.k
        local bh=(rnd()*h*0.45+h*0.35)
        local hasAntenna=rnd()<0.6
        local neonColor=rnd()<0.5 and {0.95,0.15,0.65} or {0.1,0.9,0.85}

        table.insert(fgBuildings,{
            x=curX,
            y=h-bh,
            w=bw,
            h=bh,
            hasAntenna=hasAntenna,
            neonColor=neonColor,
            neonAlpha=rnd()*0.3+0.5,
        })
        curX=curX+bw+(rnd()*25+10)*SCR.k
    end

    -- Digital neon rain streaks
    rain={}
    for i=1,90 do
        rain[i]={
            x=rnd()*w,
            y=rnd()*h,
            len=(rnd()*20+15)*SCR.k,
            speed=rnd()*400+500,
            alpha=rnd()*0.35+0.15,
            isNeon=rnd()<0.2,
        }
    end

    -- Rooftop flashing beacons
    beacons={}
    for i=1,12 do
        beacons[i]={
            x=rnd()*w,
            y=rnd()*h*0.4+h*0.3,
            freq=rnd()*2+1.5,
            phase=rnd()*6.28,
            color=rnd()<0.5 and {1,0.2,0.2} or {0.2,0.9,1},
        }
    end
end

function back.update(dt)
    dt=min(dt,0.1)
    t=t+dt
    if glitchFlash>0 then
        glitchFlash=max(0,glitchFlash-dt*2.2)
    end

    local w,h=SCR.w,SCR.h
    -- Rain falling with slant
    for i=1,#rain do
        local R=rain[i]
        R.y=R.y+R.speed*dt
        R.x=R.x-R.speed*dt*0.18
        if R.y>h+30 or R.x<-30 then
            R.y=-30
            R.x=rnd()*(w+80)
        end
    end
end

function back.draw()
    local w,h=SCR.w,SCR.h

    -- Dystopian dark indigo sky
    gc.clear(0.025,0.015,0.05)

    -- Ambient sky light bloom from megacity below
    local cityBloom=0.18+glitchFlash*0.3
    gc.setColor(0.35,0.05,0.4,cityBloom*0.5)
    gc.rectangle('fill',0,h*0.4,w,h*0.6)
    gc.setColor(0.05,0.4,0.5,cityBloom*0.3)
    gc.rectangle('fill',0,h*0.65,w,h*0.35)

    -- Sweeping sky searchlights
    for i=1,2 do
        local ang=sin(t*0.3+i*2.2)*0.45-0.1
        local sx=w*(0.25+i*0.5)
        local beamW=35*SCR.k
        gc.setColor(0.2,0.8,1.0,0.04+glitchFlash*0.06)
        gc.polygon('fill',sx,h*0.5,sx+beamW,h*0.5,sx+sin(ang)*h*1.2+beamW*3,0,sx+sin(ang)*h*1.2-beamW*3,0)
    end

    -- Draw distant background buildings
    for i=1,#bgBuildings do
        local B=bgBuildings[i]
        gc.setColor(0.04,0.03,0.08,0.95)
        gc.rectangle('fill',B.x,B.y,B.w,B.h)

        -- Windows
        for wIdx=1,#B.windows do
            local W=B.windows[wIdx]
            local c=W.col
            gc.setColor(c[1],c[2],c[3],0.45+glitchFlash*0.3)
            gc.rectangle('fill',B.x+W.x,B.y+W.y,2.5*SCR.k,3.5*SCR.k)
        end
    end

    -- Draw foreground monolithic towers
    for i=1,#fgBuildings do
        local B=fgBuildings[i]
        gc.setColor(0.015,0.01,0.035,1)
        gc.rectangle('fill',B.x,B.y,B.w,B.h)

        -- Neon edge highlights
        local c=B.neonColor
        local a=(B.neonAlpha+glitchFlash*0.4)
        gc.setLineWidth(1.8*SCR.k)
        gc.setColor(c[1],c[2],c[3],a)
        -- Rooftop horizontal neon strip
        gc.line(B.x,B.y,B.x+B.w,B.y)
        -- Side vertical edge
        gc.line(B.x,B.y,B.x,B.y+B.h)

        -- Antenna beacon
        if B.hasAntenna then
            local antX=B.x+B.w*0.5
            gc.setLineWidth(1.5*SCR.k)
            gc.setColor(0.3,0.3,0.4,0.8)
            gc.line(antX,B.y,antX,B.y-25*SCR.k)

            -- Pulsing warning red light on tip
            local beaconLum=sin(t*4+i)*0.5+0.5
            gc.setColor(1,0.2,0.2,beaconLum)
            gc.circle('fill',antX,B.y-25*SCR.k,2*SCR.k)
        end
    end

    -- Rooftop flashing beacons
    for i=1,#beacons do
        local B=beacons[i]
        local lum=max(0,sin(t*B.freq+B.phase))^3
        local c=B.color
        gc.setColor(c[1],c[2],c[3],lum)
        gc.circle('fill',B.x,B.y,2.5*SCR.k)
    end

    -- Street-level neon ground haze
    for i=1,6 do
        local frac=i/6
        local y=h-(6-i)*(15*SCR.k)
        gc.setColor(0.6*frac,0.1*frac,0.7*frac,0.06+glitchFlash*0.05)
        gc.rectangle('fill',0,y,w,16*SCR.k)
    end

    -- Digital neon rain
    for i=1,#rain do
        local R=rain[i]
        local a=R.alpha+glitchFlash*0.3
        if R.isNeon then
            gc.setLineWidth(1.8*SCR.k)
            gc.setColor(0.1,0.95,0.85,min(1,a*1.5))
        else
            gc.setLineWidth(1.2*SCR.k)
            gc.setColor(0.35,0.65,0.95,a)
        end
        gc.line(R.x,R.y,R.x-R.len*0.18,R.y+R.len)
    end
end

function back.event(power)
    -- Cyber glitch lightning flash on game events
    glitchFlash=min(1.5,glitchFlash+(tonumber(power) or 1)*0.5)
end

function back.discard()
    bgBuildings=nil
    fgBuildings=nil
    rain=nil
    beacons=nil
end

return back
