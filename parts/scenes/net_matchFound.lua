local scene={}

local gc=love.graphics
local gc_setColor,gc_setLineWidth=gc.setColor,gc.setLineWidth
local gc_rectangle,gc_circle=gc.rectangle,gc.circle
local gc_print,gc_printf=gc.print,gc.printf
local gc_push,gc_pop,gc_replaceTransform=gc.push,gc.pop,gc.replaceTransform
local gc_translate,gc_scale=gc.translate,gc.scale
local gc_line=gc.line
local setFont=FONT.set

local particles={}

local function getTierInfo(elo)
    elo = tonumber(elo) or 1200
    if elo >= 2200 then
        return "Master Division", { .85, .35, 1.0 }, "Tier I"
    elseif elo >= 1900 then
        return "Diamond Division", { .35, .85, 1.0 }, "Tier II"
    elseif elo >= 1600 then
        return "Platinum Division", { .35, 1.0, .75 }, "Tier III"
    elseif elo >= 1300 then
        return "Gold Division", { 1.0, .80, .25 }, "Tier IV"
    elseif elo >= 1000 then
        return "Silver Division", { .85, .90, 1.0 }, "Tier V"
    else
        return "Bronze Division", { .85, .55, .35 }, "Tier VI"
    end
end

function scene.enter()
    BG.set()
    DiscordRPC.update("Match Found!")
    SFX.play('reach', 0.9)

    -- Initialize ambient cyber sparks
    particles = {}
    for i=1,36 do
        table.insert(particles, {
            x = math.random(0, 1280),
            y = math.random(0, 720),
            vx = (math.random() - 0.5) * 80 + (math.random() > 0.5 and 60 or -60),
            vy = (math.random() - 0.5) * 40,
            len = math.random(8, 28),
            alpha = math.random() * 0.5 + 0.2,
            col = math.random() > 0.5 and {.3, .9, .6} or {.9, .3, .4}
        })
    end
end

function scene.leave()
    particles = {}
end

function scene.keyDown(key,rep)
    if key=='escape' and not rep then
        NET.matchFoundPending=false
        NET.matchFoundCountdown=0
        NET.matchFoundSeed=nil
        NET.matchFoundTime=nil
        NET.matchFoundOppId=nil
        NET.matchFoundOppName=nil
        NET.matchFoundOppElo=nil
        NET.matchFoundMatchId=nil
        NET._pendingMatchFoundScene=false
        NET.ranked_leave()
        NET.matchmaking=false
        NET.searchTimer=0
        NET.shakeStr=0
        SCN.go('net_ranked')
        return true
    end
    return false
end

function scene.update(dt)
    if NET.matchFoundPending and NET.matchFoundCountdown>0 then
        NET.updateMatchFoundCountdown(dt)
    end
    if NET.shakeStr and NET.shakeStr>0 then
        NET.shakeStr=math.max(0,NET.shakeStr-dt*16)
    end
    if NET.matchFoundPending and NET.matchFoundCountdown>0 then
        WIDGET.locked=true
    else
        WIDGET.locked=false
    end

    -- Update cyber sparks
    for _,p in ipairs(particles) do
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        if p.x < -40 then p.x = 1320 end
        if p.x > 1320 then p.x = -40 end
        if p.y < -20 then p.y = 740 end
        if p.y > 740 then p.y = -20 end
    end

    -- When transition countdown completes, enter dedicated ranked arena scene!
    if not NET.matchFoundPending and SCN.cur=='net_matchFound' then
        SCN.go('net_rankedGame', 'fade_togame')
    end
end

