local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"
local router = require "base.router"

local datactrl = import(lualib_path("public.datactrl"))
local mailobj = import(service_path("mail.mailobj"))
local mailmgr = import(service_path("mailmgr"))


function NewMailMgr(...)
    return CMailMgr:New(...)
end

CMailMgr = {}
CMailMgr.__index = CMailMgr
inherit(CMailMgr, mailmgr.CMailMgr)

function CMailMgr:New()
    local o = super(CMailMgr).New(self)
    o.m_mMailCache = {}
    o.m_iMailCache = 0
    return o
end

function CMailMgr:OnLogin(oPlayer,bReEnter)
    oPlayer:GetMailBox():GS2CLoginMail()
end

function CMailMgr:SendMail(pid, name, target, mData, silver, items, summons)
    self:SendMail2(nil, pid, name, target, mData, silver, items, summons)
end

function CMailMgr:SendMail2(oMailBox, pid, name, target, mData, silver, items, summons)
    mData.expert = mData.expert or 7 * 24 * 3600
    local oMail = mailobj.NewMail(0)
    oMail:Create({pid, name}, target, mData)
    if silver and silver > 0 then
        local oNewItem = global.oItemLoader:Create(1002)
        oNewItem:SetData("Value", silver) -- 奖励值
        local oAttach = mailobj.NewAttach(mailobj.ATTACH_ITEM, oNewItem)
        oMail:AddAttach(oAttach)
    end
    if items then
        for _, oItem in ipairs(items) do
            local oAttach = mailobj.NewAttach(mailobj.ATTACH_ITEM, oItem)
            oMail:AddAttach(oAttach)
        end
    end
    if summons then
        for _, oSummon in ipairs(summons) do
            local oAttach = mailobj.NewAttach(mailobj.ATTACH_SUMMON, oSummon)
            oMail:AddAttach(oAttach)
        end
    end

    self:SendMail2GS(target, oMail)
end

function CMailMgr:ClearMailBox(iPid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:NotifyMessage("ks can't clear")
    end
end

--新邮件奖励接口
function CMailMgr:SendMailNew(iSender, sName, iReceiver, mMail, mReward)
    if not mMail then return end

    self:SendMailNew2(nil, iSender, sName, iReceiver, mMail, mReward)
end

function CMailMgr:SendMailNew2(oMailBox, iSender, sName, iReceiver, mMail, mReward)
    mMail.expert = mMail.expert or 7*24*3600
    local oMail = mailobj.NewMail(0)
    oMail:Create({iSender, sName}, iReceiver, mMail)

    for sType, rInfo in pairs(mReward or {}) do
        if mAttachFunc[sType] then
            safe_call(mAttachFunc[sType], oMail, rInfo)
        end
    end

    self:SendMail2GS(iReceiver, oMail)
end

function CMailMgr:SendMail2GS(iPid, oMail)
    local mMail = oMail:Save()
    local sServerKey = global.oWorldMgr:GetServerKey(iPid)
    global.oWorldMgr:LogKSInfo("ks_mail", {pid=iPid, info=mMail})
    baseobj_delay_release(oMail)

    if not sServerKey then
        record.warning(string.format("CMailMgr:SendMail2GS send error %s %s", iPid, oMail:GetData("title")))
        return
    end
    if not global.oServerMgr:IsConnect(sServerKey) then
        record.warning(string.format("CMailMgr:SendMail2GS send error2 %s %s %s", iPid, sServerKey, oMail:GetData("title")))
        self:AddMailCache(iPid, mMail)
        return
    end

    self:_SendMail2GS(iPid, mMail)
end

function CMailMgr:_SendMail2GS(iPid, mMail)
    local sServerKey = global.oWorldMgr:GetServerKey(iPid)
    if not sServerKey then
        record.warning(string.format("CMailMgr:_SendMail2GS send error %s %s", iPid, mMail.title))
        return
    end

    router.Send(sServerKey, ".world", "kuafu_gs", "KS2GSAddMail", {
        pid = iPid,
        mail = mMail, 
    })
end

function CMailMgr:AddMailCache(iPid, mMail)
    self.m_iMailCache = self.m_iMailCache + 1
    self.m_mMailCache[self.m_iMailCache] = {iPid, mMail, get_time()}
    self:CheckMailCache()
end

function CMailMgr:DelMailCache(id)
    self.m_mMailCache[id] = nil
end

function CMailMgr:CheckMailCache()
    local sKey = self:GetTimeCb("_CheckMailCache")
    if sKey then return end

    local lCache = table_key_list(self.m_mMailCache)
    self:DelTimeCb("_CheckMailCache")
    self:AddTimeCb("_CheckMailCache", 15*1000, function ()
        self:_CheckMailCache(lCache, 1)
    end)
end

function CMailMgr:_CheckHeartBeat(lCache, iStart)
    self:DelTimeCb("_CheckMailCache")
    if iIndex > #lCache then
        self:CheckMailCache()
        return
    end
    local iEnd = math.min(100, #lCache)
    for i = iStart, iEnd do
        local iCache = lCache[i]
        local lMailCache = self.m_mMailCache[iCache]
        if lMailCache then
            local iPid = lMailCache[1]
            local mMail = lMailCache[2]
            local sServerKey = global.oWorldMgr:GetServerKey(iPid)
            if not sServerKey then
                self.m_mMailCache[iCache] = nil
            end
            if sServerKey and global.oWorldMgr:IsConnect(sServerKey) then
                self:_SendMail2GS(iPid, mMail)
                self.m_mMailCache[iCache] = nil
            end
        end
    end

    self:AddTimeCb("_CheckMailCache", 1*1000, function ()
        self:_CheckMailCache(lCache, iEnd+1)
    end)
end

function CMailMgr:OpenMail(oPlayer, iMail)
    oPlayer:NotifyMessage("不能操作")
end

function CMailMgr:AcceptMailAttach(oPlayer, iMail)
    oPlayer:NotifyMessage("不能操作")
end

function CMailMgr:AcceptAllMailAttach(oPlayer)
    oPlayer:NotifyMessage("不能操作")
end

function CMailMgr:DeleteMails(oPlayer, lMail)
    oPlayer:NotifyMessage("不能操作")
end

function CMailMgr:DeleteAllMails(oPlayer, iDelCnt)
    oPlayer:NotifyMessage("不能操作")
end

function CMailMgr:AddGSMail(iPid, iMail, mMail)
    if not iPid or not iMail then return end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local oMailBox = oPlayer:GetMailBox()
    local oMail = mailobj.NewMail(iMail)
    oMail:Load(mMail)
    oMailBox:AddMail(oMail, true)
end



