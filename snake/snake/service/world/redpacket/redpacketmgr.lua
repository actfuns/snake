local global= require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"
local net = require "base.net"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local redpacketobj=import(service_path("redpacket.redpacketobj"))
local gamedb = import(lualib_path("public.gamedb"))


local CHANNEL_ORG=101           --帮派频道
local CHANNEL_WORLD = 102   --世界频道
local CHANNEL_CUR = 103 --当前频道
local CASHTYPE_GOLD = 101       --金币类型
local CASHTYPE_SLIVER = 102     --银币类型
local mPlayerSendLimit={[CHANNEL_ORG]=1001,[CHANNEL_WORLD]=1002}    --玩家发红包对应的导标编号
local CHANNEL_LIMIT = 40


local DB_GOLD="g"
local DB_SLIVER="s"
local DB_GOLDCOIN = "gc"
local DB_CNT="cnt"

function NewRedPacketMgr(...)
    return CRedPacketMgr:New(...)
end

function RPSort( obj1,obj2 )
    if obj1:IsFinish() and obj2:IsFinish() then
            return obj1:GetData("createtime")>obj2:GetData("createtime")
        elseif obj1:IsFinish() and not obj2:IsFinish() then
            return false
        elseif not obj1:IsFinish() and obj2:IsFinish() then
            return true
        else
            return obj1:GetData("createtime")>obj2:GetData("createtime")
        end
end

CRedPacketMgr={}
CRedPacketMgr.__index=CRedPacketMgr
CRedPacketMgr.DB_KEY="redpacket"
inherit(CRedPacketMgr,datactrl.CDataCtrl)

function CRedPacketMgr:New()
    local o = super(CRedPacketMgr).New(self)
    o.m_mRedPacket ={}
    o.m_mTempRedPacket = {}
    o.m_mRobHistory = {}
    o.m_mSendHistory = {}
    o.m_mSendBuffer = {}
    o.m_RPID=0   
    return o
end

function CRedPacketMgr:LoadDb()
    if self:IsLoaded() then return end
    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.DB_KEY},
    }
    gamedb.LoadDb("redpacket", "common", "DbOperate", mInfo, function(mRecord,mData)
        if not self:IsLoaded() then
            self:Load(mData.data)
            self:OnLoaded()
        end
    end)
end

function CRedPacketMgr:DispitchRPID()
    self.m_RPID = self.m_RPID+1
    return self.m_RPID
end
-----------存盘-----
function CRedPacketMgr:ConfigSaveFunc()
    self:ApplySave(function ()
        local obj = global.oRedPacketMgr
        if obj then
            obj:_CheckSaveDb()
        else
            record.warning("redpacketmgr save err: no obj")
        end
    end)
end

function CRedPacketMgr:_CheckSaveDb()
    assert(not is_release(self), "redpacketmgr save err: has release")
    assert(self:IsLoaded(), "redpacketmgr save err: is loading")
    self:SaveDb()
end

function CRedPacketMgr:SaveDb()
    if self:IsDirty() then
        local mInfo = {
            module = "globaldb",
            cmd = "SaveGlobal",
            cond = {name = self.DB_KEY},
            data = {data = self:Save()},
        }
        gamedb.SaveDb("redpacket", "common", "DbOperate", mInfo)
        self:UnDirty()
    end
end

function CRedPacketMgr:Load( mData )
    mData = mData or {}
    if mData.redpacket then
        for idx,data in pairs(mData.redpacket) do
            local oRP=redpacketobj.NewRedPacket()
            oRP:Load(data)
            table.insert(self.m_mRedPacket,oRP)
        end
    end
    self.m_mRobHistory = mData.robhistory or {}
    self.m_mSendHistory = mData.sendhistory or {}
    self.m_mSendBuffer = mData.sendbuff or {}
end

function CRedPacketMgr:Save()
    local mData={}
    local lRedPacket={}
    for idx,obj in pairs(self.m_mRedPacket) do 
        table.insert(lRedPacket,obj:Save())
    end
    mData.redpacket=lRedPacket
    mData.robhistory = self.m_mRobHistory
    mData.sendhistory = self.m_mSendHistory
    mData.sendbuff = self.m_mSendBuffer
    return mData
end

function CRedPacketMgr:MergeFrom(mFromData)
    if not mFromData then
        return false ,"redpacket no merge_from_data"
    end
    self:Dirty()
    mFromData = mFromData or {}
    if mFromData.redpacket then
        for idx,data in pairs(mFromData.redpacket) do
            local oRP=redpacketobj.NewRedPacket()
            oRP:Load(data)
            self.m_mRedPacket[oRP.m_ID] = oRP
        end
    end
    if mFromData.robhistory then
        table_combine(self.m_mRobHistory,mFromData.robhistory)
    end
    if mFromData.sendhistory then
        table_combine(self.m_mSendHistory,mFromData.sendhistory)
    end
    if mFromData.sendbuff then
        table_combine(self.m_mSendBuffer,mFromData.sendbuff)
    end
    return true
