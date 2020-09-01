local global = require "global"
local skynet = require "skynet"
local bson = require "bson"
local cjson = require "cjson"
local interactive = require "base.interactive"
local mongoop = require "base.mongoop"

local dataanaly = import(lualib_path("public.dataanaly"))
local analylog = import(lualib_path("public.analylog"))
local gamedb = import(lualib_path("public.gamedb"))


function NewLogFileObj(...)
    local o = CLogFileObj:New(...)
    return o
end

CLogFileObj = {}
CLogFileObj.__index = CLogFileObj
inherit(CLogFileObj, logic_base_cls())

function CLogFileObj:New()
    local o = super(CLogFileObj).New(self)
    return o
end

function CLogFileObj:Init()
end

function CLogFileObj:WriteData(sName, mData)
    dataanaly.write_data(sName, self:FormatData(mData))
end

function CLogFileObj:FormatData(mData)
    for k,v in pairs(mData) do
        if type(v) == "table" then
            mData[k] = analylog.table_format_concat(v)
        end    
    end
    mData["time"] = get_time_format_str(get_time(), "%Y-%m-%d %H:%M:%S")
    return cjson.encode(mData)
end

function CLogFileObj:WriteMtbi(sName, mData)
    dataanaly.write_mtbi(sName, mData)
end

function CLogFileObj:WriteDb2File(sKey, mSave)
    mongoop.ChangeBeforeSave(mSave)
    gamedb.write_db2file(sKey, cjson.encode(mSave))
end