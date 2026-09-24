local gc = love.graphics
local max, min = math.max, math.min

local SETTINGS = {}

SETTINGS.isOpen = false
SETTINGS.w = 500
SETTINGS.h = 720
SETTINGS.x = -500
SETTINGS.targetX = -500
SETTINGS.alpha = 0
SETTINGS.scrollY = 0
SETTINGS.scrollTarget = 0
SETTINGS.maxScroll = 2100
SETTINGS.activeCategory = 'gameplay'
SETTINGS.activeSlider = nil
SETTINGS.bindingAction = nil
SETTINGS.bindingActionName = nil

local keyActions = {
    { id = 1,  name = "Move Left",          sub = "Shift piece left" },
    { id = 2,  name = "Move Right",         sub = "Shift piece right" },
    { id = 6,  name = "Hard Drop",          sub = "Instantly drop & lock piece" },
    { id = 7,  name = "Soft Drop",          sub = "Accelerate downward falling" },
    { id = 3,  name = "Rotate CW",          sub = "Rotate 90° clockwise" },
    { id = 4,  name = "Rotate CCW",         sub = "Rotate 90° counter-clockwise" },
    { id = 5,  name = "Rotate 180°",        sub = "Rotate half turn (180°)" },
    { id = 8,  name = "Hold Piece",         sub = "Store current piece in hold" },
    { id = 0,  name = "Restart Game",       sub = "Instantly restart current mode" },
    { id = 11, name = "Instant (DAS) Left",  sub = "Direct sonic drop to left wall" },
    { id = 12, name = "Instant (DAS) Right", sub = "Direct sonic drop to right wall" },
    { id = 13, name = "Instant Down",       sub = "Direct sonic drop to bottom" },
    { id = 9,  name = "Function 1",         sub = "Custom game action 1" },
    { id = 10, name = "Function 2",         sub = "Custom game action 2" },
}

local keyDisplayNames = {
    up = "↑ Up", down = "↓ Down", left = "← Left", right = "→ Right",
    space = "Space", backspace = "Backspace", tab = "Tab", capslock = "Caps",
    lshift = "L Shift", rshift = "R Shift", lctrl = "L Ctrl", rctrl = "R Ctrl",
    lalt = "L Alt", ralt = "R Alt", ['return'] = "Enter", kpenter = "Num Enter",
    delete = "Del", home = "Home", ['end'] = "End", pageup = "PgUp", pagedown = "PgDn",
    escape = "Esc",
}
local function formatKey(k)
    return keyDisplayNames[k] or k:upper()
end
local function getBoundKeysString(actId)
    local list = {}
    if KEY_MAP and KEY_MAP.keyboard then
        for k, v in pairs(KEY_MAP.keyboard) do
            if v == actId then
                table.insert(list, formatKey(k))
            end
        end
    end
    if #list == 0 then return "Unbound" end
    return table.concat(list, ", ")
end

-- Categories for the left toolbar
SETTINGS.categories = {
    { id = 'gameplay', icon = "🎮", label = "Game" },
    { id = 'graphics', icon = "🎨", label = "Video" },
    { id = 'audio',    icon = "🔊", label = "Audio" },
    { id = 'controls', icon = "⚙️", label = "Handling" },
    { id = 'keys',     icon = "⌨️", label = "Keys" },
    { id = 'skin',     icon = "🎭", label = "Skin" },
}

-- Section Y positions (computed dynamically)
local sectionY = {
    gameplay = 0,
    graphics = 380,
    audio = 860,
    controls = 1280,
    keys = 1530,
    skin = 2440,
}

function SETTINGS.open(cat)
    SETTINGS.isOpen = true
    SETTINGS.targetX = 0
    if cat and sectionY[cat] then
        SETTINGS.activeCategory = cat
        SETTINGS.scrollTarget = sectionY[cat]
    end
    if CHAT and CHAT.isOpen then CHAT.close() end
    if MES and MES.sidebarOpen then MES.closeSidebar() end
end

function SETTINGS.close()
    SETTINGS.isOpen = false
    SETTINGS.targetX = -SETTINGS.w
    SETTINGS.activeSlider = nil
    SETTINGS.bindingAction = nil
    SETTINGS.bindingActionName = nil
    if saveSettings then saveSettings() end
end

function SETTINGS.toggle(cat)
    if SETTINGS.isOpen then
        SETTINGS.close()
    else
        SETTINGS.open(cat)
    end
end

function SETTINGS.scrollTo(cat)
    if sectionY[cat] then
        SETTINGS.activeCategory = cat
        SETTINGS.scrollTarget = sectionY[cat]
        if SFX and SFX.play then pcall(SFX.play, 'click') end
    end
end

