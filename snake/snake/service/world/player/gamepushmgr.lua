local global = require "global"
local datactrl = import(lualib_path("public.datactrl"))

function NewGamePushMgr(pid)
    return CGamePushMgr:New(pid)
end

CGamePushMgr = {}
CGamePushMgr.__index = CGamePushMgr
inherit(CGamePushMgr, datactrl.CDataCtrl)

function CGamePushMgr:New(pid)
    local o = super(CGamePushMgr).New(self, {pid = pid})
    o.m_mValues = {}
    return o
end

function CGamePushMgr:ChangeValues(lValueInfos)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(self:GetInfo("pid"))
    if not oPlayer then
        return
    end
    self:Dirty()
    for _, mValueInfo in ipairs(lValueInfos) do
        self.m_mValues[mValueInfo.id] = mValueInfo.value
        if mValueInfo.id == 2001 then
            local oFriend = oPlayer:GetFriend()
            oFriend:ChangePushConfig(mValueInfo.value)
        end
    end
end

function CGamePushMgr:PackValuesInfo()
    local lInfos = {}
    for iId, iValue in pairs(self.m_mValues) do
        table.insert(lInfos, {id = iId, value = iValue})
    end
    return lInfos
end

function CGamePushMgr:PackConfigNetData()
    local mNet = {
        values = self:PackValuesInfo(),
    }
    return mNet
end

function CGamePushMgr:CallChangeConfig(lValueInfos)
    if lValueInfos then
        self:ChangeValues(lValueInfos)
    end
end

function CGamePushMgr:Save()
    return {
        values = table_to_db_key(self.m_mValues),
    }
end

function CGamePushMgr:Load(mData)
    self.m_mValues = table_to_int_key(mData.values or {})
end

function CGamePushMgr:OnLogin(oPlayer, bReEnter)
    local mNet = self:PackConfigNetData()
    oPlayer:Send("GS2CGamePushConfig", mNet)
end

