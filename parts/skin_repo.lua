local JSON = JSON
local HTTP = HTTP

local OFFICIAL_SKIN = {
    id = 'neon_cyber',
    title = 'Neon Cyber (Teblocks)',
    name = 'Neon Cyber (Teblocks)',
    author = 'Teblocks Team',
    username = 'Teblocks Team',
    description = 'Official high-contrast cyber mino skin for competitive Teblocks play.',
    tags = {'official', 'cyber', 'teblocks', 'neon'},
    likes = 128,
    downloads = 1024,
    rating = 5.0,
    isOfficial = true,
    installedName = 'Neon Cyber (Teblocks)',
    filename = 'media/image/skin/teblocks/neon_cyber.png',
}

local SKIN_REPO = {
    onlineList = { OFFICIAL_SKIN },
    filter = 'all', -- 'all', 'popular', 'latest', 'top_rated'
    searchQuery = '',
    loading = false,
    connected = false,
    lastError = nil,
    previewImages = {},
    version = 0,
}

function SKIN_REPO.init()
    SKIN_REPO.refresh()
end

function SKIN_REPO.refresh(cb)
    SKIN_REPO.fetchRemote(cb)
end

-- Query remote gameserver backend for available community skins
function SKIN_REPO.fetchRemote(cb)
    if not HTTP or not AUTHHOST then
        SKIN_REPO.connected = false
        SKIN_REPO.onlineList = { OFFICIAL_SKIN }
        SKIN_REPO.version = (SKIN_REPO.version or 0) + 1
        if cb then cb(false, 0) end
        return
    end

    SKIN_REPO.loading = true
    SKIN_REPO.lastError = nil

    TASK.new(function()
        local pool = 'skin_repo_fetch'
        HTTP.request({
            pool = pool,
            url = AUTHHOST,
            path = '/skins',
        })

        local timer = 0
        local received = false
        while timer < 6.0 do
            local msg = HTTP.pollMsg(pool)
            if msg then
                if msg.code and tostring(msg.code):sub(1,1) == '2' and msg.body then
                    local ok, data = pcall(JSON.decode, msg.body)
                    if ok and type(data) == 'table' then
                        local list = data.skins or (data.data and data.data.skins) or (data.data and type(data.data) == 'table' and data.data) or {}
                        local norm = { OFFICIAL_SKIN }
                        for _, it in ipairs(list) do
                            if it.id ~= 'neon_cyber' and (it.name or it.title) ~= 'Neon Cyber (Teblocks)' then
                                local title = it.name or it.title or "Untitled Skin"
                                local cleanName = title:gsub("[^%w_%- ]", ""):gsub("%s+", "_")
                                if #cleanName == 0 then cleanName = tostring(it.id) end

                                local dUrl = it.skin_url or it.url
                                if not dUrl or dUrl == "" then
                                    if AUTHHOST then
                                        dUrl = "http://" .. AUTHHOST .. "/skins/" .. tostring(it.id) .. "/download"
                                    end
                                elseif dUrl:sub(1, 4) ~= "http" then
                                    if AUTHHOST then
                                        if dUrl:sub(1, 1) ~= "/" then dUrl = "/" .. dUrl end
                                        dUrl = "http://" .. AUTHHOST .. dUrl
                                    end
                                end

                                table.insert(norm, {
                                    id = it.id,
                                    title = title,
                                    name = title,
                                    cleanName = cleanName,
                                    author = it.username or it.author or "Anonymous",
                                    username = it.username or it.author or "Anonymous",
                                    description = it.description or "",
                                    tags = it.tags or {},
                                    likes = it.likes or 0,
                                    downloads = it.downloads or 0,
                                    rating = it.rating or 5.0,
                                    date = (it.created_at and tostring(it.created_at):sub(1, 10)) or "2026",
                                    installedName = '[User] ' .. cleanName,
                                    rawName = cleanName,
                                    downloadUrl = dUrl,
                                    skinUrl = it.skin_url or dUrl,
                                })
                            end
                        end
                        SKIN_REPO.onlineList = norm
                        SKIN_REPO.connected = true
                        received = true
                    else
                        SKIN_REPO.onlineList = { OFFICIAL_SKIN }
                        SKIN_REPO.connected = false
                        SKIN_REPO.lastError = "Invalid server response"
                    end
                else
                    SKIN_REPO.onlineList = { OFFICIAL_SKIN }
                    SKIN_REPO.connected = false
                    SKIN_REPO.lastError = "Gameserver unavailable"
                end
                break
            end
            timer = timer + coroutine.yield()
        end

        if not received and timer >= 6.0 then
            SKIN_REPO.onlineList = { OFFICIAL_SKIN }
            SKIN_REPO.connected = false
            SKIN_REPO.lastError = "Connection timed out"
        end

        SKIN_REPO.version = (SKIN_REPO.version or 0) + 1
        SKIN_REPO.loading = false
        HTTP.deletePool(pool)
        if cb then cb(SKIN_REPO.connected, #SKIN_REPO.onlineList) end
    end)
end

-- Check if an online skin item is currently installed on the client
function SKIN_REPO.isInstalled(item)
    if not item then return false end
    if item.isOfficial or item.id == 'neon_cyber' then return true end

    local currentSkins = SKIN.getList()
    for _, name in ipairs(currentSkins) do
        if name == item.installedName or
           name == item.title or
           name == ('[User] ' .. item.title) or
           (item.cleanName and name == ('[User] ' .. item.cleanName)) or
           (item.id and name == ('[User] ' .. item.id)) then
            return true
        end
    end

    if item.cleanName and (love.filesystem.getInfo('skins/' .. item.cleanName .. '.png') or love.filesystem.getInfo('skins/' .. item.cleanName .. '.PNG')) then
        return true
    end
    if item.id and (love.filesystem.getInfo('skins/' .. item.id .. '.png') or love.filesystem.getInfo('skins/' .. item.id .. '.PNG')) then
        return true
    end

    return false
end

local previewLoading = {}

-- Request asynchronous loading of an online skin preview image
function SKIN_REPO.requestPreview(item)
    if not item or not item.id or SKIN_REPO.previewImages[item.id] or previewLoading[item.id] then
        return
    end

    -- Check if local file exists first
    local localFile = item.filename or (item.cleanName and ('skins/' .. item.cleanName .. '.png')) or ('skins/' .. item.id .. '.png')
    if love.filesystem.getInfo(localFile) then
        local ok, loaded = pcall(love.graphics.newImage, localFile)
        if ok and loaded then
            loaded:setFilter('nearest', 'nearest')
            SKIN_REPO.previewImages[item.id] = loaded
            return
        end
    end

    local dUrl = item.downloadUrl or item.skinUrl
    if not dUrl or not HTTP then return end

    previewLoading[item.id] = true
    local pool = 'prev_' .. tostring(item.id):gsub("[^%w]", ""):sub(1, 16)
    HTTP.request({
        pool = pool,
        url = dUrl,
    })

    TASK.new(function()
        local timer = 0
        while timer < 8.0 do
            local msg = HTTP.pollMsg(pool)
            if msg then
                if msg.body and #msg.body > 0 and msg.code and tostring(msg.code):sub(1, 1) == '2' then
                    local fData = love.filesystem.newFileData(msg.body, 'preview.png')
                    local ok, loaded = pcall(love.graphics.newImage, fData)
                    if ok and loaded then
                        loaded:setFilter('nearest', 'nearest')
                        SKIN_REPO.previewImages[item.id] = loaded
                    end
                end
                HTTP.deletePool(pool)
                previewLoading[item.id] = false
                return
            end
            timer = timer + coroutine.yield()
        end
        HTTP.deletePool(pool)
        previewLoading[item.id] = false
    end)
end

-- Get preview image for rendering an online skin
function SKIN_REPO.getPreviewImage(item)
    if not item then return nil end

    if SKIN_REPO.previewImages[item.id] then
        return SKIN_REPO.previewImages[item.id]
    end

    local img = nil
    if item.filename and love.filesystem.getInfo(item.filename) then
        local ok, loaded = pcall(love.graphics.newImage, item.filename)
        if ok and loaded then img = loaded end
    elseif item.cleanName and love.filesystem.getInfo('skins/' .. item.cleanName .. '.png') then
        local ok, loaded = pcall(love.graphics.newImage, 'skins/' .. item.cleanName .. '.png')
        if ok and loaded then img = loaded end
    elseif item.filename and love.filesystem.getInfo('skins/' .. item.filename) then
        local ok, loaded = pcall(love.graphics.newImage, 'skins/' .. item.filename)
        if ok and loaded then img = loaded end
    end

    if not img and item.base64Data then
        local ok, raw = pcall(love.data.decode, 'string', 'base64', item.base64Data)
        if ok and raw then
            local fData = love.filesystem.newFileData(raw, 'preview.png')
            local okImg, loaded = pcall(love.graphics.newImage, fData)
            if okImg and loaded then img = loaded end
        end
    end

    if img then
        img:setFilter('nearest', 'nearest')
        SKIN_REPO.previewImages[item.id] = img
        return img
    end

    -- Trigger async preview download if not yet started
    SKIN_REPO.requestPreview(item)
    return nil
end

-- Download and install a community skin from the server
function SKIN_REPO.download(item, onComplete)
    if not item then return end
    love.filesystem.createDirectory('skins')

    local cleanName = item.cleanName or (item.title and item.title:gsub("[^%w_%- ]", ""):gsub("%s+", "_")) or tostring(item.id)
    if #cleanName == 0 then cleanName = tostring(item.id) end
    local filename = cleanName .. '.png'
    local targetPath = 'skins/' .. filename

    -- Base64 payload from server
    if item.base64Data then
        local ok, raw = pcall(love.data.decode, 'string', 'base64', item.base64Data)
        if ok and raw and #raw > 0 then
            love.filesystem.write(targetPath, raw)
            local fh = io.open(targetPath, 'wb')
            if fh then fh:write(raw) fh:close() end

            SKIN.reloadUser('skins')
            if onComplete then onComplete(true, "Installed " .. (item.title or cleanName)) end
            return
        end
    end

    -- URL download from server
    local downloadUrl = item.downloadUrl or item.skinUrl or (AUTHHOST and ('http://' .. AUTHHOST .. '/skins/' .. item.id .. '/download'))
    if downloadUrl and HTTP then
        TASK.new(function()
            local pool = 'sk_dl_' .. tostring(item.id):gsub("[^%w]", ""):sub(1, 16)
            HTTP.request({
                pool = pool,
                url = downloadUrl,
            })
            local timer = 0
            while timer < 15.0 do
                local msg = HTTP.pollMsg(pool)
                if msg then
                    if msg.body and #msg.body > 0 and msg.code and tostring(msg.code):sub(1,1) == '2' then
                        -- Safeguard: verify valid image before writing to disk
                        local fData = love.filesystem.newFileData(msg.body, filename)
                        local okImg, img = pcall(love.graphics.newImage, fData)
                        if not okImg or not img then
                            HTTP.deletePool(pool)
                            if onComplete then onComplete(false, "Downloaded data is not a valid image") end
                            return
                        end

                        love.filesystem.write(targetPath, msg.body)
                        local fh = io.open(targetPath, 'wb')
                        if fh then fh:write(msg.body) fh:close() end

                        img:setFilter('nearest', 'nearest')
                        SKIN_REPO.previewImages[item.id] = img

                        SKIN.reloadUser('skins')
                        if onComplete then onComplete(true, "Downloaded " .. (item.title or cleanName)) end
                    else
                        local errMsg = "Download failed (HTTP " .. tostring(msg.code or '?') .. ")"
                        if onComplete then onComplete(false, errMsg) end
                    end
                    HTTP.deletePool(pool)
                    return
                end
                timer = timer + coroutine.yield()
            end
            HTTP.deletePool(pool)
            if onComplete then onComplete(false, "Download timed out") end
        end)
        return
    end

    if onComplete then onComplete(false, "No download source available for this skin") end
end

-- Publish a local skin to the gameserver
function SKIN_REPO.upload(rawName, meta, onComplete)
    love.filesystem.createDirectory('skins')
    local filename = rawName .. '.png'
    local path = 'skins/' .. filename

    local data = nil
    if love.filesystem.getInfo(path) then
        data = love.filesystem.read(path)
    else
        local fh = io.open(path, 'rb')
        if fh then
            data = fh:read('*a')
            fh:close()
        end
    end

    if not data or #data == 0 then
        if onComplete then onComplete(false, "Could not read skin file: " .. path) end
        return
    end

    -- Verify image dimensions (240x90)
    local fData = love.filesystem.newFileData(data, filename)
    local ok, img = pcall(love.graphics.newImage, fData)
    if not ok or not img then
        if onComplete then onComplete(false, "Invalid PNG image data") end
        return
    end

    local w, h = img:getDimensions()
    if w ~= 240 or h ~= 90 then
        MES.new('warn', ("Uploaded skin is %dx%d (standard is 240x90)"):format(w, h))
    end

    local base64Data = love.data.encode('string', 'base64', data)

    -- Dispatch upload to gameserver backend
    if not HTTP or not AUTHHOST then
        if onComplete then onComplete(false, "Gameserver host not configured") end
        return
    end

    TASK.new(function()
        local pool = 'skin_upload'
        local headers = {}
        local tok = USER and (USER.aToken or USER.oToken)
        if tok then
            headers["x-access-token"] = tok
            headers["Authorization"] = "Bearer " .. tok
        end
        HTTP.request({
            pool = pool,
            url = AUTHHOST,
            path = '/skins/upload',
            headers = headers,
            body = {
                name        = meta.title or rawName,
                title       = meta.title or rawName,
                author      = meta.author or (USERS and USER and USERS.getUsername(USER.uid)) or 'Anonymous',
                description = meta.description or '',
                tags        = meta.tags or '',
                data        = base64Data,
            }
        })

        local timer = 0
        while timer < 10.0 do
            local msg = HTTP.pollMsg(pool)
            if msg then
                if msg.code and tostring(msg.code):sub(1,1) == '2' then
                    if onComplete then onComplete(true, "Skin successfully published to gameserver!") end
                    SKIN_REPO.fetchRemote()
                else
                    local errMsg = "Upload failed (HTTP " .. tostring(msg.code or '?') .. ")"
                    if msg.body and #msg.body > 0 then
                        local ok, parsed = pcall(JSON.decode, msg.body)
                        if ok and type(parsed) == 'table' and (parsed.error or parsed.message) then
                            errMsg = parsed.error or parsed.message
                        end
                    end
                    if onComplete then onComplete(false, errMsg) end
                end
                HTTP.deletePool(pool)
                return
            end
            timer = timer + coroutine.yield()
        end
        HTTP.deletePool(pool)
        if onComplete then onComplete(false, "Upload timed out") end
    end)
end

-- Filter and search online list
function SKIN_REPO.getFilteredList()
    local res = {}
    local query = (SKIN_REPO.searchQuery or ''):lower():gsub('%s+', ' ')
    local filter = SKIN_REPO.filter or 'all'

    for _, item in ipairs(SKIN_REPO.onlineList) do
        local matchesQuery = true
        if #query > 0 then
            local tagStr = ""
            if type(item.tags) == 'table' then
                tagStr = table.concat(item.tags, " ")
            else
                tagStr = tostring(item.tags or "")
            end
            local textMatch = ((item.title or ''):lower():find(query, 1, true) ~= nil) or
                              ((item.author or ''):lower():find(query, 1, true) ~= nil) or
                              (tagStr:lower():find(query, 1, true) ~= nil) or
                              ((item.description or ''):lower():find(query, 1, true) ~= nil)
            matchesQuery = textMatch
        end

        local matchesFilter = true
        if filter == 'official' then
            matchesFilter = item.isOfficial == true
        end

        if matchesQuery and matchesFilter then
            table.insert(res, item)
        end
    end

    -- Sorting
    if filter == 'popular' then
        table.sort(res, function(a, b) return (a.downloads or 0) > (b.downloads or 0) end)
    elseif filter == 'latest' then
        table.sort(res, function(a, b) return (a.date or '') > (b.date or '') end)
    elseif filter == 'top_rated' then
        table.sort(res, function(a, b) return (a.rating or 0) > (b.rating or 0) end)
    end

    return res
end

return SKIN_REPO
