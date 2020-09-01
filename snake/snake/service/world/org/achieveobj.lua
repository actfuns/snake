--import module
local skynet = require "skynet"
local global = require "global"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local orgdefines = import(service_path("org.orgdefines"))


function NewAchieve(...)
    return CAchieveBase:New(...)    
end

CAchieveBase = {}
CAchieveBase.__index = CAchieveBase
inherit(CAchieveBase, datactrl.CDataCtrl)


function CAchieveBase:New(iAch, iOrg)
    local o = super(CAchieveBase).New(self, {achid = iAch, orgid=iOrg})
    o:Init()
    return o
end

function CAchieveBase:Init()
    self.m_iProcess = 0
    self.m_bReach = false
end

function CAchieveBase:Load(mData)
    self.m_iProcess = mData.process or 0
    self.m_bReach = mData.reach or false
end

function CAchieveBase:Save()
    local mData = {}
    mData.process = self.m_iProcess
    mData.reach = self.m_bReach
    return mData
end

function CAchieveBase:GetProcess()
    return self.m_iProcess
end

function CAchieveBase:GetStatus(oPlayer)
    if oPlayer.m_oAchieveCtrl:HasReceiveOrgAch(self:GetAchID()) then
        return 2
    end

    if not self:HasReach() then return 0 end
    
    return 1
end

function CAchieveBase:SetProcess(iVal)
    self.m_iProcess = iVal
    self:Dirty()
end

function CAchieveBase:AddProcess(iVal)
    self.m_iProcess = self.m_iProcess + iVal
    self:Dirty()
end

function CAchieveBase:GetAchID()
    return self:GetInfo("achid")
end

function CAchieveBase:GetOrgID()
    return self:GetInfo("orgid")
end

function CAchieveBase:CheckReach()
    local mData = res["daobiao"]["org"]["achieve"][self:GetAchID()]
    if not mData then return end
    
    if mData["reach_val"] <= self:GetProcess() then
        self:SetReach()
    end
end

function CAchieveBase:SetReach()
    self.m_bReach = true
    self:Dirty()
end

function CAchieveBase:HasReach()
    return self.m_bReach
end

function CAchieveBase:Handle(mArgs)
end

function CAchieveBase:PackAchInfo(oPlayer)
    local mNet = {}
    mNet.achid = self:GetAchID()
    mNet.ach_status = self:GetStatus(oPlayer)
    mNet.process = self:GetProcess()
    return mNet
end

-- 到达指定数值的成就
    -- 帮派达到指定等级
    -- 全部建筑达到指定等级
    -- 成员数达到指定的数量
    -- 繁荣度到达指定值
function NewAchTargetVal(...)
    return CAchTargetVal:New(...)
end

CAchTargetVal = {}
CAchTargetVal.__index = CAchTargetVal
inherit(CAchTargetVal, CAchieveBase)

function CAchTargetVal:Handle(mArgs)
    local iVal = mArgs["iVal"]
    if self:GetProcess() >= iVal then return end
    
    self:SetProcess(iVal)
    self:CheckReach()
end


-- 累计资金达到指定的值
function NewAchCashCnt(...)
    return CAchCashCnt:New(...)
end

CAchCashCnt = {}
CAchCashCnt.__index = CAchCashCnt
inherit(CAchCashCnt, CAchieveBase)

function CAchCashCnt:Handle(mArgs)
    local iVal = mArgs["iVal"]
    local mData = res["daobiao"]["org"]["achieve"][self:GetAchID()]
    if not mData then return end

    self:AddProcess(iVal)
    self:CheckReach()
end


-- 指定建筑达到指定等级
function NewAchBuildLevel(...)
    return CAchBuildLevel:New(...)
end

CAchBuildLevel = {}
CAchBuildLevel.__index = CAchBuildLevel
inherit(CAchBuildLevel, CAchieveBase)

function CAchBuildLevel:Handle(mArgs)
    local iVal = mArgs["iLevel"]
    local iCon = mArgs["iBid"]
    if self:GetProcess() >= iVal then return end
    
    local mData = res["daobiao"]["org"]["achieve"][self:GetAchID()]
    if not mData then return end

    if mData["con_val"] ~=  iCon then return end

    self:SetProcess(iVal)
    if self:GetProcess() >= mData["reach_val"] then
        self:SetReach()
    end
end


-- 指定成员等级达到指定的数量
function NewAchMemGradeCnt(...)
    return CAchMemGradeCnt:New(...)
end

CAchMemGradeCnt = {}
CAchMemGradeCnt.__index = CAchMemGradeCnt
inherit(CAchMemGradeCnt, CAchieveBase)

function CAchMemGradeCnt:Init()
    super(CAchMemGradeCnt).Init(self)
    self.m_lMember = {}
end

function CAchMemGradeCnt:CheckReach()
    local oOrgMgr = global.oOrgMgr
    local oOrg = oOrgMgr:GetNormalOrg(self:GetOrgID())
    local mData = res["daobiao"]["org"]["achieve"][self:GetAchID()]
    if not oOrg or not mData then return end 

    self.m_lMember = {}
    for pid, oMember in pairs(oOrg.m_oMemberMgr:GetMemberMap()) do
        if oMember:GetGrade() >= mData["con_val"] then
            table.insert(self.m_lMember, pid)
        end
    end
        
    self:SetProcess(#self.m_lMember)
    if #self.m_lMember >= mData["reach_val"] then
        self:SetReach()
    end
end

function CAchMemGradeCnt:Handle(mArgs)
    -- 来一个满足添加的重写检查 不需要考虑退帮情况
    local iPid = mArgs["pid"]
    local iLevel = mArgs["level"]
    if not iPid or not iLevel then return end

    local mData = res["daobiao"]["org"]["achieve"][self:GetAchID()]
    if not mData then return end

    if mData["con_val"] > iLevel then return end
    if table_in_list(self.m_lMember, iPid) then return end

    self:CheckReach()
end


-- 繁荣度连续指定天到达指定值
function NewAchBoomMoreDay(...)
    return CAchBoomMoreDay:New(...)
end

CAchBoomMoreDay = {}
CAchBoomMoreDay.__index = CAchBoomMoreDay
inherit(CAchBoomMoreDay, CAchieveBase)

function CAchBoomMoreDay:Handle(mArgs)
    local iBoomVal = mArgs["iBoom"]
    local mData = res["daobiao"]["org"]["achieve"][self:GetAchID()]
    if not mData then return end

    if iBoomVal >= mData["con_val"] then
        self:AddProcess(1)
        if self:GetProcess() >= mData["reach_val"] then
            self:SetReach()
        end
    else
        if self:GetProcess() > 0 then
            self:SetProcess(0)
        end        
    end
end