function scene.draw()
    if not (NET.matchFoundPending and NET.matchFoundCountdown>0) then return end

    -- 1. Full-screen True Dark Canvas
    gc_replaceTransform(SCR.origin)
    gc_setColor(0,0,0,1)
    gc_rectangle('fill',0,0,SCR.w,SCR.h)

    local elapsed = love.timer.getTime() - (NET.matchFoundTime or 0)
    local shakeX = (NET.shakeStr and NET.shakeStr>0) and (math.random()-.5)*NET.shakeStr*2.5 or 0
    local shakeY = (NET.shakeStr and NET.shakeStr>0) and (math.random()-.5)*NET.shakeStr*2.5 or 0

    gc_push('transform')
    gc_replaceTransform(SCR.xOy)
    gc_translate(shakeX, shakeY)

    -- 2. Cyber Ambient Grid Lines
    gc_setColor(.04,.06,.12, 0.8)
    for i=0,1280,64 do
        gc_line(i,0,i,720)
    end
    for i=0,720,64 do
        gc_line(0,i,1280,i)
    end

    -- 3. Side Ambient Energy Fields
    -- Left: Cyan/Emerald
    gc_setColor(0.05, 0.18, 0.12, 0.25)
    gc_rectangle('fill', 0, 0, 480, 720)
    -- Right: Crimson/Ruby
    gc_setColor(0.20, 0.06, 0.08, 0.25)
    gc_rectangle('fill', 800, 0, 480, 720)

    -- 4. Floating Cyber Sparks
    for _,p in ipairs(particles) do
        gc_setColor(p.col[1], p.col[2], p.col[3], p.alpha)
        gc_setLineWidth(1.5)
        gc_line(p.x, p.y, p.x + p.vx * 0.08, p.y + p.vy * 0.08)
    end

    -- 5. Shockwave Rings
    for i=1,3 do
        local t = math.min(math.max(0, elapsed - i*0.12) / 1.3, 1)
        local r = 60 + t * 580
        local a = (1 - t) * 0.20
        gc_setLineWidth(2)
        gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], a)
        gc_circle('line', 640, 340, r, 64)
    end

    -- 6. Initial Opening Flash & Diagonal Slash
    local flashT = math.min(elapsed / 0.25, 1)
    if flashT < 1 then
        local flashA = (1 - flashT) * 0.45
        gc_setColor(1, 1, 1, flashA)
        gc_rectangle('fill', 0, 0, 1280, 720)
    end

    local slashT = math.min(elapsed / 0.40, 1)
    if slashT < 1 then
        local sA = (1 - slashT) * 0.85
        gc_setColor(0.95, 0.85, 0.40, sA)
        gc_setLineWidth(6 * (1 - slashT))
        gc_line(0, 580, 1280, 100)
    end

    -- Player Data
    local myName = (USER and USER.uid and USERS.getUsername(USER.uid)) or "You"
    local oppName = NET.matchFoundOppName
    if (not oppName or oppName == "Opponent" or oppName == "Player") and NET.matchFoundOppId then
        local un = USERS.getUsername(NET.matchFoundOppId)
        if un and un ~= "" and un ~= "Player" then oppName = un end
    end
    oppName = oppName or "Opponent"

    local myElo = (USER and USER.uid and STAT.elo) or 1200
    local oppElo = NET.matchFoundOppElo or 1200

    local myTierName, myTierCol, myTierSub = getTierInfo(myElo)
    local oppTierName, oppTierCol, oppTierSub = getTierInfo(oppElo)

    -- Animation easing curves
    local slideT = math.min(elapsed / 0.70, 1)
    local slideEase = 1 - (1 - slideT)^3 -- Smooth cubic out

    local vsIntroT = math.min(math.max(0, elapsed - 0.20) / 0.60, 1)
    local vsEase = 1 - (1 - vsIntroT)^3

    local cardW, cardH = 440, 276
    local cardY = 202

    -- 7. Left Card: PLAYER 1 (YOU)
    local myTargetX = 120
    local myX = myTargetX - (1 - slideEase) * 660

    -- Glass backdrop
    gc_setColor(.04, .08, .15, 0.95)
    gc_rectangle('fill', myX, cardY, cardW, cardH, 12)
    gc_setColor(.25, .85, .50, 0.85 * slideEase)
    gc_setLineWidth(1.8)
    gc_rectangle('line', myX, cardY, cardW, cardH, 12)

    -- Header Ribbon
    gc_setColor(.08, .26, .16, 0.95)
    gc_rectangle('fill', myX, cardY, cardW, 46, 12)
    gc_rectangle('fill', myX, cardY + 30, cardW, 16)
    gc_setColor(.30, .95, .55, 0.9)
    gc_setLineWidth(1)
    gc_line(myX, cardY + 46, myX + cardW, cardY + 46)

    setFont(15)
    gc_setColor(.40, 1.0, .65, 1)
    gc_printf("★  PLAYER 1 (YOU)", myX + 20, cardY + 14, cardW - 40, 'left')
    setFont(12)
    gc_setColor(.75, .95, .85, .85)
    gc_printf("HOST", myX + 20, cardY + 16, cardW - 40, 'right')

    -- Player Name
    setFont(34)
    gc_setColor(1, 1, 1, 1)
    gc_printf(myName, myX + 20, cardY + 68, cardW - 40, 'center')

    -- Rating Box
    local rBoxY = cardY + 126
    gc_setColor(.07, .12, .22, .90)
    gc_rectangle('fill', myX + 24, rBoxY, cardW - 48, 64, 8)
    gc_setColor(.25, .45, .75, .55)
    gc_setLineWidth(1)
    gc_rectangle('line', myX + 24, rBoxY, cardW - 48, 64, 8)

    setFont(22)
    gc_setColor(myTierCol[1], myTierCol[2], myTierCol[3], 1)
    gc_printf(tostring(myElo) .. " ELO", myX + 24, rBoxY + 10, cardW - 48, 'center')

    setFont(13)
    gc_setColor(.85, .90, 1.0, .85)
    gc_printf(myTierSub .. "  •  " .. myTierName, myX + 24, rBoxY + 38, cardW - 48, 'center')

    -- Lower Status Tag
    setFont(12)
    gc_setColor(.55, .80, 1.0, .85)
    gc_printf("✔ Verified Client  •  Ranked Battle", myX + 20, cardY + 234, cardW - 40, 'center')

    -- 8. Right Card: PLAYER 2 (OPPONENT)
    local oppTargetX = 720
    local oppX = oppTargetX + (1 - slideEase) * 660

    -- Glass backdrop
    gc_setColor(.16, .06, .09, 0.95)
    gc_rectangle('fill', oppX, cardY, cardW, cardH, 12)
    gc_setColor(.95, .32, .30, 0.85 * slideEase)
    gc_setLineWidth(1.8)
    gc_rectangle('line', oppX, cardY, cardW, cardH, 12)

    -- Header Ribbon
    gc_setColor(.30, .09, .12, 0.95)
    gc_rectangle('fill', oppX, cardY, cardW, 46, 12)
    gc_rectangle('fill', oppX, cardY + 30, cardW, 16)
    gc_setColor(1.0, .40, .35, 0.9)
    gc_setLineWidth(1)
    gc_line(oppX, cardY + 46, oppX + cardW, cardY + 46)

    setFont(15)
    gc_setColor(1.0, .50, .45, 1)
    gc_printf("⚔  PLAYER 2 (OPPONENT)", oppX + 20, cardY + 14, cardW - 40, 'left')
    setFont(12)
    gc_setColor(1.0, .80, .75, .85)
    gc_printf("CHALLENGER", oppX + 20, cardY + 16, cardW - 40, 'right')

    -- Opponent Name
    setFont(34)
    gc_setColor(1, 1, 1, 1)
    gc_printf(oppName, oppX + 20, cardY + 68, cardW - 40, 'center')

    -- Rating Box
    gc_setColor(.20, .08, .11, .90)
    gc_rectangle('fill', oppX + 24, rBoxY, cardW - 48, 64, 8)
    gc_setColor(.75, .30, .32, .55)
    gc_setLineWidth(1)
    gc_rectangle('line', oppX + 24, rBoxY, cardW - 48, 64, 8)

    setFont(22)
    gc_setColor(oppTierCol[1], oppTierCol[2], oppTierCol[3], 1)
    gc_printf(tostring(oppElo) .. " ELO", oppX + 24, rBoxY + 10, cardW - 48, 'center')

    setFont(13)
    gc_setColor(1.0, .85, .85, .85)
    gc_printf(oppTierSub .. "  •  " .. oppTierName, oppX + 24, rBoxY + 38, cardW - 48, 'center')

    -- Lower Status Tag
    setFont(12)
    gc_setColor(1.0, .70, .70, .85)
    gc_printf("Matched via ELO Bracket", oppX + 20, cardY + 234, cardW - 40, 'center')

    -- 9. Center Versus Core (640, 340)
    local coreX, coreY = 640, 340
    local vsScale = (1.0 + 0.35 * (1 - vsEase)) * (1.0 + 0.04 * math.sin(elapsed * 6) * vsEase)

    -- Energy Slash Beam Behind VS
    local beamW = 210 * vsEase
    gc_setLineWidth(3)
    gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], 0.85 * vsEase)
    gc_line(coreX - beamW, coreY, coreX + beamW, coreY)

    -- Concentric Energy Ring
    for i=1,2 do
        local ringR = 64 + i*22 + 5 * math.sin(elapsed * (3 + i)) * vsEase
        local ringA = vsEase * (0.35 - i*0.1)
        gc_setLineWidth(2.5 - i*0.5)
        gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], ringA)
        gc_circle('line', coreX, coreY, ringR, 48)
    end

    -- Center VS Badge
    gc_push('transform')
    gc_translate(coreX, coreY)
    gc_scale(vsScale, vsScale)

    -- Dark circular emblem
    gc_setColor(.05, .07, .15, 0.95 * vsEase)
    gc_circle('fill', 0, 0, 52, 48)
    gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], 0.9 * vsEase)
    gc_setLineWidth(2.2)
    gc_circle('line', 0, 0, 52, 48)

    setFont(44)
    gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], vsEase)
    gc_printf("VS", -100, -25, 200, 'center')
    gc_pop()

    -- 10. Top Title Banner
    local titleT = math.min(math.max(0, elapsed - 0.15) / 0.5, 1)
    local titleEase = 1 - (1 - titleT)^3
    setFont(32)
    gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], 0.60 + 0.40 * titleEase)
    gc_printf("⚔  RANKED 1v1 MATCH FOUND  ⚔", 0, 72, 1280, 'center')

    -- Glowing underline under title
    local titleLineW = 360 * titleEase
    gc_setLineWidth(2)
    gc_setColor(COLOR.Z[1], COLOR.Z[2], COLOR.Z[3], 0.75 * titleEase)
    gc_line(640 - titleLineW, 118, 640 + titleLineW, 118)

    -- 11. Bottom Starting Timer & Status Bar
    local cd = math.max(0, NET.matchFoundCountdown or 0)
    local prog = math.min(math.max(0, (10.0 - cd) / 10.0), 1)

    local barW, barH = 520, 10
    local barX = 640 - barW * 0.5
    local barY = 560
    gc_setColor(.10, .14, .25, .85)
    gc_rectangle('fill', barX, barY, barW, barH, 5)
    gc_setColor(COLOR.lY[1], COLOR.lY[2], COLOR.lY[3], .95)
    gc_rectangle('fill', barX, barY, barW * prog, barH, 5)

    setFont(24)
    gc_setColor(COLOR.lY[1], COLOR.lY[2], COLOR.lY[3], 0.95 * vsEase)
    gc_printf(string.format("Entering Arena in %.1fs...", cd), 0, 520, 1280, 'center')

    setFont(13)
    gc_setColor(.70, .80, .95, .85)
    gc_printf("First to 3 Wins (Best of 5)  •  Identical Bag Seeds  •  Press [Esc] to Cancel Matchmaking", 0, 582, 1280, 'center')

    gc_pop()
end

return scene
