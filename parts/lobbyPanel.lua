local gc = love.graphics
local gc_setColor, gc_setLineWidth = gc.setColor, gc.setLineWidth
local gc_rectangle = gc.rectangle
local gc_print, gc_printf = gc.print, gc.printf
local gc_line = gc.line
local setFont = FONT.set

local LOBBY = {}
LOBBY.playerList = nil

CHAT = CHAT or require 'parts.globalChat'
LOBBY.chat = CHAT

function LOBBY.init()
    LOBBY.chat = CHAT or require 'parts.globalChat'
    if LOBBY.playerList then return end

    LOBBY.playerList = PANEL.new('playerList', 'left')
    LOBBY.playerList:setSize(520, 720)
    LOBBY.playerList:setTitle("Online Players")

    function LOBBY.playerList:drawContent()
        gc_setColor(1, 1, 1, .5 * self.alpha)
        setFont(16)
        gc_print((text.onlinePlayerCount or "$1 online"):repD(NET.onlineCount), 20, 150)

        gc_setColor(1, 1, 1, .2 * self.alpha)
        gc_setLineWidth(1)
        gc_line(20, 180, self.w - 20, 180)

        setFont(18)
        gc_setColor(1, 1, 1, self.alpha)
        local y = 200
        if NET.onlinePlayers then
            for i, p in ipairs(NET.onlinePlayers) do
                if y > 680 then break end
                local name = p.username
                if not name or #name == 0 or name == p.id then
                    name = USERS.getUsername(p.id)
                end
                if not name or #name == 0 then
                    name = p.id or "Guest"
                end
                gc_print(name, 30, y)
                if type(p.elo) == 'number' then
                    gc_setColor(COLOR.lY)
                    gc_printf(tostring(p.elo), self.w - 120, y, 100, 'right')
                    gc_setColor(1, 1, 1, self.alpha)
                end
                y = y + 28
            end
        end
    end
end

function LOBBY.update(dt)
    LOBBY.init()
    if LOBBY.playerList then LOBBY.playerList:update(dt) end
    if CHAT and CHAT.update then CHAT.update(dt) end
    WIDGET.blockZone = LOBBY.isAnyOpen() and LOBBY.isInside or nil
end

function LOBBY.draw()
    LOBBY.init()
    if LOBBY.playerList then LOBBY.playerList:draw() end
    -- CHAT is also drawn in global overlay, but if called here it renders cleanly
end

function LOBBY.drawToggleButtons()
    LOBBY.init()
    if LOBBY.playerList then LOBBY.playerList:drawToggleButton() end
end

function LOBBY.mouseClick(x, y)
    LOBBY.init()
    if LOBBY.playerList and LOBBY.playerList:checkToggleButtonClick(x, y) then return true end
    if CHAT and CHAT.mouseClick and CHAT.mouseClick(x, y) then return true end

    if LOBBY.playerList and LOBBY.playerList.visible and LOBBY.playerList.alpha > 0.5 then
        if x >= LOBBY.playerList.x + 20 and x <= LOBBY.playerList.x + LOBBY.playerList.w - 20 and y >= 200 and y <= 680 then
            local idx = math.floor((y - 200) / 28) + 1
            if NET.onlinePlayers and NET.onlinePlayers[idx] then
                local p = NET.onlinePlayers[idx]
                if p.id and p.id ~= USER.uid then
                    local REPORT = require 'parts.reportModal'
                    local name = p.username
                    if not name or #name == 0 or name == p.id then
                        name = USERS.getUsername(p.id)
                    end
                    if not name or #name == 0 then name = p.id or "Player" end
                    REPORT.open(p.id, name, "Online Players", "")
                    SFX.play('click')
                    return true
                end
            end
        end
    end

    return false
end

function LOBBY.keyDown(key, isRep)
    if CHAT and CHAT.keyDown and CHAT.keyDown(key, isRep) then
        return true
    end
    return false
end

function LOBBY.textInput(t)
    if CHAT and CHAT.textInput and CHAT.textInput(t) then
        return true
    end
    return false
end

function LOBBY.reset()
    LOBBY.init()
    if LOBBY.playerList then LOBBY.playerList:hide() end
    if CHAT and CHAT.close then CHAT.close() end
end

function LOBBY.isAnyOpen()
    return (LOBBY.playerList and LOBBY.playerList.visible) or (CHAT and CHAT.isOpen)
end

function LOBBY.isInside(x, y)
    if LOBBY.playerList and LOBBY.playerList:isInside(x, y) then return true end
    if CHAT and CHAT:isInside(x, y) then return true end
    return false
end

return LOBBY
