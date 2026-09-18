local function C(x,y)
    local canvas=GC.newCanvas(x,y)
    GC.setCanvas(canvas)
    return canvas
end

local Skins={}
local skinList={}

local SKIN={
    lib={},
    libMini={},
}

local function createDefaultProceduralTile(blockIdx, size)
    local canvas = C(size, size)
    GC.clear(0, 0, 0, 0)
    local colors = {
        {0.95, 0.25, 0.35}, -- 1 Z (red)
        {0.30, 0.85, 0.40}, -- 2 S (green)
        {0.25, 0.45, 0.95}, -- 3 J (blue)
        {0.95, 0.60, 0.20}, -- 4 L (orange)
        {0.70, 0.30, 0.95}, -- 5 T (purple)
        {0.95, 0.85, 0.25}, -- 6 O (yellow)
        {0.25, 0.85, 0.95}, -- 7 I (cyan)
    }
    local col = colors[((blockIdx - 1) % 7) + 1] or {0.6, 0.6, 0.6}
    GC.setColor(col[1], col[2], col[3], 0.9)
    GC.rectangle('fill', 1, 1, size - 2, size - 2, math.max(1, math.floor(size / 6)))
    GC.setColor(1, 1, 1, 0.6)
    GC.setLineWidth(1)
    GC.rectangle('line', 1, 1, size - 2, size - 2, math.max(1, math.floor(size / 6)))
    return canvas
end

function SKIN.load(list)
    for i=1,#list do
        table.insert(skinList,list[i].name)
        Skins[list[i].name]=list[i].path
    end
end

function SKIN.loadUser(dir)
    local ok,_=pcall(love.filesystem.createDirectory,dir)
    if not ok then return end
    local success,items=pcall(love.filesystem.getDirectoryItems,dir)
    if not success or not items then return end
    for _,name in next,items do
        if name:sub(-4):lower()=='.png' then
            local base = name:sub(1, -5)
            local baseLower = base:lower()
            -- Safeguard: Skip guide graphics and non-skin templates
            if baseLower ~= 'skin_guide' and baseLower ~= 'template' and baseLower ~= 'guide' and baseLower ~= 'readme' then
                local skinName='[User] '..base
                local path=dir..'/'..name
                if not Skins[skinName] then
                    table.insert(skinList,skinName)
                    Skins[skinName]=path
                end
            end
        end
    end
end

function SKIN.reloadUser(dir)
    for i=#skinList,1,-1 do
        local name=skinList[i]
        if name:sub(1,7)=='[User] ' then
            table.remove(skinList,i)
            Skins[name]=nil
            SKIN.lib[name]=nil
            SKIN.libMini[name]=nil
        end
    end
    SKIN.loadUser(dir)
end

function SKIN.getList() return skinList end

function SKIN.exists(name)
    return name ~= nil and Skins[name] ~= nil
end

function SKIN.isLoaded(name)
    return name ~= nil and rawget(SKIN.lib, name) ~= nil
end

function SKIN.get(name)
    if not name or not Skins[name] then
        name = skinList[1] or 'Neon Cyber (Teblocks)'
    end
    return SKIN.lib[name]
end

local skinMeta={__index=function(self,name)
    -- Normalize name or fall back to default
    local targetName = name
    if not targetName or not Skins[targetName] then
        targetName = skinList[1] or 'Neon Cyber (Teblocks)'
    end

    GC.push()
    GC.origin()
    GC.setDefaultFilter('nearest','nearest')

    local I = nil
    local N = Skins[targetName]
    if N and love.filesystem.getInfo(N) then
        local ok, loaded = pcall(GC.newImage, N)
        if ok and loaded then
            I = loaded
        else
            LOG("[skin error] failed to decode image: "..tostring(N))
        end
    end

    -- If target failed to load and was not the primary default, try primary default as fallback
    if not I and targetName ~= skinList[1] and skinList[1] then
        local defPath = Skins[skinList[1]]
        if defPath and love.filesystem.getInfo(defPath) then
            local ok, loaded = pcall(GC.newImage, defPath)
            if ok and loaded then
                I = loaded
            end
        end
    end

    local actualKey = name or targetName
    SKIN.lib[actualKey],SKIN.libMini[actualKey]={},{}
    GC.setColor(1,1,1,1)

    local scaleX, scaleY = 1, 1
    if I then
        local iw, ih = I:getDimensions()
        scaleX = 240 / (iw > 0 and iw or 240)
        scaleY = 90 / (ih > 0 and ih or 90)
    end

    for y=0,2 do
        for x=1,8 do
            local bIdx = 8*y+x

            -- Full size tile (30x30)
            SKIN.lib[actualKey][bIdx]=C(30,30)
            GC.clear(0, 0, 0, 0)
            if I then
                GC.push()
                GC.scale(scaleX, scaleY)
                GC.draw(I, (30-30*x)/scaleX, (-30*y)/scaleY)
                GC.pop()
            else
                createDefaultProceduralTile(bIdx, 30)
            end

            -- Mini size tile (6x6)
            SKIN.libMini[actualKey][bIdx]=C(6,6)
            GC.clear(0, 0, 0, 0)
            if I then
                GC.push()
                GC.scale(scaleX * 0.2, scaleY * 0.2)
                GC.draw(I, (6-6*x)/(scaleX * 0.2), (-6*y)/(scaleY * 0.2))
                GC.pop()
            else
                createDefaultProceduralTile(bIdx, 6)
            end
        end
    end

    GC.setDefaultFilter('linear','linear')
    GC.setCanvas()
    GC.pop()

    return self[actualKey]
end}
setmetatable(SKIN.lib,skinMeta)
setmetatable(SKIN.libMini,skinMeta)

return SKIN
