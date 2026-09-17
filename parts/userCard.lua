local gc=love.graphics
local gc_setColor,gc_setLineWidth=gc.setColor,gc.setLineWidth
local gc_draw,gc_rectangle=gc.draw,gc.rectangle
local gc_print,gc_printf=gc.print,gc.printf
local gc_push,gc_pop=gc.push,gc.pop
local gc_replaceTransform=gc.replaceTransform
local gc_translate=gc.translate
local gc_stencil,gc_setStencilTest=gc.stencil,gc.setStencilTest

local approach=MATH.expApproach

local CARD={}

local AUTH=require'parts.authModal'
local LOBBY=require'parts.lobbyPanel'

CARD.w=310
CARD.h=120
CARD.x=nil
CARD.y=nil
CARD.slideX=320
CARD.alpha=0
CARD.open=false
CARD.menu=false
CARD.menuAlpha=0
CARD.playerName=""
CARD.nameTextObj=nil
CARD.nameScaleK=1
CARD.nameWidth=0
CARD.nameOffY=0

local menuItems={}

function CARD.getPos()
    local x=(CARD.x or (1280-CARD.w-10))+CARD.slideX
    local y=CARD.y or 10
    return x,y
end

function CARD.reset()
    CARD.playerName=""
    CARD.nameTextObj=nil
    CARD.nameScaleK=1
    CARD.nameWidth=0
    CARD.nameOffY=0
end

function CARD.enter(startX)
    CARD.open=true
    CARD.menu=false
    CARD.menuAlpha=0
    CARD.alpha=0
    CARD.slideX=startX or 320
    if USER.uid then NET.getUserInfo(USER.uid) end
end

function CARD.leave()
    CARD.open=false
    CARD.menu=false
    CARD.menuAlpha=0
end

function CARD.update(dt)
    -- The card is hidden (slid out and faded) while the global chat panel is open
    local cardVisible = CARD.open and not (LOBBY and LOBBY.chat and LOBBY.chat.visible)
    local targetX = cardVisible and 0 or CARD.w
    CARD.slideX=approach(CARD.slideX,targetX,dt*12)
    if cardVisible then
        CARD.alpha=math.min(CARD.alpha+dt*8,1)
    else
        CARD.alpha=math.max(CARD.alpha-dt*8,0)
    end
    if CARD.menu then
        CARD.menuAlpha=math.min(CARD.menuAlpha+dt*10,1)
    else
        CARD.menuAlpha=math.max(CARD.menuAlpha-dt*10,0)
    end
end

function CARD._isCardAbove(mx,my)
    if CARD.alpha<0.5 then return false end
    local cardX,cardY=CARD.getPos()
    return mx>=cardX and mx<=cardX+CARD.w and my>=cardY and my<=cardY+CARD.h
end

function CARD.mouseClick(x,y)
    local cardX,cardY=CARD.getPos()
    if CARD.menuAlpha>0 and CARD.menu then
        local menuW=180
        local menuH=#menuItems*50+16
        local menuX=cardX+CARD.w-menuW
        local menuY=cardY+CARD.h+10
        if x>=menuX and x<=menuX+menuW and y>=menuY and y<=menuY+menuH then
            for i,item in ipairs(menuItems) do
                local iy=menuY+8+(i-1)*50
                if y>=iy and y<=iy+44 then
                    CARD.closeMenu()
                    if item.url then
                        love.system.openURL(item.url)
                    elseif item.code then
                        item.code()
                    end
                    return true
                end
            end
            CARD.closeMenu()
            return true
        end
        CARD.closeMenu()
        return true
    end
    if CARD._isCardAbove(x,y) then
        CARD.toggleMenu()
        return true
    end
    return false
end

function CARD.openMenu()
    CARD.menu=true
    menuItems={}
    local baseWeb=(AUTHURL and AUTHURL:find("^http")) and AUTHURL or "https://teblocks.my.id"
    if USER.uid then
        table.insert(menuItems,{label="Profile",url=baseWeb.."/profile"})
        table.insert(menuItems,{label="Match History",url=baseWeb.."/history"})
        table.insert(menuItems,{label="Skin Direct",code=function() SCN.go('skin_browse') end})
        table.insert(menuItems,{label="Log Out",code=function()
            USER.__data.uid=false
            USER.__data.aToken=false
            USER.__data.oToken=false
            love.filesystem.remove('conf/user')
            STAT.elo=nil
            STAT.globalRank=nil
            NET.ws_close()
            CARD.reset()
            MES.new('info',"Logged out")
            if SCN.cur~='main' then
                SCN.backTo('main')
            else
                NET.ws_connect()
            end
        end})
    else
        local REG_CONFIRM = require 'parts.registerConfirmModal'
        table.insert(menuItems,{label="Log In",code=function() AUTH.open('login') end})
        table.insert(menuItems,{label="Register",code=function() REG_CONFIRM.open() end})
        table.insert(menuItems,{label="Skin Direct",code=function()
            if not (USER and USER.uid and USER.uid ~= false) then
                MES.new('warn', "Please log in to access Skin Direct")
                AUTH.open('login')
            else
                SCN.go('skin_browse')
            end
        end})
    end
