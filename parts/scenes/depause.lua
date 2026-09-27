local gc=love.graphics

local scene={}

local timer

function scene.enter()
    timer=1
    scene.widgetList.pause.x=
        SETTING.menuPos=='right' and 1195 or
        SETTING.menuPos=='middle' and 860 or
        SETTING.menuPos=='left' and 190
end

function scene.keyDown(key)
    if key=='escape' then
        pauseGame()
    end
end

scene.mouseDown=NULL
scene.touchDown=NULL

function scene.update(dt)
    timer=timer-dt*.8
    if timer<0 then
        SFX.play('click')
        SCN.swapTo('game','none')
    end
end

function scene.draw()
    -- Game scene
    SCN.scenes.game.draw()

    -- Dark screen cover
    local coverAlpha=math.max(0,timer*8-7)*0.88
    gc.setColor(0.02,0.04,0.08,coverAlpha)
    gc.replaceTransform(SCR.origin)
    gc.rectangle('fill',0,0,SCR.w,SCR.h)
    gc.replaceTransform(SCR.xOy)

    -- Cyber Depause Counter bar
    local a=math.min(1,12*timer,8*(1-timer))
    if a>0 then
        -- Track backing
        gc.setColor(0.04,0.08,0.18,a*0.90)
        gc.rectangle('fill',494,336,292,48,14)
        -- Glow outline
        gc.setLineWidth(2)
        gc.setColor(0.25,0.65,1.0,a*0.85)
        gc.rectangle('line',494,336,292,48,14)
        -- Filled progress bar
        local barW=math.max(0,280*timer)
        if barW>0 then
            gc.setColor(0.20,0.60,0.95,a*0.90)
            gc.rectangle('fill',500,342,barW,36,10)
            -- Top sheen
            gc.setColor(1,1,1,a*0.12)
            gc.rectangle('fill',500,342,barW,14,8)
        end
        -- High contrast label
        FONT.set(16)
        gc.setColor(0,0,0,a*0.75)
        GC.mStr("RESUMING",641,351)
        gc.setColor(1,1,1,a)
        GC.mStr("RESUMING",640,350)
    end
end

scene.widgetList={
    WIDGET.newKey{name='pause',x=0,y=45,w=60,code=pauseGame,font=40,fText=CHAR.icon.pause},
}

return scene
