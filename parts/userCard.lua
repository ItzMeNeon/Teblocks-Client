local gc = love.graphics
local gc_setColor, gc_setLineWidth = gc.setColor, gc.setLineWidth
local gc_draw, gc_rectangle = gc.draw, gc.rectangle
local gc_print, gc_printf = gc.print, gc.printf
local gc_push, gc_pop = gc.push, gc.pop
local gc_replaceTransform = gc.replaceTransform
local gc_stencil, gc_setStencilTest = gc.stencil, gc.setStencilTest
local setFont = FONT.set
local approach = MATH.expApproach

local CARD = {}

local AUTH = require 'parts.authModal'
local LOBBY = require 'parts.lobbyPanel'

CARD.w = 230
CARD.h = 40
CARD.x = 1280 - CARD.w - 16 -- 1034
CARD.y = 6
CARD.slideX = 0
CARD.alpha = 1
CARD.open = true
CARD.menu = false
CARD.menuAlpha = 0
CARD.playerName = ""

local BCL = {
    COLOR.lR, COLOR.lS, COLOR.lV, COLOR.lO,
    COLOR.lM, COLOR.lY, COLOR.lC,
}

local function getMousePos()
    if SCR and SCR.xOy then
        return SCR.xOy:inverseTransformPoint(love.mouse.getPosition())
    end
    return love.mouse.getPosition()
end

function CARD.getPos()
    local x = (CARD.x or (1280 - CARD.w - 16)) + (CARD.slideX or 0)
    local y = CARD.y or 6
    return x, y
end

function CARD.reset()
    CARD.playerName = ""
    CARD.menu = false
    CARD.menuAlpha = 0
end

function CARD.enter(startX)
    CARD.open = true
    CARD.menu = false
    CARD.menuAlpha = 0
    CARD.alpha = 0
    CARD.slideX = startX or 0
    if USER and USER.uid then NET.getUserInfo(USER.uid) end
end

function CARD.leave()
    CARD.open = false
    CARD.menu = false
    CARD.menuAlpha = 0
end

function CARD.update(dt)
    local cardVisible = CARD.open and not (LOBBY and LOBBY.chat and LOBBY.chat.visible)
    local targetX = cardVisible and 0 or (CARD.w + 40)
    CARD.slideX = approach(CARD.slideX, targetX, dt * 14)
    if cardVisible then
        CARD.alpha = math.min(CARD.alpha + dt * 10, 1)
    else
        CARD.alpha = math.max(CARD.alpha - dt * 10, 0)
    end
    if CARD.menu then
        CARD.menuAlpha = math.min(CARD.menuAlpha + dt * 16, 1)
    else
        CARD.menuAlpha = math.max(CARD.menuAlpha - dt * 16, 0)
    end
end

local function getMenuItems()
    local baseWeb = (AUTHURL and AUTHURL:find("^http")) and AUTHURL or "https://teblocks.my.id"
    local uid = USER and USER.uid
    local isLogged = uid and uid ~= false
    local items = {}

    if isLogged then
        table.insert(items, {
            icon = CHAR.mino.T,
            label = "Skin Direct",
            sub = "Browse community skins",
            code = function() SCN.go('skin_browse') end
        })
        table.insert(items, {
            icon = CHAR.icon.globe,
            label = "View Profile",
            sub = "Open web profile page",
            url = baseWeb .. "/profile"
        })
        table.insert(items, {
            icon = CHAR.icon.info,
            label = "Match History",
            sub = "Replays & match records",
            url = baseWeb .. "/history"
        })
        table.insert(items, {
            icon = CHAR.icon.crossMark,
            label = "Log Out",
            sub = "Sign out of account",
            color = COLOR.lR,
            code = function()
                USER.__data.uid = false
                USER.__data.aToken = false
                USER.__data.oToken = false
                love.filesystem.remove('conf/user')
                STAT.elo = nil
                STAT.globalRank = nil
                NET.ws_close()
                CARD.reset()
                MES.new('info', "Logged out")
                if SCN.cur ~= 'main' then
                    SCN.backTo('main')
                else
                    NET.ws_connect()
                end
            end
        })
    else
        local REG_CONFIRM = require 'parts.registerConfirmModal'
        table.insert(items, {
            icon = CHAR.icon.checkMark,
            label = "Log In",
            sub = "Sign into your account",
            color = COLOR.lG,
            code = function() AUTH.open('login') end
        })
        table.insert(items, {
            icon = CHAR.icon.export,
            label = "Register Account",
            sub = "Create a new Teblocks ID",
            code = function() REG_CONFIRM.open() end
        })
        table.insert(items, {
            icon = CHAR.mino.T,
            label = "Skin Direct",
            sub = "Browse community skins",
            code = function()
                if not (USER and USER.uid and USER.uid ~= false) then
                    MES.new('warn', "Please log in to access Skin Direct")
                    AUTH.open('login')
                else
                    SCN.go('skin_browse')
                end
            end
        })
    end
    return items
end