end

function CARD.closeMenu()
    CARD.menu=false
end

function CARD.toggleMenu()
    if CARD.menu then
        CARD.closeMenu()
    else
        CARD.openMenu()
    end
end

function CARD.setOpen(state)
    CARD.open=state
end

function CARD.draw()
    if CARD.alpha<=0 and CARD.menuAlpha<=0 then return end

    local cardX,cardY=CARD.getPos()

    if CARD.alpha>0 then
        gc_push('transform')
        gc_replaceTransform(SCR.xOy)
            gc_setColor(.15,.15,.15,.85*CARD.alpha)
            gc_rectangle('fill',cardX,cardY,CARD.w,CARD.h,6)
            gc_setColor(1,1,1,CARD.alpha)
            gc_setLineWidth(2)
            gc_rectangle('line',cardX,cardY,CARD.w,CARD.h,6)

            -- Avatar border & avatar
            gc_setColor(1,1,1,CARD.alpha)
            gc_rectangle('line',cardX+CARD.w-106,cardY+12,96,96,3)

            local isGuest = not USER.uid
            local avatar = isGuest and USERS.getAvatar(nil) or USERS.getAvatar(USER.uid)
            if avatar then
                local avatarBoxX,avatarBoxY,avatarBoxSize=cardX+CARD.w-106,cardY+12,96
                local aw,ah=avatar:getDimensions()
                local scale=math.max(avatarBoxSize/aw,avatarBoxSize/ah)
                local drawW,drawH=aw*scale,ah*scale

                gc_stencil(function()
                    gc_rectangle('fill',avatarBoxX,avatarBoxY,avatarBoxSize,avatarBoxSize)
                end,'replace',1)
                gc_setStencilTest('equal',1)

                gc_draw(avatar,
                    avatarBoxX+(avatarBoxSize-drawW)/2,
                    avatarBoxY+(avatarBoxSize-drawH)/2,
                    nil,scale)

                gc_setStencilTest()
            end

            -- Username
            local username = isGuest and "Guest" or USERS.getUsername(USER.uid)
            if username~=CARD.playerName then
                CARD.playerName=username
                CARD.nameTextObj=GC.newText(getFont(25),username)
                CARD.nameWidth=CARD.nameTextObj:getWidth()
                CARD.nameScaleK=180/math.max(CARD.nameWidth,180)
                CARD.nameOffY=CARD.nameTextObj:getHeight()/2
            end
            gc_setColor(COLOR.Z[1],COLOR.Z[2],COLOR.Z[3],CARD.alpha)
            gc_draw(CARD.nameTextObj,cardX+16,cardY+24,nil,CARD.nameScaleK)

            -- Rank and ELO
            setFont(16)
            if isGuest then
                gc_setColor(COLOR.lH[1],COLOR.lH[2],COLOR.lH[3],CARD.alpha*.85)
                gc_print("Guest Account",cardX+16,cardY+48)
                gc_setColor(COLOR.lY[1],COLOR.lY[2],COLOR.lY[3],CARD.alpha*.85)
                gc_print("Click to Log In",cardX+16,cardY+70)
            else
                local rank = STAT.globalRank or 0
                local rankStr = rank > 0 and ("#"..rank) or "Unranked"
                gc_setColor(COLOR.lH[1],COLOR.lH[2],COLOR.lH[3],CARD.alpha)
                gc_print(text.globalRank.." "..rankStr,cardX+16,cardY+48)

                local elo = STAT.elo or 1200
                gc_setColor(COLOR.lY[1],COLOR.lY[2],COLOR.lY[3],CARD.alpha)
                gc_print(text.elo.." "..elo,cardX+16,cardY+70)
            end
        gc_pop()
    end

    -- Dropdown menu
    if CARD.menuAlpha>0 and #menuItems>0 then
        gc_push('transform')
        gc_replaceTransform(SCR.xOy)
        local menuW=180
        local menuH=#menuItems*50+16
        local menuX=cardX+CARD.w-menuW
        local menuY=cardY+CARD.h+10

        gc_setColor(.1,.1,.1,.95*CARD.menuAlpha)
        gc_rectangle('fill',menuX,menuY,menuW,menuH,4)
        gc_setColor(.3,.3,.3,CARD.menuAlpha)
        gc_setLineWidth(1)
        gc_rectangle('line',menuX,menuY,menuW,menuH,4)

        setFont(20)
        for i,item in ipairs(menuItems) do
            local iy=menuY+8+(i-1)*50
            local ih=44
            if not item.hide or not item.hide() then
                gc_setColor(.2,.2,.2,.5*CARD.menuAlpha)
                gc_rectangle('fill',menuX+4,iy,menuW-8,ih,3)
                gc_setColor(1,1,1,CARD.menuAlpha)
                gc_print(item.label,menuX+14,iy+10)
            end
        end
        gc_pop()
    end
end

return CARD
