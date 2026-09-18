local AUTH={}

local _isOpen=false
AUTH.mode='login'
AUTH.widgets={}
AUTH.prevActive=nil
AUTH.overlayAlpha=0
AUTH.boxAlpha=0

local gc=love.graphics
local gc_setColor,gc_setLineWidth=gc.setColor,gc.setLineWidth
local gc_rectangle=gc.rectangle
local gc_push,gc_pop=gc.push,gc.pop
local gc_replaceTransform=gc.replaceTransform
local gc_print=gc.print

local username=""
local password=""
local verifyCode=""
local verifyTargetId=""
local verifyTargetName=""
local focusedField="username"

local function _close()
    if AUTH.prevActive then
        WIDGET.setWidgetList(AUTH.prevActive)
    end
    _isOpen=false
    AUTH.mode=nil
    AUTH.widgets={}
    AUTH.prevActive=nil
    username=""
    password=""
    verifyCode=""
    verifyTargetId=""
    verifyTargetName=""
    focusedField="username"
    love.keyboard.setTextInput(false)
    WIDGET.unFocus(true)
    WIDGET.locked=false
end

local function _getFieldRect(fieldName)
    if AUTH.mode=='verify' then
        if fieldName=='verifyCode' then
            return 320,290,640,58
        end
    else
        if fieldName=='username' then
            return 320,255,640,58
        elseif fieldName=='password' then
            return 320,370,640,58
        end
    end
end

local function _getButtonRect(buttonName)
    if AUTH.mode=='verify' then
        if buttonName=='verify' or buttonName=='submit' then
            return 760,425,200,55
        elseif buttonName=='resend' then
            return 510,425,220,55
        elseif buttonName=='close' then
            return 320,425,160,55
        end
    else
        if buttonName=='submit' then
            return 580,455,180,60
        elseif buttonName=='close' then
            return 340,455,180,60
        end
    end
end

local function _pointInRect(px,py,rx,ry,rw,rh)
    return px>=rx and px<=rx+rw and py>=ry and py<=ry+rh
end

