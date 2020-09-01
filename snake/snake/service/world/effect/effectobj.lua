local global = require "global"

function NewEffectMgr()
    local oMgr = CEffectMgr:New()
    return oMgr
end

CEffectMgr = {}
CEffectMgr.__index = CEffectMgr
inherit(CEffectMgr, logic_base_cls())

function CEffectMgr:New()
    local o = super(CEffectMgr).New(self)
    o.m_mObject = {}
    o.m_iDispatchId = 0
    return o
end

function CEffectMgr:DispatchId()
    self.m_iDispatchId = self.m_iDispatchId + 1
    return self.m_iDispatchId
end

function CEffectMgr:AddObject(oEffect)
    self.m_mObject[oEffect:ID()] = oEffect
end

function CEffectMgr:RemoveObject(iObjId)
    self.m_mObject[iObjId] = nil
end

function CEffectMgr:GetObject(iObjId)
    return self.m_mObject[iObjId]
end

-----------------------------------------
function TouchNewSceneEffect(iEffectId, mInfo)
    if not iEffectId then
        return nil
    end
    local o = CSceneEffect:New(iEffectId)
    o:Init(mInfo)
    return o
end

CSceneEffect = {}
CSceneEffect.__index = CSceneEffect
inherit(CSceneEffect, logic_base_cls())

function CSceneEffect:New(iEffectId)
    assert(iEffectId and iEffectId > 0, string.format("effectid error:%s", iEffectId))
    local o = super(CSceneEffect).New(self)
    o.m_iEffectId = iEffectId
    o:InitObject()
    return o
end

function CSceneEffect:InitObject()
    local oEffectMgr = global.oEffectMgr
    local id = oEffectMgr:DispatchId()
    self.m_ID = id
end

function CSceneEffect:Init(mInfo)
    if mInfo then
        self.m_mPosInfo = mInfo.pos_info
        self.m_sName = mInfo.name
        self.m_iType = mInfo.type
    end
end

function CSceneEffect:ID()
    return self.m_ID
end

function CSceneEffect:Name()
    return self.m_sName
end

function CSceneEffect:Type()
    return self.m_iType
end

function CSceneEffect:EffectId()
    return self.m_iEffectId or 0
end

function CSceneEffect:PosInfo()
    return self.m_mPosInfo
end

function CSceneEffect:Release()
    super(CSceneEffect).Release(self)
end

function CSceneEffect:GetScene()
    return self.m_iScene
end

function CSceneEffect:SetScene(iScene)
    self.m_iScene = iScene
end

function CSceneEffect:PackSceneInfo()
    local mInfo = {
        objid = self:ID(),
        name = self:Name(),
    }
    return mInfo
end