function SETTINGS.update(dt)
    -- Drawer slide animation
    SETTINGS.targetX = SETTINGS.isOpen and 0 or -SETTINGS.w
    SETTINGS.x = MATH.expApproach(SETTINGS.x, SETTINGS.targetX, dt * 18)
    SETTINGS.alpha = max(0, min(1, (SETTINGS.w + SETTINGS.x) / SETTINGS.w))

    if SETTINGS.x > -SETTINGS.w + 5 then
        -- Smooth scroll animation
        SETTINGS.scrollY = MATH.expApproach(SETTINGS.scrollY, SETTINGS.scrollTarget, dt * 16)

        -- Determine active category based on current scroll position
        local sy = SETTINGS.scrollY + 60
        if sy < sectionY.graphics then
            SETTINGS.activeCategory = 'gameplay'
        elseif sy < sectionY.audio then
            SETTINGS.activeCategory = 'graphics'
        elseif sy < sectionY.controls then
            SETTINGS.activeCategory = 'audio'
        elseif sy < sectionY.keys then
            SETTINGS.activeCategory = 'controls'
        elseif sy < sectionY.skin then
            SETTINGS.activeCategory = 'keys'
        else
            SETTINGS.activeCategory = 'skin'
        end

        -- Handle active slider drag
        if SETTINGS.activeSlider and love.mouse.isDown(1) then
            local kScale = (SCR.k > 0 and SCR.k or 1)
            local mx = love.mouse.getX() / kScale
            local contentLeft = SETTINGS.x + 70
            local contentW = SETTINGS.w - 70 - 24
            local v = max(0, min(1, (mx - (contentLeft + 16)) / (contentW - 32)))

            if SETTINGS.activeSlider == 'mainVol' then
                SETTING.mainVol = math.floor(v * 100) / 100
                love.audio.setVolume(SETTING.mainVol)
            elseif SETTINGS.activeSlider == 'bgm' then
                SETTING.bgm = math.floor(v * 100) / 100
                BGM.setVol(SETTING.bgm)
            elseif SETTINGS.activeSlider == 'sfx' then
                SETTING.sfx = math.floor(v * 100) / 100
                SFX.setVol(SETTING.sfx)
            elseif SETTINGS.activeSlider == 'uiScale' then
                local scale = 0.75 + v * 0.60
                local roundScale = math.floor(scale * 100) / 100
                if applyUIScale then applyUIScale(roundScale) end
            elseif SETTINGS.activeSlider == 'das' then
                SETTING.das = math.floor(1 + v * 20)
            elseif SETTINGS.activeSlider == 'arr' then
                SETTING.arr = math.floor(v * 10)
            end
        end
    end
end

function SETTINGS.wheelMoved(x, y)
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = love.mouse.getX() / kScale

    if SETTINGS.isOpen and mx >= SETTINGS.x and mx <= SETTINGS.x + SETTINGS.w then
        SETTINGS.scrollTarget = max(0, min(SETTINGS.scrollTarget - y * 65, SETTINGS.maxScroll))
        return true
    end
    return false
end

