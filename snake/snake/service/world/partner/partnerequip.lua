-- import module
local global = require "global"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local loadskill = import(service_path("partner.skill.loadskill"))

function NewEquipCtrl(iPartner, iPid)
    return CEquipCtrl:New(iPartner, iPid)
end

CEquipCtrl = {}
CEquipCtrl.__index = CEquipCtrl
inherit(CEquipCtrl, datactrl.CDataCtrl)

function CEquipCtrl:New(iPartner, iPid)
    local o = super(CEquipCtrl).New(self, {partner = iPartner, pid=iPid})
    o.m_mEquipSID = {}
    o.m_mEquipApply = {}
    return o
end

function CEquipCtrl:Load(mData)
    mData = mData or {}
    self.m_mEquipApply = mData["equipapply"] or {}
    self.m_mEquipSID = mData["equipsid"] or {}
end

function CEquipCtrl:Save()
    local mData = {}
    mData["equipapply"] = self.m_mEquipApply
    mData["equipsid"] = self.m_mEquipSID
    return mData
end

function CEquipCtrl:AddEquip(oPartner, iPos, sid, mApply)
    self:Dirty()
    local sPos = db_key(iPos)
    self.m_mEquipSID[sPos] = sid
    self.m_mEquipApply[sPos] = mApply
    self:CheckSuitEffect(oPartner)

    local iOwner = oPartner:GetOwnerID()
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iOwner)
    if oPlayer then
        local mLogData = oPlayer:LogData()
        mLogData["partner_sid"] = oPartner:GetSID()
        mLogData["pos"] = iPos
        mLogData["equip_sid"] = sid
        mLogData["apply"] = mApply
        record.log_db("partner", "equip_partner", mLogData)
    end
end

function CEquipCtrl:GetEquip(iPos)
    local sPos = db_key(iPos)
    return self.m_mEquipSID[sPos]
end

function CEquipCtrl:GetApply(sAttr)
    local iValue = 0
    for _, mApply in pairs(self.m_mEquipApply) do
        if mApply[sAttr] then
            iValue = iValue + mApply[sAttr]
        end
    end
    return iValue
end

function CEquipCtrl:GetRatioApply(sAttr)
    return 0
end

function CEquipCtrl:CheckSuitEffect(oPartner)
    for _, iPos in pairs(gamedefines.PARTNER_EQUIP_POS) do
        if not self:GetEquip(iPos) then
            return false
        end
    end
    self:SuitEffect(oPartner)
    return true
end

function CEquipCtrl:SuitEffect(oPartner)
    local mSuit = res["daobiao"]["partner"]["suilt"]
    local mData = {}
    for _, iSk in ipairs(mSuit[oPartner:GetSID()]["suilt_effect"]) do
        local oSK = loadskill.NewSkill(iSk)
        oPartner.m_oSkillCtrl:AddSkill(oSK)
        if oSK:ProtectType() == 1 then
            oSK:SkillEffect(self)
        end
        oPartner:PropChange("skill")
        oPartner:SecondLevelPropChange()
    end
end

function CEquipCtrl:PackNetInfo(oPlayer)
    local mNet = {}
    for _, iPos in pairs(gamedefines.PARTNER_EQUIP_POS) do
        local sid = self:GetEquip(iPos)
        if sid then
            table.insert(mNet, sid)
        end
    end
    return mNet
end
