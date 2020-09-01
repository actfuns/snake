local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"
local router = require "base.router"

local datactrl = import(lualib_path("public.datactrl"))
local mailobj = import(service_path("mail.mailobj"))
local loadsummon = import(service_path("summon.loadsummon"))

mAttachFunc = {}
mAttachFunc.gold = function(oMail, iGold)
    oMail:AddVirtualItem(1001, iGold)
end

mAttachFunc.silver = function(oMail, iSilver)
    oMail:AddVirtualItem(1002, iSilver)
end

mAttachFunc.goldcoin = function(oMail, iGoldCoin)
    oMail:AddVirtualItem(1004, iGoldCoin)
end

mAttachFunc.exp = function(oMail, iExp)
    oMail:AddVirtualItem(1005, iExp)
end

mAttachFunc.summexp = function(oMail, iSummExp)
    oMail:AddVirtualItem(1007, iSummExp)
end

mAttachFunc.org_offer = function(oMail, iOrgOffer)
    oMail:AddVirtualItem(1008, iOrgOffer)
end

mAttachFunc.wuxun = function(oMail, iWuXun)
    oMail:AddVirtualItem(1013, iWuXun)
end

mAttachFunc.jjcpoint = function(oMail, iJJCPoint)
    oMail:AddVirtualItem(1014, iJJCPoint)
end

mAttachFunc.summsid = function(oMail, mSummon)
    if not mSummon then return end

    local iSummSid, iSummFixed = table.unpack(mSummon)
    if not iSummSid or iSummSid <= 0 then return end

    local oSummon = nil
    if iSummFixed and iSummFixed > 0 then
        oSummon = loadsummon.CreateFixedPropSummon(iSummSid, iSummFixed)
    else
        oSummon = loadsummon.CreateSummon(iSummSid, 0)
    end

    local oAttach = mailobj.NewAttach(mailobj.ATTACH_SUMMON, oSummon)
    oMail:AddAttach(oAttach)
end

mAttachFunc.summons = function(oMail, lSummons)
    for _, oSummon in ipairs(lSummons) do
        local oAttach = mailobj.NewAttach(mailobj.ATTACH_SUMMON, oSummon)
        oMail:AddAttach(oAttach)
    end
end

mAttachFunc.items = function(oMail, lItems)
    for _, oItem in ipairs(lItems) do
        local oAttach = mailobj.NewAttach(mailobj.ATTACH_ITEM, oItem)
        oMail:AddAttach(oAttach)
    end
end


function NewMailMgr(...)
    return CMailMgr:New(...)
end

CMailMgr = {}
CMailMgr.__index = CMailMgr
inherit(CMailMgr,logic_base_cls())

function CMailMgr:New()
    local o = super(CMailMgr).New(self)
    return o
end

function CMailMgr:OnLogin(oPlayer,bReEnter)
    local oSysMailCache = global.oWorldMgr.m_oSysMailCache
    oSysMailCache:LoginCheckSysMail(oPlayer)
    oPlayer:GetMailBox():GS2CLoginMail()
end

function CMailMgr:SendMailReward(oPlayer, iMailId, iRewardId, sRewardGroup, mArgs)
    local mRewardContent
    if iRewardId and iRewardId > 0 and sRewardGroup then
        mRewardContent = global.oRewardMgr:PackRewardContentByGroup(oPlayer, sRewardGroup, iRewardId, mArgs)
    end
    self:SendMailRewardContent(oPlayer, iMailId, mRewardContent)
end

function CMailMgr:SendMailRewardContent(oPlayer, iMailId, mRewardContent)
    local mMailInfo, sSenderName = self:GetMailInfo(iMailId)
    if not mMailInfo then
        return
    end
    -- 邮件发物品需先创建
    local lItems = {}
    local iSilver = 0

    local mReward = {}
    if mRewardContent then
        for itemidx, mItems in pairs(mRewardContent.items or {}) do
            lItems = list_combine(lItems, mItems.items)
        end

        if mRewardContent.silver and mRewardContent.silver > 0 then
            mReward.silver = mRewardContent.silver
        end
        if mRewardContent.exp and mRewardContent.exp > 0 then
            mReward.exp = mRewardContent.exp
        end
        -- if mRewardContent.summexp and mRewardContent.summexp > 0 then
        --     mReward.summexp = mRewardContent.summexp
        -- end
        if mRewardContent.gold and mRewardContent.gold > 0 then
            mReward.gold = mRewardContent.gold
        end
        if mRewardContent.goldcoin and mRewardContent.goldcoin > 0 then
            mReward.goldcoin = mRewardContent.goldcoin
        end
        if mRewardContent.org_offer and mRewardContent.org_offer > 0 then
            mReward.org_offer = mRewardContent.org_offer
        end
        if mRewardContent.summsid and table_count(mRewardContent.summsid) > 0 then
            mReward.summsid = mRewardContent.summsid
        end
        local mSumms = mRewardContent.summons
        if mSumms and next(mSumms) then
            mReward.summons = {}
            for _, mSumm in pairs(mSumms) do
                table.insert(mReward.summons, mSumm.summ)
            end
        end
    end
    self:SendMailNew(0, sSenderName, oPlayer:GetPid(), mMailInfo, mReward)
