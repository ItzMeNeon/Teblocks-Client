local gc = love.graphics
local max, min = math.max, math.min

local CHAT = {}

CHAT.messages = {}
CHAT.inputText = ""
CHAT.isOpen = false
CHAT.visible = false
CHAT.maxMessages = 150
CHAT.alpha = 0
CHAT.x = 1280
CHAT.targetX = 1280
CHAT.w = 520
CHAT.h = 720
CHAT.focused = false
CHAT.scrollOffset = 0
CHAT.maxScroll = 0
CHAT.unreadCount = 0
CHAT.tabHover = false
CHAT.tabAnim = 0
CHAT.cursorTimer = 0

function CHAT.open()
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    CHAT.isOpen = true
    CHAT.visible = true
    CHAT.targetX = screenW - CHAT.w
    CHAT.focused = true
    love.keyboard.setTextInput(true)
    CHAT.unreadCount = 0
    CHAT.scrollOffset = 0
    if MES and MES.sidebarOpen then
        MES.closeSidebar()
    end
end

function CHAT.close()
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    CHAT.isOpen = false
    CHAT.visible = false
    CHAT.targetX = screenW
    CHAT.focused = false
    love.keyboard.setTextInput(false)
end

function CHAT.toggle()
    if CHAT.isOpen then
        CHAT.close()
    else
        CHAT.open()
    end
end

-- Backward compatibility aliases for LOBBY.chat
CHAT.show = CHAT.open
CHAT.hide = CHAT.close
function CHAT:isInside(mx, my)
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local screenH = SCR.h > 0 and (SCR.h / SCR.k) or 720
    if not CHAT.isOpen and CHAT.x >= screenW - 5 then return false end
    return mx >= CHAT.x and mx <= screenW and my >= 0 and my <= screenH
end

function CHAT.clear()
    CHAT.messages = {}
    CHAT.scrollOffset = 0
    CHAT.maxScroll = 0
end

