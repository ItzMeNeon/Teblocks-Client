local REG_CONFIRM = {}

local _isOpen = false
local overlayAlpha = 0
local boxAlpha = 0
local openTimer = 0
local onAgreeCb = nil

local gc = love.graphics
local gc_setColor, gc_setLineWidth = gc.setColor, gc.setLineWidth
local gc_rectangle = gc.rectangle
local gc_push, gc_pop = gc.push, gc.pop
local gc_replaceTransform = gc.replaceTransform
local gc_print, gc_printf = gc.print, gc.printf

local MODAL_W, MODAL_H = 680, 480
local MODAL_X = (1280 - MODAL_W) * 0.5
local MODAL_Y = (720 - MODAL_H) * 0.5

local BTN_Y = MODAL_Y + 405
local BTN_H = 50

local DECLINE_X = MODAL_X + 35
local DECLINE_W = 260

local AGREE_X = MODAL_X + MODAL_W - 35 - 320
local AGREE_W = 320

local function _close()
    _isOpen = false
    onAgreeCb = nil
    openTimer = 0
end

local function _pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function REG_CONFIRM.open(cb)
    _isOpen = true
    openTimer = 0.35
    onAgreeCb = cb
end

function REG_CONFIRM.close()
    _close()
end

function REG_CONFIRM.isOpen()
    return _isOpen or overlayAlpha > 0.01 or boxAlpha > 0.01
end

function REG_CONFIRM.update(dt)
    if _isOpen then
        WIDGET.locked = true
        if openTimer > 0 then
            openTimer = math.max(0, openTimer - dt)
        end
        overlayAlpha = math.min(overlayAlpha + dt * 10, 0.72)
        boxAlpha     = math.min(boxAlpha + dt * 10, 1.0)
    else
        overlayAlpha = math.max(overlayAlpha - dt * 10, 0)
        boxAlpha     = math.max(boxAlpha - dt * 10, 0)
    end
end