end

function CMailMgr:OnUpGrade(oPlayer, iFromGrade, iToGrade)
    local mGradeMailInfo = table_get_depth(res, {"daobiao", "grade_mail"})
    if not mGradeMailInfo then
        return
    end

    local mMailed = oPlayer:Query("mailed_upgrade") or {}
    local bChanged
    for iId, mInfo in pairs(mGradeMailInfo) do
        local iGrade = mInfo.grade
        if iToGrade >= iGrade and iFromGrade < iGrade then
            if not mMailed[iId] then
                local iMailId = mInfo.mail
                local iRewardId = mInfo.reward_id
                mMailed[iId] = iMailId
                bChanged = true
                self:SendMailReward(oPlayer, iMailId, iRewardId, "mail")
            end
        end
    end
    if bChanged then
        oPlayer:Set("mailed_upgrade", mMailed)
     end
end

function CMailMgr:GetMailInfo(iIdx)
    local mInfo = res["daobiao"]["mail"][iIdx]
    assert(mInfo, "mail config nil, mailIdx:" .. iIdx)
    local mData = {
        title = mInfo.subject,
        context = mInfo.content,
        keeptime = mInfo.keepday * 3600 * 24,
        readtodel = mInfo.readtodel,
        autoextract = mInfo.autoextract,
        type = mInfo.type,
        icon = mInfo.icon,
        openicon = mInfo.openicon,
        audio = mInfo.audio,
    }
    return mData, mInfo.name
end

function CMailMgr:SendAllSysMail(mData)
    local oWorldMgr = global.oWorldMgr
    local oSysMailCache = oWorldMgr.m_oSysMailCache
    oSysMailCache:AddSysMail(mData)
    oSysMailCache:CheckOnlinePlayerMail()
    -- for pid, oPlayer in pairs(oWorldMgr:GetOnlinePlayerList()) do
    --     oSysMailCache:LoginCheckSysMail(oPlayer)
    -- end
end

function CMailMgr:SendMail(pid, name, target, mData, silver, items, summons)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadMailBox(target, function (oMailBox)
        if oMailBox then
            self:SendMail2(oMailBox, pid, name, target, mData, silver, items, summons)
        end
    end)
end

function CMailMgr:SendMail2(oMailBox, pid, name, target, mData, silver, items, summons)
    mData.expert = mData.expert or 7 * 24 * 3600
    local oMail = mailobj.NewMail(oMailBox:DispitchMailID())
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

    oMailBox:AddMail(oMail, mData.bsort)
end

function CMailMgr:ClearMailBox(pid)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadMailBox(pid, function (oMailBox)
        if oMailBox then
            oMailBox:ClearMail()
        end
    end)
end

--新邮件奖励接口
function CMailMgr:SendMailNew(iSender, sName, iReceiver, mMail, mReward)
    if not mMail then return end

    local func = function(oMailBox)
        self:SendMailNew2(oMailBox, iSender, sName, iReceiver, mMail, mReward)
    end

    global.oWorldMgr:LoadMailBox(iReceiver, func)
end

function CMailMgr:SendMailNew2(oMailBox, iSender, sName, iReceiver, mMail, mReward)
    if not oMailBox then
        record.warning("can't load mailbox %d %s %d", iReceiver, sName, iTarget)
        return
    end

    mMail.expert = mMail.expert or 7*24*3600
    local iMailId = oMailBox:DispitchMailID()
    local oMail = mailobj.NewMail(iMailId)
    oMail:Create({iSender, sName}, iReceiver, mMail)

    for sType, rInfo in pairs(mReward or {}) do
        if mAttachFunc[sType] then
            safe_call(mAttachFunc[sType], oMail, rInfo)
        end
    end
    oMailBox:AddMail(oMail, mMail.bsort)
