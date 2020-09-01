-- import file
local interactive = require "base.interactive"
require "public.serverdefines"
local router = require "base.router"


local bInitName = bInitName or false
local iTurnID = iTurnID or 0
local mServiceName = mServiceName or {}
local mBlock2Service = mBlock2Service or {}

function CheckInitServiceName()
    if bInitName then return end
    bInitName = true
    mBlock2Service = {}
    mServiceName = {}
    for iNo=1,GAMEDB_SERVICE_COUNT do
        table.insert(mServiceName,".gamedb"..iNo)
    end
end

function HashBlock(sBlock)
    if not sBlock or #sBlock <= 0 then
        return 100
    end
    local iTotal = 0
    for i = 1, #sBlock do
        iTotal = sBlock:byte(i) + iTotal
    end
    return iTotal
end

function GetServiceName(sBlock)
    local iBlock = tonumber(sBlock)
    if iBlock then
        return mServiceName[iBlock % GAMEDB_SERVICE_COUNT + 1]
    end
    if mBlock2Service[sBlock] then
        return mBlock2Service[sBlock]
    end
    mBlock2Service[sBlock] = mServiceName[HashBlock(sBlock) % GAMEDB_SERVICE_COUNT + 1]
    return mBlock2Service[sBlock]
end

function SaveDb(sBlock,sModule,sCmd,mData)
    if is_ks_server() then
        print("liuzla-debug-ks-SaveDb-")
        print(debug.traceback())
        return
    end
    CheckInitServiceName()
    interactive.Send(GetServiceName(sBlock),sModule,sCmd,mData)
end

function LoadDb(sBlock,sModule,sCmd,mData,func)
    if is_ks_server() then
        print("liuzla-debug-ks-LoadDb-")
        print(debug.traceback())
        return
    end
    CheckInitServiceName()
    interactive.Request(GetServiceName(sBlock),sModule,sCmd, mData,func)
end

function SaveGameDb(sServerKey, sBlock, sModule, sCmd, mData)
    if is_ks_server() then
        SaveRemoteDb(sServerKey, sBlock, sModule, sCmd, mData)
    else
        SaveDb(sBlock, sModule, sCmd, mData)
    end
end

function LoadGameDb(sServerKey, sBlock, sModule, sCmd, mData, func)
    if is_ks_server() then
        LoadRemoteDb(sServerKey, sBlock, sModule, sCmd, mData, func)
    else
        LoadDb(sBlock, sModule, sCmd, mData, func)
    end
end

function LoadRemoteDb(sServerKey, sBlock, sModule, sCmd, mData, func)
    if not is_ks_server() or not sServerKey then
        print("liuzla-debug-LoadRemoteDb-", sServerKey, sBlock, sModule, sCmd)
        print(debug.traceback())
        return
    end
    CheckInitServiceName()
    router.Request(sServerKey, GetServiceName(sBlock), sModule, sCmd, mData, func)    
end

function SaveRemoteDb(sServerKey, sBlock, sModule, sCmd, mData)
    if not is_ks_server() or not sServerKey then
        print("liuzla-debug-SaveRemoteDb-", sServerKey, sBlock, sModule, sCmd)
        print(debug.traceback())
        return
    end
    CheckInitServiceName()
    router.Send(sServerKey, GetServiceName(sBlock), sModule, sCmd, mData)
end

function SaveDb2File(sKey, mData)
    interactive.Send(".logfile", "common", "WriteDb2File",  {
        key = sKey, 
        data = mData,
    })
end

function write_db2file(sName, sData)
    local sPath = DB_FILE_PATH
    if create_folder(sPath) then
        local sDate = get_time_format_str(get_time(), "%Y-%m-%d-%H%M")
        local sFile = string.format("%s/%s_%s",sPath,sName,sDate)
        local fd = io.open(sFile,"a")
        write_file_byfd(fd,sData)
        fd:close()
    end
end