function CARD._isCardAbove(mx, my)
    if CARD.alpha < 0.3 then return false end
    local cardX, cardY = CARD.getPos()
    return mx >= cardX and mx <= cardX + CARD.w and my >= cardY and my <= cardY + CARD.h
end

function CARD.mouseClick(x, y)
    local cardX, cardY = CARD.getPos()

    -- Dropdown Menu interactions
    if CARD.menuAlpha > 0.05 and CARD.menu then
        local items = getMenuItems()
        local itemH = 38
        local uid = USER and USER.uid
        local isLogged = uid and uid ~= false
        local headerH = isLogged and 46 or 36
        local menuW = 230
        local menuH = headerH + #items * itemH + 8
        local menuX = cardX + CARD.w - menuW
        local menuY = cardY + CARD.h + 4

        if x >= menuX and x <= menuX + menuW and y >= menuY and y <= menuY + menuH then
            for i, item in ipairs(items) do
                local iy = menuY + headerH + 4 + (i - 1) * itemH
                if y >= iy and y < iy + itemH then
                    CARD.closeMenu()
                    SFX.play('click')
                    if item.url then
                        love.system.openURL(item.url)
                    elseif item.code then
                        item.code()
                    end
                    return true
                end
            end
            return true
        end

        -- Clicking outside dropdown menu closes it
        CARD.closeMenu()
        if not CARD._isCardAbove(x, y) then
            return true
        end
    end

    -- Click on Card Pill
    if CARD._isCardAbove(x, y) then
        CARD.toggleMenu()
        SFX.play('click')
        return true
    end

    return false
end

function CARD.openMenu()
    CARD.menu = true
end

function CARD.closeMenu()
    CARD.menu = false
end

function CARD.toggleMenu()
    CARD.menu = not CARD.menu
end

function CARD.setOpen(state)
    CARD.open = state
end

