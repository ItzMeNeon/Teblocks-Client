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
    {id = "macro",     label = "Macro / Auto-Player (Bot)"},
    {id = "speedhack", label = "Speedhack / Clock Warp"},
    {id = "exploit",   label = "Illegal Attack / Desync Exploit"},
    {id = "toxic",     label = "Abusive / Offensive Chat"},
    {id = "other",     label = "Other Suspicious Behavior"},
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

local MODAL_W, MODAL_H = 640, 520
local MODAL_X = (1280 - MODAL_W) * 0.5
local MODAL_Y = (720 - MODAL_H) * 0.5

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

function REPORT.draw()
    if overlayAlpha <= 0 and boxAlpha <= 0 then return end

    -- 1. Full-screen Dark Overlay
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

    -- 2. Modal Body
    local bA = boxAlpha
    gc_setColor(.07, .09, .18, .96 * bA)
    gc_rectangle('fill', MODAL_X, MODAL_Y, MODAL_W, MODAL_H, 12)

    -- Border Glow
    local borderGlow = 0.75 + 0.25 * math.sin(t * 3.5)
    gc_setColor(.85, .30, .25, borderGlow * bA)
    gc_setLineWidth(2)
    gc_rectangle('line', MODAL_X, MODAL_Y, MODAL_W, MODAL_H, 12)

    -- Header Banner
    gc_setColor(.18, .08, .12, .95 * bA)
    gc_rectangle('fill', MODAL_X, MODAL_Y, MODAL_W, 52, 12)
    gc_rectangle('fill', MODAL_X, MODAL_Y + 38, MODAL_W, 14)
    gc_setColor(1.0, .35, .30, .85 * bA)
    gc_setLineWidth(1)
    gc.line(MODAL_X, MODAL_Y + 52, MODAL_X + MODAL_W, MODAL_Y + 52)

    setFont(20)
    gc_setColor(1.0, .85, .85, bA)
    gc_print("🚩 REPORT PLAYER", MODAL_X + 22, MODAL_Y + 14)

    -- Close Button [✕] (Top right)
    local closeBtnX = MODAL_X + MODAL_W - 40
    local closeBtnY = MODAL_Y + 14
    local isCloseHov = _pointInRect(mx, my, closeBtnX - 4, closeBtnY - 4, 28, 28)
    gc_setColor(isCloseHov and 1.0 or .70, .40, .40, bA)
    setFont(16)
    gc_print("✕", closeBtnX, closeBtnY)

    -- Target Player Info Pill
    gc_setColor(.12, .16, .30, .9 * bA)
    gc_rectangle('fill', MODAL_X + 22, MODAL_Y + 66, MODAL_W - 44, 44, 6)
    gc_setColor(.35, .45, .75, .6 * bA)
    gc_setLineWidth(1)
    gc_rectangle('line', MODAL_X + 22, MODAL_Y + 66, MODAL_W - 44, 44, 6)

    setFont(13)
    gc_setColor(.65, .78, 1.0, .85 * bA)
    gc_print("Reported User:", MODAL_X + 34, MODAL_Y + 80)
    setFont(15)
    gc_setColor(1.0, .90, .40, bA)
    gc_print(targetUsername, MODAL_X + 140, MODAL_Y + 79)
    setFont(12)
    gc_setColor(.50, .60, .80, .85 * bA)
    gc_print("(UID: " .. targetUid .. ")", MODAL_X + 145 + FONT.get(15):getWidth(targetUsername), MODAL_Y + 82)

    -- Reason Selection Section
    setFont(13)
    gc_setColor(.75, .85, 1.0, .9 * bA)
    gc_print("Select Violation Category:", MODAL_X + 22, MODAL_Y + 124)

    local startY = MODAL_Y + 146
    for i, r in ipairs(reasons) do
        local chipY = startY + (i - 1) * 36
        local isSel = (selectedReason == i)
        local isHov = _pointInRect(mx, my, MODAL_X + 22, chipY, MODAL_W - 44, 30)

        if isSel then
            gc_setColor(.75, .25, .20, .85 * bA)
            gc_rectangle('fill', MODAL_X + 22, chipY, MODAL_W - 44, 30, 6)
            gc_setColor(1.0, .55, .50, bA)
            gc_setLineWidth(1.5)
            gc_rectangle('line', MODAL_X + 22, chipY, MODAL_W - 44, 30, 6)
            gc_setColor(1, 1, 1, bA)
        else
            gc_setColor(isHov and .18 or .10, isHov and .22 or .13, isHov and .35 or .22, .8 * bA)
            gc_rectangle('fill', MODAL_X + 22, chipY, MODAL_W - 44, 30, 6)
            gc_setColor(.28, .36, .58, (isHov and .8 or .5) * bA)
            gc_setLineWidth(1)
            gc_rectangle('line', MODAL_X + 22, chipY, MODAL_W - 44, 30, 6)
            gc_setColor(.85, .90, .98, (isHov and 1.0 or .80) * bA)
        end

        -- Radio dot indicator
        gc_setColor(isSel and 1.0 or .50, isSel and .60 or .60, isSel and .55 or .70, bA)
        gc_circle(isSel and 'fill' or 'line', MODAL_X + 40, chipY + 15, isSel and 5 or 4)

        setFont(13)
        gc_setColor(isSel and 1.0 or .85, isSel and 1.0 or .88, 1.0, bA)
        gc_print(r.label, MODAL_X + 54, chipY + 7)
    end

    -- Details Input Label
    local inputLabelY = startY + #reasons * 36 + 10
    setFont(13)
    gc_setColor(.75, .85, 1.0, .9 * bA)
    gc_print("Additional Details / Evidence (Optional):", MODAL_X + 22, inputLabelY)

    -- Details Input Box
    local inBoxY = inputLabelY + 22
    local inBoxH = 64
    gc_setColor(.09, .12, .24, .95 * bA)
    gc_rectangle('fill', MODAL_X + 22, inBoxY, MODAL_W - 44, inBoxH, 6)
    gc_setColor(isInputFocused and 1.0 or .28, isInputFocused and .60 or .40, isInputFocused and .55 or .70, (isInputFocused and 1.0 or .6) * bA)
    gc_setLineWidth(isInputFocused and 1.5 or 1)
    gc_rectangle('line', MODAL_X + 22, inBoxY, MODAL_W - 44, inBoxH, 6)

    setFont(13)
    if #details == 0 and not isInputFocused then
        gc_setColor(.45, .55, .70, .7 * bA)
        gc_print("Describe what happened (e.g. impossible speed, instant placements, chat spam)...", MODAL_X + 32, inBoxY + 12)
    else
        gc_setColor(1, 1, 1, bA)
        gc_printf(details .. (isInputFocused and ((t * 2 % 1 > .5) and "|" or "") or ""), MODAL_X + 32, inBoxY + 10, MODAL_W - 64, 'left')
    end

    -- Bottom Buttons: Cancel & Submit
    local btnY = inBoxY + inBoxH + 18
    local btnH = 46

    -- Cancel Button
    local cancelW = 160
    local cancelX = MODAL_X + 22
    local isCancelHov = _pointInRect(mx, my, cancelX, btnY, cancelW, btnH)
    gc_setColor(isCancelHov and .22 or .12, isCancelHov and .25 or .14, isCancelHov and .35 or .22, .9 * bA)
    gc_rectangle('fill', cancelX, btnY, cancelW, btnH, 8)
    gc_setColor(.35, .45, .70, isCancelHov and .9 or .6 * bA)
    gc_setLineWidth(1)
    gc_rectangle('line', cancelX, btnY, cancelW, btnH, 8)
    gc_setColor(.85, .90, 1.0, isCancelHov and 1.0 or .8 * bA)
    setFont(15)
    gc_printf("Cancel", cancelX, btnY + 13, cancelW, 'center')

    -- Submit Report CTA Button
    local submitW = MODAL_W - 44 - cancelW - 14
    local submitX = cancelX + cancelW + 14
    local isSubmitHov = _pointInRect(mx, my, submitX, btnY, submitW, btnH)
    if isSubmitHov then
        gc_setColor(.75, .20, .20, .95 * bA)
        gc_rectangle('fill', submitX, btnY, submitW, btnH, 8)
        gc_setColor(1.0, .60, .60, bA)
        gc_setLineWidth(2)
        gc_rectangle('line', submitX, btnY, submitW, btnH, 8)
    else
        gc_setColor(.55, .15, .15, .90 * bA)
        gc_rectangle('fill', submitX, btnY, submitW, btnH, 8)
        gc_setColor(.90, .35, .35, .85 * bA)
        gc_setLineWidth(1.5)
        gc_rectangle('line', submitX, btnY, submitW, btnH, 8)
    end
    gc_setColor(1, 1, 1, bA)
    setFont(15)
    gc_printf("SUBMIT REPORT  ✦", submitX, btnY + 13, submitW, 'center')
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
    local closeBtnX = MODAL_X + MODAL_W - 40
    local closeBtnY = MODAL_Y + 14
    if _pointInRect(x, y, closeBtnX - 4, closeBtnY - 4, 28, 28) then
        SFX.play('back')
        _close()
        return true
    end

    -- Check reason selection
    local startY = MODAL_Y + 146
    for i = 1, #reasons do
        local chipY = startY + (i - 1) * 36
        if _pointInRect(x, y, MODAL_X + 22, chipY, MODAL_W - 44, 30) then
            selectedReason = i
            SFX.play('click')
            return true
        end
    end

    -- Check details input box focus
    local inputLabelY = startY + #reasons * 36 + 10
    local inBoxY = inputLabelY + 22
    local inBoxH = 64
    if _pointInRect(x, y, MODAL_X + 22, inBoxY, MODAL_W - 44, inBoxH) then
        isInputFocused = true
        love.keyboard.setTextInput(true)
        return true
    else
        isInputFocused = false
    end

    -- Check buttons
    local btnY = inBoxY + inBoxH + 18
    local btnH = 46
    local cancelW = 160
    local cancelX = MODAL_X + 22
    if _pointInRect(x, y, cancelX, btnY, cancelW, btnH) then
        SFX.play('back')
        _close()
        return true
    end

    local submitW = MODAL_W - 44 - cancelW - 14
    local submitX = cancelX + cancelW + 14
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

    if key == 'escape' then
        SFX.play('back')
        _close()
        return true
    elseif key == 'return' or key == 'kpenter' then
        if not isInputFocused then
            _submit()
            return true
        end
    elseif key == 'backspace' then
        if #details > 0 then
            details = details:sub(1, -2)
        end
        return true
    end
    return true
end

function REPORT.textInput(t)
    if not REPORT.isOpen() or not isInputFocused then return false end
    if #details < 256 then
        details = details .. t
    end
    return true
end

return REPORT
