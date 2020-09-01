local global = require "global"
local extend = require "base.extend"
local router = require "base.router"
local record = require "public.record"
local res = require "base.res"

local util = import(lualib_path("public.util"))
local gamedefines = import(lualib_path("public.gamedefines"))
local channelinfo = import(lualib_path("public.channelinfo"))
local loadsummon = import(service_path("summon.loadsummon"))

function NewRedeemCodeMgr(...)
    local oMgr = CRedeemCodeMgr:New(...)
    return oMgr
end

CRedeemCodeMgr = {}
CRedeemCodeMgr.__index = CRedeemCodeMgr
inherit(CRedeemCodeMgr, logic_base_cls())

function CRedeemCodeMgr:New()
    local o = super(CRedeemCodeMgr).New(self)
    return o
end

function CRedeemCodeMgr:UseRedeemCode(oPlayer, sCode)
    if not global.oToolMgr:IsSysOpen("REDEEM_CODE", oPlayer) then return end
    
    local iPid = oPlayer:GetPid()
    if not sCode then
        oPlayer:NotifyMessage("输入错误请重新输入")
        return
    end

    if oPlayer.m_oThisTemp:Query("redeem_code") then
        oPlayer:NotifyMessage("道友莫急.....")
        return
    end
    oPlayer.m_oThisTemp:Set("redeem_code", sCode, 2)

    sCode = string.upper(sCode)
    local mArgs = {
        cmd= "UseRedeemCode", 
        data = {
            pid = iPid, 
            code = sCode, 
            channel = oPlayer:GetChannel(), 
            platform = oPlayer:GetPlatform(),
        }
    } 
    router.Request("cs", ".redeemcode", "common", "Forward", mArgs, function (m1, m2)
        self:_UseRedeemCode2(iPid, sCode, m2.errcode, m2.data) 
    end)
end