end

function CRedPacketMgr:GetOrg(orgid)
    local mOrgRP = {}
    for _,obj in pairs(self.m_mRedPacket) do
        if obj:GetData("orgid") == orgid then
            table.insert(mOrgRP,obj)
        end
    end
    return mOrgRP
end

function CRedPacketMgr:GetWorld( )
    local mWorldRP = {}
    for _,obj in pairs(self.m_mRedPacket) do
        if obj:GetData("orgid") == 0 then
            table.insert(mWorldRP,obj)
        end
    end
    return mWorldRP
end

function CRedPacketMgr:GetPlayer(pid)
    local mPlayerRP = {}
    for _,obj in pairs(self.m_mRedPacket) do
        if obj:GetData("owner") == pid then
            table.insert(mPlayerRP,obj)
        end
    end
    return mPlayerRP

end
--[[
    pid
            频道
                            金币   
                            银币
                            数量     
]]
function CRedPacketMgr:AddRobHistory(pid,channel,cashtype,cash)
    assert(cash>0,"RP_rob_his cash")
    if not mPlayerSendLimit[channel] then
        return 
    end
    self:Dirty()
    pid = db_key(pid)
    channel=db_key(channel)
    self.m_mRobHistory[pid] = self.m_mRobHistory[pid] or {}
    self.m_mRobHistory[pid][channel] = self.m_mRobHistory[pid][channel] or {}
    self.m_mRobHistory[pid][channel][DB_GOLD] =self.m_mRobHistory[pid][channel][DB_GOLD] or 0
    self.m_mRobHistory[pid][channel][DB_SLIVER] =self.m_mRobHistory[pid][channel][DB_SLIVER] or 0
    self.m_mRobHistory[pid][channel][DB_CNT] =self.m_mRobHistory[pid][channel][DB_CNT] or 0
    self.m_mRobHistory[pid][channel][DB_CNT] =self.m_mRobHistory[pid][channel][DB_CNT] + 1

    if cashtype == CHANNEL_ORG then     
        self.m_mRobHistory[pid][channel][DB_GOLD] =self.m_mRobHistory[pid][channel][DB_GOLD] + cash
    elseif cashtype == CASHTYPE_SLIVER then
        self.m_mRobHistory[pid][channel][DB_SLIVER] =self.m_mRobHistory[pid][channel][DB_SLIVER] + cash
    end
end
--[[
    pid
            频道
                            元宝   
                            金币
                            银币
                            数量     
]]
function CRedPacketMgr:AddSendHistory(pid,channel,goldcoin,cashtype,cash)
    assert(goldcoin>0,"RP_send_his goldcoin")
    assert(cash>0,"RP_send_his cash")
    self:Dirty()
    pid = db_key(pid)
    channel=db_key(channel)
    self.m_mSendHistory[pid] = self.m_mSendHistory[pid] or {}
    self.m_mSendHistory[pid][channel] = self.m_mSendHistory[pid][channel] or {}
    self.m_mSendHistory[pid][channel][DB_GOLD]=self.m_mSendHistory[pid][channel][DB_GOLD] or 0
    self.m_mSendHistory[pid][channel][DB_SLIVER]=self.m_mSendHistory[pid][channel][DB_SLIVER] or 0
    self.m_mSendHistory[pid][channel][DB_GOLDCOIN]=self.m_mSendHistory[pid][channel][DB_GOLDCOIN] or 0
    self.m_mSendHistory[pid][channel][DB_CNT]=self.m_mSendHistory[pid][channel][DB_CNT] or 0
    self.m_mSendHistory[pid][channel][DB_CNT]=self.m_mSendHistory[pid][channel][DB_CNT] +1
    self.m_mSendHistory[pid][channel][DB_GOLDCOIN] = self.m_mSendHistory[pid][channel][DB_GOLDCOIN] + goldcoin

    if cashtype == CASHTYPE_GOLD then
        self.m_mSendHistory[pid][channel][DB_GOLD] = self.m_mSendHistory[pid][channel][DB_GOLD] + cash
    elseif cashtype == CASHTYPE_SLIVER then
        self.m_mSendHistory[pid][channel][DB_SLIVER] = self.m_mSendHistory[pid][channel][DB_SLIVER] + cash
    end
end

-------------更新接口------------
function CRedPacketMgr:GetRP(id)
    local obj = self.m_mRedPacket[id]
    if obj then
        return obj
    end
    obj = self.m_mTempRedPacket[id]
    if obj then
        return obj
    end
end

function CRedPacketMgr:AddRP(obj)
    local mRes=obj:GetRes()
    if mRes.channel ~= CHANNEL_CUR then
        self:Dirty()
        self.m_mRedPacket[obj.m_ID]=obj
        self:CheckChannelLimit(mRes.channel,obj:GetData("orgid",0))
    else
        self:Dirty()
        self.m_mTempRedPacket[obj.m_ID]=obj
    end
    local mLogData = {}
    mLogData.pid = obj:GetData("owner")
    mLogData.rbinfo = obj:PackLogData()
    record.log_db("redpacket", "sendrb", mLogData)