local function _addMessage(username, message, isServer)
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local font = FONT.get(15)
    local msgW = CHAT.w - 110
    local _, wrapped = font:getWrap(tostring(message), max(100, msgW))
    local lineCount = max(1, #wrapped)
    local msgH = max(40, 24 + lineCount * 18)

    table.insert(CHAT.messages, {
        time = os.time(),
        timeStr = os.date("%H:%M"),
        username = tostring(username or "Guest"),
        message = tostring(message or ""),
        isServer = isServer or (username == 'SERVER' or username == 'system'),
        h = msgH,
    })

    if #CHAT.messages > CHAT.maxMessages then
        table.remove(CHAT.messages, 1)
    end

    -- Auto-scroll to bottom
    CHAT.scrollOffset = 0
end

function CHAT.sendMessage()
    local text = CHAT.inputText
    if text and #text > 0 then
        -- Send via Net WebSocket
        if NET and NET.global_chat then
            NET.global_chat(text)
        else
            -- Offline test fallback
            local myName = USER and USER.uid and USERS and USERS.getUsername(USER.uid) or "Me"
            _addMessage(myName, text, false)
        end
        CHAT.inputText = ""
    end
end

function CHAT.receiveMessage(username, message)
    local isServer = (username == 'SERVER' or username == 'system' or string.sub(tostring(message), 1, 21) == "[SERVER ANNOUNCEMENT]")
    _addMessage(username, message, isServer)

    if not CHAT.isOpen then
        CHAT.unreadCount = (CHAT.unreadCount or 0) + 1
        if SFX and SFX.play then
            pcall(SFX.play, 'notify', 0.3)
        end
    end
end

function CHAT.update(dt)
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local screenH = SCR.h > 0 and (SCR.h / SCR.k) or 720

    -- Animation for drawer slide
    local targetX = CHAT.isOpen and (screenW - CHAT.w) or screenW
    CHAT.x = MATH.expApproach(CHAT.x, targetX, dt * 18)
    CHAT.alpha = max(0, min(1, (screenW - CHAT.x) / CHAT.w))

    -- Tab hover animation
    CHAT.tabAnim = MATH.expApproach(CHAT.tabAnim, CHAT.tabHover and 1 or 0, dt * 16)

    -- Blinking cursor
    CHAT.cursorTimer = (CHAT.cursorTimer + dt) % 1.0

    -- Compute max scroll
    local totalMsgH = 0
    for i = 1, #CHAT.messages do
        totalMsgH = totalMsgH + CHAT.messages[i].h + 8
    end
    local viewH = screenH - 130
    CHAT.maxScroll = max(0, totalMsgH - viewH)
end

function CHAT.drawSideTab(screenW, screenH)
    if CHAT.isOpen then return end

    local tabW, tabH = 36, 85
    local tabY = 260
    local tabX = screenW - tabW - (CHAT.tabAnim * 8)

    GC.push('transform')
    -- Tab Background
    if CHAT.tabHover then
        GC.setColor(0.18, 0.20, 0.28, 0.96)
    else
        GC.setColor(0.11, 0.12, 0.18, 0.90)
    end
    GC.rectangle('fill', tabX, tabY, tabW + 10, tabH, 8, 0, 0, 8)

    -- Tab Border
    GC.setColor(0.40, 0.44, 0.60, CHAT.tabHover and 0.9 or 0.5)
    GC.setLineWidth(1.5)
    GC.rectangle('line', tabX, tabY, tabW + 10, tabH, 8, 0, 0, 8)

    -- Accent stripe
    GC.setColor(0.20, 0.65, 0.95, 0.9)
    GC.rectangle('fill', tabX, tabY + 8, 3, tabH - 16, 2)

    -- Chat Icon & Vertical Label
    GC.setColor(1, 1, 1, 0.95)
    FONT.set(16)
    GC.printf("💬", tabX + 4, tabY + 10, tabW, 'center')
    FONT.set(11)
    GC.printf("C\nH\nA\nT", tabX + 6, tabY + 30, tabW, 'center')

    -- Small hotkey badge
    FONT.set(9)
    GC.setColor(0.65, 0.70, 0.85, 0.75)
    GC.printf("F8", tabX + 2, tabY + 70, tabW, 'center')

    -- Unread Red Badge
    if (CHAT.unreadCount or 0) > 0 then
        local countStr = tostring(min(CHAT.unreadCount, 99))
        local bw = max(18, #countStr * 8 + 8)
        GC.setColor(0.95, 0.25, 0.25, 0.98)
        GC.rectangle('fill', tabX - 6, tabY - 6, bw, 18, 9)
        GC.setColor(1, 1, 1, 1)
        FONT.set(10)
        GC.printf(countStr, tabX - 6, tabY - 3, bw, 'center')
    end
    GC.pop()
end

function CHAT.draw()
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local screenH = SCR.h > 0 and (SCR.h / SCR.k) or 720
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = love.mouse.getX() / kScale
    local my = love.mouse.getY() / kScale

    -- 1. Draw side tab if closed
    CHAT.drawSideTab(screenW, screenH)

    -- 2. Draw Chat Drawer if visible/animating
    if CHAT.x < screenW then
        local openRatio = (screenW - CHAT.x) / CHAT.w

        -- Dimmed Backdrop
        GC.setColor(0, 0, 0, 0.40 * openRatio)
        GC.rectangle('fill', 0, 0, screenW, screenH)

        GC.push('transform')
        GC.translate(CHAT.x, 0)

        -- Panel Container
        GC.setColor(0.09, 0.10, 0.15, 0.97)
        GC.rectangle('fill', 0, 0, CHAT.w, screenH)

        -- Left Glowing Border Line
        GC.setColor(0.20, 0.65, 0.95, 0.85)
        GC.rectangle('fill', 0, 0, 3, screenH)

        -- Header Area (y = 0..55)
        GC.setColor(0.12, 0.14, 0.20, 0.98)
        GC.rectangle('fill', 3, 0, CHAT.w - 3, 55)

        GC.setColor(0.25, 0.28, 0.38, 0.6)
        GC.setLineWidth(1)
        GC.line(3, 55, CHAT.w, 55)

        -- Title & Icon
        FONT.set(18)
        GC.setColor(1, 1, 1, 0.98)
        GC.print("💬 GLOBAL CHAT", 16, 17)

        -- Online Status Pill
        local onlineText = "● " .. tostring(NET and NET.onlineCount or 1) .. " online"
        local onW = max(70, #onlineText * 8 + 12)
        GC.setColor(0.15, 0.25, 0.22, 0.9)
        GC.rectangle('fill', 185, 18, onW, 20, 10)
        GC.setColor(0.25, 0.85, 0.55, 0.95)
        FONT.set(12)
        GC.printf(onlineText, 185, 20, onW, 'center')

        -- Hotkey Hint
        FONT.set(11)
        GC.setColor(0.55, 0.60, 0.70, 0.75)
        GC.print("[F8 / ESC]", CHAT.w - 95, 21)

        -- Close '✕' Button
        local closeHov = (mx >= screenW - 36 and mx <= screenW - 10 and my >= 12 and my <= 40)
        if closeHov then
            GC.setColor(0.9, 0.3, 0.3, 0.95)
        else
            GC.setColor(0.40, 0.44, 0.55, 0.7)
        end
        FONT.set(18)
        GC.printf("✕", CHAT.w - 36, 16, 26, 'center')

        -- Scrollable Message History Area (y = 60..screenH - 70)
        local viewY = 60
        local viewH = screenH - 130
        GC.setScissor(CHAT.x * kScale, viewY * kScale, CHAT.w * kScale, viewH * kScale)

        if #CHAT.messages == 0 then
            FONT.set(16)
            GC.setColor(0.50, 0.55, 0.65, 0.7)
            GC.printf("No messages yet", 20, 240, CHAT.w - 40, 'center')
            FONT.set(12)
            GC.setColor(0.40, 0.44, 0.52, 0.6)
            GC.printf("Say hello to players online!", 20, 265, CHAT.w - 40, 'center')
        else
            -- Render from bottom upwards
            local curY = viewY + viewH - 10 + CHAT.scrollOffset
            for i = #CHAT.messages, 1, -1 do
                local msg = CHAT.messages[i]
                curY = curY - msg.h - 8

                if curY + msg.h >= viewY - 10 and curY <= viewY + viewH + 10 then
                    local cardW = CHAT.w - 30

                    if msg.isServer then
                        -- Server Broadcast Highlight Card
                        GC.setColor(0.18, 0.12, 0.28, 0.92)
                        GC.rectangle('fill', 14, curY, cardW, msg.h, 6)
                        GC.setColor(0.62, 0.44, 0.98, 0.95)
                        GC.rectangle('fill', 14, curY, 4, msg.h, 4, 0, 0, 4)
                        GC.setColor(0.62, 0.44, 0.98, 0.6)
                        GC.setLineWidth(1)
                        GC.rectangle('line', 14, curY, cardW, msg.h, 6)

                        -- Timestamp & Server Badge
                        FONT.set(11)
                        GC.setColor(0.70, 0.65, 0.85, 0.8)
                        GC.print("[" .. msg.timeStr .. "]", 24, curY + 6)
                        FONT.set(12)
                        GC.setColor(0.98, 0.80, 0.20, 0.98)
                        GC.print("📢 [SERVER]", 72, curY + 5)

                        -- Message Text
                        FONT.set(14)
                        GC.setColor(1, 1, 1, 0.98)
                        GC.printf(msg.message, 24, curY + 22, cardW - 24, 'left')
                    else
                        -- Regular Chat Message Card
                        GC.setColor(0.12, 0.14, 0.19, 0.85)
                        GC.rectangle('fill', 14, curY, cardW, msg.h, 6)
                        GC.setColor(0.25, 0.28, 0.38, 0.4)
                        GC.setLineWidth(1)
                        GC.rectangle('line', 14, curY, cardW, msg.h, 6)

                        -- Timestamp
                        FONT.set(11)
                        GC.setColor(0.55, 0.58, 0.68, 0.7)
                        GC.print("[" .. msg.timeStr .. "]", 24, curY + 6)

                        -- Username
                        FONT.set(13)
                        GC.setColor(0.35, 0.75, 1.0, 0.95)
                        GC.print(msg.username .. ":", 72, curY + 5)

                        -- Text
                        FONT.set(14)
                        GC.setColor(0.92, 0.94, 0.98, 0.95)
                        local nameOffset = 76 + #msg.username * 7.5
                        if #msg.message < 35 and msg.h <= 42 then
                            GC.print(msg.message, nameOffset, curY + 5)
                        else
                            GC.printf(msg.message, 24, curY + 22, cardW - 24, 'left')
                        end
                    end
                end
            end
        end

        GC.setScissor()

        -- Bottom Input Bar Area (y = screenH - 65..screenH - 10)
        local inputY = screenH - 60
        local inputW = CHAT.w - 110
        local inputH = 42

        -- Input Box Background
        GC.setColor(0.12, 0.14, 0.20, 0.98)
        GC.rectangle('fill', 14, inputY, inputW, inputH, 6)

        -- Input Box Border (Glows when focused)
        if CHAT.focused then
            GC.setColor(0.20, 0.65, 0.95, 0.95)
            GC.setLineWidth(1.8)
        else
            GC.setColor(0.30, 0.34, 0.45, 0.6)
            GC.setLineWidth(1)
        end
        GC.rectangle('line', 14, inputY, inputW, inputH, 6)

        -- Input Text or Placeholder
        FONT.set(15)
        if #CHAT.inputText == 0 then
            GC.setColor(0.50, 0.54, 0.65, 0.65)
            GC.print("Type a message... (Enter to send)", 24, inputY + 12)
        else
            GC.setColor(1, 1, 1, 0.98)
            GC.print(CHAT.inputText, 24, inputY + 12)
        end

        -- Blinking Cursor
        if CHAT.focused and CHAT.cursorTimer < 0.5 then
            local textW = FONT.get(15):getWidth(CHAT.inputText)
            GC.setColor(0.20, 0.65, 0.95, 0.95)
            GC.rectangle('fill', 24 + textW + 2, inputY + 10, 2, 22)
        end

        -- Send Button
        local sendX = CHAT.w - 86
        local sendW = 72
        local sendHov = (mx >= screenW - 86 and mx <= screenW - 14 and my >= inputY and my <= inputY + inputH)
        if sendHov then
            GC.setColor(0.25, 0.70, 0.40, 0.98)
        else
            GC.setColor(0.18, 0.55, 0.32, 0.90)
        end
        GC.rectangle('fill', sendX, inputY, sendW, inputH, 6)
        GC.setColor(0.40, 0.85, 0.50, 0.8)
        GC.setLineWidth(1)
        GC.rectangle('line', sendX, inputY, sendW, inputH, 6)

        FONT.set(15)
        GC.setColor(1, 1, 1, 0.98)
        GC.printf("Send", sendX, inputY + 12, sendW, 'center')

        GC.pop()
    end
end

function CHAT.mouseClick(rawX, rawY, k)
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = rawX / kScale
    local my = rawY / kScale
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280
    local screenH = SCR.h > 0 and (SCR.h / SCR.k) or 720

    -- 1. Check side tab click
    local tabW, tabH = 36, 85
    local tabY = 260
    local tabX = screenW - tabW - (CHAT.tabAnim * 8)
    if not CHAT.isOpen and mx >= tabX and mx <= screenW and my >= tabY and my <= tabY + tabH then
        CHAT.toggle()
        if SFX and SFX.play then pcall(SFX.play, 'click') end
        return true
    end

    -- 2. If Chat Drawer is open
    if CHAT.isOpen and CHAT.x < screenW - 10 then
        -- Inside chat drawer
        if mx >= CHAT.x and mx <= screenW and my >= 0 and my <= screenH then
            -- Close button '✕'
            if mx >= screenW - 36 and mx <= screenW - 10 and my >= 12 and my <= 40 then
                CHAT.close()
                if SFX and SFX.play then pcall(SFX.play, 'click') end
                return true
            end

            local inputY = screenH - 60
            local inputW = CHAT.w - 110
            local inputH = 42

            -- Send button
            local sendX = screenW - 86
            local sendW = 72
            if mx >= sendX and mx <= sendX + sendW and my >= inputY and my <= inputY + inputH then
                CHAT.sendMessage()
                if SFX and SFX.play then pcall(SFX.play, 'click') end
                return true
            end

            -- Input box click
            local inX = CHAT.x + 14
            if mx >= inX and mx <= inX + inputW and my >= inputY and my <= inputY + inputH then
                CHAT.focused = true
                love.keyboard.setTextInput(true)
                return true
            else
                -- Clicked elsewhere inside drawer
                CHAT.focused = false
                return true
            end
        else
            -- Clicked outside chat drawer: close it
            CHAT.close()
            return true
        end
    end

    return false
end

function CHAT.mouseMove(rawX, rawY)
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = rawX / kScale
    local my = rawY / kScale
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280

    local tabW, tabH = 36, 85
    local tabY = 260
    local tabX = screenW - tabW - 12
    CHAT.tabHover = (mx >= tabX and mx <= screenW and my >= tabY and my <= tabY + tabH)
end

function CHAT.wheelMoved(x, y)
    local kScale = (SCR.k > 0 and SCR.k or 1)
    local mx = love.mouse.getX() / kScale
    local screenW = SCR.w > 0 and (SCR.w / SCR.k) or 1280

    if CHAT.isOpen and mx >= CHAT.x and mx <= screenW then
        CHAT.scrollOffset = max(0, min(CHAT.scrollOffset + y * 45, CHAT.maxScroll))
        return true
    end
    return false
end

function CHAT.keyDown(key, isRep)
    -- F8 hotkey opens/closes global chat anywhere!
    if key == 'f8' then
        CHAT.toggle()
        if SFX and SFX.play then pcall(SFX.play, 'click') end
        return true
    end

    if CHAT.isOpen then
        if key == 'escape' then
            CHAT.close()
            if SFX and SFX.play then pcall(SFX.play, 'back') end
            return true
        end

        if CHAT.focused then
            if key == 'return' or key == 'kpenter' then
                CHAT.sendMessage()
                return true
            elseif key == 'backspace' then
                local t = CHAT.inputText
                if #t > 0 then
                    local p = #t
                    while p > 0 and t:byte(p) >= 128 and t:byte(p) < 192 do
                        p = p - 1
                    end
                    if p > 0 then
                        CHAT.inputText = t:sub(1, p - 1)
                    end
                end
                return true
            end
            -- Consumes all other keys while typing so gameplay doesn't receive keystrokes
            return true
        end
    end

    return false
end

function CHAT.textInput(t)
    if CHAT.isOpen and CHAT.focused then
        if #CHAT.inputText < 256 then
            CHAT.inputText = CHAT.inputText .. t
        end
        return true
    end
    return false
end

return CHAT
