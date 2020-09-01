--import module
local global = require "global"
local extend = require "base.extend"
local record = require "public.record"

local datactrl = import(lualib_path("public.datactrl"))
local loadsummon = import(service_path("summon.loadsummon"))

ATTACH_ITEM = 1
ATTACH_SILVER = 2
ATTACH_SUMMON = 3

function NewMail(...)
    return CMail:New(...)
end

function CheckMailExpire(iPid, iMid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oMailBox = oWorldMgr:GetMailBox(iPid)
    if not oMailBox then return end

    local oMail = oMailBox:GetMail(iMid)
    if not oMail then return end

    oMailBox:GS2CDelMail({iMid})
    oMailBox:DelMail(iMid)
end

CMail = {}
CMail.__index = CMail
inherit(CMail,datactrl.CDataCtrl)

function CMail:New(iMid)
    local o = super(CMail).New(self)
    o.m_iID = iMid
    o.m_lAttachs = {}
    o.m_lRecAttachs = {}
    return o
end

function CMail:Release()
    for _, oAttach in ipairs(self.m_lAttachs) do
        baseobj_safe_release(oAttach)
    end
    self.m_lAttachs = {}
    self.m_lRecAttachs = {}
    super(CMail).Release(self)
end

function CMail:Create(senderinfo, recieverid, mData)
    self:SetData("senderinfo", senderinfo)
    self:SetData("recieverid", recieverid)
    self:SetData("createtime", mData.createtime or get_time())
    self:SetData("title", mData.title)
    self:SetData("context", mData.context)
    self:SetData("keeptime", mData.keeptime or 7*24*3600)
    self:SetData("readtodel", mData.readtodel or 0)
    self:SetData("autoextract", mData.autoextract or 1)
    self:SetData("type", mData.type or 101)
    self:SetData("icon", mData.icon)
    self:SetData("openicon", mData.openicon)
    self:SetData("audio", mData.audio)
    self:SetData("opened", 0)
    self:SetData("recieved", 0)
end

function CMail:Load(mData)
    mData = mData or {}
    self:SetData("senderinfo", mData.senderinfo)
    self:SetData("recieverid", mData.recieverid)
    self:SetData("createtime", mData.createtime)
    self:SetData("keeptime", mData.keeptime)
    self:SetData("title", mData.title)
    self:SetData("context", mData.context)
    self:SetData("readtodel", mData.readtodel)
    self:SetData("autoextract", mData.autoextract)
    self:SetData("type", mData.type or 101)
    self:SetData("icon", mData.icon)
    self:SetData("openicon", mData.openicon)
    self:SetData("opened",  mData.opened)
    self:SetData("recieved",  mData.recieved)
    self:SetData("audio", mData.audio)
    self.m_lRecAttachs = mData.recattachs or {}

    for _, info in ipairs(mData.attachs) do
        local oAttach = NewAttach()
        oAttach:Load(info)
        table.insert(self.m_lAttachs, oAttach)
    end
end

function CMail:Save()
    local mData = {}
    mData.senderinfo = self:GetData("senderinfo")
    mData.recieverid = self:GetData("recieverid")
    mData.createtime = self:GetData("createtime")
    mData.keeptime = self:GetData("keeptime")
    mData.title = self:GetData("title")
    mData.context = self:GetData("context")
    mData.readtodel = self:GetData("readtodel")
    mData.autoextract = self:GetData("autoextract")
    mData.type = self:GetData("type")
    mData.icon = self:GetData("icon")
    mData.openicon = self:GetData("openicon")
    mData.opened = self:GetData("opened")
    mData.recieved = self:GetData("recieved")
    mData.audio = self:GetData("audio")

    local lAttachs = {}
    local lRecAttachs = {}
    for _, oAttach in ipairs(self.m_lAttachs) do
        table.insert(lAttachs, oAttach:Save())
    end
    mData.attachs = lAttachs
    mData.recattachs = self.m_lRecAttachs
    return mData
end

function CMail:UnDirty()
    super(CMail).UnDirty(self)
    for _, oAttach in ipairs(self.m_lAttachs) do
        if oAttach:IsDirty() then
            oAttach:UnDirty()
        end
    end
end

function CMail:IsDirty()
    local bDirty = super(CMail).IsDirty(self)
    if bDirty then
        return true
    end
    for _, oAttach in ipairs(self.m_lAttachs) do
        if oAttach:IsDirty() then
            return true
        end
    end
    return false
end

function CMail:Schedule()
    self:CheckTimeCb()
end

function CMail:CheckTimeCb()
    self:DelTimeCb("_CheckExpire")
    local iLeftTime = self:ValidTime() - get_time()
    -- if iLeftTime < 0 then return end

    local iLeftTime = math.max(1, iLeftTime)
    if iLeftTime > 1 * 24 * 3600 then return end
    
    local iMailId = self.m_iID
    local iPid = self:GetData("recieverid")
    local f = function ()
        CheckMailExpire(iPid, iMailId)
    end
    self:AddTimeCb("_CheckExpire", iLeftTime * 1000, f)
end

function CMail:ValidTime()
    return self:GetData("createtime") + self:GetData("keeptime")
end

function CMail:Validate()
    return self:ValidTime() >= get_time()
end

function CMail:ReadToDel()
    return self:GetData("readtodel") == 1
end

function CMail:AutoExtract()
    return self:GetData("autoextract") == 1
end

function CMail:Open()
    if not self:HasAttach() then
        self:SetData("opened", 1)
    end
end

function CMail:Opened()
    return self:GetData("opened", 0) == 1
end

function CMail:AddVirtualItem(iVirtualSID, iValue)
    if iValue <= 0 then return end

    local oItem = global.oItemLoader:Create(iVirtualSID)
    if not oItem then return end

    oItem:SetData("Value", iValue)
    local oAttach = NewAttach(ATTACH_ITEM, oItem)
    self:AddAttach(oAttach)
end

function CMail:AddAttach(oAttach)
    self:Dirty()
    table.insert(self.m_lAttachs, oAttach)
end

function CMail:HasAttach()
    return next(self.m_lAttachs)
end

function CMail:NeedBagSpace()
    local iSpace = 0
    for _, oAttach in ipairs(self.m_lAttachs) do
        iSpace = iSpace + oAttach:NeedBagSpace()
    end
    return iSpace
end

function CMail:NeedSummonSpace()
    local iSpace = 0
    for _, oAttach in ipairs(self.m_lAttachs) do
        iSpace = iSpace + oAttach:NeedSummonSpace()
    end
    return iSpace
end

function CMail:ValidAttach(oPlayer, mArgs)
    mArgs = mArgs or {}
    local iBagSpace, iSummonSpace = 0, 0
    for _, oAttach in ipairs(self.m_lAttachs) do
        if oAttach:GetData("type") == ATTACH_ITEM then
            local oItem = oAttach:GetData("attach")
            if oItem.m_ItemType == "virtual" then
                if not oItem:ValidReward(oPlayer, mArgs) then
                    return false 
                end
            else
                iBagSpace = iBagSpace + oAttach:NeedBagSpace()
            end
        elseif oAttach:GetData("type") == ATTACH_SUMMON then
            iSummonSpace = iSummonSpace + oAttach:NeedSummonSpace()
        end
    end
    if oPlayer.m_oItemCtrl:GetCanUseSpaceSize() < iBagSpace then
        if not mArgs.cancel_tip then
            oPlayer:NotifyMessage(global.oToolMgr:GetTextData(1002))
        end
        return false
    end
    if oPlayer.m_oSummonCtrl:EmptySpaceCnt() < iSummonSpace then
        if not mArgs.cancel_tip then
            oPlayer:NotifyMessage(global.oToolMgr:GetTextData(1003))
        end
        return false
    end
    return true
end

function CMail:RecieveAttach(oPlayer)
    if not self:Validate() then
        return false
    end
    if not self:HasAttach() then
        return false
    end
    if not self:ValidAttach(oPlayer, {cancel_tip=true}) then
        return false
    end

    self:Dirty()
    local attachs = self.m_lAttachs

    local mLog = oPlayer:LogData()
    mLog = table_combine(mLog, self:LogInfo())
    record.log_db("mail", "rec_mail", mLog)

    self.m_lAttachs = {}
    self.m_lRecAttachs = {}
    for _, oAttach in ipairs(attachs) do
        table.insert(self.m_lRecAttachs, oAttach:PackInfo())
        oAttach:Recieve(oPlayer)
    end
    self:SetData("recieved", 1)
    self:Open()
    return true
end

function CMail:GetRecieveStatus()
    local hasattach = 0
    if self:GetData("recieved", 0) == 1 then
        hasattach = 2
    elseif self:HasAttach() then
        hasattach = 1
    end
    return hasattach
end

function CMail:PackSimpleInfo()
    local hasattach = self:GetRecieveStatus()
    local mNet = {
        mailid = self.m_iID,
        title = self:GetData("title"),
        validtime = self:ValidTime(),
        hasattach = hasattach,
        opened = self:GetData("opened"),
        readtodel = self:GetData("readtodel"),
        createtime = self:GetData("createtime"),
        mailtype = self:GetData("type"),
        icon = self:GetData("icon"),
        openicon = self:GetData("openicon"),
        audio = self:GetData("audio"),
    }
    return mNet
end

function CMail:PackInfo()
    -- 注意兼容self.m_lRecAttachs
    local hasattach = self:GetRecieveStatus()
    local lAttachs = {}
    if hasattach == 2 then
        lAttachs = self.m_lRecAttachs
    else
        for _, oAttach in ipairs(self.m_lAttachs) do
            table.insert(lAttachs, oAttach:PackInfo())
        end
    end

    local pid, name = table.unpack(self:GetData("senderinfo") or {})
    local mNet = {
        mailid = self.m_iID,
        title = self:GetData("title"),
        context = self:GetData("context"),
        createtime = self:GetData("createtime"),
        validtime = self:ValidTime(),
        pid = pid,
        name = name,
        opened = self:GetData("opened"),
        hasattach = hasattach,
        attachs = lAttachs,
    }
    return mNet
end

function CMail:LogInfo()
    local mData = {}
    mData["mail_title"] = self:GetData("title")
    mData["mail_time"] = self:GetData("createtime")
    local lAttachs  = {}
    for _, oAtt in pairs(self.m_lAttachs) do
        table.insert(lAttachs, oAtt:Save())
    end
    mData["attach"] = lAttachs
    return mData
end


function NewAttach(...)
    return CAttach:New(...)
end

CAttach = {}
CAttach.__index = CAttach
inherit(CAttach,datactrl.CDataCtrl)

function CAttach:New(iType, ...)
    local o = super(CAttach).New(self)
    o:Init(iType, ...)
    return o
end

function CAttach:Release()
    if self:GetData("type") == ATTACH_ITEM then
        local oItem = self:GetData("attach")
        baseobj_safe_release(oItem)
    elseif self:GetData("type") == ATTACH_SUMMON then
        local oSummon = self:GetData("attach")
        baseobj_safe_release(oSummon)
    end
    super(CAttach).Release(self)
end

function CAttach:Init(iType, rAttach)
    self:SetData("type", iType)
    self:SetData("attach", rAttach)
end

function CAttach:Load(mData)
    mData = mData or {}
    self:SetData("type", mData.type)
    if self:GetData("type") == ATTACH_ITEM then
        local attach = mData.attach
        local oItem = global.oItemLoader:LoadItem(attach["sid"],attach)
        self:SetData("attach", oItem)
    elseif self:GetData("type") == ATTACH_SUMMON then
        local attach = mData.attach
        local oSummon = loadsummon.LoadSummon(attach["sid"],attach)
        self:SetData("attach", oSummon)
    else
        self:SetData("attach", mData.attach)
    end
end

function CAttach:Save()
    local mData = {}
    mData.type = self:GetData("type")
    if self:GetData("type") == ATTACH_ITEM then
        local oItem = self:GetData("attach")
        mData.attach = oItem:Save()
    elseif self:GetData("type") == ATTACH_SUMMON then
        local oSummon = self:GetData("attach")
        mData.attach = oSummon:Save()
    else
        mData.attach = self:GetData("attach")
    end
    return mData
end

function CAttach:NeedBagSpace()
    local iSpace = 0
    if self:GetData("type") == ATTACH_ITEM then
        local oItem = self:GetData("attach")
        if oItem.m_ItemType ~= "virtual" then
            iSpace = iSpace + math.floor(oItem:GetAmount() / math.max(1, oItem:GetMaxAmount()))
            if oItem:GetAmount() % oItem:GetMaxAmount() ~= 0 then
                iSpace = iSpace + 1
            end
        end
    end
    return iSpace
end

function CAttach:NeedSummonSpace()
    if self:GetData("type") == ATTACH_SUMMON then
        return 1
    else
        return 0
    end
end

function CAttach:Recieve(who)
    local iType = self:GetData("type")
    if iType == ATTACH_ITEM then
        local oItem = self:GetData("attach")
        self:SetData("attach", nil)
        if oItem.m_ItemType ~= "virtual" and oItem:GetAmount() > oItem:GetMaxAmount() then
            local iMax = math.max(1, oItem:GetMaxAmount())
            local iNum = math.floor(oItem:GetAmount() / math.max(1, oItem:GetMaxAmount()))
            local iLeft = oItem:GetAmount() % iMax
            for i=1,iNum do
                local oNewItem = global.oItemLoader:LoadItem(oItem:SID(), oItem:Save())
                oNewItem:SetAmount(iMax)
                who:RewardItem(oNewItem, "邮件附件")
            end
            if iLeft > 0 then
                local oNewItem = global.oItemLoader:LoadItem(oItem:SID(), oItem:Save())
                oNewItem:SetAmount(iLeft)
                who:RewardItem(oNewItem, "邮件附件")
            end
        else
            who:RewardItem(oItem, "邮件附件")
        end
    elseif iType == ATTACH_SUMMON then
        local oSummon = self:GetData("attach")
        self:SetData("attach", nil)
        who.m_oSummonCtrl:AddSummon(oSummon, "邮件附件")
    elseif iType == ATTACH_SILVER then
        local iVal = self:GetData("attach")
        if iVal > 0 then
            who:RewardSilver(iVal, "邮件附件")
        end
    end
end

function CAttach:PackInfo()
    local sid = 0
    local val = 0
    local iType = self:GetData("type")
    if iType == ATTACH_ITEM then
        local oItem = self:GetData("attach")
        if oItem then
            sid = oItem:SID()
            if oItem:ItemType() == "virtual" and not oItem:RealObj() then
                val = oItem:GetData("Value", 1)
            else
                val = oItem:GetAmount()
            end
        end
    elseif iType == ATTACH_SUMMON then
        local oSummon = self:GetData("attach")
        if oSummon then
            sid = oSummon:TypeID()
            val = 1
        end
    elseif iType == ATTACH_SILVER then
        sid = 0
        val = self:GetData("attach")
    end
    local mNet = {
        type = self:GetData("type"),
        sid = sid,
        val = val,
    }
    return mNet
end