function CRedeemCodeMgr:_UseRedeemCode2(iPid, sCode, iErr, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    
    if iErr == 0 then
        self:SuccessRedeem(iPid, sCode, mArgs)
    else
        local sRedeemName = mArgs["redeem_name"]
        if not oPlayer then return end

        if table_in_list({1, 2}, iErr) then
            return oPlayer:NotifyMessage("未找到指定的兑换码")
        elseif iErr == 3 then
            return oPlayer:NotifyMessage(string.format("您的%s兑换码已过期", sRedeemName))
        elseif table_in_list({7, 8}, iErr) then
            return oPlayer:NotifyMessage(string.format("您已经领取过%s了", sRedeemName))
        elseif iErr == 6 then
            return oPlayer:NotifyMessage("该兑换码已经被玩家使用")
        elseif table_in_list({4, 5}, iErr)  then
            return oPlayer:NotifyMessage("不能使用该兑换码")
        else
            record.warning("使用兑换码未知异常 Pid:%d, Code:%s, Error:%d", iPid, sCode, iErr)
            return
        end
    end
end

function CRedeemCodeMgr:GenRewardContent(iPid, sRewards, iRedeem, sCode)
    -- rewards 格式 10001,1,1,1;10002,1,1,1; --> 物品ID，类型，数量，是否绑定（1表示绑定）
    local lRewards = split_string(sRewards, ";")
    if #lRewards <= 0 then return end
    
    local lItem, lSummons = {}, {}
    for _,sInfo in pairs(lRewards) do
        local lArgs = split_string(sInfo, ",", tonumber)
        if #lArgs >= 4 then
            local iSid, iType, iAmount, iBind = lArgs[1], lArgs[2], lArgs[3], lArgs[4]
            if iType == 2 then
                local oSummon = loadsummon.CreateSummon(iSid)
                table.insert(lSummons, oSummon)
            else
                local oItem = global.oItemLoader:ExtCreate(iSid)
                if oItem:SID() < 10000 then
                    oItem:SetData("Value", iAmount or 0)
                else
                    oItem:SetAmount(iAmount or 0)
                    if iBind > 0 then
                        oItem:Bind(iPid)
                    end
                end
                table.insert(lItem, oItem)
            end
        else
            record.warning("CRedeemCodeMgr:GenRewardContent Pid:%s, Code:%d, Redeem:%s, Reward:%d", iPid, sCode, iRedeem, sRewards)
        end
    end
    return lItem, lSummons
end

function CRedeemCodeMgr:SuccessRedeem(iPid, sCode, mArgs)
    local sTitle = mArgs["mail_title"]
    local sContext = mArgs["mail_context"]
    local sRewards = mArgs["rewards"]
    if not sTitle or not sContext or not sRewards then
        record.warning("CRedeemCodeMgr:SuccessRedeem Pid:%s, Code:%d, Redeem:%s, Reward:%d", iPid, sCode, iRedeem, sRewards)
        return 
    end

    local mMail = {
        title = sTitle,
        context = sContext,
        keeptime = 30 * 3600 * 24,
        icon = "h7_xinfeng_1",
        openicon = "h7_xinfeng_6",
    }
    local lItem, lSummons = self:GenRewardContent(iPid, sRewards, mArgs["redeem_id"], sCode) 
    global.oMailMgr:SendMail(0, "系统", iPid, mMail, 0, lItem, lSummons)
    
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    local iShowId, sName = 0, ""
    if oPlayer then
        iShowId, sName = oPlayer:GetShowId(), oPlayer:GetName()
        oPlayer:NotifyMessage("兑换成功，请邮件提取...")
    end
    record.log_db("player", "redeem_code", {
        pid = iPid,
        show_id = iShowId,
        name = sName,
        code = sCode,
        gift_id = sRewards,
        status = 0,
    })
end

-- function CRedeemCodeMgr:_UseRedeemCode(iPid, sCode, iErr, mArgs)
--     local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
--     if oPlayer then
--         oPlayer:RedeemCodeReward(sCode, iErr, mArgs["gift_id"], mArgs["redeem_id"])
--     else
--         local oPubMgr = global.oPubMgr
--         oPubMgr:OnlineExecute(iPid, "RedeemCodeReward", {sCode, iErr, mArgs["gift_id"], mArgs["redeem_id"]})
--     end
-- end

-- function CRedeemCodeMgr:RedeemCodeReward(oPlayer, sCode, iErr, iGift, iRedeem)
--     if table_in_list({1, 2}, iErr) then
--         return oPlayer:NotifyMessage("未找到指定的兑换码")
--     end
--     iGift = math.floor(iGift)
--     local iPid = oPlayer:GetPid()
--     local oItem = global.oItemLoader:GetItem(iGift)
--     if not oItem then
--         record.error("RedeemCodeReward error Pid:%d Redeem:%d sCode:%s iGift:%d", iPid, iRedeem, sCode, iGift)
--         return
--     end
--     if iErr == 0 then
--         oPlayer:RewardItems(iGift, 1, "兑换码")
--         oPlayer:NotifyMessage("兑换成功")
--         self:SendRedeemMail(oPlayer, oItem:GetItemData()["mailid"])
--         record.log_db("player", "redeem_code", {
--             pid = iPid,
--             show_id = oPlayer:GetShowId(),
--             name = oPlayer:GetName(),
--             code = sCode,
--             gift_id = iGift,
--             status = iErr
--         })
--     elseif iErr == 3 then
--         return oPlayer:NotifyMessage(string.format("您的%s兑换码已过期", oItem:TipsName()))
--     elseif table_in_list({7, 8}, iErr) then
--         return oPlayer:NotifyMessage(string.format("您已经领取过%s了", oItem:TipsName()))
--     elseif iErr == 6 then
--         return oPlayer:NotifyMessage("该兑换码已经被玩家使用")
--     elseif table_in_list({4, 5}, iErr)  then
--         return oPlayer:NotifyMessage("不能使用该兑换码")
--     else
--         record.warning("使用兑换码未知异常 Pid:%d, Code:%s, Error:%d", iPid, sCode, iErr)
--         return
--     end
-- end

-- function CRedeemCodeMgr:SendRedeemMail(oPlayer, iMail)
--     if not oPlayer or not iMail or iMail <= 0 then return end

--     local oMailMgr = global.oMailMgr
--     local mMail, sName = oMailMgr:GetMailInfo(iMail)
--     if not mMail then return end

--     oMailMgr:SendMail(0, sName, oPlayer:GetPid(), mMail, 0)
-- end

-- function CRedeemCodeMgr:GetPublisherByChannel(iChannel)
--     local mChannelInfo = channelinfo.get_channel_info()
--     local mData = mChannelInfo[iChannel]
--     if not mData then return end

--     return mData["publisher"]
-- end
