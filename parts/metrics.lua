local gc = love.graphics
local max, min = math.max, math.min

local METRICS = {}

-- Modes: 0 = Off, 1 = Compact (Bottom-Left), 2 = Detailed (Bottom-Left)
METRICS.mode = 1

METRICS.fps = 60
METRICS.frameTimeMs = 16.6
METRICS.avgFrameTimeMs = 16.6
METRICS.minFps = 60
METRICS.maxFps = 60
METRICS.drawCalls = 0
METRICS.canvasSwitches = 0
METRICS.textureMemMB = 0
METRICS.imagesCount = 0
METRICS.canvasesCount = 0
METRICS.fontsCount = 0
METRICS.luaMemMB = 0
METRICS.activeAudios = 0
METRICS.tasksCount = 0

-- Rolling history for frame times (60 frames)
METRICS.history = {}
METRICS.maxHistory = 60
for i = 1, METRICS.maxHistory do
    METRICS.history[i] = 16.6
end

METRICS.updateTimer = 0

function METRICS.toggle()
    METRICS.mode = (METRICS.mode + 1) % 3
    if SFX and SFX.play then
        pcall(SFX.play, 'click')
    end
    if MES and MES.new then
        local modeNames = {
            [0] = "Metrics: OFF",
            [1] = "Metrics: COMPACT (Bottom-Left)",
            [2] = "Metrics: DETAILED",
        }
        MES.new('info', modeNames[METRICS.mode] or "Metrics Toggled", 1.5)
    end
end

function METRICS.update(dt)
    if dt <= 0 then dt = 1 / 60 end

    local currentMs = dt * 1000
    METRICS.frameTimeMs = currentMs
    METRICS.avgFrameTimeMs = METRICS.avgFrameTimeMs * 0.92 + currentMs * 0.08
    METRICS.fps = love.timer.getFPS()

    -- Shift history
    table.remove(METRICS.history, 1)
    table.insert(METRICS.history, currentMs)

    -- Refresh slower stats every 0.25 seconds to reduce overhead
    METRICS.updateTimer = METRICS.updateTimer + dt
    if METRICS.updateTimer >= 0.25 then
        METRICS.updateTimer = 0

        -- Lua memory
        METRICS.luaMemMB = collectgarbage("count") / 1024

        -- Graphics stats
        if love.graphics.getStats then
            local stats = love.graphics.getStats()
            METRICS.drawCalls = stats.drawcalls or 0
            METRICS.canvasSwitches = stats.canvasswitches or 0
            METRICS.textureMemMB = (stats.texturememory or 0) / (1024 * 1024)
            METRICS.imagesCount = stats.images or 0
            METRICS.canvasesCount = stats.canvases or 0
            METRICS.fontsCount = stats.fonts or 0
        end

        -- Audio sources
        if love.audio then
            if love.audio.getActiveSourceCount then
                METRICS.activeAudios = love.audio.getActiveSourceCount()
            elseif love.audio.getSourceCount then
                METRICS.activeAudios = love.audio.getSourceCount()
            end
        end

        -- Tasks
        if TASK and TASK.getCount then
            METRICS.tasksCount = TASK.getCount()
        end
    end
end

function METRICS.keyDown(key)
    if key == 'f7' then
        METRICS.toggle()
        return true
    end
    return false
end

