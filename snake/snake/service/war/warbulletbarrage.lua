local global = require "global"

function NewBulletBarrage(iWarId)
    local o = CWarBulletBarrage:New(iWarId)
    return o
end

CWarBulletBarrage = {}
CWarBulletBarrage.__index = CWarBulletBarrage
inherit(CWarBulletBarrage,logic_base_cls())

function CWarBulletBarrage:New(iWarId)
    local o = super(CWarBulletBarrage).New(self)
    o.m_iWarId = iWarId
    o.m_mBulletBarrage = {}
    return o
end

function CWarBulletBarrage:GetWarId()
    return self.m_iWarId
end

function CWarBulletBarrage:GetWar()
    local oWarMgr = global.oWarMgr
    return oWarMgr:GetWar(self:GetWarId())
end

function CWarBulletBarrage:AddBulletBarrage(sName,sMsg)
    local oWar = self:GetWar()
    local iBoutStartTime = oWar:GetExtData("bout_start")
    iBoutStartTime = iBoutStartTime or get_time()
    local iBout = oWar:CurBout()
    local iSecs = get_time() - iBoutStartTime

    local lBout = table_get_set_depth(self.m_mBulletBarrage, {tostring(iBout), tostring(iSecs)})
    table.insert(lBout, {sName, sMsg})

    local mRet = {}
    mRet.bout = iBout
    mRet.secs = iSecs
    return mRet
end

function CWarBulletBarrage:PacketBulletBarrageData()
    local oWar = self:GetWar()
    if oWar:IsWarRecord() then
        return self.m_mBulletBarrage
    end
end

function CWarBulletBarrage:Release()
    super(CWarBulletBarrage).Release(self)
end

