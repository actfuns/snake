local global = require "global"
local interactive = require "base.interactive"
local extend = require "base.extend"
local record = require "public.record"
local gamedefines = import(lualib_path("public.gamedefines"))
local gamedb = import(lualib_path("public.gamedb"))

function NewBackendMgr(...)
    return CBackendMgr:New(...)
end


CBackendMgr = {}
CBackendMgr.__index = CBackendMgr
inherit(CBackendMgr, logic_base_cls())

function CBackendMgr:New()
    local o = super(CBackendMgr).New(self)
    return o
end

function CBackendMgr:RunGmCmd(iPid, sCmd)
    local oGMMgr = global.oGMMgr
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    oGMMgr:ReceiveCmd(oPlayer, sCmd)
end

function CBackendMgr:OnlineExecute(iPid, sFunc, mArgs)
    local oPubMgr = global.oPubMgr
    oPubMgr:OnlineExecute(iPid, sFunc, mArgs)
end

function CBackendMgr:BanPlayerChat(oPlayer, iTime)
    local oChatMgr = global.oChatMgr
    oChatMgr:BanChat(oPlayer, iTime)
end

function CBackendMgr:BanPlayerLogin(iPid, iSecond)
    local mData = {ban_time = get_time() + iSecond}
    local mInfo = {
        module = "playerdb",
        cmd = "SavePlayerMain",
        cond = {pid = iPid},
        data = {data = mData},
    }
    gamedb.SaveDb(iPid, "common", "DbOperate", mInfo)
end

function CBackendMgr:FinePlayerMoney(oPlayer, iMoneyType, iVal, sReason)
    sReason = sReason or "GM后台"
    local iOweOld = 0
    if iMoneyType == gamedefines.MONEY_TYPE.GOLD then
        iOweOld = oPlayer.m_oActiveCtrl:GetData("gold_owe", 0) 
    elseif iMoneyType == gamedefines.MONEY_TYPE.SILVER then
        iOweOld = oPlayer.m_oActiveCtrl:GetData("silver_owe", 0) 
    elseif iMoneyType == gamedefines.MONEY_TYPE.GOLDCOIN then
        local oProfile = oPlayer:GetProfile()
        iOweOld = oProfile:GoldCoinOwe()
    elseif iMoneyType == gamedefines.MONEY_TYPE.TRUE_GOLDCOIN then
        local oProfile = oPlayer:GetProfile()
        iOweOld = oProfile:TrueGoldCoinOwe()
    end
    oPlayer:ResumeMoneyByType(iMoneyType, iVal, "gm处罚", {cancel_tip=true,cancel_rank = true,subreason = sReason})

    local iOwe = 0
    local sMoneyType
    local mReplace = {}
    if iMoneyType == gamedefines.MONEY_TYPE.GOLD then
        iOwe = oPlayer.m_oActiveCtrl:GetData("gold_owe", 0) 
        sMoneyType = "#gold#cur_3"
        mReplace = {gold = {iVal, iVal - iOwe + iOweOld, iOwe}}
    elseif iMoneyType == gamedefines.MONEY_TYPE.SILVER then
        iOwe = oPlayer.m_oActiveCtrl:GetData("silver_owe", 0) 
        sMoneyType = "#silver#cur_4"
        mReplace = {silver = {iVal, iVal - iOwe + iOweOld, iOwe}}
    elseif iMoneyType == gamedefines.MONEY_TYPE.GOLDCOIN then
        local oProfile = oPlayer:GetProfile()
        iOwe = oProfile:GoldCoinOwe()
        sMoneyType = "#goldcoin#cur_2"
        mReplace = {goldcoin = {iVal, iVal - iOwe + iOweOld, iOwe}}
    elseif iMoneyType == gamedefines.MONEY_TYPE.TRUE_GOLDCOIN then
        local oProfile = oPlayer:GetProfile()
        iOwe = oProfile:TrueGoldCoinOwe()
        sMoneyType = "#goldcoin#cur_1"
        mReplace = {goldcoin = {iVal, iVal - iOwe + iOweOld, iOwe}}
    end
    if sMoneyType then
        local oToolMgr = global.oToolMgr
        local oMailMgr = global.oMailMgr
        local mData, name = oMailMgr:GetMailInfo(9006)
        local sContext = oToolMgr:FormatString(mData.context, {total = sMoneyType, real = sMoneyType, owe = sMoneyType})
        sContext = oToolMgr:FormatString(sContext, mReplace)
        mData.context = sContext
        oMailMgr:SendMail(0, name, oPlayer:GetPid(), mData)
    end
end

function CBackendMgr:GmRenamePlayer(iPid, sName)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        self:RenamePlayer(oPlayer, sName)
    else
        self:OnlineExecute(iPid, "RenamePlayer", {sName})
    end
end

