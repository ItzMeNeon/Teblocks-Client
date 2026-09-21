local ext=(SYSTEM=='Windows') and 'dll' or (SYSTEM=='macOS') and 'dylib' or 'so'
local ccDir
local arch=jit and jit.arch or 'x64'
if SYSTEM=='Linux' then
    ccDir='ColdClear/Linux'
elseif SYSTEM=='Windows' then
    ccDir='ColdClear/Windows/'..(arch=='x64' and 'x64' or 'x86')
elseif SYSTEM=='Android' then
    local platform=(function()
        local p=io.popen('uname -m')
        if p then
            local a=p:read('*a'):lower()
            p:close()
            if a:find('v8') and not a:find('v8l') or a:find('64') then
                return 'arm64-v8a'
            end
        end
        return 'armeabi-v7a'
    end)()
    ccDir='ColdClear/Android/'..platform
end

local sourcePath=love.filesystem.getSource()
local gameLibPath=sourcePath and (sourcePath..'/'..ccDir..'/?.'..ext) or (ccDir..'/?.'..ext)

package.cpath=package.cpath
    ..';'..gameLibPath
    ..';'..ccDir..'/?.'..ext
    ..';?.dylib'
    ..(SYSTEM=='Android' and (';'..love.filesystem.getSaveDirectory()..'/lib/?.'..ext) or '')

local loaded={}
local errorCount={}
return function(libName)
    local require=require
    local success,res
    if SYSTEM=='Web' then
        return
    end
    if SYSTEM=='macOS' then
        local a,b,c=package.loadlib(libName..'.dylib','luaopen_'..libName)
        require=a

        if require then
            success,res=pcall(require)
        else
            success,res=false,'package.loadlib returned nil, along with:\n[2]:\n'..b..'[3]:\n'..c
        end
    else
        if SYSTEM=='Android' and not loaded[libName] and ccDir then
            local srcPath=ccDir..'/'..libName..'.'..ext
            local targetFile='lib/'..libName..'.'..ext
            if not love.filesystem.getInfo(targetFile) and love.filesystem.getInfo(srcPath) then
                local data=love.filesystem.read('data',srcPath)
                if data then
                    love.filesystem.createDirectory('lib')
                    love.filesystem.write(targetFile,data)
                end
            end
            loaded[libName]=true
        end
        success,res=pcall(require,libName)
    end
    if success and res then
        return res
    else
        if not next(errorCount) then
            MES.new('info',"Architecture: "..arch)
        end
        errorCount[libName]=(errorCount[libName] or 0)+1
        if errorCount[libName]==1 then
            MES.new('error',"Cannot load "..libName..": "..tostring(res):gsub('[\128-\255]+','??'))
        else
            MES.new('error',("Cannot load %s (x%d)"):format(libName,errorCount[libName]),1)
        end
    end
end