end

function CMailMgr:GetSupportType()
    return mAttachFunc 
end

function CMailMgr:OpenMail(oPlayer, iMail)
    local oMailBox = oPlayer:GetMailBox()
    local oMail = oMailBox:GetMail(iMail)
    if oMail then
        oMail:Open()
        local mNet = oMail:PackInfo()
        oPlayer:Send("GS2CMailInfo", mNet)
    end
end

function CMailMgr:AcceptMailAttach(oPlayer, iMail)
    local oMailBox = oPlayer:GetMailBox()
    local oMail = oMailBox:GetMail(iMail)
    if oMail then
        local oNotifyMgr = global.oNotifyMgr
        local oToolMgr = global.oToolMgr
        if not oMail:Validate() then
            oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSystemText({"text"}, 1001))
            return
        end
        if not oMail:ValidAttach(oPlayer) then
            return false
        end

        if oMail:RecieveAttach(oPlayer) then
            if oMail:Opened() then
                oPlayer:Send("GS2CMailOpened", {mailids={iMail}})
            end
        end
    end
end

function CMailMgr:AcceptAllMailAttach(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    local oMailBox = oPlayer:GetMailBox()
    local iNoExtractCnt = 0
    local lRecieved = {}
    local mArgs = {} 
    for _, mailid in ipairs(oMailBox:GetAllShowMailIDs()) do
        local oMail = oMailBox:GetMail(mailid)
        if oMail and oMail:Validate() then
            if not oMail:ValidAttach(oPlayer, mArgs) then
                break
            end

            if not oMail:AutoExtract() then
                iNoExtractCnt = iNoExtractCnt + 1
            else
                if oMail:RecieveAttach(oPlayer) then
                    table.insert(lRecieved, mailid)
                    mArgs = {cancel_tip=true}
                end
            end
        end
    end
    if #(lRecieved) == 0 then
        if iNoExtractCnt == 0 then
            oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSystemText({"text"}, 1004))
        else
            oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSystemText({"text"}, 1006, {amount=iNoExtractCnt}))
        end
    else
        oPlayer:Send("GS2CMailOpened", {mailids=lRecieved})
    end
end

function CMailMgr:DeleteMails(oPlayer, lMail)
    local oMailBox = oPlayer:GetMailBox()
    for _, iMail in ipairs(lMail or {}) do
        local oMail = oMailBox:GetMail(iMail)
        if oMail and not oMail:HasAttach() then
            oMailBox:DelMail(iMail)
        end        
    end
end

function CMailMgr:DeleteAllMails(oPlayer, iDelCnt)
    local oMailBox = oPlayer:GetMailBox()
    local iDelCnt = iDelCnt or 0
    local lMailid = {}

    for _, mailid in ipairs(oMailBox:GetAllShowMailIDs()) do
        local oMail = oMailBox:GetMail(mailid)
        if oMail and not oMail:HasAttach() then
            oMailBox:DelMail(mailid)
            table.insert(lMailid, mailid)
            iDelCnt = iDelCnt + 1
        end
    end

    local oNotifyMgr = global.oNotifyMgr
    local oToolMgr = global.oToolMgr
    if iDelCnt > 0 then    
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSystemText({"text"}, 1007, {amount=iDelCnt}))
    else
        oNotifyMgr:Notify(oPlayer:GetPid(), oToolMgr:GetSystemText({"text"}, 1005))
    end
    oMailBox:GS2CDelMail(lMailid)    
end


-------------------ks------------------------------------
function CMailMgr:AddKSMail(iPid, mMail)
    if not iPid or not mMail then return end

    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadMailBox(iPid, function (oMailBox)
        if oMailBox then
            self:_AddKSMail(oMailBox, iPid, mMail)
        end
    end)
end

function CMailMgr:_AddKSMail(oMailBox, iPid, mMail)
    local iMailId = oMailBox:DispitchMailID()
    local oMail = mailobj.NewMail(iMailId)
    oMail:Load(mMail)
    oMailBox:AddMail(oMail, true)
end

function CMailMgr:PushMail2KS(iPid, oMail)
    local oKuaFu = global.oKuaFuMgr:GetKuaFuObj(iPid)
    if not oKuaFu then return end

    router.Send(oKuaFu:GetKuaFuKey(), ".world", "kuafu_ks", "GS2KSPushMail", {
        pid = iPid,
        mailid = oMail.m_iID,
        mail = oMail:Save(), 
    })
end