function SETTINGS.mouseClick(rawX, rawY, k)
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = rawX / kScale
    local my = rawY / kScale
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local screenH = SCR.h > 0 and (SCR.h / SCR.k) or 720

    if not SETTINGS.isOpen or SETTINGS.x < -SETTINGS.w + 10 then return false end

    -- Click outside sidebar: close it
    if mx > SETTINGS.x + SETTINGS.w then
        SETTINGS.close()
        return true
    end

    -- 1. Close button in header (top-right of sidebar)
    if mx >= SETTINGS.x + SETTINGS.w - 38 and mx <= SETTINGS.x + SETTINGS.w - 10 and my >= 12 and my <= 42 then
        SETTINGS.close()
        if SFX and SFX.play then pcall(SFX.play, 'click') end
        return true
    end

    -- 2. Left Category Toolbar Click (x = SETTINGS.x .. SETTINGS.x + 64)
    if mx >= SETTINGS.x and mx <= SETTINGS.x + 64 then
        local catY = 70
        for _, cat in ipairs(SETTINGS.categories) do
            if my >= catY and my <= catY + 62 then
                SETTINGS.scrollTo(cat.id)
                return true
            end
            catY = catY + 70
        end
        return true
    end

    -- 3. Content Area Click (x = SETTINGS.x + 64 .. SETTINGS.x + SETTINGS.w)
    local contentX = SETTINGS.x + 70
    local contentW = SETTINGS.w - 70 - 24
    local sy = my - 60 + SETTINGS.scrollY

    -- === GAMEPLAY SECTION ===
    if sy >= sectionY.gameplay and sy < sectionY.graphics then
        -- Rotation System Chips (y ~ 45)
        if sy >= 45 and sy <= 82 then
            local rsList = {'TRS', 'SRS', 'SRS_plus', 'BiRS', 'Classic'}
            local chipW = (contentW - 20) / #rsList
            for idx, rs in ipairs(rsList) do
                local cx = contentX + 10 + (idx - 1) * chipW
                if mx >= cx and mx <= cx + chipW - 4 then
                    SETTING.RS = rs
                    if saveSettings then saveSettings() end
                    if SFX and SFX.play then pcall(SFX.play, 'rotate') end
                    return true
                end
            end
        end

        -- Auto Pause Toggle (y ~ 95)
        if sy >= 95 and sy <= 135 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTING.autoPause = not SETTING.autoPause
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            return true
        end

        -- Auto Save Toggle (y ~ 145)
        if sy >= 145 and sy <= 185 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTING.autoSave = not SETTING.autoSave
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            return true
        end

        -- Simplistic Mode Toggle (y ~ 195)
        if sy >= 195 and sy <= 235 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTING.simpMode = not SETTING.simpMode
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            if SCN and SCN.stack then
                local p = TABLE.find(SCN.stack, 'main') or TABLE.find(SCN.stack, 'main_simple')
                if p then SCN.stack[p] = SETTING.simpMode and 'main_simple' or 'main' end
                SCN.swapTo(SETTING.simpMode and 'main_simple' or 'main', 'fade')
            end
            return true
        end

        -- UI Scale Presets (y ~ 285) & Slider (y ~ 245)
        if sy >= 245 and sy <= 325 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            if sy >= 285 then
                local chips = { {val=0.8, x=contentX+10}, {val=1.0, x=contentX+120}, {val=1.2, x=contentX+230} }
                for _, ch in ipairs(chips) do
                    if mx >= ch.x and mx <= ch.x + 95 then
                        if applyUIScale then applyUIScale(ch.val) end
                        if saveSettings then saveSettings() end
                        if SFX and SFX.play then pcall(SFX.play, 'click') end
                        return true
                    end
                end
            end
            SETTINGS.activeSlider = 'uiScale'
            return true
        end
    end

    -- === GRAPHICS SECTION (with UNLIMITED FPS option!) ===
    if sy >= sectionY.graphics and sy < sectionY.audio then
        local gy = sy - sectionY.graphics

        -- Frame Rate Limiter Chips (gy ~ 45..85)
        if gy >= 45 and gy <= 85 then
            local fpsOptions = {
                { label = "60", val = 60 },
                { label = "120", val = 120 },
                { label = "144", val = 144 },
                { label = "240", val = 240 },
                { label = "Unlimited 🚀", val = 'unlimited' },
            }
            local chipW = (contentW - 16) / #fpsOptions
            for idx, opt in ipairs(fpsOptions) do
                local cx = contentX + 8 + (idx - 1) * chipW
                if mx >= cx and mx <= cx + chipW - 4 then
                    SETTING.maxFPS = opt.val
                    if Z and Z.setMaxFPS then Z.setMaxFPS(opt.val) end
                    if saveSettings then saveSettings() end
                    if SFX and SFX.play then pcall(SFX.play, 'click') end
                    if MES and MES.new then
                        local label = (opt.val == 'unlimited') and "Unlimited (Uncapped) FPS" or (tostring(opt.val) .. " FPS")
                        MES.new('check', "Frame rate limit: " .. label, 2)
                    end
                    return true
                end
            end
        end

        -- Fullscreen Toggle (gy ~ 95..135)
        if gy >= 95 and gy <= 135 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTING.fullscreen = not SETTING.fullscreen
            if applySettings then applySettings('fullscreen') end
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            return true
        end

        -- Smooth Falling Toggle (gy ~ 145..185)
        if gy >= 145 and gy <= 185 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTING.smooth = not SETTING.smooth
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            return true
        end

        -- 3D Block Outlines (upEdge) (gy ~ 195..235)
        if gy >= 195 and gy <= 235 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTING.upEdge = not SETTING.upEdge
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            return true
        end

        -- Active Piece Glow (gy ~ 245..285)
        if gy >= 245 and gy <= 285 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTING.block = not SETTING.block
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            return true
        end

        -- Performance Metrics (F7) Chips (gy ~ 305..345)
        if gy >= 305 and gy <= 345 then
            local modes = { {label="Off", val=0}, {label="Compact (F7)", val=1}, {label="Detailed", val=2} }
            local chipW = (contentW - 16) / #modes
            for idx, m in ipairs(modes) do
                local cx = contentX + 8 + (idx - 1) * chipW
                if mx >= cx and mx <= cx + chipW - 4 then
                    if METRICS then METRICS.mode = m.val end
                    if SFX and SFX.play then pcall(SFX.play, 'click') end
                    return true
                end
            end
        end

        -- Block Saturation (gy ~ 365..405)
        if gy >= 365 and gy <= 405 then
            local saturs = {'soft', 'normal', 'color', 'light', 'gray'}
            local chipW = (contentW - 16) / #saturs
            for idx, s in ipairs(saturs) do
                local cx = contentX + 8 + (idx - 1) * chipW
                if mx >= cx and mx <= cx + chipW - 4 then
                    SETTING.blockSatur = s
                    if applySettings then applySettings() end
                    if saveSettings then saveSettings() end
                    if SFX and SFX.play then pcall(SFX.play, 'click') end
                    return true
                end
            end
        end
    end

    -- === AUDIO SECTION ===
    if sy >= sectionY.audio and sy < sectionY.controls then
        local ay = sy - sectionY.audio

        -- Master Volume Slider (ay ~ 45..85)
        if ay >= 45 and ay <= 85 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTINGS.activeSlider = 'mainVol'
            local v = max(0, min(1, (mx - (contentX + 16)) / (contentW - 32)))
            SETTING.mainVol = math.floor(v * 100) / 100
            love.audio.setVolume(SETTING.mainVol)
            if saveSettings then saveSettings() end
            return true
        end

        -- Music Volume Slider (ay ~ 95..135)
        if ay >= 95 and ay <= 135 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTINGS.activeSlider = 'bgm'
            local v = max(0, min(1, (mx - (contentX + 16)) / (contentW - 32)))
            SETTING.bgm = math.floor(v * 100) / 100
            BGM.setVol(SETTING.bgm)
            if saveSettings then saveSettings() end
            return true
        end

        -- SFX Volume Slider (ay ~ 145..185)
        if ay >= 145 and ay <= 185 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTINGS.activeSlider = 'sfx'
            local v = max(0, min(1, (mx - (contentX + 16)) / (contentW - 32)))
            SETTING.sfx = math.floor(v * 100) / 100
            SFX.setVol(SETTING.sfx)
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'warn_1') end
            return true
        end

        -- Voice Pack Chips (ay ~ 205..245)
        if ay >= 205 and ay <= 245 then
            local vocs = {'miya', 'mono', 'xiaoya', 'flore'}
            local chipW = (contentW - 16) / #vocs
            for idx, vname in ipairs(vocs) do
                local cx = contentX + 8 + (idx - 1) * chipW
                if mx >= cx and mx <= cx + chipW - 4 then
                    SETTING.vocPack = vname
                    if saveSettings then saveSettings() end
                    if VOC and VOC.setPack then VOC.setPack(vname) end
                    if SFX and SFX.play then pcall(SFX.play, 'click') end
                    return true
                end
            end
        end

        -- Auto Mute Toggle (ay ~ 265..305)
        if ay >= 265 and ay <= 305 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTING.autoMute = not SETTING.autoMute
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            return true
        end
    end

    -- === CONTROLS SECTION ===
    if sy >= sectionY.controls and sy < sectionY.keys then
        local cy = sy - sectionY.controls

        -- DAS Slider (cy ~ 45..85)
        if cy >= 45 and cy <= 85 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTINGS.activeSlider = 'das'
            return true
        end

        -- ARR Slider (cy ~ 95..135)
        if cy >= 95 and cy <= 135 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTINGS.activeSlider = 'arr'
            return true
        end

        -- Virtual Keypad / Touch Toggle (cy ~ 145..185)
        if cy >= 145 and cy <= 185 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTING.VKSwitch = not SETTING.VKSwitch
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            return true
        end

        -- Key Bindings Button (cy ~ 205..245)
        if cy >= 205 and cy <= 245 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTINGS.scrollTo('keys')
            return true
        end
    end

    -- === KEY BINDINGS SECTION ===
    if sy >= sectionY.keys and sy < sectionY.skin then
        local ky = sy - sectionY.keys

        -- Action cards (ky ~ 54 + (idx-1)*54)
        for idx, act in ipairs(keyActions) do
            local rowY = 54 + (idx - 1) * 54
            if ky >= rowY and ky <= rowY + 46 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
                if SETTINGS.bindingAction == act.id then
                    SETTINGS.bindingAction = nil
                    SETTINGS.bindingActionName = nil
                    if SFX and SFX.play then pcall(SFX.play, 'click') end
                else
                    SETTINGS.bindingAction = act.id
                    SETTINGS.bindingActionName = act.name
                    if SFX and SFX.play then pcall(SFX.play, 'lock', .5) end
                end
                return true
            end
        end

        -- Reset All Keys to Default (resetY = 54 + #keyActions * 54 + 6)
        local resetY = 54 + #keyActions * 54 + 6
        if ky >= resetY and ky <= resetY + 44 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            if not KEY_MAP then KEY_MAP = {} end
            KEY_MAP.keyboard = {
                left = 1, right = 2, x = 3, z = 4, c = 5,
                up = 6, down = 7, space = 8, a = 9, s = 10,
                r = 0,
            }
            saveFile(KEY_MAP, 'conf/key')
            SETTINGS.bindingAction = nil
            SETTINGS.bindingActionName = nil
            if SFX and SFX.play then pcall(SFX.play, 'reach', .5) end
            if MES and MES.new then MES.new('check', "Key bindings reset to default") end
            return true
        end
    end

    -- === SKIN SECTION ===
    if sy >= sectionY.skin then
        local sky = sy - sectionY.skin

        -- Skin Set Chips (sky ~ 45..85)
        if sky >= 45 and sky <= 85 then
            local skins = {'Neon Cyber (Teblocks)', 'Pure Color', 'Flat'}
            local chipW = (contentW - 16) / #skins
            for idx, sname in ipairs(skins) do
                local cx = contentX + 8 + (idx - 1) * chipW
                if mx >= cx and mx <= cx + chipW - 4 then
                    SETTING.skinSet = sname
                    if SKIN and SKIN.change then SKIN.change(sname) end
                    if saveSettings then saveSettings() end
                    if SFX and SFX.play then pcall(SFX.play, 'click') end
                    return true
                end
            end
        end

        -- Grid Background Toggle (sky ~ 95..135)
        if sky >= 95 and sky <= 135 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTING.grid = not SETTING.grid
            if saveSettings then saveSettings() end
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            return true
        end

        -- Online Skin Browser Button (sky ~ 155..195)
        if sky >= 155 and sky <= 195 and mx >= contentX + 10 and mx <= contentX + contentW - 10 then
            SETTINGS.close()
            if not (USER and USER.uid and USER.uid ~= false) then
                if MES and MES.new then MES.new('warn', "Please log in to browse online skins") end
                if AUTH and AUTH.open then AUTH.open('login') end
            else
                SCN.go('skin_browse')
            end
            return true
        end
    end

    return true
end

function SETTINGS.mouseUp(rawX, rawY, k)
    if SETTINGS.activeSlider then
        SETTINGS.activeSlider = nil
        if saveSettings then saveSettings() end
    end
end

function SETTINGS.keyDown(key, isRep)
    -- If currently listening for a key rebind in Key Bindings section
    if SETTINGS.bindingAction then
        if isRep then return true end
        if key == 'escape' then
            SETTINGS.bindingAction = nil
            SETTINGS.bindingActionName = nil
            if SFX and SFX.play then pcall(SFX.play, 'click') end
            return true
        elseif key == 'backspace' then
            if KEY_MAP and KEY_MAP.keyboard then
                for k, v in pairs(KEY_MAP.keyboard) do
                    if v == SETTINGS.bindingAction then
                        KEY_MAP.keyboard[k] = nil
                    end
                end
                saveFile(KEY_MAP, 'conf/key')
            end
            local actName = SETTINGS.bindingActionName or "Action"
            SETTINGS.bindingAction = nil
            SETTINGS.bindingActionName = nil
            if SFX and SFX.play then pcall(SFX.play, 'finesseError', .5) end
            if MES and MES.new then MES.new('info', "Cleared key binding for " .. actName) end
            return true
        else
            if key ~= '\\' and key ~= 'return' and key ~= 'kpenter' then
                if not KEY_MAP then KEY_MAP = {} end
                if not KEY_MAP.keyboard then KEY_MAP.keyboard = {} end
                KEY_MAP.keyboard[key] = SETTINGS.bindingAction
                saveFile(KEY_MAP, 'conf/key')
                local actName = SETTINGS.bindingActionName or "Action"
                local keyStr = formatKey(key)
                SETTINGS.bindingAction = nil
                SETTINGS.bindingActionName = nil
                if SFX and SFX.play then pcall(SFX.play, 'reach', .5) end
                if MES and MES.new then MES.new('check', ("Bound [%s] to %s"):format(keyStr, actName)) end
                return true
            end
        end
        return true
    end

    -- Ctrl+O hotkey toggles settings anywhere (osu! style)
    local ctrlDown = (KBisDown and KBisDown('lctrl', 'rctrl')) or (love.keyboard.isDown and love.keyboard.isDown('lctrl', 'rctrl'))
    if ctrlDown and key == 'o' then
        SETTINGS.toggle()
        return true
    end

    if SETTINGS.isOpen then
        if key == 'escape' then
            SETTINGS.close()
            if SFX and SFX.play then pcall(SFX.play, 'back') end
            return true
        end
        return true
    end

    return false
end

function SETTINGS.draw()
    if SETTINGS.x <= -SETTINGS.w then return end

    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local screenH = SCR.h > 0 and (SCR.h / SCR.k) or 720
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = love.mouse.getX() / kScale
    local my = love.mouse.getY() / kScale

    -- Dimmed backdrop
    local openRatio = (SETTINGS.w + SETTINGS.x) / SETTINGS.w
    GC.setColor(0, 0, 0, 0.45 * openRatio)
    GC.rectangle('fill', 0, 0, screenW, screenH)

    GC.push('transform')
    GC.translate(SETTINGS.x, 0)

    -- Sidebar background
    GC.setColor(0.08, 0.09, 0.13, 0.97)
    GC.rectangle('fill', 0, 0, SETTINGS.w, screenH)

    -- Right glowing border
    GC.setColor(0.98, 0.55, 0.20, 0.85)
    GC.rectangle('fill', SETTINGS.w - 3, 0, 3, screenH)

    -- ════════════════ LEFT CATEGORY TOOLBAR (osu!-style) ════════════════
    local barW = 64
    GC.setColor(0.11, 0.12, 0.18, 0.98)
    GC.rectangle('fill', 0, 0, barW, screenH)

    GC.setColor(0.25, 0.28, 0.38, 0.5)
    GC.setLineWidth(1)
    GC.line(barW, 0, barW, screenH)

    -- Category Buttons
    local catY = 70
    for _, cat in ipairs(SETTINGS.categories) do
        local isActive = (SETTINGS.activeCategory == cat.id)
        local isHov = (mx >= SETTINGS.x and mx <= SETTINGS.x + barW and my >= catY and my <= catY + 62)

        if isActive then
            GC.setColor(0.98, 0.55, 0.20, 0.95)
            GC.rectangle('fill', 0, catY, 4, 62, 0, 2, 2, 0)
            GC.setColor(0.20, 0.22, 0.32, 0.95)
            GC.rectangle('fill', 4, catY, barW - 4, 62)
        elseif isHov then
            GC.setColor(0.16, 0.18, 0.26, 0.9)
            GC.rectangle('fill', 0, catY, barW, 62)
        end

        -- Icon & Label
        FONT.set(20)
        GC.setColor(1, 1, 1, isActive and 1.0 or (isHov and 0.9 or 0.65))
        GC.printf(cat.icon, 0, catY + 8, barW, 'center')

        FONT.set(10)
        GC.setColor(isActive and {0.98, 0.65, 0.25, 1.0} or {0.60, 0.65, 0.75, 0.75})
        GC.printf(cat.label, 0, catY + 36, barW, 'center')

        catY = catY + 70
    end

    -- ════════════════ HEADER AREA ════════════════
    GC.setColor(0.12, 0.14, 0.20, 0.98)
    GC.rectangle('fill', barW, 0, SETTINGS.w - barW, 55)

    GC.setColor(0.25, 0.28, 0.38, 0.5)
    GC.line(barW, 55, SETTINGS.w, 55)

    FONT.set(18)
    GC.setColor(1, 1, 1, 0.98)
    GC.print("⚙️ SETTINGS", barW + 16, 17)

    FONT.set(11)
    GC.setColor(0.55, 0.60, 0.72, 0.75)
    GC.print("[Ctrl+O / ESC]", SETTINGS.w - 145, 21)

    -- Close '✕' Button
    local closeHov = (mx >= SETTINGS.x + SETTINGS.w - 38 and mx <= SETTINGS.x + SETTINGS.w - 10 and my >= 12 and my <= 42)
    if closeHov then
        GC.setColor(0.9, 0.28, 0.28, 0.95)
    else
        GC.setColor(0.40, 0.44, 0.55, 0.7)
    end
    FONT.set(18)
    GC.printf("✕", SETTINGS.w - 36, 16, 26, 'center')

    -- ════════════════ SCROLLABLE SETTINGS CONTENT ════════════════
    local contentX = barW + 8
    local contentW = SETTINGS.w - barW - 16
    local viewY = 56
    local viewH = screenH - 56

    GC.setScissor((SETTINGS.x + barW) * kScale, viewY * kScale, (SETTINGS.w - barW) * kScale, viewH * kScale)

    local startY = viewY + 12 - SETTINGS.scrollY

    -- Helper: Draw Section Header
    local function drawSectionHeader(title, icon, y)
        GC.setColor(0.98, 0.55, 0.20, 0.95)
        GC.rectangle('fill', contentX + 6, y, 4, 22, 2)
        FONT.set(15)
        GC.setColor(1, 1, 1, 0.98)
        GC.print(icon .. "  " .. title, contentX + 16, y + 2)
        GC.setColor(0.25, 0.28, 0.38, 0.4)
        GC.line(contentX + 16, y + 28, contentX + contentW - 10, y + 28)
    end

    -- Helper: Draw Toggle Row
    local function drawToggleRow(label, desc, value, y)
        local isHov = (mx >= SETTINGS.x + contentX and mx <= SETTINGS.x + contentX + contentW - 10 and my >= y - SETTINGS.scrollY + viewY and my <= y - SETTINGS.scrollY + viewY + 40)
        GC.setColor(0.12, 0.13, 0.19, isHov and 0.85 or 0.5)
        GC.rectangle('fill', contentX + 6, y, contentW - 12, 40, 6)
        GC.setColor(0.25, 0.28, 0.38, 0.4)
        GC.rectangle('line', contentX + 6, y, contentW - 12, 40, 6)

        FONT.set(14)
        GC.setColor(1, 1, 1, 0.95)
        GC.print(label, contentX + 16, y + 11)

        -- Switch pill on right
        local swX = contentX + contentW - 65
        local swY = y + 10
        if value then
            GC.setColor(0.20, 0.75, 0.45, 0.95)
            GC.rectangle('fill', swX, swY, 44, 20, 10)
            GC.setColor(1, 1, 1, 1)
            GC.circle('fill', swX + 32, swY + 10, 8)
        else
            GC.setColor(0.25, 0.28, 0.38, 0.85)
            GC.rectangle('fill', swX, swY, 44, 20, 10)
            GC.setColor(0.60, 0.65, 0.75, 0.9)
            GC.circle('fill', swX + 12, swY + 10, 8)
        end
    end

    -- Helper: Draw Slider Row
    local function drawSliderRow(label, valueStr, pct, y)
        GC.setColor(0.12, 0.13, 0.19, 0.6)
        GC.rectangle('fill', contentX + 6, y, contentW - 12, 48, 6)
        GC.setColor(0.25, 0.28, 0.38, 0.4)
        GC.rectangle('line', contentX + 6, y, contentW - 12, 48, 6)

        FONT.set(13)
        GC.setColor(1, 1, 1, 0.95)
        GC.print(label, contentX + 16, y + 6)
        FONT.set(12)
        GC.setColor(0.35, 0.75, 1.0, 0.95)
        GC.printf(valueStr, contentX + contentW - 80, y + 6, 65, 'right')

        -- Slider Track
        local trkX = contentX + 16
        local trkW = contentW - 32
        local trkY = y + 28
        GC.setColor(0.20, 0.22, 0.30, 0.9)
        GC.rectangle('fill', trkX, trkY, trkW, 8, 4)

        -- Slider Fill
        GC.setColor(0.20, 0.65, 0.95, 0.95)
        GC.rectangle('fill', trkX, trkY, trkW * pct, 8, 4)

        -- Handle
        GC.setColor(1, 1, 1, 1)
        GC.circle('fill', trkX + trkW * pct, trkY + 4, 7)
    end

    -- Helper: Draw Button Row
    local function drawButtonRow(label, subtext, y)
        local isHov = (mx >= SETTINGS.x + contentX and mx <= SETTINGS.x + contentX + contentW - 10 and my >= y - SETTINGS.scrollY + viewY and my <= y - SETTINGS.scrollY + viewY + 40)
        if isHov then
            GC.setColor(0.20, 0.24, 0.35, 0.9)
        else
            GC.setColor(0.14, 0.16, 0.23, 0.8)
        end
        GC.rectangle('fill', contentX + 6, y, contentW - 12, 40, 6)
        GC.setColor(0.35, 0.40, 0.55, isHov and 0.8 or 0.5)
        GC.rectangle('line', contentX + 6, y, contentW - 12, 40, 6)

        FONT.set(14)
        GC.setColor(1, 1, 1, 0.95)
        GC.print(label, contentX + 16, y + 11)
        FONT.set(14)
        GC.setColor(0.60, 0.65, 0.75, 0.8)
        GC.printf("▶", contentX + contentW - 40, y + 11, 20, 'center')
    end

    -- ─────────────────────────────────────────────────────────────
    -- SECTION 1: GAMEPLAY
    -- ─────────────────────────────────────────────────────────────
    local y = startY + sectionY.gameplay
    drawSectionHeader("GAMEPLAY & GENERAL", "🎮", y)

    -- Rotation System
    FONT.set(12)
    GC.setColor(0.70, 0.74, 0.85, 0.85)
    GC.print("Rotation System (RS):", contentX + 10, y + 36)
    local rsList = {'TRS', 'SRS', 'SRS_plus', 'BiRS', 'Classic'}
    local rsChipW = (contentW - 20) / #rsList
    for idx, rs in ipairs(rsList) do
        local isSel = (SETTING.RS == rs)
        local cx = contentX + 10 + (idx - 1) * rsChipW
        GC.setColor(isSel and {0.98, 0.55, 0.20, 0.95} or {0.15, 0.17, 0.24, 0.85})
        GC.rectangle('fill', cx, y + 54, rsChipW - 4, 28, 5)
        GC.setColor(isSel and {1, 1, 1, 1} or {0.70, 0.75, 0.85, 0.85})
        FONT.set(11)
        GC.printf(rs, cx, y + 61, rsChipW - 4, 'center')
    end

    drawToggleRow("Auto Pause on Window Blur", "Pause gameplay when unfocused", SETTING.autoPause, y + 95)
    drawToggleRow("Auto Save Game Records", "Save replay recordings", SETTING.autoSave, y + 145)
    drawToggleRow("Simplistic Interface Mode", "Minimal clutter-free layout", SETTING.simpMode, y + 195)

    -- UI Scale Slider & Presets
    local uiScaleVal = SETTING.uiScale or 1.0
    local uiPct = max(0, min(1, (uiScaleVal - 0.75) / 0.60))
    drawSliderRow("UI & Display Scale", string.format("%d%%", math.floor(uiScaleVal * 100)), uiPct, y + 245)

    local scaleChips = { {val=0.8, label="80%"}, {val=1.0, label="100%"}, {val=1.2, label="120%"} }
    for idx, ch in ipairs(scaleChips) do
        local isSel = (math.abs(uiScaleVal - ch.val) < 0.04)
        local cx = contentX + 10 + (idx - 1) * 110
        GC.setColor(isSel and {0.20, 0.65, 0.95, 0.95} or {0.16, 0.18, 0.26, 0.8})
        GC.rectangle('fill', cx, y + 300, 95, 24, 4)
        GC.setColor(isSel and {1, 1, 1, 1} or {0.75, 0.80, 0.90, 0.85})
        FONT.set(11)
        GC.printf(ch.label, cx, y + 304, 95, 'center')
    end

    -- ─────────────────────────────────────────────────────────────
    -- SECTION 2: GRAPHICS & DISPLAY (WITH UNLIMITED FPS!)
    -- ─────────────────────────────────────────────────────────────
    y = startY + sectionY.graphics
    drawSectionHeader("GRAPHICS & DISPLAY", "🎨", y)

    -- Frame Rate Limiter (with Unlimited option!)
    FONT.set(12)
    GC.setColor(0.70, 0.74, 0.85, 0.85)
    GC.print("Frame Rate Limit (FPS):", contentX + 10, y + 36)
    local curFPS = SETTING.maxFPS or 'unlimited'
    local fpsOptions = {
        { label = "60", val = 60 },
        { label = "120", val = 120 },
        { label = "144", val = 144 },
        { label = "240", val = 240 },
        { label = "Unlimited 🚀", val = 'unlimited' },
    }
    local fChipW = (contentW - 16) / #fpsOptions
    for idx, opt in ipairs(fpsOptions) do
        local isSel = (curFPS == opt.val) or (opt.val == 'unlimited' and (curFPS == 'unlimited' or curFPS == 0 or curFPS == nil))
        local cx = contentX + 8 + (idx - 1) * fChipW
        if isSel then
            GC.setColor(0.18, 0.82, 0.45, 0.95)
        else
            GC.setColor(0.15, 0.17, 0.24, 0.85)
        end
        GC.rectangle('fill', cx, y + 54, fChipW - 4, 30, 6)
        GC.setColor(isSel and {1, 1, 1, 1} or {0.75, 0.80, 0.90, 0.85})
        FONT.set(11)
        GC.printf(opt.label, cx, y + 62, fChipW - 4, 'center')
    end

    drawToggleRow("Fullscreen Mode", "Switch between fullscreen/windowed", SETTING.fullscreen, y + 95)
    drawToggleRow("Smooth Falling Piece", "Interpolate tetromino falling animation", SETTING.smooth, y + 145)
    drawToggleRow("3D Block Shading (upEdge)", "Render enhanced 3D bevels", SETTING.upEdge, y + 195)
    drawToggleRow("Active Piece Glow / Shadow", "Render glowing active piece", SETTING.block, y + 245)

    -- Performance Metrics Overlay
    FONT.set(12)
    GC.setColor(0.70, 0.74, 0.85, 0.85)
    GC.print("Performance Metrics Overlay (F7):", contentX + 10, y + 296)
    local mModes = { {label="Off", val=0}, {label="Compact (Bottom-Left)", val=1}, {label="Detailed", val=2} }
    local mChipW = (contentW - 16) / #mModes
    for idx, m in ipairs(mModes) do
        local isSel = (METRICS and METRICS.mode == m.val)
        local cx = contentX + 8 + (idx - 1) * mChipW
        GC.setColor(isSel and {0.20, 0.65, 0.95, 0.95} or {0.15, 0.17, 0.24, 0.85})
        GC.rectangle('fill', cx, y + 314, mChipW - 4, 28, 5)
        GC.setColor(isSel and {1, 1, 1, 1} or {0.75, 0.80, 0.90, 0.85})
        FONT.set(11)
        GC.printf(m.label, cx, y + 321, mChipW - 4, 'center')
    end

    -- Block Saturation
    FONT.set(12)
    GC.setColor(0.70, 0.74, 0.85, 0.85)
    GC.print("Block Saturation Palette:", contentX + 10, y + 352)
    local saturs = {'soft', 'normal', 'color', 'light', 'gray'}
    local sChipW = (contentW - 16) / #saturs
    for idx, s in ipairs(saturs) do
        local isSel = (SETTING.blockSatur == s)
        local cx = contentX + 8 + (idx - 1) * sChipW
        GC.setColor(isSel and {0.62, 0.44, 0.98, 0.95} or {0.15, 0.17, 0.24, 0.85})
        GC.rectangle('fill', cx, y + 370, sChipW - 4, 28, 5)
        GC.setColor(isSel and {1, 1, 1, 1} or {0.75, 0.80, 0.90, 0.85})
        FONT.set(11)
        GC.printf(s, cx, y + 377, sChipW - 4, 'center')
    end

    -- ─────────────────────────────────────────────────────────────
    -- SECTION 3: AUDIO
    -- ─────────────────────────────────────────────────────────────
    y = startY + sectionY.audio
    drawSectionHeader("AUDIO & SOUND", "🔊", y)

    local mainVol = SETTING.mainVol or 1.0
    local bgmVol = SETTING.bgm or 0.8
    local sfxVol = SETTING.sfx or 0.8

    drawSliderRow("Master Volume", string.format("%d%%", math.floor(mainVol * 100)), mainVol, y + 45)
    drawSliderRow("Music Volume (BGM)", string.format("%d%%", math.floor(bgmVol * 100)), bgmVol, y + 100)
    drawSliderRow("Sound Effects (SFX)", string.format("%d%%", math.floor(sfxVol * 100)), sfxVol, y + 155)

    -- Voice Pack Chips
    FONT.set(12)
    GC.setColor(0.70, 0.74, 0.85, 0.85)
    GC.print("Announcer Voice Pack:", contentX + 10, y + 215)
    local vocs = {'miya', 'mono', 'xiaoya', 'flore'}
    local vocChipW = (contentW - 16) / #vocs
    for idx, vname in ipairs(vocs) do
        local isSel = (SETTING.vocPack == vname)
        local cx = contentX + 8 + (idx - 1) * vocChipW
        GC.setColor(isSel and {0.98, 0.55, 0.20, 0.95} or {0.15, 0.17, 0.24, 0.85})
        GC.rectangle('fill', cx, y + 233, vocChipW - 4, 28, 5)
        GC.setColor(isSel and {1, 1, 1, 1} or {0.75, 0.80, 0.90, 0.85})
        FONT.set(11)
        GC.printf(vname, cx, y + 240, vocChipW - 4, 'center')
    end

    drawToggleRow("Auto Mute on Inactive Window", "Silence audio when backgrounded", SETTING.autoMute, y + 275)

    -- ─────────────────────────────────────────────────────────────
    -- SECTION 4: CONTROLS & HANDLING
    -- ─────────────────────────────────────────────────────────────
    y = startY + sectionY.controls
    drawSectionHeader("CONTROLS & HANDLING", "⚙️", y)

    local dasVal = SETTING.das or 10
    local arrVal = SETTING.arr or 2
    drawSliderRow("DAS (Delayed Auto Shift)", string.format("%d frames", dasVal), min(1, dasVal / 20), y + 45)
    drawSliderRow("ARR (Auto Repeat Rate)", string.format("%d frames", arrVal), min(1, arrVal / 10), y + 100)
    drawToggleRow("Virtual Keypad / Touch Controls", "On-screen touch controls", SETTING.VKSwitch, y + 155)
    drawButtonRow("Jump to Key Bindings ↓", "Configure keyboard and action mapping", y + 205)

    -- ─────────────────────────────────────────────────────────────
    -- SECTION 5: KEY BINDINGS (Direct in-place configuration)
    -- ─────────────────────────────────────────────────────────────
    y = startY + sectionY.keys
    drawSectionHeader("KEY BINDINGS", "⌨️", y)

    FONT.set(11)
    GC.setColor(0.65, 0.70, 0.85, 0.75)
    GC.print("Click any action to rebind. Press Backspace to clear, Esc to cancel.", contentX + 10, y + 36)

    for idx, act in ipairs(keyActions) do
        local rowY = y + 54 + (idx - 1) * 54
        local isListening = (SETTINGS.bindingAction == act.id)
        local isHover = (mx >= contentX + 10 and mx <= contentX + contentW - 10 and my >= rowY and my <= rowY + 46)

        -- Background card
        if isListening then
            local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 8)
            GC.setColor(0.18 + 0.12 * pulse, 0.35 + 0.25 * pulse, 0.75, 0.95)
            GC.rectangle('fill', contentX + 10, rowY, contentW - 20, 46, 6)
            GC.setColor(0.55, 0.85, 1, 1)
            GC.setLineWidth(2)
            GC.rectangle('line', contentX + 10, rowY, contentW - 20, 46, 6)
        else
            GC.setColor(0.10, 0.11, 0.16, isHover and 0.95 or 0.75)
            GC.rectangle('fill', contentX + 10, rowY, contentW - 20, 46, 6)
            GC.setColor(0.20, 0.24, 0.38, isHover and 0.90 or 0.45)
            GC.setLineWidth(1)
            GC.rectangle('line', contentX + 10, rowY, contentW - 20, 46, 6)
        end

        -- Action title & subtitle
        GC.setColor(1, 1, 1, 1)
        FONT.set(13)
        GC.print(act.name, contentX + 20, rowY + 7)

        GC.setColor(0.55, 0.60, 0.75, 0.85)
        FONT.set(10)
        GC.print(act.sub, contentX + 20, rowY + 26)

        -- Key Badge on right
        if isListening then
            GC.setColor(1, 0.85, 0.25, 1)
            FONT.set(11)
            GC.printf("Press key...", contentX + contentW - 130, rowY + 16, 110, 'right')
        else
            local boundStr = getBoundKeysString(act.id)
            local badgeW = math.max(68, #boundStr * 8 + 18)
            local bx = contentX + contentW - badgeW - 16
            local by = rowY + 11
            local isNone = (boundStr == "Unbound")

            GC.setColor(isNone and {0.20, 0.22, 0.30, 0.7} or {0.18, 0.32, 0.60, 0.85})
            GC.rectangle('fill', bx, by, badgeW, 24, 4)
            GC.setColor(isNone and {0.35, 0.38, 0.50, 0.8} or {0.45, 0.70, 1.0, 0.9})
            GC.setLineWidth(1)
            GC.rectangle('line', bx, by, badgeW, 24, 4)

            GC.setColor(isNone and {0.60, 0.65, 0.75, 0.8} or {0.95, 0.98, 1, 1})
            FONT.set(11)
            GC.printf(boundStr, bx, by + 5, badgeW, 'center')
        end
    end

    -- Reset to Defaults button
    local resetY = y + 54 + #keyActions * 54 + 6
    drawButtonRow("Reset All Keys to Default", "Restore standard Techmino key bindings", resetY)

    -- ─────────────────────────────────────────────────────────────
    -- SECTION 6: SKINS
    -- ─────────────────────────────────────────────────────────────
    y = startY + sectionY.skin
    drawSectionHeader("SKINS & APPEARANCE", "🎭", y)

    FONT.set(12)
    GC.setColor(0.70, 0.74, 0.85, 0.85)
    GC.print("Block Skin Preset:", contentX + 10, y + 36)
    local skins = {'Neon Cyber (Teblocks)', 'Pure Color', 'Flat'}
    local skChipW = (contentW - 16) / #skins
    for idx, sname in ipairs(skins) do
        local isSel = (SETTING.skinSet == sname)
        local cx = contentX + 8 + (idx - 1) * skChipW
        GC.setColor(isSel and {0.18, 0.82, 0.45, 0.95} or {0.15, 0.17, 0.24, 0.85})
        GC.rectangle('fill', cx, y + 54, skChipW - 4, 30, 6)
        GC.setColor(isSel and {1, 1, 1, 1} or {0.75, 0.80, 0.90, 0.85})
        FONT.set(11)
        GC.printf(sname:match("^(%S+)") or sname, cx, y + 62, skChipW - 4, 'center')
    end

    drawToggleRow("Grid Board Background", "Show field background grid lines", SETTING.grid, y + 95)
    drawButtonRow("Browse Online Skin Direct...", "Download community block skins", y + 145)

    GC.setScissor()
    GC.pop()
end

return SETTINGS
