--import module

local global = require "global"

local titleobj = import(service_path("title.titleobj"))
local titledefines = import(service_path("title.titledefines"))


function NewTitle(iPid, iTid, ...)
    local sPath = GetTitlePath(iTid)
    local oModule = import(service_path(sPath))
    assert(oModule, string.format("newtitel err:%d",iTid))
    local o = oModule.NewTitle(iPid, iTid, ...)
    return o
end

function GetTitlePath(iTid)
    local mData = GetTitleDataByTid(iTid)
    local sFile = mData["class_file"]
    
    if sFile and #sFile > 0 then
        return string.format("title/common/%s", sFile)
    end 
    return "title/titleobj"
end

function GetTitleDataByTid(iTid)
    local res = require "base.res"
    local mData = res["daobiao"]["title"]["title"][iTid]
    assert(mData,string.format("loadtitle GetTitleDataByTid err: %d", iTid))
    return mData
end