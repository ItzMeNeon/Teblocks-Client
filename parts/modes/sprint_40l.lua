local defaultEnv = {
    drop = 60,
    lock = 60,
    eventSet = 'checkLine_40',
    bg = 'bg2',
    bgm = 'race',
}

return {
    env = defaultEnv,
    load = function()
        if not GAME.replaying then
            local today = os.date("!%Y-%m-%d")
            local challenge = NET.dailyChallenge
            if not challenge or challenge.date ~= today then
                challenge = NET.generateOfflineDailyChallenge(today)
                NET.dailyChallenge = challenge
            end

            GAME.seed = challenge.seed
            GAME.modeEnv.seqData = TABLE.copy(challenge.seqData)
            GAME.modeEnv.sequence = challenge.sequence
            GAME.dailyDate = challenge.date
            GAME.dailyTitle = challenge.title
            GAME.dailyDesc = challenge.description
        end

        local title = GAME.dailyTitle or "Daily Sprint"
        local date = GAME.dailyDate or os.date("!%Y-%m-%d")
        if TEXTOBJ and TEXTOBJ.modeName then
            if GAME.replaying then
                TEXTOBJ.modeName:set("Daily Replay   " .. title .. " (" .. date .. ")")
            else
                TEXTOBJ.modeName:set("Daily Challenge   " .. title)
            end
        end

        PLY.newPlayer(1)
    end,
    savePrivate = function()
        return {
            date = GAME.dailyDate or os.date("!%Y-%m-%d"),
            seed = GAME.seed,
            seqData = GAME.modeEnv and TABLE.copy(GAME.modeEnv.seqData),
            sequence = GAME.modeEnv and GAME.modeEnv.sequence,
            title = GAME.dailyTitle,
            desc = GAME.dailyDesc,
            targetLines = 40,
        }
    end,
    loadPrivate = function(p)
        if not p then return end
        GAME.dailyDate = p.date
        GAME.seed = p.seed
        if GAME.modeEnv then
            if p.seqData then GAME.modeEnv.seqData = TABLE.copy(p.seqData) end
            if p.sequence then GAME.modeEnv.sequence = p.sequence end
        end
        GAME.dailyTitle = p.title
        GAME.dailyDesc = p.desc
        if TEXTOBJ and TEXTOBJ.modeName then
            TEXTOBJ.modeName:set("Daily Replay   " .. (p.title or "Sprint") .. " (" .. (p.date or "") .. ")")
        end
    end,
    score = function(P) return {P.stat.time, P.stat.piece} end,
    scoreDisp = function(D) return STRING.time(D[1]) .. "   " .. D[2] .. " Pieces" end,
    comp = function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end,
    getRank = function(P)
        if P.stat.row < 40 then return end
        local T = P.stat.time
        return
            T <= 26 and 5 or
            T <= 36 and 4 or
            T <= 52.6 and 3 or
            T <= 92.9 and 2 or
            T <= 183 and 1 or
            0
    end,
}