end

function CRedPacketMgr:ClearAll()
    self:Dirty()
    self.m_mRedPacket={}
    self.m_mRobHistory={}
    self.m_mSendHistory={}
    self.m_mSendBuffer = {}
    self.m_mTempRedPacket = {}
end

function CRedPacketMgr:DelRP( obj )
    if self.m_mRedPacket[obj.m_ID ] then
        self.m_mRedPacket[obj.m_ID]=nil
    end
    if self.m_mTempRedPacket[obj.m_ID] then
        self.m_mTempRedPacket[obj.m_ID] = nil
    end
    local mLogData = {}
    mLogData.pid = obj:GetData("owner")
    mLogData.rbinfo = obj:PackLogData()
    record.log_db("redpacket", "delrb", mLogData)
    baseobj_delay_release(obj)
end

function CRedPacketMgr:DelTempRPByFlag(sFlag)
    local lDel = {}
    for id,obj in pairs(self.m_mTempRedPacket) do
        local mRes = obj:GetRes()
        if mRes.gameplay == sFlag then
            table.insert(lDel,obj)
        end
    end
    for _,obj in ipairs(lDel) do
        self:DelRP(obj)
    end
end

function CRedPacketMgr:DeleteOrgRP(orgid)
    local lDelete={}
        for index,obj in pairs(self.m_mRedPacket) do
            if mRes==orgid then
                table.insert(lDelete,index)
            end
        end
        for _,index in ipairs(lDelete) do
            self:Dirty()
            local obj=self.m_mRedPacket[index]
            self.m_mRedPacket[index]=nil
            if obj then
                baseobj_delay_release(obj)
            end
        end
end

function CRedPacketMgr:CheckChannelLimit(iChannel,orgid)
    local m_RP={}
    if iChannel == CHANNEL_ORG and orgid then
        m_RP = self:GetOrg(orgid)
    elseif iChannel == CHANNEL_WORLD then
        m_RP = self:GetWorld()
    end
    if #m_RP>CHANNEL_LIMIT then
        table.sort(m_RP,RPSort)
        for i=CHANNEL_LIMIT+1,#m_RP do
            self:DelRP(m_RP[i])
        end
    end
end

