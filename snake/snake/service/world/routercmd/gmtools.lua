--import module
local global = require "global"
local skynet = require "skynet"
local record = require "public.record"
local interactive = require "base.interactive"
local cjson = require "cjson"
local router = require "base.router"
local gamedb = import(lualib_path("public.gamedb"))


ForwardCmd = {}
ForwardOpenKS = {}

function ForwardCmd.SendPublicEmail(mRecord, mArgs)
    local oMailMgr = global.oMailMgr
    oMailMgr:SendAllSysMail(mArgs)
end

function ForwardCmd.SendPrivateEmail(mRecord, mArgs)
    local lPlayerId = mArgs["playerids"]
    if #lPlayerId <= 0 then return end

    local oWorldMgr = global.oWorldMgr
    local oSysMailCache = oWorldMgr.m_oSysMailCache
    local oMail = oSysMailCache:CreateMailCacheObj(0, mArgs)
    if oMail:IsExpire() then
        record.warning(string.format("gmtools SendPrivateEmail expire %s", oMail.m_sTitle))
        return
    end

    for _, iPid in pairs(lPlayerId) do
        oMail:SendSysMail(iPid)
    end
    baseobj_delay_release(oMail)
end

function ForwardCmd.BanPlayerChat(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local iSecond = mArgs["seconds"]
    
    local oBackendMgr = global.oBackendMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    local iTime = get_time() + iSecond
    if oPlayer then
        oBackendMgr:BanPlayerChat(oPlayer, iTime)
    else
        oBackendMgr:OnlineExecute(iPid, "BanPlayerChat", {iTime})
    end
end

function ForwardCmd.BanPlayerLogin(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local iSecond = mArgs["seconds"] or 0
    local oBackendMgr = global.oBackendMgr
    oBackendMgr:BanPlayerLogin(iPid, iSecond)
end

function ForwardCmd.FinePlayerMoney(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local iMoneyType = mArgs["money_type"]
    local iValue = mArgs["value"]
    local sReason = mArgs["reason"]
    local oBackendMgr = global.oBackendMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oBackendMgr:FinePlayerMoney(oPlayer, iMoneyType, iValue, sReason)
    else
        oBackendMgr:OnlineExecute(iPid, "FinePlayerMoney", {iMoneyType, iValue, sReason})
    end
end

function ForwardCmd.RenamePlayer(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local sName = mArgs["name"]
    if #sName <= 0 then
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {errcode=3, errmsg="名字为空"})
        return
    end
    local mInfo = {
        module = "namecounter",
        cmd = "FindName",
        cond = {name = sName},
    }
    gamedb.LoadDb(iPid, "common", "DbOperate", mInfo, function (m, data)
        if data.success then
            router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {errcode=3, errmsg="名字重复"})
            return
        end
        local oBackendMgr = global.oBackendMgr
        oBackendMgr:GmRenamePlayer(iPid, sName)
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {})
    end)
    return {off=true}
end

function ForwardCmd.RemovePlayerItem(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local iItem = mArgs["item"]
    local iValue = mArgs["value"]
    local oBackendMgr = global.oBackendMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oBackendMgr:RemovePlayerItem(oPlayer, iItem, iValue)
    else
        oBackendMgr:OnlineExecute(iPid, "RemovePlayerItem", {iMoneyType, iValue})
    end
end

ForwardOpenKS["KickPlayer"] = true
function ForwardCmd.KickPlayer(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local oBackendMgr = global.oBackendMgr
    oBackendMgr:KickPlayer(iPid)
end

ForwardOpenKS["ForceWarEnd"] = true
function ForwardCmd.ForceWarEnd(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local oBackendMgr = global.oBackendMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oBackendMgr:ForceWarEnd(oPlayer)
    end
end

ForwardOpenKS["ForceLeaveTeam"] = true
function ForwardCmd.ForceLeaveTeam(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local oBackendMgr = global.oBackendMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oBackendMgr:ForceLeaveTeam(oPlayer)
    else
        if not is_ks_server() then
            oBackendMgr:OnlineExecute(iPid, "ForceLeaveTeam", {})    
        end
    end
end

ForwardOpenKS["ForceChangeScene"] = true
function ForwardCmd.ForceChangeScene(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local oBackendMgr = global.oBackendMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oBackendMgr:ForceChangeScene(oPlayer)
    else
        if not is_ks_server() then
            oBackendMgr:OnlineExecute(iPid, "OnlineChangeScene", {})
        end
    end
end

ForwardOpenKS["SendSysChat"] = true
function ForwardCmd.SendSysChat(mRecord, mArgs)
    local sMsg = mArgs["content"]
    local iHorse = mArgs["type"]
    local oChatMgr = global.oChatMgr
    oChatMgr:HandleSysChat(sMsg, 0, iHorse)
end

function ForwardCmd.SendGmCmd(mRecord, mArgs)
    local sCmd = mArgs["content"]
    local iPid = mArgs["pid"]

    local oBackendMgr = global.oBackendMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {errcode=3, errmsg="指定玩家不在线"})
        -- interactive.Response(mRecord.source, mRecord.session, {errcode=3, errmsg="指定玩家不在线"})
        return
    end

    local br, res = safe_call(oBackendMgr.RunGmCmd, oBackendMgr, iPid, sCmd)
    if not br then
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {errcode=2, errmsg="执行错误，请检查参数"})
        -- interactive.Response(mRecord.source, mRecord.session, {errcode=2, errmsg="执行错误，请检查参数"})
        return
    end

    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {})
    -- interactive.Response(mRecord.source, mRecord.session, {})
    return {off=true}
end

function ForwardCmd.RenameSummon(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local sName = mArgs["name"]
    local iSummon = mArgs["sumid"]

    local oBackendMgr = global.oBackendMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oBackendMgr:RenameSummon(oPlayer, iSummon, sName)
    else
        oBackendMgr:OnlineExecute(iPid, "RenameSummon", {iSummon, sName})
    end
end

function ForwardCmd.RenameOrg(mRecord, mArgs)
    local iOrgId = mArgs["orgid"]
    local sName = mArgs["name"]
    local iFlag = mArgs["flag"] or 0
    local oOrgMgr = global.oOrgMgr
    local oOrg = oOrgMgr:GetNormalOrg(iOrgId)
    if not oOrg then
        return {errcode=3, errmsg="帮派不存在"}
    end

    if iFlag == 1 then
        oOrg:SetAim("")
    end
    if #sName > 0 then
        if oOrgMgr:HasSameName(sName) then
            return {errcode=3, errmsg="名字重复"}
        end
        oOrgMgr:RenameOrg(iOrgId, sName)
    end
end

function ForwardCmd.PushGmAccount(mRecord, mArgs)
    -- {[1]={['id']=2,['channel']="pc",['account']="xxxx"},[2]={['id']=6,['channel']="pc",['account']="sssss"}}
end

function ForwardCmd.SearchPlayerInfo(mRecord, mArgs)
    local iPid = mArgs["pid"]
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    local oBackendMgr = global.oBackendMgr    

    local mRet = {online=false}
    if oPlayer then
        mRet = oBackendMgr:PackPlayer2Backend(oPlayer)
    end
    return mRet
end

function ForwardCmd.RegisterHDInfo(mRecord, mData)
    local oYunYingMgr = global.oYunYingMgr
    local bSucc, sMsg = oYunYingMgr:RegisterHD(mData)
    return {errcode=(bSucc and 0 or 1), errmsg=sMsg}
end

function ForwardCmd.UnRegisterHDInfo(mRecord, mData)
    local oYunYingMgr = global.oYunYingMgr
    oYunYingMgr:UnRegisterHD(mData.ids)
end

ForwardOpenKS["SearchSysOpenStatus"] = true
function ForwardCmd.SearchSysOpenStatus(mRecord, mData)
    return global.oToolMgr:GetAllSysOpenStatus()
end

ForwardOpenKS["SetSysOpenStatus"] = true
function ForwardCmd.SetSysOpenStatus(mRecord, mData)
    local lSysOpen = mData.sysopen
    local iStatus = mData.status
    global.oToolMgr:SetSysOpenStatus(lSysOpen, iStatus)
end

function ForwardCmd.PayForGame(mRecord, mData)
    local lPlayerId = mData["playerids"]
    local iType = mData["type"]
    local sProductKey = mData["payid"]

    for _,iPid in pairs(lPlayerId) do
        local mOrders = {
            product_key = sProductKey,
            product_amount = 1,
        }
        global.oPayMgr:DealSucceedOrder(iPid, mOrders)
        -- if iType == 1 then          --补单
        --     global.oPayMgr:PaySuccessLog(iPid, mOrders)
        -- end
        
        record.user("pay", "backendpay", {
            pid = iPid,
            amount = 1,
            productkey = sProductKey,
            type = iType,
        }) 
    end
end

function ForwardCmd.SetFeedBackState(mRecord, mData)
    global.oFeedBackMgr:SetFeedBackState(mData)
    return { errcode = 0, data = {answerer = mData.answerer}}
end

function ForwardCmd.SetCustServInfo(mRecord, mData)
    local oYunYingInfoMgr = global.oYunYingInfoMgr
    oYunYingInfoMgr:SetCustServInfo(mData)
end

function ForwardCmd.SetSysSwitchInfo(mRecord, mData)
    local oYunYingInfoMgr = global.oYunYingInfoMgr
    oYunYingInfoMgr:SetSysSwitchInfo(mData)
end

function Forward(mRecord, mData)
    local sCmd = mData["cmd"]
    local mArgs = mData["data"]
    local func = ForwardCmd[sCmd]
    if is_ks_server() and not ForwardOpenKS[sCmd] then
        record.warning(string.format("gmtools Forward ks can't excute %s", sCmd))
        router.Response(mRecord.srcsk, mRecord.src, mRecord.session, {errcode=3, errmsg="ks can't excute"})    
        return
    end

    local mRes = {}
    if func then
        local bSucc, mRet = safe_call(func, mRecord, mArgs)
        if not bSucc then
            mRes = {
                errcode = 2, 
                errmsg = "world service call error",
            }
        else
            if not mRet or not mRet["off"] then
                mRes = mRet or {errcode = 0}
            end
        end
    else
        mRes = {
            errcode = 1,
            errmsg = "world service func not find",
        }
    end
    router.Response(mRecord.srcsk, mRecord.src, mRecord.session, mRes)
end

