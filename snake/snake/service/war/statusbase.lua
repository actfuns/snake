--import module

local global = require "global"
local skynet = require "skynet"


CStatus = {}
CStatus.__index = CStatus
inherit(CStatus, logic_base_cls())

function CStatus:New(id, mArgs)
    local o = super(CStatus).New(self)
    o:Init(id, mArgs)
    return o
end

function CStatus:Init(id, mArgs)
    self.m_ID = id
    self.m_mSet = {}
    self:Update(mArgs)
end

function CStatus:StatusId()
    return self.m_ID
end

function CStatus:SetAttr(skey,value)
    self.m_mSet[skey] = value
end

function CStatus:GetAttr(skey, rDefault)
    return self.m_mSet[skey] or rDefault
end

function CStatus:Update(mArgs, bReset)
    if bReset then
        self.m_mSet = {}
    end
    for k,v in pairs(mArgs or {}) do
        self.m_mSet[k] = v
    end
end

function CStatus:PackUnit()
    local mNet = {}
    mNet.status_id = self.m_ID
    mNet.attrlist = {}
    for k,v in pairs(self.m_mSet) do
        if type(v) == "number" then
            table.insert(mNet.attrlist, {key=k,value=v})
        end
    end
    return mNet
end

function NewStatus(...)
    local o = CStatus:New(...)
    return o
end