function CRedPacketMgr:AddRPBuff(pid,iRP)
    local sPid = db_key(pid)
    local mRes =res["daobiao"]["redpacket"]["basic"][iRP]
    if not mRes then
        return
    end
    if mRes.channel ~= CHANNEL_ORG then 
        return
    end
    self:Dirty()
    self.m_mSendBuffer[sPid] = self.m_mSendBuffer[sPid] or {}
    table.insert(self.m_mSendBuffer[sPid],{rp=iRP,createtime = get_time()})
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        local mNet = {index = #self.m_mSendBuffer[sPid],rp = iRP}
        oPlayer:Send("GS2CAddActiveRP",mNet)
    end
end

function CRedPacketMgr:HasRPBuff(pid)
    pid = db_key(pid)
    if not self.m_mSendBuffer[pid] then 
        return false
    end
    if #self.m_mSendBuffer[pid] >0 then
        return true
    else
        return false
    end
end

function CRedPacketMgr:GetRPBuff(pid,iIndex)
    pid = db_key(pid)
    if not self.m_mSendBuffer[pid] then return end
    if not self.m_mSendBuffer[pid][iIndex] then return end
    local iRB = self.m_mSendBuffer[pid][iIndex]["rp"]
    return iRB
end

function CRedPacketMgr:GetRPBuffList(pid)
    pid = db_key(pid)
    local mBuffer = {}
    if not self.m_mSendBuffer[pid] then
        return mBuffer
    end
    if next(self.m_mSendBuffer[pid]) then
        for _,mRP in ipairs(self.m_mSendBuffer[pid]) do
            if next(mRP) then
                table.insert(mBuffer,mRP["rp"])
            end
        end
    end
    return mBuffer
end

function CRedPacketMgr:DelRPBuff(oPlayer,iIndex)
    local pid = oPlayer:GetPid()
    pid = db_key(pid)
    if not self.m_mSendBuffer[pid] then return end
    if not self.m_mSendBuffer[pid][iIndex] then return end
    local iRB = self.m_mSendBuffer[pid][iIndex]["rp"]
    self:Dirty()
    table.remove(self.m_mSendBuffer[pid], iIndex)
    if #self.m_mSendBuffer[pid] <=0 then 
        self.m_mSendBuffer[pid] = nil
    end
    oPlayer:Send("GS2CDelActiveRP",{index = iIndex})
end

---------------红包接口---------
function CRedPacketMgr:SysAddRedPacket(sid,orgid,mArgs)
    mArgs = mArgs or {}
    if orgid then
        local oOrgMgr=global.oOrgMgr
        if not oOrgMgr:GetNormalOrg(orgid) then
            assert(nil,string.format("SysAddRedPacket %s %s ",sid,orgid))
        end
    end
    local obj=redpacketobj.NewRedPacket(sid)
    local mRes=obj:GetRes()
    local mData={}
    mData.sid=sid
    mData.ownername= mRes.ownername or "系统"
    mData.ownericon= mRes.ownershape or 0
    mData.owner=0
    mData.createtime=get_time()
    if mRes.channel == CHANNEL_ORG then
        mData.orgid=orgid
    else
        mData.orgid=0
    end

    local sName = mRes.name
    if mArgs.name_replace then
        sName = global.oToolMgr:FormatColorString(sName, mArgs.name_replace)
    end
    
    local sBless = mRes.bless
    if mArgs.bless_replace then
        sBless = global.oToolMgr:FormatColorString(sBless,mArgs.bless_replace)
    end
    mData.name = sName
    mData.bless= sBless
    mData.count=mRes.count
    mData.channel=mRes.channel
    mData.goldcoin=mRes.goldcoin
    if obj:ValidCreateBySys(mData) then
        obj:CreateBySys(mData)
        self:AddRP(obj)
        self:BroadRB(nil,obj,mData.channel)
        if mRes.text and mRes.text>0 then
            local mChuanwen = res["daobiao"]["chuanwen"][mRes.text]
            local sContent = mChuanwen.content
            local mReplace = mArgs.cw_replace
            sContent = global.oToolMgr:FormatColorString(sContent,mReplace)
            global.oChatMgr:HandleSysChat(sContent, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,mChuanwen.horse_race)
        end
    else
        baseobj_delay_release(obj)
    end
end

function CRedPacketMgr:ActiveSendSysRP(oPlayer,mArgs,bAuto)
    mArgs = mArgs or {}
    local index = mArgs.index or 0
    local iGoldCoin = mArgs.goldcoin or 0
    local iAddAmount = mArgs.amount or 0
    if iAddAmount<=0 then
        iAddAmount = 0
    end

    local pid = oPlayer:GetPid()
    local orgid = oPlayer:GetOrgID()
    local oNotifyMgr = global.oNotifyMgr

    local oHD = global.oHuodongMgr:GetHuodong("orgcampfire")
    if  not bAuto and oHD and oHD.m_iState and oHD.m_iState == gamedefines.ACTIVITY_STATE.STATE_START then
        local sText = res["daobiao"]["redpacket"]["text"][1013]["content"]
        oNotifyMgr:Notify(pid,sText)
        return
    end
    
    if orgid == 0 then 
        local sText = res["daobiao"]["redpacket"]["text"][1019]["content"]
        oNotifyMgr:Notify(pid, sText)
        return 
    end
    local iRP = self:GetRPBuff(pid,index)
    if not iRP then
        oNotifyMgr:Notify(pid,"不存在此红包")
        return
    end
    local mRes =res["daobiao"]["redpacket"]["basic"][iRP]
    if mRes.channel ~= CHANNEL_ORG then 
        record.warning(string.format("ActiveSendSysRP %s %s",pid,iRP))
        return
    end
    if iGoldCoin>0 and not oPlayer:ValidGoldCoin(iGoldCoin,"增加元宝") then
        return
    end

    local orgobj = oPlayer:GetOrg()
    if not orgobj and  mRes.channel == CHANNEL_ORG then
        local sText = res["daobiao"]["redpacket"]["text"][1019]["content"]
        oNotifyMgr:Notify(pid,sText)
        return
    end

    local obj=redpacketobj.NewRedPacket(iRP)
    local mData = {}
    mData.bless = mRes.bless
    if mArgs.bless then
        mData.bless = mArgs.bless
    end
    mData.name = mRes.name
    mData.owner=pid
    mData.ownername=oPlayer:GetName()
    mData.ownericon=oPlayer:GetIcon()
    mData.createtime=get_time()
    mData.isitem=false
    mData.orgid=orgid
    mData.count=mRes.count + iAddAmount
    mData.channel=mRes.channel
    mData.goldcoin=mRes.goldcoin + iGoldCoin
    if obj:ValidCreateBySys(mData) then
        if iGoldCoin>0 then
            oPlayer:ResumeGoldCoin(iGoldCoin,"增加红包元宝")
        end
        self:DelRPBuff(oPlayer,index)
        obj:CreateBySys(mData)
        self:AddRP(obj)
        if iGoldCoin > 0 then
            self:AddSendHistory(pid,mData.channel,iGoldCoin,mRes.cashtype,obj:GetData("cashsum"))
        end
        self:BroadRB(oPlayer,obj,mData.channel)
        if mRes.text and mRes.text>0 then
            local mChuanwen = res["daobiao"]["chuanwen"][mRes.text]
            local sContent = mChuanwen.content
            local mReplace = mArgs.cw_replace
            if mReplace then
                sContent = global.oToolMgr:FormatColorString(sContent,mReplace)
            end
            global.oChatMgr:HandleSysChat(sContent, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG,mChuanwen.horse_race)
        end
    else
        baseobj_delay_release(obj)
    end
end

function CRedPacketMgr:SendRP(oPlayer,mData)
    assert(mPlayerSendLimit[mData.channel],"RP_send type err")
    local oNotifyMgr = global.oNotifyMgr
    local pid = oPlayer:GetPid()
    local sid=mPlayerSendLimit[mData.channel]
    local obj=redpacketobj.NewRedPacket(sid)
    local mRes=obj:GetRes()
    if not mData.bless or mData.bless=="" then
        mData.bless = mRes.bless
    end
    mData.name = mRes.name
    mData.owner=pid
    mData.ownername=oPlayer:GetName()
    mData.ownericon=oPlayer:GetIcon()
    mData.createtime=get_time()
    mData.isitem=false
    
    if mRes.channel == CHANNEL_ORG then
        mData.orgid=oPlayer:GetOrgID()
    else
        mData.orgid=0
    end

    local orgobj = oPlayer:GetOrg()
    if not orgobj and  mRes.channel == CHANNEL_ORG then
        local sText = res["daobiao"]["redpacket"]["text"][1019]["content"]
        oNotifyMgr:Notify(pid,sText)
        return
    end

    if obj:ValidCreate(oPlayer,mData) then
        obj:Create(oPlayer,mData)
        oPlayer:ResumeGoldCoin(mData.goldcoin,"兑换红包")
        self:AddRP(obj)
        self:AddSendHistory(pid,mData.channel,mData.goldcoin,mRes.cashtype,obj:GetData("cashsum"))
        self:BroadRB(oPlayer,obj,mData.channel)
    else
        baseobj_delay_release(obj)
    end
 end

function CRedPacketMgr:RPItem(oPlayer,mData)
    local oNotifyMgr = global.oNotifyMgr
    assert(mPlayerSendLimit[mData.channel],"RP_send type err")
    local oItem=oPlayer:HasItem(mData.itemid)
    if not  oItem then
        oNotifyMgr:Notify(pid,"没有此道具")
        return
    end

    
    local pid=oPlayer:GetPid()
    local sid=mPlayerSendLimit[mData.channel]
    local obj=redpacketobj.NewRedPacket(sid)
    local mRes=obj:GetRes()
    mData.name = oItem:GetData("name","")
    if mData.name=="" then
        mData.name = mRes.name
    end
    mData.bless = mRes.bless
    mData.count=oItem:GetData("count",0)
    mData.owner=pid
    mData.ownericon=oPlayer:GetIcon()
    mData.ownername=oPlayer:GetName()
    mData.createtime=get_time()
    mData.isitem=true
    if mRes.channel == CHANNEL_ORG then
        mData.orgid=oPlayer:GetOrgID()
    else
        mData.orgid=0
    end
    mData.goldcoin=oItem:GetData("goldcoin",0)

    local orgobj = oPlayer:GetOrg()
    if not orgobj and  mRes.channel == CHANNEL_ORG then
        local sText = res["daobiao"]["redpacket"]["text"][1019]["content"]
        oNotifyMgr:Notify(pid,sText)
        return
    end

    if mData.name == "" or mData.count==0 or mData.goldcoin==0 then
        baseobj_delay_release(obj)
        assert(nil,string.format("rpitem err %d %s %d %d ",pid,sRPName,iRPCount,iRPGoldCoin))
    end

    if obj:ValidCreate(oPlayer,mData) then
        obj:Create(oPlayer,mData)
        oPlayer.m_oItemCtrl:RemoveItem(oItem)
        self:AddRP(obj)
        self:AddSendHistory(pid,mData.channel,mData.goldcoin,mRes.cashtype,obj:GetData("cashsum"))
        self:BroadRB(oPlayer,obj,mData.channel)
    else
        baseobj_delay_release(obj)
    end
end

function CRedPacketMgr:BroadRB(oPlayer,obj,iChannel)
    local mNet = self:PackNewRP(obj)
    local oChatMgr = global.oChatMgr

    if iChannel==CHANNEL_ORG then
        interactive.Send(".broadcast", "channel", "SendChannel", {
            message = "GS2CNewRB",
            id = obj:GetData("orgid"),
            type = gamedefines.BROADCAST_TYPE.ORG_TYPE,
            data = mNet,
            exclude = {},
        })
        local sName = obj:GetData("bless") or obj:GetData("name")
        local sMsg = string.format("{link20,%d,%s}", obj.m_ID, sName)
        oChatMgr:SendMsg2Org(sMsg, obj:GetData("orgid"),oPlayer)
    elseif iChannel == CHANNEL_WORLD then
        interactive.Send(".broadcast", "channel", "SendChannel", {
            message = "GS2CNewRB",
            id = 1,
            type = gamedefines.BROADCAST_TYPE.WORLD_TYPE,
            data = mNet,
            exclude = {},
        })
        local sName = obj:GetData("bless") or obj:GetData("name")
        local sMsg = string.format("{link20,%d,%s}", obj.m_ID, sName)
        oChatMgr:SendMsg2World(sMsg,oPlayer)
    elseif iChannel == CHANNEL_CUR then
        local oScene = self:GetCurScene(obj)
        assert(oScene,string.format("no %s rp scene",obj.m_Sid))
        local sName = obj:GetData("bless") or obj:GetData("name")
        local sMsg = string.format("{link20,%d,%s}", obj.m_ID, sName)
        oChatMgr:SendMsg2Scene(oPlayer,oScene,sMsg,gamedefines.CHANNEL_TYPE.CURRENT_TYPE)
        oScene:BroadcastMessage("GS2CNewRB",mNet,{})
    end
end

function CRedPacketMgr:GetCurScene(obj)
    local mRes = obj:GetRes()
    local sGamePlay = mRes.gameplay 
    if sGamePlay == "liumai" then
        local oHD = global.oHuodongMgr:GetHuodong(sGamePlay)
        return oHD:GetScene()
    end
end

function CRedPacketMgr:RobRP(oPlayer, mData)
    local oNotifyMgr = global.oNotifyMgr
    local obj=self:GetRP(mData.id)
    if not obj then
        oNotifyMgr:Notify(oPlayer:GetPid(),"此红包不存在")
        return
    end
    obj:Rob(oPlayer)
end

function CRedPacketMgr:QueryAll(oPlayer, mData)
    if mData.channel ==CHANNEL_ORG then
        local orgid=oPlayer:GetOrgID()
        -- local mOrgRP = self:GetOrg(orgid)
        local mPackage={}
        if orgid and orgid > 0 then
            mPackage.channel = mData.channel
            mPackage.allrp = self:PackageOrgRP(orgid,oPlayer)
            mPackage.activerplist = self:GetRPBuffList(oPlayer:GetPid())
        end
        oPlayer:Send("GS2CAll",mPackage)
    elseif mData.channel == CHANNEL_WORLD then
        local mWorldRP = self:GetWorld()
        local mPackage = {channel = mData.channel}
        if mWorldRP and #mWorldRP>0 then
            mPackage.allrp = self:PackageWorldRP(oPlayer)
        end
        oPlayer:Send("GS2CAll",mPackage)
    end
end

function CRedPacketMgr:QueryBasic(oPlayer, mData)
    local obj = self:GetRP(mData.id)
    if not obj then
        oPlayer:Send("GS2CRemove",{id=mData.id})
        return
    end
    local mPackage = self:PackageRP(obj)
    oPlayer:Send("GS2CBasic",{rpbasicinfo=mPackage})
end

function CRedPacketMgr:QueryHistory(oPlayer, mData )
    local mPackage = self:PackageHistory(oPlayer:GetPid())
    oPlayer:Send("GS2CHistory",mPackage)
end


--------------打包接口----------
function CRedPacketMgr:PackageRP( obj )
    local mPackage = {}
    mPackage.id = obj.m_ID
    mPackage.name = obj:GetData("name")
    mPackage.cashsum = obj:GetData("cashsum")
    mPackage.count = obj:GetData("count")
    mPackage.createtime = obj:GetData("createtime")
    mPackage.ownername = obj:GetData("ownername")
    mPackage.ownericon = obj:GetData("ownericon")
    mPackage.receiveinfo = obj:GetReceive()
    mPackage.bless = obj:GetData("bless")
    return mPackage
end

function CRedPacketMgr:PackNewRP(obj)
    local mPackage = {}
    mPackage.id = obj.m_ID
    mPackage.name = obj:GetData("name")
    mPackage.ownername = obj:GetData("ownername")
    mPackage.valid = 1
    mPackage.finish = 1
    mPackage.se = obj:GetSe()
    mPackage.bless = obj:GetData("bless")
    return {newrb=mPackage}
end

function CRedPacketMgr:PackSubRP(obj,oPlayer)
    local mPackage = {}
    mPackage.id = obj.m_ID
    mPackage.name = obj:GetData("name")
    mPackage.ownername = obj:GetData("ownername")
    mPackage.createtime = obj:GetData("createtime")
    mPackage.se = obj:GetSe()
    mPackage.bless = obj:GetData("bless")
    if obj:ValidRob(oPlayer,false)then
        mPackage.valid = 1
    else
        mPackage.valid = 2
    end
    if obj:IsFinish() then
        mPackage.finish =2
    else
        mPackage.finish=1
    end
    return mPackage
end

function CRedPacketMgr:PackageOrgRP(orgid,oPlayer)
    local mPackage={}
    local mOrgRP = self:GetOrg(orgid)
    for _,obj in ipairs(mOrgRP) do
        if obj:GetData("orgid") == orgid then
            table.insert(mPackage,self:PackSubRP(obj,oPlayer))
        end
    end
    return mPackage
end

function CRedPacketMgr:PackageWorldRP(oPlayer)
    local mPackage={}
    local mWorldRP=self:GetWorld()
    for _,obj in ipairs(mWorldRP) do
        table.insert(mPackage,self:PackSubRP(obj,oPlayer))
    end
    return mPackage
end

function CRedPacketMgr:PackageReceive( obj )
    return obj:GetReceive()
end

function CRedPacketMgr:PackageHistory( pid )
    local mPackage = {}
    local pid = db_key(pid)
    local org_channel=db_key(CHANNEL_ORG)
    local world_channel = db_key(CHANNEL_WORLD)
    if self.m_mRobHistory[pid] then
        local iRobGOld=0
        if self.m_mRobHistory[pid][org_channel] then
            mPackage.rob_org_cnt = self.m_mRobHistory[pid][org_channel][DB_CNT]
            iRobGOld = iRobGOld + self.m_mRobHistory[pid][org_channel][DB_GOLD]
        else
            mPackage.rob_org_cnt=0
        end

        if self.m_mRobHistory[pid][world_channel] then
            mPackage.rob_world_cnt = self.m_mRobHistory[pid][world_channel][DB_CNT]
            iRobGOld = iRobGOld + self.m_mRobHistory[pid][world_channel][DB_GOLD]
        else
            mPackage.rob_world_cnt = 0
        end
        mPackage.rob_gold = iRobGOld
    end
    if self.m_mSendHistory[pid] then
        mPackage.send_org_gold = 0
        mPackage.send_org_goldcoin = 0
        mPackage.send_world_gold = 0
        mPackage.send_world_goldcoin = 0

        if self.m_mSendHistory[pid][org_channel] then
            mPackage.sent_org_cnt = self.m_mSendHistory[pid][org_channel][DB_CNT]
            mPackage.send_org_gold = mPackage.send_org_gold + self.m_mSendHistory[pid][org_channel][DB_GOLD]
            mPackage.send_org_goldcoin = mPackage.send_org_goldcoin + self.m_mSendHistory[pid][org_channel][DB_GOLDCOIN]
        else
            mPackage.sent_org_cnt = 0
        end

        if self.m_mSendHistory[pid][world_channel] then
            mPackage.sent_world_cnt = self.m_mSendHistory[pid][world_channel][DB_CNT]
            mPackage.send_world_gold = mPackage.send_world_gold + self.m_mSendHistory[pid][world_channel][DB_GOLD]
            mPackage.send_world_goldcoin = mPackage.send_world_goldcoin + self.m_mSendHistory[pid][world_channel][DB_GOLDCOIN]
        else
            mPackage.sent_world_cnt = 0
        end
    end
    return mPackage
end

function CRedPacketMgr:StopAutoSendActiveRP()
    self:DelTimeCb("AutoSendActiveRP")
end

function CRedPacketMgr:StartAutoSendActiveRP()
    self:DelTimeCb("AutoSendActiveRP")
    self:AddTimeCb("AutoSendActiveRP", 2*60*1000, function()
        self:AutoSendActiveRP()
    end)
    local mChuanwen = res["daobiao"]["chuanwen"][1060]
    for orgid,orgobj in pairs(global.oOrgMgr:GetNormalOrgs()) do
        global.oChatMgr:SendMsg2Org(mChuanwen.content, orgid)
    end
end

function CRedPacketMgr:AutoSendActiveRP()
    self:DelTimeCb("AutoSendActiveRP")
    self:AddTimeCb("AutoSendActiveRP", 60*1000, function()
        self:AutoSendActiveRP()
    end)
    self:TrueAutoSendActiveRP()
end

function CRedPacketMgr:TrueAutoSendActiveRP()
    for _,orgobj in pairs(global.oOrgMgr:GetNormalOrgs()) do
        local mMember = orgobj:GetOnlineMembers()
        local mXueTu = orgobj:GetOnlineXuetu()
        local mRP = {}
        for pid,oPlayer in pairs(mMember) do
            local sPID = db_key(pid)
            if self.m_mSendBuffer[sPID] then
                for index,mSubRP in ipairs(self.m_mSendBuffer[sPID]) do
                    table.insert(mRP,{pid = pid,createtime = mSubRP["createtime"],rp = index})
                end
            end
        end
        for pid,oPlayer in pairs(mXueTu) do
            local sPID = db_key(pid)
            if self.m_mSendBuffer[sPID] then
                for index,mSubRP in ipairs(self.m_mSendBuffer[sPID]) do
                    table.insert(mRP,{pid = pid,createtime = mSubRP["createtime"],rp = index})
                end
            end
        end
        if not next(mRP) then
            goto continue 
        end
        table.sort( mRP,function (mInfo1,mInfo2)
            return mInfo1.createtime>mInfo2.createtime
        end)
        for _,mTarget in ipairs(mRP) do
            local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(mTarget.pid)
            if oTarget then
                local mArgs = {}
                mArgs.index = mTarget.rp
                self:ActiveSendSysRP(oTarget,mArgs,true)
            end
        end
        ::continue::
    end
end

-------------测试----------------
function CRedPacketMgr:TestOP(oPlayer,iFlag,arg)
    arg=arg or {}
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr=global.oChatMgr
    local pid = oPlayer:GetPid()
    local mCommand={
        "100 指令查看",
        "101 查看所有红包\nredpacket 101",
        "102 查看世界频道红包",
        "103 查看指定帮派频道红包",
        "104 查看指定玩家所有红包",
        "105 触发一次发放手动红包\nredpacket 105",
        "106 开始自动发放手动红包\nredpacket 106",
        "107 停止自动发放手动红包\nredpacket 107",
        "201 玩家生成红包\nredpacket 201 {count=10,goldcoin=100,channel=102}",
        "202 发放指定的系统红包\nredpacket 202 {id = 1003}",
        "205 删除所有红包\nredpacket 205",
        "301 增加主动帮派红包\nredpacket 301 {index = 1003}",


        --robot　测试指令
        --C2GSQueryBasic {id=1}
        --C2GSQueryAll {channel=101}
        --C2GSQueryHistory {}
        --C2GSRobRP {id=2}
        --C2GSSendRP {name="testname",goldcoin=900,count=9,channel=101}
    }

    if iFlag==100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
    elseif iFlag ==101 then
        local iLen=#self.m_mRedPacket
        oChatMgr:HandleMsgChat(oPlayer,string.format("总个数=%s",iLen))
        for id,oRP in pairs(self.m_mRedPacket) do
            local sText=string.format("%s=%s",id,extend.Table.serialize(oRP:Save()))
            oChatMgr:HandleMsgChat(oPlayer,sText)
        end
    elseif iFlag == 102 then
        local mWorld = self:GetWorld()
        local iLen = #mWorld
        oChatMgr:HandleMsgChat(oPlayer,string.format("世界频道总个数=%s",iLen))
        for id,oRP in pairs(mWorld) do
            local sText=string.format("%s=%s",id,extend.Table.serialize(oRP:Save()))
            oChatMgr:HandleMsgChat(oPlayer,sText)
        end
    elseif iFlag == 103 then
        local mOrg = self:GetOrg(arg.id)
        local iLen = #mOrg
        oChatMgr:HandleMsgChat(oPlayer,string.format("帮派%s总个数=%s",arg.id,iLen))
         for id,oRP in pairs(mOrg) do
            local sText=string.format("%s=%s",id,extend.Table.serialize(oRP:Save()))
            oChatMgr:HandleMsgChat(oPlayer,sText)
        end       
    elseif iFlag == 104 then
        local mPlayer = self:GetPlayer()
        local iLen = #mPlayer
        oChatMgr:HandleMsgChat(oPlayer,string.format("玩家%s总个数=%s",arg.id,iLen))
        for id,oRP in pairs(mPlayer) do
            local sText = string.format("%s=%s",id,extend.Table.serialize(oRP:Save()))
            oChatMgr:HandleMsgChat(oPlayer,sText)
        end
    elseif iFlag == 105 then
        self:TrueAutoSendActiveRP()
    elseif iFlag == 106 then
        self:StartAutoSendActiveRP()
    elseif iFlag == 107 then
        self:StopAutoSendActiveRP()
    elseif iFlag == 201 then
        self:SendRP(oPlayer,arg)
        oNotifyMgr:Notify(oPlayer:GetPid(),"添加成功")
    elseif iFlag == 202 then
        self:SysAddRedPacket(arg.id,oPlayer:GetOrgID())
    elseif iFlag==203 then
        self:RobRP(oPlayer,arg)
    elseif iFlag ==205 then
        self:ClearAll()
        oNotifyMgr:Notify(oPlayer:GetPid(),"全部清除成功")
    elseif iFlag==207 then
        local sItem="10016{name=test,count=10,goldcoin=100}"
        local oItem=global.oItemLoader:ExtCreate(sItem)
        oPlayer:RewardItem(oItem, "test")
    elseif iFlag == 301 then
        local iIndex = arg.index or 1003
        self:AddRPBuff(oPlayer:GetPid(),iIndex) 
    elseif iFlag == 302 then
        local mArgs = {}
        mArgs.index = 1
        self:ActiveSendSysRP(oPlayer,mArgs)
    elseif iFlag == 303 then
        global.oRedPacketMgr:AddRPBuff(pid,2010) 
    end
    oNotifyMgr:Notify(oPlayer:GetPid(),"执行完毕")
end
