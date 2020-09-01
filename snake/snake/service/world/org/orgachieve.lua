--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local orgdefines = import(service_path("org.orgdefines"))
local loadobj = import(service_path("org.loadobj"))


function NewAchieveMgr(...)
    return COrgAchieveMgr:New(...)
end


COrgAchieveMgr = {}
COrgAchieveMgr.__index = COrgAchieveMgr
inherit(COrgAchieveMgr, datactrl.CDataCtrl)

-- 帮派目标
function COrgAchieveMgr:New(orgid)
    local o = super(COrgAchieveMgr).New(self, {orgid = orgid})
    o:Init()
    return o
end

function COrgAchieveMgr:Init()
    self.m_mAchieve = {}
end

function COrgAchieveMgr:Release()
    for _, oAch in pairs(self.m_mAchieve) do
        baseobj_safe_release(oAch)
    end
    self.m_mAchieve = {}
    super(COrgAchieveMgr).Release(self)
end

function COrgAchieveMgr:Load(mData)
    if not mData then return end

    for iAch, m in pairs(mData) do
        iAch = tonumber(iAch)
        local oAch = loadobj.LoadAchieve(iAch, self:GetInfo("orgid"), m)
        self.m_mAchieve[iAch] = oAch
    end
end

function COrgAchieveMgr:Save()
    local mData = {}
    for iAch, oAch in pairs(self.m_mAchieve) do
        mData[db_key(iAch)] = oAch:Save()
    end
    return mData
end

function COrgAchieveMgr:IsDirty()
    local bDirty = super(COrgAchieveMgr).IsDirty(self)
    if bDirty then
        return true
    end

    for _, oAch in pairs(self.m_mAchieve) do
        if oAch:IsDirty() then
            return true
        end
    end
    return false
end

function COrgAchieveMgr:UnDirty()
    super(COrgAchieveMgr).UnDirty(self)
    for _, oAch in pairs(self.m_mAchieve) do
        if oAch:IsDirty() then
            oAch:UnDirty()
        end
    end
 end

function COrgAchieveMgr:GetOrg()
    local orgid = self:GetInfo("orgid")
    local oOrgMgr = global.oOrgMgr
    return oOrgMgr:GetNormalOrg(orgid)
end

function COrgAchieveMgr:HandleEvent(iType, mArgs)
    local mData = res["daobiao"]["org"]["achtype"][iType]
    if not mData then return end

    for _, iAch in ipairs(mData) do
        local oAch = self.m_mAchieve[iAch]
        if not oAch then
            oAch = loadobj.NewAchieve(iType, iAch, self:GetInfo("orgid"))
            self.m_mAchieve[iAch] = oAch
            self:Dirty()
        end

        if not oAch:HasReach() then
            oAch:Handle(mArgs)
            if oAch:HasReach() then
                -- TODO
            end
        end
    end
end

function COrgAchieveMgr:GS2CGetAchieveInfo(oPlayer)
    local mNet = {}
    for iAch, oAch in pairs(self.m_mAchieve) do
        table.insert(mNet, oAch:PackAchInfo(oPlayer))
    end
    oPlayer:Send("GS2CGetAchieveInfo", {achieves=mNet})
end

function COrgAchieveMgr:ReceiveAchieve(oPlayer, iAch)
    local oAch = self.m_mAchieve[iAch]
    if not oAch then return end

    if oAch:GetStatus(oPlayer) ~= 1 then return end

    local mData = res["daobiao"]["org"]["achieve"][iAch]
    if not mData or oPlayer:GetGrade() < mData["receive_lv"] then return end

    local oOrg = self:GetOrg()
    if not oOrg or oOrg:GetHisOffer(oPlayer:GetPid()) < mData["receive_offer"] then return end

    local mLog = oPlayer:LogData()
    mLog["org_id"] = self:GetInfo("orgid")
    mLog["achid"] = iAch

    oPlayer.m_oAchieveCtrl:ReceiveOrgAch(iAch)
    local lReward = mData["reward"]
    for _, mItem in pairs(lReward) do
        local oNewItem = global.oItemLoader:Create(mItem["id"])
        oNewItem:SetAmount(mItem["val"])
        oPlayer:RewardItem(oNewItem, "帮派成就")
    end

    mLog["reward"] = lReward
    record.log_db("org", "receive_achieve", mLog)
    -- TODO
    oPlayer:Send("GS2CUpdateAchieveInfo", {achieve=oAch:PackAchInfo(oPlayer)})
end


