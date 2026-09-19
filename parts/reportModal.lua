local REPORT = {}

local _isOpen = false
local overlayAlpha = 0
local boxAlpha = 0
local openTimer = 0

local targetUid = ""
local targetUsername = ""
local roomId = ""
local matchId = ""

local reasons = {
    {id = "macro",     label = "Macro / Bot / Autoplayer",        icon = "🤖"},
    {id = "speedhack", label = "Speedhack / Clock Manipulation",  icon = "⏱"},
    {id = "exploit",   label = "Desync / Combat Exploit",         icon = "💥"},
    {id = "toxic",     label = "Abusive / Toxic Chat",            icon = "💬"},
    {id = "other",     label = "Other Suspicious Behavior",       icon = "❓"},
}
local selectedReason = 1
local details = ""
local isInputFocused = false

local gc = love.graphics
local gc_setColor, gc_setLineWidth = gc.setColor, gc.setLineWidth
local gc_rectangle, gc_circle = gc.rectangle, gc.circle
local gc_push, gc_pop = gc.push, gc.pop
local gc_replaceTransform = gc.replaceTransform
local gc_print, gc_printf = gc.print, gc.printf
local setFont = FONT.set

local MODAL_W, MODAL_H = 780, 580
local MODAL_X = math.floor((1280 - MODAL_W) * 0.5)
local MODAL_Y = math.floor((720 - MODAL_H) * 0.5)

local function _close()
    _isOpen = false
    openTimer = 0
    targetUid = ""
    targetUsername = ""
    roomId = ""
    matchId = ""
    details = ""
    isInputFocused = false
    love.keyboard.setTextInput(false)
    WIDGET.unFocus(true)
    WIDGET.locked = false
end

local function _pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function getMousePos()
    if SCR and SCR.xOy then
        return SCR.xOy:inverseTransformPoint(love.mouse.getPosition())
    end
    return love.mouse.getPosition()
end

function REPORT.open(uid, name, rId, mId)
    targetUid = tostring(uid or "")
    targetUsername = tostring(name or ("Player " .. targetUid))
    roomId = tostring(rId or "")
    matchId = tostring(mId or "")
    selectedReason = 1
    details = ""
    isInputFocused = false

    _isOpen = true
    openTimer = 0.35
    love.keyboard.setTextInput(true)
end

function REPORT.close()
    _close()
end

function REPORT.isOpen()
    return _isOpen or overlayAlpha > 0.01 or boxAlpha > 0.01
end

function REPORT.update(dt)
    if _isOpen then
        WIDGET.locked = true
        if openTimer > 0 then
            openTimer = math.max(0, openTimer - dt)
        end
        overlayAlpha = math.min(overlayAlpha + dt * 10, 0.75)
        boxAlpha     = math.min(boxAlpha + dt * 10, 1.0)
    else
        overlayAlpha = math.max(overlayAlpha - dt * 10, 0)
        boxAlpha     = math.max(boxAlpha - dt * 10, 0)
    end
end

-- Helper to get category chip geometry
local function _getChipRect(idx)
    local padding = 24
    local spacing = 12
    local chipW = math.floor((MODAL_W - padding * 2 - spacing) * 0.5)
    local chipH = 38
    local startY = MODAL_Y + 162

    local row = math.floor((idx - 1) / 2)
    local col = (idx - 1) % 2

    local chipX = MODAL_X + padding + col * (chipW + spacing)
    local chipY = startY + row * (chipH + 8)

    if idx == 5 then
        -- 5th chip spans full width
        chipW = MODAL_W - padding * 2
    end

    return chipX, chipY, chipW, chipH
end

