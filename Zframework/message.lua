local ins, rem = table.insert, table.remove
local max, min = math.max, math.min

local mesList = {}
local mesIcon = {
    check = GC.DO{40, 40,
        {'setLW', 10},
        {'setCL', 0, 0, 0},
        {'line', 4, 19, 15, 30, 36, 9},
        {'setLW', 6},
        {'setCL', .7, 1, .6},
        {'line', 5, 20, 15, 30, 35, 10},
    },
    info = GC.DO{40, 40,
        {'setCL', .2, .25, .85},
        {'fCirc', 20, 20, 15},
        {'setCL', 1, 1, 1},
        {'setLW', 2},
        {'dCirc', 20, 20, 15},
        {'fRect', 18, 11, 4, 4},
        {'fRect', 18, 17, 4, 12},
    },
    broadcast = GC.DO{40, 40,
        {'setCL', 1, 1, 1},
        {'fRect', 2, 4, 36, 26, 3},
        {'fPoly', 2, 27, 2, 37, 14, 25},
        {'setCL', .5, .5, .5},
        {'fRect', 6, 11, 4, 4, 1}, {'fRect', 14, 11, 19, 4, 1},
        {'fRect', 6, 19, 4, 4, 1}, {'fRect', 14, 19, 19, 4, 1},
    },
    warn = GC.DO{40, 40,
        {'setCL', .95, .83, .4},
        {'fPoly', 20.5, 1, 0, 38, 40, 38},
        {'setCL', 0, 0, 0},
        {'dPoly', 20.5, 1, 0, 38, 40, 38},
        {'fRect', 17, 10, 7, 18, 2},
        {'fRect', 17, 29, 7, 7, 2},
        {'setCL', 1, 1, 1},
        {'fRect', 18, 11, 5, 16, 2},
        {'fRect', 18, 30, 5, 5, 2},
    },
    error = GC.DO{40, 40,
        {'setCL', .95, .3, .3},
        {'fCirc', 20, 20, 19},
        {'setCL', 0, 0, 0},
        {'dCirc', 20, 20, 19},
        {'setLW', 6},
        {'line', 10.2, 10.2, 29.8, 29.8},
        {'line', 10.2, 29.8, 29.8, 10.2},
        {'setLW', 4},
        {'setCL', 1, 1, 1},
        {'line', 11, 11, 29, 29},
        {'line', 11, 29, 29, 11},
    },
    music = GC.DO{40, 40,
        {'setLW', 2},
        {'dRect', 1, 3, 38, 34, 3},
        {'setLW', 4},
        {'line', 21, 26, 21, 10, 28, 10},
        {'fElps', 17, 26, 6, 5},
    },
}

local categoryMeta = {
    broadcast = {
        title = "SERVER ANNOUNCEMENT",
        badge = "ANNOUNCEMENT",
        color = {0.62, 0.44, 0.98, 1.0},
        bg = {0.11, 0.10, 0.18, 0.95},
    },
    check = {
        title = "SUCCESS",
        badge = "SUCCESS",
        color = {0.18, 0.82, 0.45, 1.0},
        bg = {0.08, 0.15, 0.11, 0.95},
    },
    warn = {
        title = "WARNING",
        badge = "WARNING",
        color = {0.98, 0.68, 0.12, 1.0},
        bg = {0.16, 0.13, 0.08, 0.95},
    },
    error = {
        title = "ERROR",
        badge = "ERROR",
        color = {0.94, 0.28, 0.28, 1.0},
        bg = {0.16, 0.08, 0.08, 0.95},
    },
    info = {
        title = "INFORMATION",
        badge = "INFO",
        color = {0.20, 0.65, 0.95, 1.0},
        bg = {0.08, 0.12, 0.18, 0.95},
    },
    music = {
        title = "NOW PLAYING",
        badge = "MUSIC",
        color = {0.10, 0.80, 0.70, 1.0},
        bg = {0.08, 0.15, 0.14, 0.95},
    },
    other = {
        title = "NOTIFICATION",
        badge = "NOTICE",
        color = {0.55, 0.60, 0.70, 1.0},
        bg = {0.09, 0.10, 0.14, 0.95},
    },
}

