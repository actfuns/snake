local global = require "global"
local res = require "base.res"

local statebase = import(service_path("state/statebase"))

CState = {}
CState.__index = CState
inherit(CState,statebase.CState)

local BAOSHI_LIMIT = 200
local BAOSHI_ITEM = {[10046] = true,[10049] = true ,[10057] = true}

function NewState(iState)
    local o = CState:New(iState)
    return o 
end

function CState:New(iState)
    local o = super(CState).New(self,iState)
    return o
end

function CState:Load(mData)
    mData = mData or {}
    self:SetData("count",mData.count or 0)
end

function CState:Save()
    local mData = {}
    mData["count"] = self:GetData("count",0)
    return mData
end

function CState:Config(oPlayer,mArgs)
    self:SetData("count",BAOSHI_LIMIT)
end

function CState:Click(oPlayer,mData)
    local oNotifyMgr = global.oNotifyMgr
    local iNeedCount = BAOSHI_LIMIT - self:GetCount()
    if iNeedCount<= 0 then
        oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1001))
        return
    end
    self:PopUI(oPlayer:GetPid())
end

function CState:GetOtherData()
    local mData = {}
    table.insert(mData,{key="count",value=self:GetData("count",0)})
    return mData
end

function CState:AddCount(pid,iValue,open)
    self:SetCount(self:GetCount() + iValue)
    if not open then
        self:TryPopUI(pid)
    end
end

function CState:TryPopUI(pid)
    if self:GetCount() < 30 then
        self:PopUI(pid)
    end
end

function CState:GetCount()
    return self:GetData("count",0)
end

function CState:GetMaxCount()
    return BAOSHI_LIMIT
end

function CState:SetCount(iValue)
    iValue = math.min(iValue,BAOSHI_LIMIT)
    iValue = math.max(iValue,0)
    self:SetData("count",iValue)
    self:Refresh(self:GetInfo("pid"))
end

function CState:AddCountByItem(oPlayer)
    
end

function CState:AddCountBySilver(oPlayer)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iServerGrade  = oPlayer:GetServerGrade()
    local iCurCount = self:GetCount()
    local iNeedCount = BAOSHI_LIMIT - iCurCount
    if iNeedCount<= 0 then
        oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1001))
        return
    end
    local iSilver = math.floor((iServerGrade*25+4000)/10)
    local iNeedSilver = iSilver*iNeedCount
    if oPlayer.m_oActiveCtrl:ValidSilver(iNeedSilver) then
        oPlayer.m_oActiveCtrl:ResumeSilver(iNeedSilver,"增加饱食度")
        self:AddCount(oPlayer:GetPid(),iNeedCount,true)
        oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1002))
        if iCurCount == 0 then
            self:RelifeAll(oPlayer)
        end
    else
        oPlayer:Send("GS2CBaoShiSilver",{})
    end
end

function CState:GetNeedCountBySilver(oPlayer)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iServerGrade  = oPlayer:GetServerGrade()
    local iCurCount = self:GetCount()
    local iNeedCount = BAOSHI_LIMIT - iCurCount
    if iNeedCount<= 0 then
        oNotifyMgr:Notify(oPlayer:GetPid(),self:GetTextData(1001))
        return
    end
    local iSilver = math.floor((iServerGrade*25+4000)/10)
    local iNeedSilver = iSilver*iNeedCount
    return iNeedCount,iNeedSilver
end

function CState:PopUI(pid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    local iNeedCount
    local iNeedSliver
    iNeedCount,iNeedSliver = self:GetNeedCountBySilver(oPlayer)
    local mNet = {}
    mNet.count = iNeedCount
    mNet.sliver = iNeedSliver
    oPlayer:Send("GS2CAddBaoShi",mNet)
end

function CState:RelifeAll(oPlayer)
    local bCut
    if self:RelifePlayer(oPlayer) then
        bCut = true
    end
    if self:RelifePartner(oPlayer) then
        bCut = true
    end
    if self:RelifeSummon(oPlayer) then
        bCut = true
    end
    if bCut then
        self:AddCount(oPlayer:GetPid(),-1,true)
    end
end

function CState:RelifePlayer(oPlayer)
    local bCut = false
    if oPlayer:GetMaxHp() ~= oPlayer.m_oActiveCtrl:GetData("hp",0) then
        oPlayer.m_oActiveCtrl:SetData("hp",oPlayer:GetMaxHp())
        oPlayer:PropChange("hp")
        bCut = true
    end

    if oPlayer:GetMaxMp() ~= oPlayer.m_oActiveCtrl:GetData("mp",0) then
        oPlayer.m_oActiveCtrl:SetData("mp",oPlayer:GetMaxMp())
        oPlayer:PropChange("mp")
        bCut = true
    end
    return bCut
end

function CState:RelifePartner(oPlayer)
    local bCut = false
    for _,obj in pairs(oPlayer.m_oPartnerCtrl:GetAllPartner()) do
        if obj:GetMaxHp() ~= obj:GetData("hp") then
            obj:SetData("hp", obj:GetMaxHp())
            obj:PropChange("hp")
            bCut = true
        end
        if obj:GetMaxMp() ~= obj:GetData("mp") then
            obj:SetData("mp", obj:GetMaxMp())
            obj:PropChange("mp")
            bCut = true
        end
    end
    return bCut
end

function CState:RelifeSummon(oPlayer)
    local bCut = false
    for _, obj in pairs(oPlayer.m_oSummonCtrl:SummonList()) do
        if obj:GetMaxHP() ~= obj:GetData("hp") then
            obj:SetData("hp", obj:GetMaxHP())
            obj:PropChange("hp")
            bCut = true
        end
        if obj:GetMaxMP() ~= obj:GetData("mp") then
            obj:SetData("mp", obj:GetMaxMP())
            obj:PropChange("mp")
            bCut = true
        end
    end
    return bCut
end