function METRICS.draw()
    if METRICS.mode == 0 then return end

    local kScale = (SCR.k > 0 and SCR.k or 1)
    local safeX = (SCR.safeX or 0) / kScale

    -- Color coding based on FPS
    local fpsClr
    if METRICS.fps >= 55 then
        fpsClr = {0.18, 0.85, 0.45, 1.0} -- Green
    elseif METRICS.fps >= 30 then
        fpsClr = {0.98, 0.75, 0.15, 1.0} -- Yellow
    else
        fpsClr = {0.95, 0.30, 0.30, 1.0} -- Red
    end

    if METRICS.mode == 1 then
        -- ================= COMPACT MODE (Bottom-Left) =================
        local cardW = 240
        local cardH = 54
        local cardX = safeX + 8
        local cardY = -cardH - 8

        GC.push('transform')

        -- Card background (dark translucent acrylic)
        GC.setColor(0.08, 0.09, 0.13, 0.88)
        GC.rectangle('fill', cardX, cardY, cardW, cardH, 6)

        -- Left accent line (color-coded to FPS)
        GC.setColor(fpsClr[1], fpsClr[2], fpsClr[3], 0.95)
        GC.rectangle('fill', cardX, cardY, 4, cardH, 4, 0, 0, 4)

        -- Border
        GC.setColor(0.28, 0.32, 0.42, 0.5)
        GC.setLineWidth(1)
        GC.rectangle('line', cardX, cardY, cardW, cardH, 6)

        -- Line 1: FPS and Frame Time
        FONT.set(18)
        GC.setColor(fpsClr[1], fpsClr[2], fpsClr[3], 0.98)
        local fpsStr = tostring(METRICS.fps)
        GC.print(fpsStr, cardX + 12, cardY + 6)

        FONT.set(11)
        GC.setColor(0.60, 0.64, 0.75, 0.85)
        local fpsW = FONT.get(18):getWidth(fpsStr)
        GC.print("FPS", cardX + 14 + fpsW, cardY + 12)

        -- Frame Time (ms)
        FONT.set(12)
        GC.setColor(0.35, 0.75, 1.0, 0.9)
        local msStr = string.format("%.1f ms", METRICS.avgFrameTimeMs)
        GC.print(msStr, cardX + 70 + fpsW, cardY + 11)

        -- Shortcut hint [F7]
        FONT.set(9)
        GC.setColor(0.50, 0.54, 0.65, 0.6)
        GC.print("[F7]", cardX + cardW - 28, cardY + 8)

        -- Line 2: Render & Memory Stats
        FONT.set(11)
        GC.setColor(0.85, 0.88, 0.94, 0.9)
        local line2 = string.format("R: %d calls · %.1f MB | M: %.1f MB",
            METRICS.drawCalls,
            METRICS.textureMemMB,
            METRICS.luaMemMB
        )
        GC.print(line2, cardX + 12, cardY + 32)

        GC.pop()

    elseif METRICS.mode == 2 then
        -- ================= DETAILED MODE (Bottom-Left) =================
        local cardW = 320
        local cardH = 195
        local cardX = safeX + 8
        local cardY = -cardH - 8

        GC.push('transform')

        -- Card background
        GC.setColor(0.07, 0.08, 0.12, 0.94)
        GC.rectangle('fill', cardX, cardY, cardW, cardH, 8)

        -- Left accent stripe
        GC.setColor(fpsClr[1], fpsClr[2], fpsClr[3], 0.95)
        GC.rectangle('fill', cardX, cardY, 4, cardH, 4, 0, 0, 4)

        -- Card border
        GC.setColor(0.30, 0.35, 0.48, 0.6)
        GC.setLineWidth(1)
        GC.rectangle('line', cardX, cardY, cardW, cardH, 8)

        -- Header row
        FONT.set(12)
        GC.setColor(1, 1, 1, 0.95)
        GC.print("📊 PERFORMANCE METRICS", cardX + 12, cardY + 8)

        FONT.set(10)
        GC.setColor(0.55, 0.60, 0.72, 0.75)
        GC.print("[DETAILED · F7]", cardX + cardW - 85, cardY + 9)

        -- Divider
        GC.setColor(0.25, 0.28, 0.38, 0.5)
        GC.line(cardX + 4, cardY + 26, cardX + cardW, cardY + 26)

        -- Row 1: FPS & Frame Time
        FONT.set(20)
        GC.setColor(fpsClr[1], fpsClr[2], fpsClr[3], 0.98)
        local fpsStr = tostring(METRICS.fps)
        GC.print(fpsStr, cardX + 12, cardY + 32)

        FONT.set(11)
        GC.setColor(0.60, 0.65, 0.75, 0.85)
        local fpsW = FONT.get(20):getWidth(fpsStr)
        GC.print("FPS", cardX + 14 + fpsW, cardY + 39)

        FONT.set(12)
        GC.setColor(0.35, 0.75, 1.0, 0.95)
        local msStr = string.format("avg: %.1f ms (%.1f ms)", METRICS.avgFrameTimeMs, METRICS.frameTimeMs)
        GC.print(msStr, cardX + 70 + fpsW, cardY + 38)

        -- Row 2: Sparkline Frame Time Graph (height = 32px)
        local graphX = cardX + 12
        local graphY = cardY + 62
        local graphW = cardW - 24
        local graphH = 32

        -- Graph background box
        GC.setColor(0.11, 0.12, 0.18, 0.85)
        GC.rectangle('fill', graphX, graphY, graphW, graphH, 4)
        GC.setColor(0.22, 0.25, 0.35, 0.4)
        GC.rectangle('line', graphX, graphY, graphW, graphH, 4)

        -- 16.6ms Target line (60 FPS)
        local line16Y = graphY + graphH - (16.6 / 40.0 * graphH)
        GC.setColor(0.20, 0.65, 0.95, 0.35)
        GC.setLineWidth(1)
        GC.line(graphX, line16Y, graphX + graphW, line16Y)

        -- Draw sparkline bars
        local barW = graphW / METRICS.maxHistory
        for i = 1, #METRICS.history do
            local ms = METRICS.history[i]
            local barH = min(graphH - 2, max(2, (ms / 40.0) * graphH))
            local bx = graphX + (i - 1) * barW
            local by = graphY + graphH - barH

            if ms <= 17.5 then
                GC.setColor(0.18, 0.82, 0.45, 0.75) -- Green
            elseif ms <= 34.0 then
                GC.setColor(0.98, 0.75, 0.15, 0.85) -- Yellow
            else
                GC.setColor(0.95, 0.30, 0.30, 0.95) -- Red spike
            end
            GC.rectangle('fill', bx, by, max(1, barW - 0.5), barH)
        end

        -- Row 3: Graphics & Render Stats
        FONT.set(11)
        GC.setColor(0.92, 0.94, 0.98, 0.95)
        GC.print(string.format("🎨 Render: %d draw calls · %d canvas switches", METRICS.drawCalls, METRICS.canvasSwitches), cardX + 12, cardY + 102)
        GC.print(string.format("💾 VRAM: %.1f MB texture memory (%d imgs, %d cvs, %d fonts)",
            METRICS.textureMemMB,
            METRICS.imagesCount,
            METRICS.canvasesCount,
            METRICS.fontsCount
        ), cardX + 12, cardY + 120)

        -- Row 4: Memory & Engine Stats
        GC.print(string.format("🧠 Lua RAM: %.2f MB allocated (GC)", METRICS.luaMemMB), cardX + 12, cardY + 140)
        GC.print(string.format("⚙️ Engine: %d tasks · %d audio sources", METRICS.tasksCount, METRICS.activeAudios), cardX + 12, cardY + 158)

        local resStr = string.format("🖥️ Screen: %dx%d (%d%% scale)",
            math.floor(SCR.w or 1280),
            math.floor(SCR.h or 720),
            math.floor((SCR.k or 1) * 100)
        )
        FONT.set(10)
        GC.setColor(0.60, 0.65, 0.75, 0.75)
        GC.print(resStr, cardX + 12, cardY + 176)

        GC.pop()
    end
end

return METRICS
