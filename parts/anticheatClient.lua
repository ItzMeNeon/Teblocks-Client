local AC = {}

local lastWallTime = os.time()
local lastTimerTime = love.timer.getTime()
local warpCounter = 0
local suspiciousInputCount = 0

-- Piece lock interval samples for client-side macro detection
local lockTimes = {}
local lastLockTime = 0

function AC.reset()
    lastWallTime = os.time()
    lastTimerTime = love.timer.getTime()
    warpCounter = 0
    suspiciousInputCount = 0
    lockTimes = {}
    lastLockTime = 0
end

-- Update runs each frame to monitor clock speed consistency
function AC.update(dt)
    local nowWall = os.time()
    local nowTimer = love.timer.getTime()

    local wallDelta = nowWall - lastWallTime
    if wallDelta >= 5 then
        local timerDelta = nowTimer - lastTimerTime
        local ratio = timerDelta / wallDelta

        -- If game timer is running more than 2.0x faster than wall-clock, flag speedhack
        if ratio > 2.0 then
            warpCounter = warpCounter + 1
            if warpCounter >= 2 then
                MES.new('error', "Abnormal clock speed detected! Speed manipulation is prohibited in multiplayer.", 5)
                if WS and WS.status('game') == 'running' then
                    WS.close('game')
                end
                warpCounter = 0
            end
        else
            warpCounter = math.max(0, warpCounter - 1)
        end

        lastWallTime = nowWall
        lastTimerTime = nowTimer
    end
end

-- Feed piece lock for macro / 0-variance detection
function AC.onPieceLock()
    local t = love.timer.getTime()
    if lastLockTime > 0 then
        local interval = (t - lastLockTime) * 1000 -- ms
        table.insert(lockTimes, interval)
        if #lockTimes > 20 then
            table.remove(lockTimes, 1)
        end

        -- Check variance once 20 samples are collected
        if #lockTimes >= 20 then
            local sum = 0
            for i = 1, #lockTimes do sum = sum + lockTimes[i] end
            local mean = sum / #lockTimes

            local variance = 0
            for i = 1, #lockTimes do
                local d = lockTimes[i] - mean
                variance = variance + d * d
            end
            variance = variance / #lockTimes

            -- Variance < 4ms^2 (stddev < 2ms) indicates automated macro play
            if variance < 4 and mean < 300 then
                suspiciousInputCount = suspiciousInputCount + 1
            else
                suspiciousInputCount = math.max(0, suspiciousInputCount - 1)
            end
        end
    end
    lastLockTime = t
end

function AC.isMacroFlagged()
    return suspiciousInputCount >= 3
end

return AC
