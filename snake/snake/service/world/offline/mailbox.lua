local skynet = require "skynet"
local global = require "global"
local extend = require "base.extend"
local record = require "public.record"

local CBaseOfflineCtrl = import(service_path("offline.baseofflinectrl")).CBaseOfflineCtrl
local mailobj = import(service_path("mail.mailobj"))


DISPLAYCNT = 100
BOX_MAX_CNT = 500

CMailBox = {}
CMailBox.__index = CMailBox
inherit(CMailBox, CBaseOfflineCtrl)

function CMailBox:New(pid)
    local o = super(CMailBox).New(self, pid)
    o.m_sDbFlag = "MailBox"
    o.m_lMails = {}
    o.m_mMailIDs = {}
    o:SetData("sysversion", 0)
    o.m_iDispitchMailID = 0
    return o
end

function CMailBox:DispitchMailID()
    self.m_iDispitchMailID = self.m_iDispitchMailID + 1
    return self.m_iDispitchMailID
end

function CMailBox:Release()
    for _, oMail in ipairs(self.m_lMails) do
        baseobj_safe_release(oMail)
    end
    self.m_lMails = {}
    self.m_mMailIDs = {}
    super(CMailBox).Release(self)
end

function CMailBox:Load(mData)
    mData = mData or {}
    self:SetData("sysversion", mData.sysversion or 0)
    if mData.mails then
        for _, info in ipairs(mData.mails) do
            local oMail = mailobj.NewMail(self:DispitchMailID())
            oMail:Load(info)
            if oMail:Validate() then
                table.insert(self.m_lMails, oMail)
                self.m_mMailIDs[oMail.m_iID] = oMail
                oMail:Schedule()
            else
                baseobj_delay_release(oMail)       
            end
        end
    end
end

function CMailBox:Save()
    local mData = {}
    local lMails = {}
    for _, oMail in ipairs(self.m_lMails) do
        table.insert(lMails, oMail:Save())
    end
    mData.mails = lMails
    mData.sysversion = self:GetData("sysversion")
    return mData
end

function CMailBox:UnDirty()
    super(CMailBox).UnDirty(self)
    for _, oMail in ipairs(self.m_lMails) do
        if oMail:IsDirty() then
            oMail:UnDirty()
        end
    end
end

function CMailBox:IsDirty()
    local bDirty = super(CMailBox).IsDirty(self)
    if bDirty then
        return true
    end
    for _, oMail in ipairs(self.m_lMails) do
        if oMail:IsDirty() then
            return true
        end
    end
    return false
end

function CMailBox:AddMail(oMail, bSort)
    if self:IsFullCnt() then return end

    self:Dirty()
    local iFullDis = false
    if self:IsFullDisplay() then
        iFullDis = true
    end
    local iPos

    if bSort then
        for iTmpPos, oTmpMail in ipairs(self.m_lMails) do
            if oTmpMail:GetData("createtime") > oMail:GetData("createtime") then
                iPos = iTmpPos
                break
            end
        end
    end    

    if iPos then
        table.insert(self.m_lMails, iPos, oMail)
    else
        table.insert(self.m_lMails, oMail)
    end
    self.m_mMailIDs[oMail.m_iID] = oMail
    oMail:Schedule()

    if not iFullDis then
        self:GS2CAddMail(oMail)
    end

    if is_gs_server() then
        local mLog = oMail:LogInfo()
        mLog["pid"] = self:GetInfo("pid")
        record.log_db("mail", "add_mail", mLog)

        global.oMailMgr:PushMail2KS(self:GetInfo("pid"), oMail)     
    end
end

function CMailBox:GetMail(id)
    return self.m_mMailIDs[id]
end

function CMailBox:DelMail(id)
    local oMail = self:GetMail(id)
    if not oMail then return end

    self:Dirty()
    extend.Array.remove(self.m_lMails, oMail)
    self.m_mMailIDs[oMail.m_iID] = nil

    local mLog = {}
    mLog["pid"] = self:GetInfo("pid")
    mLog["mail_title"] = oMail:GetData("title")
    mLog["mail_time"] = oMail:GetData("createtime")
    record.log_db("mail", "del_mail", mLog)
    baseobj_delay_release(oMail)

    if self:IsFullDisplay() then
        local oNewMail = self.m_lMails[DISPLAYCNT]
        if oNewMail then
            self:GS2CAddMail(oNewMail)
        end
    end
end

function CMailBox:ClearMail()
    self.m_lMails = {}
    self.m_mMailIDs = {}
    self:Dirty()
end

function CMailBox:GetAllShowMailIDs()
    local lInfo = {}
    local iCnt = 0
    for _, oMail in ipairs(self.m_lMails) do
        if iCnt >= DISPLAYCNT then
            break
        end
        iCnt = iCnt + 1
        table.insert(lInfo, oMail.m_iID)
    end
    return lInfo
end

function CMailBox:GetSysVersion()
    return self:GetData("sysversion")
end

function CMailBox:SetSysVersion(iVer)
    self:SetData("sysversion", iVer)
end

function CMailBox:IsFullCnt()
    return #self.m_lMails >= BOX_MAX_CNT
end

function CMailBox:IsFullDisplay()
    return #self.m_lMails >= DISPLAYCNT
end

function CMailBox:CheckTimeCb()
    for _,oMail in pairs(self.m_lMails) do
        oMail:CheckTimeCb()
    end
end

function CMailBox:GS2CLoginMail()
    local pid = self:GetInfo("pid")
    if not pid or pid == 0 then
        return
    end
    local lInfo = {}
    local iCnt = 0
    for _, oMail in ipairs(self.m_lMails) do
        -- 最多发给客户端DISPLAYCNT封邮件
        if iCnt >= DISPLAYCNT then
            break
        end
        iCnt = iCnt + 1
        table.insert(lInfo, oMail:PackSimpleInfo())
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CLoginMail", {simpleinfo=lInfo})
    end
end

function CMailBox:GS2CAddMail(oMail)
    local pid = self:GetInfo("pid")
    if not pid or pid == 0 then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CAddMail", {simpleinfo = oMail:PackSimpleInfo()})
    end
end

function CMailBox:GS2CDelMail(mailids)
    local pid = self:GetInfo("pid")
    if not pid or pid == 0 then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if oPlayer then
        oPlayer:Send("GS2CDelMail", {mailids = mailids})
    end
end