function CARD.draw()
    if CARD.alpha <= 0 and CARD.menuAlpha <= 0 then return end

    local cardX, cardY = CARD.getPos()
    local mx, my = getMousePos()
    local isHover = (mx >= cardX and mx <= cardX + CARD.w and my >= cardY and my <= cardY + CARD.h)

    local uid = USER and USER.uid
    local isLogged = uid and uid ~= false
    local uname = isLogged and USERS.getUsername(uid) or "Guest Player"
    if not uname or #uname == 0 then uname = "Guest Player" end

    gc_push('transform')
    gc_replaceTransform(SCR.xOy)

    -- Pill Background
    if CARD.alpha > 0 then
        if isHover or CARD.menu then
            gc_setColor(.14, .20, .42, .88 * CARD.alpha)
            gc_rectangle('fill', cardX, cardY, CARD.w, CARD.h, 7)
            gc_setColor(.38, .60, 1.0, .90 * CARD.alpha)
            gc_setLineWidth(1.5)
            gc_rectangle('line', cardX, cardY, CARD.w, CARD.h, 7)
        else
            gc_setColor(.07, .10, .22, .65 * CARD.alpha)
            gc_rectangle('fill', cardX, cardY, CARD.w, CARD.h, 7)
            gc_setColor(.22, .32, .60, .55 * CARD.alpha)
            gc_setLineWidth(1)
            gc_rectangle('line', cardX, cardY, CARD.w, CARD.h, 7)
        end

        -- Circular Avatar
        local avX, avY, avR = cardX + 20, cardY + CARD.h * 0.5, 14
        local avatar = isLogged and USERS.getAvatar(uid) or USERS.getAvatar(nil)
        if avatar then
            gc_setColor(1, 1, 1, CARD.alpha)
            gc_stencil(function() gc.circle('fill', avX, avY, avR) end, 'replace', 1)
            gc_setStencilTest('equal', 1)
            local aw, ah = avatar:getDimensions()
            local s = (avR * 2) / math.max(aw, ah)
            gc_draw(avatar, avX - avR, avY - avR, 0, s, s)
            gc_setStencilTest()

            gc_setColor(.35, .65, 1.0, (isHover and .9 or .6) * CARD.alpha)
            gc_setLineWidth(1.5)
            gc.circle('line', avX, avY, avR)
        else
            local t = love.timer.getTime()
            local idx = math.floor(t * 0.4) % 7 + 1
            local bc = BCL[idx]
            gc_setColor(bc[1], bc[2], bc[3], .35 * CARD.alpha)
            gc.circle('fill', avX, avY, avR)
            gc_setColor(bc[1], bc[2], bc[3], .80 * CARD.alpha)
            gc_setLineWidth(1.5)
            gc.circle('line', avX, avY, avR)
            gc_setColor(1, 1, 1, .6 * CARD.alpha)
            setFont(14)
            gc.printf("?", avX - 10, avY - 8, 20, 'center')
        end

        -- Text Info
        local tx = cardX + 42
        local maxTextW = CARD.w - 62
        setFont(13)
        local displayName = uname
        if FONT.get(13):getWidth(displayName) > maxTextW then
            while #displayName > 3 and FONT.get(13):getWidth(displayName .. "...") > maxTextW do
                displayName = displayName:sub(1, -2)
            end
            displayName = displayName .. "..."
        end

        gc_setColor(.95, .98, 1, .95 * CARD.alpha)
        gc_print(displayName, tx, cardY + 5)

        -- Status dot (online green dot if logged in)
        if isLogged then
            local dotX = tx + FONT.get(13):getWidth(displayName) + 6
            if dotX < cardX + CARD.w - 20 then
                gc_setColor(.2, .85, .4, .9 * CARD.alpha)
                gc.circle('fill', dotX, cardY + 11, 3.5)
            end
        end

        -- Subtitle: Rank / ELO or guest hint
        setFont(10)
        if isLogged then
            local rank = STAT.globalRank or 0
            local rankStr = rank > 0 and ("#" .. rank) or "Unranked"
            local elo = STAT.elo or 1200
            gc_setColor(.55, .72, .95, .85 * CARD.alpha)
            gc_print(("★ %d ELO   %s"):format(elo, rankStr), tx, cardY + 22)
        else
            gc_setColor(.95, .75, .25, .85 * CARD.alpha)
            gc_print("Click to Log In", tx, cardY + 22)
        end

        -- Dropdown indicator arrow
        gc_setColor(.60, .72, .95, (isHover and .9 or .6) * CARD.alpha)
        setFont(11)
        gc.printf(CARD.menu and "▲" or "▼", cardX + CARD.w - 20, cardY + 13, 16, 'center')
    end

    -- Dropdown Menu
    if CARD.menuAlpha > 0.05 then
        local items = getMenuItems()
        local itemH = 38
        local headerH = isLogged and 46 or 36
        local menuW = 230
        local menuH = headerH + #items * itemH + 8
        local menuX = cardX + CARD.w - menuW
        local menuY = cardY + CARD.h + 4

        -- Container backdrop & border
        gc_setColor(.04, .06, .14, .96 * CARD.menuAlpha)
        gc_rectangle('fill', menuX, menuY, menuW, menuH, 8)
        gc_setColor(.24, .36, .75, .8 * CARD.menuAlpha)
        gc_setLineWidth(1.5)
        gc_rectangle('line', menuX, menuY, menuW, menuH, 8)

        -- Header within menu
        gc_setColor(.10, .14, .30, .7 * CARD.menuAlpha)
        gc_rectangle('fill', menuX + 6, menuY + 6, menuW - 12, headerH - 8, 5)

        if isLogged then
            setFont(13)
            gc_setColor(1, 1, 1, .95 * CARD.menuAlpha)
            gc_print(uname, menuX + 14, menuY + 10)
            setFont(10)
            local elo = STAT.elo or 1200
            local rank = STAT.globalRank or 0
            local rankStr = rank > 0 and ("#" .. rank) or "Unranked"
            gc_setColor(.55, .75, 1, .85 * CARD.menuAlpha)
            gc_print(("Rating: %d ELO  •  %s"):format(elo, rankStr), menuX + 14, menuY + 26)
        else
            setFont(12)
            gc_setColor(.95, .75, .25, .95 * CARD.menuAlpha)
            gc_print("Not logged in", menuX + 14, menuY + 12)
        end

        -- Menu items
        for i, item in ipairs(items) do
            local iy = menuY + headerH + 4 + (i - 1) * itemH
            local isItemHover = (mx >= menuX + 6 and mx <= menuX + menuW - 6 and my >= iy and my < iy + itemH)

            if isItemHover then
                gc_setColor(.18, .26, .55, .75 * CARD.menuAlpha)
                gc_rectangle('fill', menuX + 6, iy, menuW - 12, itemH - 2, 5)
                gc_setColor(.40, .60, 1.0, .7 * CARD.menuAlpha)
                gc_setLineWidth(1)
                gc_rectangle('line', menuX + 6, iy, menuW - 12, itemH - 2, 5)
            end

            -- Icon
            if item.icon then
                setFont(14)
                if item.color then
                    gc_setColor(item.color[1], item.color[2], item.color[3], .95 * CARD.menuAlpha)
                else
                    gc_setColor(.45, .75, 1.0, .95 * CARD.menuAlpha)
                end
                gc.printf(item.icon, menuX + 12, iy + 6, 20, 'center')
            end

            -- Label & Subtitle
            setFont(12)
            if item.color then
                gc_setColor(item.color[1], item.color[2], item.color[3], (isItemHover and 1 or .9) * CARD.menuAlpha)
            else
                gc_setColor(isItemHover and 1 or .9, isItemHover and 1 or .94, 1, CARD.menuAlpha)
            end
            gc_print(item.label, menuX + 38, iy + 4)

            if item.sub then
                setFont(10)
                gc_setColor(.48, .56, .78, .75 * CARD.menuAlpha)
                gc_print(item.sub, menuX + 38, iy + 20)
            end
        end
    end

    gc_pop()
end

return CARD
