local global= require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))

local RAMDOM_TYPE = 101
local AVE_TYPE = 102
local CHANNEL_ORG=101           --帮派频道
local CHANNEL_WORLD = 102   --世界频道
local CASHTYPE_GOLD = 101       --金币类型
local CASHTYPE_SLIVER = 102     --银币类型

function NewRedPacket(sid)
    if sid then
        assert(res["daobiao"]["redpacket"]["basic"][sid],string.format("NewRedPacket %s",sid))
    end
    return CRedPacket:New(sid)
end


CRedPacket={}
CRedPacket.__index=CRedPacket
inherit(CRedPacket,datactrl.CDataCtrl)

function CRedPacket:New(sid)
    local o = super(CRedPacket).New(self)
    local oRedPacketMgr=global.oRedPacketMgr
    o.m_ID=oRedPacketMgr:DispitchRPID()
    o.m_Sid=sid
    o.m_lBasicInfo={}
    o.m_lReceiveInfo={}
    return o
end

function CRedPacket:Save()
    local mData = {}
    mData.basicinfo = self.m_lBasicInfo
    mData.receiveinfo = self.m_lReceiveInfo
    mData.name = self:GetData("name")
    mData.count = self:GetData("count")
    mData.cashsum = self:GetData("cashsum")
    mData.owner = self:GetData("owner")
    mData.ownericon = self:GetData("ownericon")
    mData.ownername = self:GetData("ownername")
    mData.orgid = self:GetData("orgid")
    mData.createtime = self:GetData("createtime")
    mData.bless = self:GetData("bless")
    mData.sid = self.m_Sid
    return mData
end

function CRedPacket:Load( mData)
    mData = mData or {}
    self:SetData("name", mData.name)
    self:SetData("count", mData.count)
    self:SetData("cashsum", mData.cashsum)
    self:SetData("owner", mData.owner)
    self:SetData("ownericon", mData.ownericon)
    self:SetData("ownername", mData.ownername)
    self:SetData("orgid", mData.orgid)
    self:SetData("createtime", mData.createtime)
    self:SetData("bless",mData.bless)
    self.m_lReceiveInfo = mData.receiveinfo
    self.m_lBasicInfo = mData.basicinfo
    self.m_Sid = mData.sid
end


-------------系统创建-----------
function CRedPacket:CreateBySys(mData)
    local iCashSum = self:ExchangeMoney(mData.goldcoin)
    self:SetData("name",mData.name)
    self:SetData("count",mData.count)
    self:SetData("cashsum",iCashSum)
    self:SetData("owner",mData.owner)
    self:SetData("ownericon",mData.ownericon)
    self:SetData("ownername",mData.ownername)
    self:SetData("createtime",mData.createtime)
    self:SetData("orgid",mData.orgid)
    self:SetData("bless",mData.bless)
    self:Setup()
end

function CRedPacket:ValidCreateBySys(mData)
    assert(mData.count>0,"create rb by sys count err")
    if mData.count<=0 then 
        record.warning(string.format("CreateBySys cnt1  %s %s",self.m_Sid,mData.count))
        return false
    end
    return true
end

--------------玩家创建---------------
function CRedPacket:Create( oPlayer,mData )
    local iCashSum = self:ExchangeMoney(mData.goldcoin)
    self:SetData("name",mData.name)
    self:SetData("count",mData.count)
    self:SetData("cashsum",iCashSum)
    self:SetData("owner",mData.owner)
    self:SetData("ownericon",mData.ownericon)
    self:SetData("ownername",mData.ownername)
    self:SetData("createtime",mData.createtime)
    self:SetData("orgid",mData.orgid)
    self:SetData("bless",mData.bless)
    self:Setup()
end

function CRedPacket:ValidCreate( oPlayer,mData)
    assert(mData.count>0,"create rb  count err")
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    if not mData.isitem then
        if not oPlayer:ValidGoldCoin(mData.goldcoin,"兑换红包") then
            return false
        end
    end
    if mData.goldcoin<=0 then
        oNotifyMgr:Notify(pid,"数量不合法")
        return false
    end
    local iMinCnt,iMaxCnt=self:GetValidCnt(mData.goldcoin)
    if mData.count<iMinCnt or mData.count>iMaxCnt then
        oNotifyMgr:Notify(pid,"数量不合法")
        return false
    end
    local oOrgMgr=global.oOrgMgr
    if mData.channel==CHANNEL_ORG  then
        local orgid = oPlayer:GetOrgID()
        if not (orgid ~=0 and  orgid == mData.orgid) then
            oNotifyMgr:Notify(pid,"你还未加入帮派")
            return false
        end
    end
    return true