function CBackendMgr:RenamePlayer(oPlayer, sName)
    local mInfo = {
        module = "namecounter",
        cmd = "InsertNewNameCounter",
        data = {name = sName},
    }
    local iPid = oPlayer:GetPid()
    gamedb.LoadDb(iPid, "common", "DbOperate", mInfo, function (mRecord, mData)
        local o = global.oWorldMgr:GetOnlinePlayerByPid(iPid)    
        if o and mData.success then
            global.oRenameMgr:DoRenameSuccess(o, sName, nil, true)        
        else
            record.warning('gm player rename error pid:%s name:%s', iPid, sName)
        end
    end)
end

function CBackendMgr:RemovePlayerItem(oPlayer, iItemSid, iCnt)
    local bHasItem = global.oItemLoader:HasItem(iItemSid)
    assert(bHasItem, string.format("gm RemovePlayerItem:%s", iItemSid))

    if oPlayer:GetItemAmount(iItemSid) < iCnt then
        iCnt = oPlayer:GetItemAmount(iItemSid)
    end
    if iCnt <= 0 then return end

    oPlayer:RemoveItemAmount(iItemSid, iCnt, "gm删除道具")
end

function CBackendMgr:KickPlayer(iPid)
    if is_ks_server() then
        global.oWorldMgr:TryBackGS(self)
    else
        global.oWorldMgr:Logout(iPid)    
    end
end

function CBackendMgr:RenameSummon(oPlayer, iTraceno, sName)
    local oSummon = oPlayer.m_oSummonCtrl:GetSummonByTraceNo({oPlayer:GetPid(), iTraceno})
    if not oSummon then return end

    oSummon:SetName(sName)
    if oPlayer.m_oSummonCtrl:GetFollowID() == oSummon.m_iID then
        oPlayer.m_oSummonCtrl:SyncSceneInfo()
        oPlayer:PropChange("followers")
    end
end

function CBackendMgr:ForceWarEnd(oPlayer, iFlag)
    local oWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oWar then
        if iFlag and iFlag < 0 then
            oWar:TestCmd("warfail",oPlayer:GetPid(),{})
        else
            oWar:TestCmd("warend",oPlayer:GetPid(),{})
        end
    end
end

function CBackendMgr:ForceLeaveTeam(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        oTeam:Leave(oPlayer:GetPid())
    end
end

function CBackendMgr:ForceChangeScene(oPlayer)
    local oSceneMgr = global.oSceneMgr
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        self:ForceLeaveTeam(oPlayer)
    end
    oSceneMgr:ChangeMap(oPlayer, 101000)
end

function CBackendMgr:OnlineChangeScene(oPlayer)
    local iTargetX, iTargetY = global.oSceneMgr:GetFlyData(101000)
    local mDurable = oPlayer.m_oActiveCtrl:GetDurableSceneInfo()
    if mDurable and mDurable.pos then
        local mNowPos = mDurable.pos
        oPlayer.m_oActiveCtrl:SetDurableSceneInfo(101000, {x = iTargetX, y = iTargetY, z = mNowPos.z, face_x = mNowPos.face_x, face_y = mNowPos.face_y, face_z = mNowPos.face_z})
    end
end

function CBackendMgr:PackPlayer2Backend(oPlayer)
    local mPlayer = {}
    mPlayer["pid"] = oPlayer:GetPid()
    mPlayer["name"] = oPlayer:GetName()
    mPlayer["title_info"] = oPlayer.m_oTitleCtrl:Save()
    mPlayer["base_info"] = oPlayer.m_oBaseCtrl:PackBackendInfo()
    mPlayer["active_info"] = oPlayer.m_oActiveCtrl:PackBackendInfo()
    mPlayer["item_info"] = oPlayer.m_oItemCtrl:PackBackendInfo()
    mPlayer["wh_info"] = oPlayer.m_oWHCtrl:PackBackendInfo()
    mPlayer["skill_info"] = oPlayer.m_oSkillCtrl:Save()
    mPlayer["summon_info"] = oPlayer.m_oSummonCtrl:PackBackendInfo()
    mPlayer["partner_info"] = oPlayer.m_oPartnerCtrl:Save()
    mPlayer["summon_ck_info"] = oPlayer.m_oSummCkCtrl:PackBackendInfo()
    -- mPlayer["ride_info"] = oPlayer.m_oRideCtrl:Save()
    
    local mRet = {}
    mRet["online"] = true
    mRet["player"] = mPlayer
    mRet["offline"] = oPlayer:GetProfile():PackBackendInfo()
    mRet["war"] = oPlayer:PackBackendWarInfo()
    mRet["task"] = oPlayer.m_oTaskCtrl:PackBackendInfo()
    return mRet
end

function CBackendMgr:OnServerStartEnd()
    global.oYunYingMgr:GetHuoDongTagInfo()
end