local function _drawInputBox(x,y,w,h,value,secret,focused)
    gc_setColor(.1,.1,.1,.9)
    gc_rectangle('fill',x,y,w,h,4)
    gc_setColor(focused and 1 or .6,focused and 1 or .6,focused and 1 or .6,1)
    gc_setLineWidth(2)
    gc_rectangle('line',x,y,w,h,4)

    setFont(25)
    gc_setColor(1,1,1)
    local displayText=secret and string.rep('*',#value) or value
    if #displayText==0 and not focused then
        gc_setColor(.5,.5,.5,1)
    end
    gc_print(displayText,x+10,y+(h-25)/2)
end

local function _drawButton(x,y,w,h,label,color)
    local r,g,b=1,1,1
    if color=='lG' then r,g,b=.4,1,.4
    elseif color=='lR' then r,g,b=1,.4,.4
    elseif color=='lB' then r,g,b=.3,.7,1
    end

    gc_setColor(r*.7,g*.7,b*.7,.9)
    gc_rectangle('fill',x,y,w,h,6)
    gc_setColor(r,g,b,1)
    gc_setLineWidth(2)
    gc_rectangle('line',x,y,w,h,6)

    setFont(24)
    gc_setColor(1,1,1)
    gc_print(label,x+(w-#label*12)/2,y+(h-24)/2)
end

function AUTH.open(mode)
    if _isOpen then _close() end
    AUTH.mode='login'
    AUTH.prevActive=WIDGET.active
    AUTH.widgets={}
    username=""
    password=""
    verifyCode=""
    focusedField="username"
    _isOpen=true
    AUTH.openTimer=0.35
    love.keyboard.setTextInput(true)
end

function AUTH.openVerify(uid, uname)
    if _isOpen then _close() end
    AUTH.mode='verify'
    AUTH.prevActive=WIDGET.active
    AUTH.widgets={}
    verifyTargetId=tostring(uid or "")
    verifyTargetName=tostring(uname or uid or "")
    verifyCode=""
    focusedField="verifyCode"
    _isOpen=true
    AUTH.openTimer=0.35
    love.keyboard.setTextInput(true)
end

function AUTH._submit()
    if #username==0 or #password==0 then
        MES.new('error', text.noUsername or 'Please enter username and password')
        return
    end
    NET.loginWithPassword(username, password)
    _close()
end

function AUTH._submitVerify()
    if #verifyCode==0 then
        MES.new('error', "Please enter the 6-digit verification code")
        return
    end
    SFX.play('enter')
    MES.new('info', "Verifying account...")
    NET.verifyAccount(verifyTargetId, verifyCode, function(ok, msg)
        if ok then
            MES.new('check', "Account verified! Please log in.")
            local savedName = verifyTargetName
            _close()
            AUTH.open()
            username = savedName
            focusedField = "password"
        else
            MES.new('error', msg or "Verification failed")
        end
    end)
end

function AUTH._resendCode()
    SFX.play('click')
    MES.new('info', "Requesting verification code...")
    NET.sendVerificationCode(verifyTargetId, function(ok, msg)
        if ok then
            MES.new('info', "Verification code sent! Check console / email.")
        else
            MES.new('error', msg or "Failed to send code")
        end
    end)
end

function AUTH.isOpen()
    return _isOpen
end

function AUTH.close()
    _close()
end

function AUTH.update(dt)
    WIDGET.locked=_isOpen
    if AUTH.openTimer and AUTH.openTimer > 0 then
        AUTH.openTimer = math.max(0, AUTH.openTimer - dt)
    end
    if _isOpen then
        AUTH.overlayAlpha=math.min(AUTH.overlayAlpha+dt*10,0.7)
        AUTH.boxAlpha=math.min(AUTH.boxAlpha+dt*10,1)
    else
        AUTH.overlayAlpha=math.max(AUTH.overlayAlpha-dt*10,0)
        AUTH.boxAlpha=math.max(AUTH.boxAlpha-dt*10,0)
    end
end

function AUTH.draw()
    if AUTH.overlayAlpha<=0 and AUTH.boxAlpha<=0 then return end

    gc_push('transform')
    gc_replaceTransform(SCR.origin)
    if AUTH.overlayAlpha>0 then
        gc_setColor(0,0,0,AUTH.overlayAlpha)
        gc_rectangle('fill',0,0,SCR.w,SCR.h)
    end
    gc_pop()

    if AUTH.boxAlpha>0 then
        gc_push('transform')
        gc_replaceTransform(SCR.xOy)
        local w,h=700,480
        local x,y=290,120
        gc_setColor(.15,.15,.15,.95*AUTH.boxAlpha)
        gc_rectangle('fill',x,y,w,h,10)
        gc_setColor(1,1,1,AUTH.boxAlpha)
        gc_setLineWidth(2)
        gc_rectangle('line',x,y,w,h,10)

        if AUTH.mode=='verify' then
            setFont(38)
            gc_setColor(COLOR.Z[1],COLOR.Z[2],COLOR.Z[3],AUTH.boxAlpha)
            gc_print('Verify Account',320,150)

            setFont(16)
            gc_setColor(.8,.85,1,AUTH.boxAlpha)
            gc_print("Account for "..(verifyTargetName~="" and verifyTargetName or "user").." is not yet verified.",320,205)

            setFont(16)
            gc_setColor(.7,.7,.7,AUTH.boxAlpha)
            gc_print("Enter 6-digit verification code:",320,255)
            _drawInputBox(320,290,640,58,verifyCode,false,focusedField=='verifyCode')

            _drawButton(760,425,200,55,'Verify','lG')
            _drawButton(510,425,220,55,'Resend Code','lB')
            _drawButton(320,425,160,55,'Close','lR')
        else
            setFont(42)
            gc_setColor(COLOR.Z[1],COLOR.Z[2],COLOR.Z[3],AUTH.boxAlpha)
            gc_print('Log In',320,155)

            setFont(22)
            gc_setColor(.7,.7,.7,AUTH.boxAlpha)
            gc_print("Username",320,225)
            _drawInputBox(320,255,640,58,username,false,focusedField=='username')

            gc_print("Password",320,340)
            _drawInputBox(320,370,640,58,password,true,focusedField=='password')

            _drawButton(580,455,180,60,'Log In','lG')
            _drawButton(340,455,180,60,'Close','lR')
        end
        gc_pop()
    end
end

function AUTH.mouseClick(x,y)
    if not _isOpen then return false end

    love.keyboard.setTextInput(true)

    if AUTH.mode=='verify' then
        local fx,fy,fw,fh=_getFieldRect('verifyCode')
        if fx and _pointInRect(x,y,fx-6,fy-6,fw+12,fh+12) then
            focusedField='verifyCode'
            love.keyboard.setTextInput(true)
            return true
        end

        local verX,verY,verW,verH=_getButtonRect('verify')
        if verX and _pointInRect(x,y,verX-8,verY-8,verW+16,verH+16) then
            AUTH._submitVerify()
            return true
        end

        local resX,resY,resW,resH=_getButtonRect('resend')
        if resX and _pointInRect(x,y,resX-8,resY-8,resW+16,resH+16) then
            AUTH._resendCode()
            return true
        end

        local closeX,closeY,closeW,closeH=_getButtonRect('close')
        if closeX and _pointInRect(x,y,closeX-8,closeY-8,closeW+16,closeH+16) then
            _close()
            return true
        end
    else
        local fields={'username','password'}
        for _,fieldName in ipairs(fields) do
            local fx,fy,fw,fh=_getFieldRect(fieldName)
            if fx and _pointInRect(x,y,fx-6,fy-6,fw+12,fh+12) then
                focusedField=fieldName
                love.keyboard.setTextInput(true)
                return true
            end
        end

        local submitX,submitY,submitW,submitH=_getButtonRect('submit')
        if submitX and _pointInRect(x,y,submitX-8,submitY-8,submitW+16,submitH+16) then
            AUTH._submit()
            return true
        end

        local closeX,closeY,closeW,closeH=_getButtonRect('close')
        if closeX and _pointInRect(x,y,closeX-8,closeY-8,closeW+16,closeH+16) then
            _close()
            return true
        end
    end

    local w,h=700,480
    local x1,y1=290,120
    local x2,y2=x1+w,y1+h
    if x<x1 or x>x2 or y<y1 or y>y2 then
        if not (AUTH.openTimer and AUTH.openTimer > 0) then
            _close()
        end
        return true
    end

    return true
end

AUTH.mouseDown = AUTH.mouseClick
AUTH.touchDown = AUTH.mouseClick
AUTH.touchClick = AUTH.mouseClick

function AUTH.keyDown(key,rep)
    if not _isOpen then return nil end

    if (key=='escape' or key=='back') and not rep then
        _close()
        return false
    elseif (key=='return' or key=='kpenter') and not rep then
        if AUTH.mode=='verify' then
            AUTH._submitVerify()
        else
            AUTH._submit()
        end
        return false
    elseif key=='tab' and not rep then
        if AUTH.mode=='verify' then
            focusedField='verifyCode'
        else
            local fields={'username','password'}
            for i,fieldName in ipairs(fields) do
                if fieldName==focusedField then
                    focusedField=fields[(i%#fields)+1]
                    break
                end
            end
        end
        return false
    elseif key=='backspace' then
        if AUTH.mode=='verify' then
            if #verifyCode>0 then
                verifyCode=verifyCode:sub(1,-2)
            end
        elseif focusedField=='username' then
            local t=username
            local p=#t
            while p>0 and t:byte(p)>=128 and t:byte(p)<192 do
                p=p-1
            end
            username=t:sub(1,p-1)
        elseif focusedField=='password' then
            local t=password
            local p=#t
            while p>0 and t:byte(p)>=128 and t:byte(p)<192 do
                p=p-1
            end
            password=t:sub(1,p-1)
        end
        return false
    end

    return false
end

function AUTH.textInput(t)
    if not _isOpen then return nil end

    if AUTH.mode=='verify' then
        if #verifyCode<16 then
            verifyCode=verifyCode..t
        end
    elseif focusedField=='username' and #username<64 then
        username=username..t
    elseif focusedField=='password' and #password<64 then
        password=password..t
    end

    return true
end

return AUTH