end

function CRedPacket:ExchangeMoney(iGoldCoin)
    assert(iGoldCoin>0,"rp err goldcoin")
    local mRes=self:GetRes()
    if mRes.cashtype == CASHTYPE_GOLD then
        return iGoldCoin*100
    elseif mRes.cashtype == CASHTYPE_SLIVER then
        return iGoldCoin*1000
    else
        assert(nil,"rp err goldtype")
    end
end

function CRedPacket:Setup()
    self.m_lBasicInfo={}
    local mRes=self:GetRes()
    local iCount=self:GetData("count")
    local iSum=self:GetData("cashsum")
    if mRes.type==RAMDOM_TYPE then
        local iDiff = math.floor(iSum*51/100)
        local iHalf = math.floor(iSum/2)
        local iAvg = math.floor(iSum/iCount)
        local iLeft = iSum
        for i=1 , iCount do
            local iMinValue = math.floor(math.random(1,10)/100.0*iLeft)
            iLeft = iLeft - iMinValue
            self.m_lBasicInfo[i] = iMinValue
        end
        for  i=1,iCount do
            if iLeft<=0 then
                break
            end
            local iAddValue = math.floor(math.random(1,40)/100.0*iLeft)
            if i == iCount then
                iAddValue = iLeft
            end
            iLeft = iLeft - iAddValue
            self.m_lBasicInfo[i] = self.m_lBasicInfo[i] + iAddValue
        end
    elseif mRes.type==AVE_TYPE then
        assert(iSum%iCount == 0,"err setup_rp_2")
        local iValue=math.floor(iSum/iCount)
        --assert( iValue >= iMinCash ,"err setup_rp_3")
        for  i=1,iCount,1 do
            table.insert(self.m_lBasicInfo,iValue)
        end
    else
        assert(nil,"err setup_rp_4")
    end
    if not is_production_env() then
        local oOwner = global.oWorldMgr:GetOnlinePlayerByPid(self:GetData("owner"))
        if oOwner then
            global.oChatMgr:HandleMsgChat(oOwner,extend.Table.serialize(self.m_lBasicInfo))
        end
    end
    self.m_lBasicInfo=extend.Random.random_size(self.m_lBasicInfo,#self.m_lBasicInfo)
end

--------------抢红包------------
function CRedPacket:ValidRob( oPlayer,bNotify)
    local mRes=self:GetRes()
    local oNotifyMgr = global.oNotifyMgr

    if mRes.channel==CHANNEL_ORG then
        if oPlayer:GetOrgID()~=self:GetData("orgid") then
            if bNotify then
                local sText = res["daobiao"]["redpacket"]["text"][1020]["content"]
                oNotifyMgr:Notify(oPlayer:GetPid(),sText)
            end
            return false
        end
    end
    for _,mValue in pairs(self.m_lReceiveInfo) do
        if mValue.pid == oPlayer:GetPid() then
            if bNotify then
                local sText = res["daobiao"]["redpacket"]["text"][1021]["content"]
                oNotifyMgr:Notify(oPlayer.m_iPid,sText)
            end
            return false
        end
    end
    if self:IsFinish() then
        if bNotify then
            local sText = res["daobiao"]["redpacket"]["text"][1008]["content"]
            oNotifyMgr:Notify(oPlayer:GetPid(),sText)
        end
        return false
    end
    return true
end

function CRedPacket:Rob(oPlayer)
    if not self:ValidRob(oPlayer,true) then
        self:GS2CRefresh(oPlayer,2)
        return
    end
    local pid = oPlayer:GetPid()
    local oChatMgr = global.oChatMgr
    local mRes=self:GetRes()
    local oRedPacketMgr=global.oRedPacketMgr
    local iLen = #self.m_lBasicInfo
    local iValue = self.m_lBasicInfo[iLen]

    oRedPacketMgr:Dirty()
    self.m_lBasicInfo[iLen]=nil
    
    
    local mInfo={name=oPlayer:GetName(),pid=pid,icon=oPlayer:GetIcon(),cash=iValue,time=get_time()}
    table.insert(self.m_lReceiveInfo,mInfo)
    if mRes.cashtype==CASHTYPE_GOLD then 
        oPlayer:RewardGold(iValue,"抢红包")
    elseif mRes.cashtype==CASHTYPE_SLIVER then
        oPlayer:RewardSilver(iValue,"抢红包")
    end
    local mLogData = {}
    mLogData.pid = pid
    mLogData.rbinfo = self:PackLogData({value = iValue})
    record.log_db("redpacket", "robrb", mLogData)
    oRedPacketMgr:AddRobHistory(pid,mRes.channel,mRes.cashtype,iValue)
    local mNet={id=self.m_ID,
            name=self:GetData("name"),
            ownername=self:GetData("ownername"),
            robcash=iValue}
    oPlayer:Send("GS2CRobSuccess",mNet)
    -- if mRes.channel == CHANNEL_ORG then
    --     oChatMgr:SendMsg2Org(self:GetData("name"),self:GetData("orgid"),oPlayer)
    -- elseif mRes.channel == CHANNEL_WORLD then
    --     oChatMgr:SendMsg2World(self:GetData("name"),oPlayer)
    -- end
    self:GS2CRefresh(oPlayer,2)
    if self:IsFinish()  then
        local sText = res["daobiao"]["redpacket"]["text"][1015]["content"]
        local sOwner = self:GetData("ownername","")
        local iCashSum = self:GetData("cashsum",0)
        local iRBCnt = self:GetData("count")
        local iTime = get_time() - self:GetData("createtime")
        local sBestRober
        local iMostRobCnt = 0
        for _,mInfo in ipairs(self.m_lReceiveInfo) do
            if mInfo.cash >iMostRobCnt then
                iMostRobCnt = mInfo.cash 
                sBestRober = mInfo.name
            end
        end
        if sBestRober then
            local mRes=self:GetRes()
            sText = global.oToolMgr:FormatColorString(sText, {role = {sOwner,sBestRober},amount = {iRBCnt,iCashSum,iTime,iMostRobCnt}})
            if mRes.channel==CHANNEL_ORG then
                local iOrgid = self:GetData("orgid")
                global.oChatMgr:SendMsg2Org(sText,iOrgid)
            elseif mRes.channel == CHANNEL_WORLD then
                global.oNotifyMgr:SendWorldChat(sText,{pid=0})
            end
        end
    end
end

function CRedPacket:GS2CRefresh(oPlayer,iValid)
    local mNet = {}
    mNet.id = self.m_ID
    mNet.valid = iValid
    if self:IsFinish() then
        mNet.finish = 2
    else
        mNet.finish = 1
    end
    oPlayer:Send("GS2CRefresh",mNet)
end

function CRedPacket:GetReceive()
    return self.m_lReceiveInfo
end

function CRedPacket:IsFinish()
    if #self.m_lBasicInfo==0 and #self.m_lReceiveInfo~=0 then return true end
    return false
end

function CRedPacket:IsReceive(pid)
    for _,mInfo in ipairs(self.m_lReceiveInfo) do
        if mInfo.pid == pid then
            return true
        end
    end
    return false
end

function CRedPacket:GetRes()
    return res["daobiao"]["redpacket"]["basic"][self.m_Sid]
end

function CRedPacket:GetValidCnt(iValue)
    assert(iValue>0,"rp getvalidcnt")
    local mRes = res["daobiao"]["redpacket"]["personnum"]
    for k,v in ipairs(mRes) do
        if iValue<=v.range then
            return v.min,v.max
        end
    end
    return mRes[#mRes].min,mRes[#mRes].max
end

function CRedPacket:GetSe()
    local iValue = self:GetData("cashsum")
    local mRes = res["daobiao"]["redpacket"]["personnum"]
    for k,v in ipairs(mRes) do
        if iValue<v.range*100 then
            return v.se
        end
    end
    return mRes[#mRes].se
end

function CRedPacket:PackLogData(mExtend)
    mExtend = mExtend or {}
    local mLog = {}
    mLog.ownername = self:GetData("ownername")
    mLog.createtime = self:GetData("createtime")
    mLog.name = self:GetData("name")
    mLog.orgid = self:GetData("orgid")
    for k,v in pairs(mExtend) do
        mLog.k = v
    end
    return extend.Table.serialize(mLog)
end