function REPORT.draw()
    if overlayAlpha <= 0 and boxAlpha <= 0 then return end

    -- 1. Full-screen Dark Backdrop
    gc_push('transform')
    gc_replaceTransform(SCR.origin)
    if overlayAlpha > 0 then
        gc_setColor(0, 0, 0, overlayAlpha)
        gc_rectangle('fill', 0, 0, SCR.w, SCR.h)
    end
    gc_pop()

    if boxAlpha <= 0 then return end

    local t = love.timer.getTime()
    local mx, my = getMousePos()
    local bA = boxAlpha

    gc_push('transform')
    gc_replaceTransform(SCR.xOy)

    -- 2. Modal Window Frame
    gc_setColor(.07, .09, .18, .96 * bA)
    gc_rectangle('fill', MODAL_X, MODAL_Y, MODAL_W, MODAL_H, 12)

    -- Glowing Security Border
    local borderGlow = 0.75 + 0.25 * math.sin(t * 3.5)
    gc_setColor(.85, .28, .25, borderGlow * bA)
    gc_setLineWidth(2)
    gc_rectangle('line', MODAL_X, MODAL_Y, MODAL_W, MODAL_H, 12)

    -- 3. Header Banner
    gc_setColor(.20, .08, .12, .96 * bA)
    gc_rectangle('fill', MODAL_X, MODAL_Y, MODAL_W, 54, 12)
    gc_rectangle('fill', MODAL_X, MODAL_Y + 38, MODAL_W, 16)
    gc_setColor(1.0, .35, .30, .85 * bA)
    gc_setLineWidth(1.5)
    gc.line(MODAL_X, MODAL_Y + 54, MODAL_X + MODAL_W, MODAL_Y + 54)

    setFont(21)
    gc_setColor(1.0, .88, .88, bA)
    gc_print("🚩 PLAYER REPORT & FAIR PLAY REVIEW", MODAL_X + 24, MODAL_Y + 15)

    -- Close Button [✕] (Top right)
    local closeBtnX = MODAL_X + MODAL_W - 44
    local closeBtnY = MODAL_Y + 14
    local isCloseHov = _pointInRect(mx, my, closeBtnX - 4, closeBtnY - 4, 32, 32)
    gc_setColor(isCloseHov and 1.0 or .75, .40, .40, bA)
    setFont(20)
    gc_print("✕", closeBtnX + 2, closeBtnY)

    -- 4. Target Player Context Pill
    local userPillY = MODAL_Y + 68
    gc_setColor(.12, .16, .30, .92 * bA)
    gc_rectangle('fill', MODAL_X + 24, userPillY, MODAL_W - 48, 50, 8)
    gc_setColor(.35, .45, .75, .65 * bA)
    gc_setLineWidth(1)
    gc_rectangle('line', MODAL_X + 24, userPillY, MODAL_W - 48, 50, 8)

    setFont(14)
    gc_setColor(.65, .78, 1.0, .85 * bA)
    gc_print("Reported Player:", MODAL_X + 38, userPillY + 16)

    setFont(17)
    gc_setColor(1.0, .90, .40, bA)
    gc_print(targetUsername, MODAL_X + 160, userPillY + 14)

    setFont(13)
    gc_setColor(.55, .65, .85, .85 * bA)
    local uidLabel = "UID: " .. targetUid
    if roomId ~= "" then uidLabel = uidLabel .. "  •  Room: " .. roomId end
    gc_print("(" .. uidLabel .. ")", MODAL_X + 168 + FONT.get(17):getWidth(targetUsername), userPillY + 17)

    -- 5. Violation Category Section
    local catTitleY = userPillY + 60
    setFont(14)
    gc_setColor(.85, .90, 1.0, .95 * bA)
    gc_print("Select Violation Category:", MODAL_X + 24, catTitleY)

    for i, r in ipairs(reasons) do
        local chipX, chipY, chipW, chipH = _getChipRect(i)
        local isSel = (selectedReason == i)
        local isHov = _pointInRect(mx, my, chipX, chipY, chipW, chipH)

        if isSel then
            gc_setColor(.75, .25, .20, .90 * bA)
            gc_rectangle('fill', chipX, chipY, chipW, chipH, 6)
            gc_setColor(1.0, .60, .55, bA)
            gc_setLineWidth(1.5)
            gc_rectangle('line', chipX, chipY, chipW, chipH, 6)
        else
            gc_setColor(isHov and .18 or .10, isHov and .22 or .13, isHov and .35 or .22, .85 * bA)
            gc_rectangle('fill', chipX, chipY, chipW, chipH, 6)
            gc_setColor(.28, .36, .58, (isHov and .90 or .55) * bA)
            gc_setLineWidth(1)
            gc_rectangle('line', chipX, chipY, chipW, chipH, 6)
        end

        -- Radio indicator
        gc_setColor(isSel and 1.0 or .50, isSel and .65 or .60, isSel and .60 or .70, bA)
        gc_circle(isSel and 'fill' or 'line', chipX + 22, chipY + chipH * 0.5, isSel and 6 or 5)

        setFont(14)
        gc_setColor(isSel and 1.0 or .88, isSel and 1.0 or .90, 1.0, bA)
        gc_print(r.icon .. "  " .. r.label, chipX + 38, chipY + 10)
    end

    -- 6. Details / Evidence Input Area
    local inputLabelY = MODAL_Y + 316
    setFont(14)
    gc_setColor(.85, .90, 1.0, .95 * bA)
    gc_print("Additional Details & Evidence (Optional):", MODAL_X + 24, inputLabelY)

    setFont(12)
    gc_setColor(.60, .70, .88, .80 * bA)
    local charCountStr = #details .. " / 300"
    gc.printf(charCountStr, MODAL_X + 24, inputLabelY + 2, MODAL_W - 48, 'right')

    local inBoxY = inputLabelY + 24
    local inBoxH = 112
    gc_setColor(.09, .12, .24, .95 * bA)
    gc_rectangle('fill', MODAL_X + 24, inBoxY, MODAL_W - 48, inBoxH, 8)

    gc_setColor(isInputFocused and 1.0 or .28, isInputFocused and .60 or .40, isInputFocused and .55 or .70, (isInputFocused and 1.0 or .65) * bA)
    gc_setLineWidth(isInputFocused and 1.5 or 1)
    gc_rectangle('line', MODAL_X + 24, inBoxY, MODAL_W - 48, inBoxH, 8)

    setFont(14)
    if #details == 0 and not isInputFocused then
        gc_setColor(.45, .55, .70, .75 * bA)
        gc_printf("Describe what happened (e.g. impossible placement speed, clock lag, offensive chat messages)...", MODAL_X + 36, inBoxY + 14, MODAL_W - 72, 'left')
    else
        gc_setColor(1, 1, 1, bA)
        local cursorStr = (isInputFocused and ((t * 2 % 1 > .5) and "|" or "") or "")
        gc_printf(details .. cursorStr, MODAL_X + 36, inBoxY + 14, MODAL_W - 72, 'left')
    end

    -- 7. Bottom Action Bar: Cancel & Submit
    local btnY = MODAL_Y + MODAL_H - 66
    local btnH = 48

    -- Cancel Button
    local cancelW = 190
    local cancelX = MODAL_X + 24
    local isCancelHov = _pointInRect(mx, my, cancelX, btnY, cancelW, btnH)
    gc_setColor(isCancelHov and .22 or .12, isCancelHov and .25 or .14, isCancelHov and .35 or .22, .92 * bA)
    gc_rectangle('fill', cancelX, btnY, cancelW, btnH, 8)
    gc_setColor(.35, .45, .70, isCancelHov and .95 or .65 * bA)
    gc_setLineWidth(1)
    gc_rectangle('line', cancelX, btnY, cancelW, btnH, 8)
    gc_setColor(.85, .90, 1.0, isCancelHov and 1.0 or .85 * bA)
    setFont(16)
    gc_printf("Cancel", cancelX, btnY + 13, cancelW, 'center')

    -- Submit Report CTA Button
    local submitW = MODAL_W - 48 - cancelW - 16
    local submitX = cancelX + cancelW + 16
    local isSubmitHov = _pointInRect(mx, my, submitX, btnY, submitW, btnH)
    if isSubmitHov then
        gc_setColor(.80, .22, .22, .98 * bA)
        gc_rectangle('fill', submitX, btnY, submitW, btnH, 8)
        gc_setColor(1.0, .65, .65, bA)
        gc_setLineWidth(2)
        gc_rectangle('line', submitX, btnY, submitW, btnH, 8)
    else
        gc_setColor(.60, .16, .16, .92 * bA)
        gc_rectangle('fill', submitX, btnY, submitW, btnH, 8)
        gc_setColor(.95, .38, .38, .85 * bA)
        gc_setLineWidth(1.5)
        gc_rectangle('line', submitX, btnY, submitW, btnH, 8)
    end
    gc_setColor(1, 1, 1, bA)
    setFont(16)
    gc_printf("🚩  SUBMIT REPORT  ✦", submitX, btnY + 13, submitW, 'center')

    gc_pop()
