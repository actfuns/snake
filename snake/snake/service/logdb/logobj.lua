local global = require "global"
local skynet = require "skynet"
local bson = require "bson"
local interactive = require "base.interactive"
local mongoop = require "base.mongoop"

function NewLogObj(...)
    local o = CLogObj:New(...)
    return o
end

CLogObj = {}
CLogObj.__index = CLogObj
inherit(CLogObj, logic_base_cls())

function CLogObj:New()
    local o = super(CLogObj).New(self)
    o.m_oClient = nil
    o.m_sBaseDbName = nil
    o.m_mLogDb = {}
    o.m_oUnmoveLogDb = nil
    return o
end

function CLogObj:Init(mInit)
    self.m_sBaseDbName = mInit.basename
    self.m_oClient = mongoop.NewMongoClient({
        host = mInit.host,
        port = mInit.port,
        username = mInit.username,
        password = mInit.password
    })
end

function CLogObj:InitUnmoveLogDb(mInit)
    local oClient = mongoop.NewMongoClient({
        host = mInit.host,
        port = mInit.port,
        username = mInit.username,
        password = mInit.password
    })
    self.m_oUnmoveLogDb = mongoop.NewMongoObj()
    self.m_oUnmoveLogDb:Init(oClient, mInit.basename)
    
    local o = self.m_oUnmoveLogDb
    skynet.fork(function ()
        o:CreateIndex("analy", {_time = 1}, {name = "analy_time_index"})
    end)
end

function CLogObj:LogMonth(iTime)
    return os.date("%Y%m", iTime)
end

function CLogObj:InitLogDb(sTime)
    local o = mongoop.NewMongoObj()
    o:Init(self.m_oClient, self.m_sBaseDbName..sTime)

    skynet.fork(function ()
        local sTestTableName = "test"
        o:CreateIndex(sTestTableName, {_time = 1}, {name = "test_time_index"})

        local lTableName = {"player", "economic", "formation", "friend", "gm", "equip",
            "huodong", "item", "mail", "money", "partner", "summon", "task", "title",
            "ride", "playerskill", "recovery", "redpacket", "shop",
        }
        for _, sTableName in pairs(lTableName) do
            o:CreateIndex(sTableName, {_time = 1}, {name = sTableName.."_time_index"})
            o:CreateIndex(sTableName, {pid = 1}, {name = sTableName.."_pid_index"})
        end

        local lTableName2 = {"costcount", "gamesys", "jjc", "online", "statistics", "org",
            "huodonginfo", "behavior", "rank", "scene",
        }
        for _, sTableName in pairs(lTableName2) do
            o:CreateIndex(sTableName, {_time = 1}, {name = sTableName.."_time_index"})
        end

        local sAccountTable = "account"
        o:CreateIndex(sAccountTable, {_time = 1}, {name = "account_time_index"})
        o:CreateIndex(sAccountTable, {account = 1}, {name = "account_index"})
    end)

    self.m_mLogDb[sTime] = o
end

function CLogObj:PushLog(sType, m)
    local iTime = get_time()
    local sTime = self:LogMonth(iTime)
    m._time = bson.date(iTime)

    if not self.m_mLogDb[sTime] then
        self:InitLogDb(sTime)
    end
    self.m_mLogDb[sTime]:InsertLowPriority(sType, m)
end

function CLogObj:PushUnmoveLog(sType, m)
    if not m["_time"] then
        local iTime = get_time()
        m._time = bson.date(iTime)
    end
    self.m_oUnmoveLogDb:InsertLowPriority(sType, m)
end

function CLogObj:FindLog(sType,mSearch,mBackInfo, iTime)
    local sTime = self:LogMonth(iTime or get_time())
    if not self.m_mLogDb[sTime] then
        self:InitLogDb(sTime)
    end
    return self.m_mLogDb[sTime]:Find(sType,mSearch,mBackInfo)
end

function CLogObj:FindUnmoveLog(sType,mSearch,mBackInfo)
    return self.m_oUnmoveLogDb:Find(sType,mSearch,mBackInfo)
end