function REG_CONFIRM.draw()
    if overlayAlpha <= 0 and boxAlpha <= 0 then return end

    -- ── 1. Full-screen Dark Overlay (darkens all underlying widgets & UI) ──
    gc_push('transform')
    gc_replaceTransform(SCR.origin)
    if overlayAlpha > 0 then
        gc_setColor(0, 0, 0, overlayAlpha)
        gc_rectangle('fill', 0, 0, SCR.w, SCR.h)
    end
    gc_pop()

    if boxAlpha <= 0 then return end

    -- ── 2. Modal Dialog Window (centered on 1280x720 canvas) ──
    gc_push('transform')
    gc_replaceTransform(SCR.xOy)

    local mx, my = SCR.xOy:inverseTransformPoint(love.mouse.getPosition())

    -- Main Card Backdrop
    gc_setColor(.07, .09, .18, .96 * boxAlpha)
    gc_rectangle('fill', MODAL_X, MODAL_Y, MODAL_W, MODAL_H, 12)

    -- Sleek Neon Accent Border
    gc_setColor(.25, .55, .95, .90 * boxAlpha)
    gc_setLineWidth(2)
    gc_rectangle('line', MODAL_X, MODAL_Y, MODAL_W, MODAL_H, 12)

    -- Header Title
    setFont(24)
    gc_setColor(1, 1, 1, boxAlpha)
    gc_print("ACCOUNT REGISTRATION", MODAL_X + 32, MODAL_Y + 22)

    -- Subtitle
    setFont(12)
    gc_setColor(.55, .72, .95, .85 * boxAlpha)
    gc_print("Please review and agree to the 3 Community Rules before registering:", MODAL_X + 32, MODAL_Y + 54)

    -- Divider line
    gc_setColor(.25, .40, .70, .45 * boxAlpha)
    gc_rectangle('fill', MODAL_X + 30, MODAL_Y + 76, MODAL_W - 60, 1)

    -- ── The 3 Rules Cards ────────────────────────────────────
    local rules = {
        {
            num   = "1",
            title = "No Cheating or Macro Exploits",
            desc  = "Third-party input scripts, automated bots, and unfair game modifications are strictly banned in multiplayer and leaderboards.",
            color = { .25, .80, 1.0 },
        },
        {
            num   = "2",
            title = "One Account Per Player (No Multi-Accounting)",
            desc  = "Each player is permitted only one Teblocks account. Smurfing, account sharing, and rating manipulation will lead to bans.",
            color = { 1.0, .75, .25 },
        },
        {
            num   = "3",
            title = "Be Respectful & Have Common Sense",
            desc  = "Treat all players with good sportsmanship. Harassment, hate speech, toxicity, and griefing are not tolerated.",
            color = { .35, .95, .55 },
        },
    }

    local cardY = MODAL_Y + 92
    for _, r in ipairs(rules) do
        -- Rule Card Box
        gc_setColor(.04, .06, .14, .85 * boxAlpha)
        gc_rectangle('fill', MODAL_X + 30, cardY, MODAL_W - 60, 78, 8)
        gc_setColor(r.color[1], r.color[2], r.color[3], .35 * boxAlpha)
        gc_setLineWidth(1)
        gc_rectangle('line', MODAL_X + 30, cardY, MODAL_W - 60, 78, 8)

        -- Number Pill Badge
        gc_setColor(r.color[1], r.color[2], r.color[3], .25 * boxAlpha)
        gc_rectangle('fill', MODAL_X + 42, cardY + 14, 30, 30, 6)
        gc_setColor(r.color[1], r.color[2], r.color[3], .90 * boxAlpha)
        gc_setLineWidth(1.5)
        gc_rectangle('line', MODAL_X + 42, cardY + 14, 30, 30, 6)
        setFont(16)
        GC.mStr(r.num, MODAL_X + 57, cardY + 20)

        -- Rule Title
        setFont(15)
        gc_setColor(1, 1, 1, .98 * boxAlpha)
        gc_print(r.title, MODAL_X + 84, cardY + 12)

        -- Rule Description
        setFont(11)
        gc_setColor(.70, .80, .92, .80 * boxAlpha)
        gc_printf(r.desc, MODAL_X + 84, cardY + 34, MODAL_W - 130)

        cardY = cardY + 90
    end

    -- Notice text
    setFont(11)
    gc_setColor(.55, .65, .82, .75 * boxAlpha)
    GC.mStr("Agreeing will open the Teblocks web registration page in your browser.", MODAL_X + MODAL_W * 0.5, MODAL_Y + 372)

    -- ── Action Buttons ───────────────────────────────────────
    -- 1. Decline Button (Red / Cancel)
    local isHovDecline = _pointInRect(mx, my, DECLINE_X, BTN_Y, DECLINE_W, BTN_H)
    if isHovDecline then
        gc_setColor(.35, .12, .16, .95 * boxAlpha)
        gc_rectangle('fill', DECLINE_X, BTN_Y, DECLINE_W, BTN_H, 6)
        gc_setColor(.95, .35, .45, 1 * boxAlpha)
        gc_setLineWidth(1.5)
        gc_rectangle('line', DECLINE_X, BTN_Y, DECLINE_W, BTN_H, 6)
        gc_setColor(1, 1, 1, boxAlpha)
    else
        gc_setColor(.18, .08, .10, .85 * boxAlpha)
        gc_rectangle('fill', DECLINE_X, BTN_Y, DECLINE_W, BTN_H, 6)
        gc_setColor(.75, .25, .35, .7 * boxAlpha)
        gc_setLineWidth(1)
        gc_rectangle('line', DECLINE_X, BTN_Y, DECLINE_W, BTN_H, 6)
        gc_setColor(.85, .85, .85, .9 * boxAlpha)
    end
    setFont(16)
    GC.mStr("✕ Decline & Cancel", DECLINE_X + DECLINE_W * 0.5, BTN_Y + 15)

    -- 2. Agree Button (Green / Proceed to Website)
    local isHovAgree = _pointInRect(mx, my, AGREE_X, BTN_Y, AGREE_W, BTN_H)
    if isHovAgree then
        gc_setColor(.16, .45, .28, .95 * boxAlpha)
        gc_rectangle('fill', AGREE_X, BTN_Y, AGREE_W, BTN_H, 6)
        gc_setColor(.35, 1.0, .60, 1 * boxAlpha)
        gc_setLineWidth(1.5)
        gc_rectangle('line', AGREE_X, BTN_Y, AGREE_W, BTN_H, 6)
        gc_setColor(1, 1, 1, boxAlpha)
    else
        gc_setColor(.10, .32, .18, .88 * boxAlpha)
        gc_rectangle('fill', AGREE_X, BTN_Y, AGREE_W, BTN_H, 6)
        gc_setColor(.25, .80, .45, .8 * boxAlpha)
        gc_setLineWidth(1)
        gc_rectangle('line', AGREE_X, BTN_Y, AGREE_W, BTN_H, 6)
        gc_setColor(.92, 1, .94, .95 * boxAlpha)
    end
    setFont(16)
    GC.mStr("✓ Agree & Continue to Web", AGREE_X + AGREE_W * 0.5, BTN_Y + 15)

    gc_pop()
end

function REG_CONFIRM.mouseClick(x, y)
    if not _isOpen then return false end

    -- 1. Decline button clicked
    if _pointInRect(x, y, DECLINE_X, BTN_Y, DECLINE_W, BTN_H) then
        _close()
        SFX.play('back')
        MES.new('info', "Registration cancelled")
        return true
    end

    -- 2. Agree button clicked
    if _pointInRect(x, y, AGREE_X, BTN_Y, AGREE_W, BTN_H) then
        local cb = onAgreeCb
        _close()
        SFX.play('reach')
        if cb then
            cb()
        else
            local baseWeb = (AUTHURL and AUTHURL:find("^http")) and AUTHURL or "https://teblocks.my.id"
            love.system.openURL(baseWeb .. "/register")
            MES.new('check', "Opening registration page in web browser...")
        end
        return true
    end

    -- 3. Click inside modal card (consume click, don't dismiss)
    if _pointInRect(x, y, MODAL_X, MODAL_Y, MODAL_W, MODAL_H) then
        return true
    end

    -- 4. Click outside modal (closes/declines if openTimer expired)
    if openTimer <= 0 then
        _close()
        SFX.play('back')
    end
    return true
end

function REG_CONFIRM.keyDown(key, rep)
    if not _isOpen then return false end

    if key == 'escape' and not rep then
        _close()
        SFX.play('back')
        return true
    elseif (key == 'return' or key == 'kpenter') and not rep then
        local cb = onAgreeCb
        _close()
        SFX.play('reach')
        if cb then
            cb()
        else
            local baseWeb = (AUTHURL and AUTHURL:find("^http")) and AUTHURL or "https://teblocks.my.id"
            love.system.openURL(baseWeb .. "/register")
            MES.new('check', "Opening registration page in web browser...")
        end
        return true
    end

    return true
end

return REG_CONFIRM