end

local function _submit()
    if targetUid == "" then return end
    local reasonObj = reasons[selectedReason] or reasons[5]
    local reasonId = reasonObj.id
    local reportDetails = STRING.trim(details)

    SFX.play('enter')
    MES.new('info', "Submitting report against " .. targetUsername .. "...")

    NET.reportPlayer({
        reported_uid = targetUid,
        reported_username = targetUsername,
        reason = reasonId,
        details = reportDetails,
        room_id = roomId,
        match_id = matchId,
    }, function(success, msg)
        if success then
            MES.new('info', "Report submitted. Thank you for keeping Teblocks fair!")
        else
            MES.new('warn', "Report saved locally: " .. tostring(msg or "queued"))
        end
    end)

    _close()
end

function REPORT.mouseDown(x, y)
    if not REPORT.isOpen() or boxAlpha < 0.5 then return false end

    -- Check close button
    local closeBtnX = MODAL_X + MODAL_W - 44
    local closeBtnY = MODAL_Y + 14
    if _pointInRect(x, y, closeBtnX - 4, closeBtnY - 4, 32, 32) then
        SFX.play('back')
        _close()
        return true
    end

    -- Check reason selection
    for i = 1, #reasons do
        local chipX, chipY, chipW, chipH = _getChipRect(i)
        if _pointInRect(x, y, chipX, chipY, chipW, chipH) then
            selectedReason = i
            SFX.play('click')
            return true
        end
    end

    -- Check details input box focus
    local inBoxY = MODAL_Y + 340
    local inBoxH = 112
    if _pointInRect(x, y, MODAL_X + 24, inBoxY, MODAL_W - 48, inBoxH) then
        isInputFocused = true
        love.keyboard.setTextInput(true)
        return true
    else
        isInputFocused = false
    end

    -- Check action buttons
    local btnY = MODAL_Y + MODAL_H - 66
    local btnH = 48
    local cancelW = 190
    local cancelX = MODAL_X + 24
    if _pointInRect(x, y, cancelX, btnY, cancelW, btnH) then
        SFX.play('back')
        _close()
        return true
    end

    local submitW = MODAL_W - 48 - cancelW - 16
    local submitX = cancelX + cancelW + 16
    if _pointInRect(x, y, submitX, btnY, submitW, btnH) then
        _submit()
        return true
    end

    -- Consume clicks inside modal body
    if _pointInRect(x, y, MODAL_X, MODAL_Y, MODAL_W, MODAL_H) then
        return true
    end

    -- Click outside closes modal
    SFX.play('back')
    _close()
    return true
