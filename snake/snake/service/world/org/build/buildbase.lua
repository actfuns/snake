--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))


function NewBuild(...)
    return CBuildBase:New(...)
end

function CheckSuccessBuild(iOrgId, iBid)
    local oOrgMgr = global.oOrgMgr
    local oOrg = oOrgMgr:GetNormalOrg(iOrgId)
    if not oOrg then return end

    local oBuild = oOrg.m_oBuildMgr:GetBuildById(iBid)
    if oBuild then
        oBuild:UpGradeSuccess()
    end
end

CBuildBase = {}
CBuildBase.__index = CBuildBase
inherit(CBuildBase, datactrl.CDataCtrl)

function CBuildBase:New(iBid, iOrgId)
    local o = super(CBuildBase).New(self, {bid=iBid, orgid=iOrgId})
    o:Init()
    return o
end

function CBuildBase:Init()
    self.m_iLevel = 0                                            -- 等级
    self.m_iBuildTime = 0                                    -- 开始时间-建造或升级
    self.m_iQuickSec = 0                                      -- 加速秒数   
    self.m_mMemQuickSec = {}                           -- 玩家加速秒数
    self.m_mMemQuickNum = {}                        -- 加速次数
end

function CBuildBase:Load(mData)
    if not mData then return end

    self.m_iLevel = mData.level
    self.m_iBuildTime = mData.build_time or 0
    self.m_iQuickSec = mData.quick_sec
    self.m_mMemQuickSec = mData.mem_quick_sec
    self.m_mMemQuickNum = mData.mem_quick_num
end

function CBuildBase:Save()
    local mData = {}
    mData.level = self.m_iLevel
    mData.build_time = self.m_iBuildTime
    mData.quick_sec = self.m_iQuickSec
    mData.mem_quick_sec = self.m_mMemQuickSec
    mData.mem_quick_num = self.m_mMemQuickNum
    return mData
end

function CBuildBase:AfterLoad()
    self:_CheckBuild()
end

function CBuildBase:GetOrg()
    local orgid = self:GetInfo("orgid")
    local oOrgMgr = global.oOrgMgr
    return oOrgMgr:GetNormalOrg(orgid)
end

function CBuildBase:BuildID()
    return self:GetInfo("bid")
end

function CBuildBase:OrgID()
    return self:GetInfo("orgid")
end

function CBuildBase:Level()
    return self.m_iLevel
end

function CBuildBase:GetBuildData()
    local mData = res["daobiao"]["org"]["buildlevel"]
    if mData[self:BuildID()] then
        return mData[self:BuildID()][self:Level()]
    end
    return nil
end

function CBuildBase:GetNextLevelData()
    local mData = res["daobiao"]["org"]["buildlevel"]
    if mData[self:BuildID()] then
        return mData[self:BuildID()][self:Level() + 1]
    end
    return nil
end

function CBuildBase:UpGradeBuild()
    self.m_iBuildTime = get_time()
    self.m_iQuickSec = 0
    self.m_mMemQuickSec = {}
    self.m_mMemQuickNum = {}
    self:Dirty()

    self:_CheckBuild()
end

function CBuildBase:_CheckBuild()
    if not self:IsUpGrade() then return end

    self:DelTimeCb("_CheckBuild")
    local iLeftTime = math.max(1, self:GetLeftTime())

    local iOrgId = self:GetInfo("orgid")
    local iBid = self:BuildID()
    local f = function ()
        CheckSuccessBuild(iOrgId, iBid)
    end
    
    self:AddTimeCb("_CheckBuild", iLeftTime * 1000, f)    
end

function CBuildBase:IsUpGrade()
    return self.m_iBuildTime > 0
end

function CBuildBase:GetLeftTime()
    if not self:IsUpGrade() then return 0 end

    return self.m_iBuildTime + self:GetNextLevelData()["upgrade_time"] - self.m_iQuickSec - get_time()
end

function CBuildBase:GetQuickNum(iPid)
    return self.m_mMemQuickNum[iPid] or 0
end

function CBuildBase:QuickBuild(iPid, iVal, bGm)
    if not bGm then
        local iCnt = self.m_mMemQuickNum[iPid] or 0
        self.m_mMemQuickNum[iPid] = iCnt + 1
    end
    
    local iCnt = self.m_mMemQuickSec[iPid] or 0
    self.m_mMemQuickSec[iPid] = iCnt + iVal

    self.m_iQuickSec = self.m_iQuickSec + iVal
    self:Dirty()

    if self:GetLeftTime() <= 0 then
        self:UpGradeSuccess()
    else
        self:_CheckBuild()
    end
end

function CBuildBase:UpGradeSuccess()
    self:DelTimeCb("_CheckBuild")
    self:AddLevel(1)
    self.m_iQuickSec = 0
    self.m_iBuildTime = 0
    self:Dirty()

    local oOrgMgr = global.oOrgMgr
    local oOrg = oOrgMgr:GetNormalOrg(self:GetInfo("orgid"))
    if oOrg then
        oOrg:BuildUpGradeSuccess(self:BuildID(), self:Level())
    end
end

function CBuildBase:NewHour(iHour)
end

function CBuildBase:AddLevel(iVal)
    self:Dirty()
    self.m_iLevel = self.m_iLevel + iVal
end

function CBuildBase:PackBuildInfo(iPid)
    local mNet = {}
    mNet.bid = self:BuildID()
    mNet.level = self.m_iLevel
    if self:IsUpGrade() and iPid then 
        mNet.build_time = self.m_iBuildTime
        mNet.quick_sec = self.m_iQuickSec
        mNet.quick_num = self:GetQuickNum(iPid)
    end
    return mNet 
end

function CBuildBase:ClickBuild(oPlayer)
end