local MES = {}
MES.history = {}
MES.unreadCount = 0
MES.sidebarOpen = false
MES.sidebarX = 1280
MES.sidebarW = 380
MES.sidebarScroll = 0
MES.maxSidebarScroll = 0
MES.tabHover = false
MES.tabAnim = 0

function MES.toggleSidebar()
    if MES.sidebarOpen then
        MES.closeSidebar()
    else
        MES.openSidebar()
    end
end

function MES.openSidebar()
    MES.sidebarOpen = true
    MES.unreadCount = 0
    if CHAT and CHAT.isOpen then
        CHAT.close()
    end
end

function MES.closeSidebar()
    MES.sidebarOpen = false
end

function MES.clearHistory()
    MES.history = {}
    MES.sidebarScroll = 0
    MES.maxSidebarScroll = 0
end

function MES.new(icon, str, time)
    local iconKey = icon
    local meta = categoryMeta.other
    if type(icon) == 'string' then
        meta = categoryMeta[icon] or categoryMeta.other
        iconKey = icon
        icon = mesIcon[icon]
    end

    local line = string.format("[%s] %s: %s", os.date("%Y/%m/%d %H:%M:%S"), iconKey or "other", tostring(str))
    print(line)
    if not TEMP_MODE then
        pcall(function()
            love.filesystem.append("conf/notifications.log", line .. "\n")
        end)
    end

    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local cardW = 380
    local font = FONT.get(15)
    local _, wrappedLines = font:getWrap(tostring(str), cardW - 55)
    local lineCount = max(1, #wrappedLines)
    local cardH = max(78, 38 + lineCount * 19 + 8)

    local totalDuration = tonumber(time) or 4.5
    local timeStr = os.date("%H:%M")

    local toastItem = {
        key = iconKey,
        icon = icon,
        meta = meta,
        str = tostring(str),
        w = cardW,
        h = cardH,
        timeStr = timeStr,
        totalTime = totalDuration,
        time = totalDuration,
        startTime = 0.25,
        endTime = 0.5,
        x = screenW + 60,
        y = 75,
        targetX = screenW - cardW - 20,
        targetY = 75,
        rot = 0,
        yeeted = false,
        vx = 0,
        vy = 0,
        rotSpeed = 0,
        hovered = false,
    }

    ins(mesList, 1, toastItem)

    -- Record into persistent history (up to 50 items)
    local histItem = {
        id = os.time() .. "_" .. math.random(1000, 9999),
        key = iconKey,
        icon = icon,
        meta = meta,
        title = meta.title,
        str = tostring(str),
        time = os.time(),
        timeStr = os.date("%H:%M:%S"),
        h = cardH,
    }
    ins(MES.history, 1, histItem)
    if #MES.history > 50 then
        rem(MES.history, #MES.history)
    end

    if not MES.sidebarOpen then
        MES.unreadCount = MES.unreadCount + 1
    end
end

function MES.yeet(idx, flickVx, flickVy)
    local m = mesList[idx]
    if not m or m.yeeted then return end
    m.yeeted = true
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    m.targetX = screenW + m.w + 60
    m.endTime = 0.4
    if flickVx and math.abs(flickVx) > 50 then
        m.vx = flickVx
        m.vy = flickVy or -100
        m.rotSpeed = (flickVx > 0 and 1 or -1) * 6
    end
    if SFX and SFX.play then
        pcall(SFX.play, 'reach')
    end
end

function MES.mouseDown(rawX, rawY, k)
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = rawX / kScale
    local my = rawY / kScale
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local screenH = SCR.h > 0 and (SCR.h / SCR.k) or 720

    -- 1. Check Notification Tab click
    local tabW, tabH = 36, 85
    local tabY = 360
    local tabX = screenW - tabW - (MES.tabAnim * 10)
    if mx >= tabX and mx <= screenW and my >= tabY and my <= tabY + tabH then
        MES.toggleSidebar()
        if SFX and SFX.play then pcall(SFX.play, 'click') end
        return true
    end

    -- 2. Check Notification Sidebar interactions if open
    if MES.sidebarOpen and MES.sidebarX < screenW - 10 then
        -- Inside sidebar container
        if mx >= MES.sidebarX and mx <= screenW and my >= 0 and my <= screenH then
            -- Close button
            if mx >= screenW - 38 and mx <= screenW - 10 and my >= 12 and my <= 40 then
                MES.closeSidebar()
                if SFX and SFX.play then pcall(SFX.play, 'click') end
                return true
            end
            -- Clear all button
            if mx >= screenW - 110 and mx <= screenW - 44 and my >= 14 and my <= 38 then
                MES.clearHistory()
                if SFX and SFX.play then pcall(SFX.play, 'click') end
                return true
            end
            -- Check delete individual notification items
            local curItemY = 65 - MES.sidebarScroll
            for i = 1, #MES.history do
                local item = MES.history[i]
                if my >= curItemY and my <= curItemY + item.h then
                    -- Delete 'x' on right of history card
                    if mx >= screenW - 36 and mx <= screenW - 14 and my >= curItemY + 8 and my <= curItemY + 28 then
                        rem(MES.history, i)
                        if SFX and SFX.play then pcall(SFX.play, 'click') end
                        return true
                    end
                end
                curItemY = curItemY + item.h + 10
            end
            return true
        else
            -- Clicked outside sidebar: close it
            MES.closeSidebar()
            return true
        end
    end

    -- 3. Check Live Toast Toasts
    for i = 1, #mesList do
        local m = mesList[i]
        if not m.yeeted then
            if mx >= m.x and mx <= m.x + m.w and my >= m.y and my <= m.y + m.h then
                -- Check close button '✕'
                if mx >= m.x + m.w - 32 and mx <= m.x + m.w - 8 and my >= m.y + 8 and my <= m.y + 32 then
                    MES.yeet(i)
                    return true
                else
                    -- Clicking toast body opens the Notification Sidebar
                    MES.openSidebar()
                    MES.yeet(i)
                    return true
                end
            end
        end
    end

    return false
end

function MES.mouseMove(rawX, rawY, dx, dy)
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = rawX / kScale
    local my = rawY / kScale
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280

    -- Check tab hover
    local tabW, tabH = 36, 85
    local tabY = 360
    local tabX = screenW - tabW - 12
    MES.tabHover = (mx >= tabX and mx <= screenW and my >= tabY and my <= tabY + tabH)

    -- Check toast hover
    for i = 1, #mesList do
        local m = mesList[i]
        m.hovered = not m.yeeted and (mx >= m.x and mx <= m.x + m.w and my >= m.y and my <= m.y + m.h)
    end
end

function MES.mouseUp(rawX, rawY, k)
    return false
end

function MES.wheelMoved(x, y)
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = love.mouse.getX() / kScale
    local my = love.mouse.getY() / kScale
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280

    if MES.sidebarOpen and mx >= MES.sidebarX and mx <= screenW then
        MES.sidebarScroll = max(0, min(MES.sidebarScroll - y * 45, MES.maxSidebarScroll))
        return true
    end
    return false
end

function MES.keyDown(key, isRep)
    if key == 'escape' and MES.sidebarOpen then
        MES.closeSidebar()
        return true
    end
    return false
end

function MES.update(dt)
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local screenH = SCR.h > 0 and (SCR.h / SCR.k) or 720

    -- Tab hover animation
    MES.tabAnim = MATH.expApproach(MES.tabAnim, MES.tabHover and 1 or 0, dt * 16)

    -- Sidebar slide animation
    local sidebarTargetX = MES.sidebarOpen and (screenW - MES.sidebarW) or screenW
    MES.sidebarX = MATH.expApproach(MES.sidebarX, sidebarTargetX, dt * 18)

    -- Compute max scroll for sidebar
    local totalHistH = 0
    for i = 1, #MES.history do
        totalHistH = totalHistH + MES.history[i].h + 10
    end
    MES.maxSidebarScroll = max(0, totalHistH - (screenH - 80))

    -- Update live toasts (stacking from top right downwards)
    local curY = 75
    for i = #mesList, 1, -1 do
        local m = mesList[i]
        if m.yeeted then
            if m.vx ~= 0 or m.vy ~= 0 then
                m.x = m.x + m.vx * dt
                m.vy = m.vy + 1800 * dt
                m.y = m.y + m.vy * dt
                m.rot = m.rot + m.rotSpeed * dt
            else
                m.x = MATH.expApproach(m.x, m.targetX, dt * 16)
            end
            m.endTime = m.endTime - dt
            if m.endTime <= 0 or m.x > screenW + 200 then
                rem(mesList, i)
            end
        else
            if m.startTime > 0 then
                m.startTime = max(0, m.startTime - dt)
            elseif not m.hovered then
                -- Only decrement timer when not hovered so player can read comfortably
                m.time = max(0, m.time - dt)
                if m.time <= 0 then
                    MES.yeet(i)
                end
            end

            local targetX = screenW - m.w - 20
            local targetY = curY
            curY = curY + m.h + 10

            m.x = MATH.expApproach(m.x, targetX, dt * 18)
            m.y = MATH.expApproach(m.y, targetY, dt * 18)
        end
    end
end

function MES.draw()
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local screenH = SCR.h > 0 and (SCR.h / SCR.k) or 720
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = love.mouse.getX() / kScale
    local my = love.mouse.getY() / kScale

    -- 1. Draw Notification Tab on right edge (when sidebar is closed)
    if not MES.sidebarOpen then
        local tabW, tabH = 36, 85
        local tabY = 360
        local tabX = screenW - tabW - (MES.tabAnim * 8)

        GC.push('transform')
        -- Tab background
        if MES.tabHover then
            GC.setColor(0.18, 0.20, 0.28, 0.96)
        else
            GC.setColor(0.11, 0.12, 0.18, 0.90)
        end
        GC.rectangle('fill', tabX, tabY, tabW + 10, tabH, 8, 0, 0, 8)

        -- Tab border
        GC.setColor(0.40, 0.44, 0.60, MES.tabHover and 0.9 or 0.5)
        GC.setLineWidth(1.5)
        GC.rectangle('line', tabX, tabY, tabW + 10, tabH, 8, 0, 0, 8)

        -- Left accent line
        GC.setColor(0.60, 0.45, 0.98, 0.9)
        GC.rectangle('fill', tabX, tabY + 8, 3, tabH - 16, 2)

        -- Tab bell icon / text
        GC.setColor(1, 1, 1, 0.95)
        FONT.set(16)
        GC.printf("🔔", tabX + 4, tabY + 12, tabW, 'center')
        FONT.set(11)
        GC.printf("N\nO\nT\nI\nF", tabX + 6, tabY + 34, tabW, 'center')

        -- Unread badge
        if MES.unreadCount > 0 then
            local badgeCount = tostring(min(MES.unreadCount, 99))
            local bw = max(18, #badgeCount * 8 + 8)
            GC.setColor(0.95, 0.30, 0.30, 0.98)
            GC.rectangle('fill', tabX - 6, tabY - 6, bw, 18, 9)
            GC.setColor(1, 1, 1, 1)
            FONT.set(10)
            GC.printf(badgeCount, tabX - 6, tabY - 3, bw, 'center')
        end
        GC.pop()
    end

    -- 2. Draw Live Toast Notifications (Sliding from Right to Left)
    for i = 1, #mesList do
        local m = mesList[i]
        local a = 1.0
        if m.yeeted then
            a = max(0, min(1, m.endTime / 0.4))
        elseif m.startTime > 0 then
            a = max(0, min(1, (0.25 - m.startTime) / 0.25))
        end

        local isHov = m.hovered and not m.yeeted

        GC.push('transform')
        if m.rot ~= 0 then
            GC.translate(m.x + m.w * 0.5, m.y + m.h * 0.5)
            GC.rotate(m.rot)
            GC.translate(-m.w * 0.5, -m.h * 0.5)
        else
            GC.translate(m.x, m.y)
        end

        -- Drop Shadow
        GC.setColor(0, 0, 0, 0.45 * a)
        GC.rectangle('fill', 2, 4, m.w, m.h, 8)

        -- Card Background (Dark Glass Acrylic)
        local bg = m.meta.bg or {0.10, 0.11, 0.16, 0.94}
        if isHov then
            GC.setColor(bg[1] * 1.3, bg[2] * 1.3, bg[3] * 1.3, 0.98 * a)
        else
            GC.setColor(bg[1], bg[2], bg[3], bg[4] * a)
        end
        GC.rectangle('fill', 0, 0, m.w, m.h, 8)

        -- Left Accent Color Stripe
        local clr = m.meta.color
        GC.setColor(clr[1], clr[2], clr[3], 0.98 * a)
        GC.rectangle('fill', 0, 0, 5, m.h, 4, 0, 0, 4)

        -- Outline Border
        if isHov then
            GC.setColor(clr[1], clr[2], clr[3], 0.85 * a)
            GC.setLineWidth(1.8)
        else
            GC.setColor(0.30, 0.34, 0.45, 0.55 * a)
            GC.setLineWidth(1.2)
        end
        GC.rectangle('line', 0, 0, m.w, m.h, 8)

        -- Header Row: Category Badge & Title
        FONT.set(12)
        GC.setColor(clr[1], clr[2], clr[3], 0.98 * a)
        local badgeText = m.meta.title or "NOTIFICATION"
        GC.print(badgeText, 16, 12)

        -- Timestamp
        FONT.set(11)
        GC.setColor(0.65, 0.68, 0.75, 0.70 * a)
        GC.print(m.timeStr, m.w - 65, 12)

        -- Close '✕' button
        local closeHov = isHov and (mx >= m.x + m.w - 30 and mx <= m.x + m.w - 8 and my >= m.y + 8 and my <= m.y + 28)
        if closeHov then
            GC.setColor(0.9, 0.25, 0.25, 0.9 * a)
            GC.circle('fill', m.w - 18, 18, 9)
            GC.setColor(1, 1, 1, a)
        else
            GC.setColor(0.60, 0.64, 0.72, 0.65 * a)
        end
        FONT.set(11)
        GC.printf("✕", m.w - 24, 11, 12, 'center')

        -- Message Body
        FONT.set(15)
        GC.setColor(0.94, 0.95, 0.98, 0.95 * a)
        GC.printf(m.str, 16, 34, m.w - 36, 'left')

        -- Bottom Progress Timer Bar
        if not m.yeeted and m.totalTime > 0 then
            local pct = max(0, min(1, m.time / m.totalTime))
            GC.setColor(clr[1], clr[2], clr[3], (isHov and 0.95 or 0.75) * a)
            GC.rectangle('fill', 5, m.h - 2.5, (m.w - 5) * pct, 2.5, 0, 0, 2, 0)
        end

        GC.pop()
    end

    -- 3. Draw Notification Sidebar (osu!-style Drawer on Right)
    if MES.sidebarX < screenW then
        local openRatio = (screenW - MES.sidebarX) / MES.sidebarW

        -- Dimmed Backdrop
        GC.setColor(0, 0, 0, 0.40 * openRatio)
        GC.rectangle('fill', 0, 0, screenW, screenH)

        GC.push('transform')
        GC.translate(MES.sidebarX, 0)

        -- Sidebar Container Background
        GC.setColor(0.09, 0.10, 0.15, 0.97)
        GC.rectangle('fill', 0, 0, MES.sidebarW, screenH)

        -- Left Border Glow Line
        GC.setColor(0.62, 0.44, 0.98, 0.85)
        GC.rectangle('fill', 0, 0, 3, screenH)

        -- Header Area (y = 0..55)
        GC.setColor(0.12, 0.14, 0.20, 0.98)
        GC.rectangle('fill', 3, 0, MES.sidebarW - 3, 55)

        GC.setColor(0.25, 0.28, 0.38, 0.6)
        GC.setLineWidth(1)
        GC.line(3, 55, MES.sidebarW, 55)

        -- Header Title & Icon
        FONT.set(18)
        GC.setColor(1, 1, 1, 0.98)
        GC.print("🔔 NOTIFICATIONS", 16, 17)

        -- Count Pill
        local countStr = tostring(#MES.history)
        local countW = max(24, #countStr * 9 + 10)
        GC.setColor(0.20, 0.24, 0.35, 0.9)
        GC.rectangle('fill', 195, 18, countW, 20, 10)
        GC.setColor(0.85, 0.88, 0.95, 0.95)
        FONT.set(12)
        GC.printf(countStr, 195, 20, countW, 'center')

        -- Clear All Button
        local clearHov = (mx >= screenW - 110 and mx <= screenW - 44 and my >= 14 and my <= 38)
        if clearHov then
            GC.setColor(0.85, 0.25, 0.25, 0.95)
        else
            GC.setColor(0.25, 0.28, 0.38, 0.85)
        end
        GC.rectangle('fill', MES.sidebarW - 110, 16, 62, 24, 6)
        GC.setColor(1, 1, 1, 0.95)
        FONT.set(12)
        GC.printf("Clear", MES.sidebarW - 110, 20, 62, 'center')

        -- Close '✕' Button
        local closeSideHov = (mx >= screenW - 38 and mx <= screenW - 10 and my >= 12 and my <= 40)
        if closeSideHov then
            GC.setColor(0.9, 0.3, 0.3, 0.95)
        else
            GC.setColor(0.40, 0.44, 0.55, 0.7)
        end
        FONT.set(18)
        GC.printf("✕", MES.sidebarW - 36, 16, 26, 'center')

        -- Scrollable History Content
        GC.setScissor(MES.sidebarX * kScale, 56 * kScale, MES.sidebarW * kScale, (screenH - 56) * kScale)

        if #MES.history == 0 then
            FONT.set(16)
            GC.setColor(0.55, 0.58, 0.68, 0.7)
            GC.printf("No notifications yet", 20, 220, MES.sidebarW - 40, 'center')
            FONT.set(12)
            GC.setColor(0.40, 0.44, 0.52, 0.6)
            GC.printf("System announcements and alerts will be logged here.", 20, 245, MES.sidebarW - 40, 'center')
        else
            local curY = 65 - MES.sidebarScroll
            for i = 1, #MES.history do
                local item = MES.history[i]
                local cardW = MES.sidebarW - 24
                local itemHov = (mx >= MES.sidebarX + 12 and mx <= screenW - 12 and my >= curY and my <= curY + item.h)

                -- History Card Fill
                local bg = item.meta.bg or {0.12, 0.13, 0.18, 0.92}
                if itemHov then
                    GC.setColor(bg[1] * 1.25, bg[2] * 1.25, bg[3] * 1.25, 0.96)
                else
                    GC.setColor(bg[1], bg[2], bg[3], 0.90)
                end
                GC.rectangle('fill', 12, curY, cardW, item.h, 6)

                -- Left Accent Strip
                local clr = item.meta.color
                GC.setColor(clr[1], clr[2], clr[3], 0.95)
                GC.rectangle('fill', 12, curY, 4, item.h, 4, 0, 0, 4)

                -- Card Border
                GC.setColor(0.25, 0.28, 0.38, itemHov and 0.8 or 0.4)
                GC.setLineWidth(1)
                GC.rectangle('line', 12, curY, cardW, item.h, 6)

                -- Card Badge Title
                FONT.set(12)
                GC.setColor(clr[1], clr[2], clr[3], 0.95)
                GC.print(item.title or "NOTIFICATION", 24, curY + 10)

                -- Card Timestamp
                FONT.set(11)
                GC.setColor(0.60, 0.64, 0.72, 0.75)
                GC.print(item.timeStr, cardW - 55, curY + 10)

                -- Delete item '✕'
                local delHov = (mx >= screenW - 36 and mx <= screenW - 14 and my >= curY + 6 and my <= curY + 26)
                if delHov then
                    GC.setColor(0.9, 0.3, 0.3, 0.95)
                else
                    GC.setColor(0.50, 0.54, 0.62, 0.5)
                end
                FONT.set(10)
                GC.printf("✕", cardW - 10, curY + 9, 14, 'center')

                -- Card Message Text
                FONT.set(14)
                GC.setColor(0.92, 0.93, 0.96, 0.95)
                GC.printf(item.str, 24, curY + 30, cardW - 30, 'left')

                curY = curY + item.h + 10
            end
        end

        GC.setScissor()
        GC.pop()
    end
end

function MES.traceback()
    local mes = debug.traceback('', 1)
        :gsub(': in function', ', in')
        :gsub(':', ' ')
        :gsub('\t', '')
    MES.new('error', mes:sub(
        mes:find("\n", 2) + 1,
        mes:find("\n%[C%], in 'xpcall'")
    ), 5)
end

return MES