end
REPORT.mouseClick = REPORT.mouseDown
REPORT.touchDown = REPORT.mouseDown
REPORT.touchClick = REPORT.mouseDown

function REPORT.keyDown(key, isRep)
    if not REPORT.isOpen() then return false end

    local ctrl = love.keyboard.isDown('lctrl', 'rctrl') or love.keyboard.isDown('lgui', 'rgui')

    if key == 'escape' then
        SFX.play('back')
        _close()
        return true
    elseif key == 'return' or key == 'kpenter' then
        if ctrl or not isInputFocused then
            _submit()
            return true
        else
            -- Allow newline if input focused and length under limit
            if #details < 295 then
                details = details .. "\n"
            end
            return true
        end
    elseif key == 'backspace' then
        if #details > 0 then
            details = details:sub(1, -2)
        end
        return true
    elseif ctrl and key == 'v' then
        -- Paste clipboard content
        local clip = love.system.getClipboardText()
        if clip and type(clip) == 'string' then
            local clean = clip:gsub("[%c]", " ")
            local remaining = 300 - #details
            if remaining > 0 then
                details = details .. clean:sub(1, remaining)
            end
        end
        return true
    end
    return true
end

function REPORT.textInput(t)
    if not REPORT.isOpen() or not isInputFocused then return false end
    if #details < 300 then
        details = details .. t
    end
    return true
end

return REPORT
