local global = require "global"
local interactive = require "base.interactive"
local record = require "public.record"
local router = require "base.router"
local gamedb = import(lualib_path("public.gamedb"))

function NewRenameMgr()
    local o = CRenameMgr:New()
    return o
end


CRenameMgr = {}
CRenameMgr.__index = CRenameMgr
inherit(CRenameMgr, logic_base_cls())

function CRenameMgr:New()
    local o = super(CRenameMgr).New(self)
    o:Init()
    return o
end

function CRenameMgr:Init()
    self.m_sDBName = "namecounter"
end

function CRenameMgr:Notify(iPid, sMsg)
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(iPid, sMsg)
end

function CRenameMgr:GetPlayer(iPid)
    local oWorldMgr = global.oWorldMgr
    return oWorldMgr:GetOnlinePlayerByPid(iPid)
end

function CRenameMgr:DoRename(oPlayer, sNewName)
    local iPid = oPlayer:GetPid()
    if oPlayer:GetGrade() < 10 then
        self:Notify(iPid, "你的等级＜10级无法改名")
        return
    end
    sNewName = trim(sNewName)
    if not sNewName or sNewName == "" then
        self:Notify(iPid, "请输入名字")
        return
    end
    local mInfo = {
        module = "namecounter",
        cmd = "FindName",
        cond = {name = sNewName},
    }
    gamedb.LoadDb(iPid, "common", "DbOperate", mInfo, function(mRecord, mData)
        self:DoRename1(iPid, sNewName, mData)
    end)
end

function CRenameMgr:DoRename1(iPid, sNewName, mData)
    local oPlayer = self:GetPlayer(iPid)
    if not oPlayer then return end

    if mData.success then
        self:Notify(iPid, "名字已重复")
        return
    end
    
    local sMsg = string.format("[896055]你确定要将名字修改为：[-][1d8e00]%s[-][896055]？[-]", sNewName)
    self:SetCallBack(iPid, sNewName, sMsg)
end

function CRenameMgr:SetCallBack(iPid, sNewName, sMsg)
    local oPlayer = self:GetPlayer(iPid)
    if not oPlayer then return end
   
    local oCbMgr = global.oCbMgr
    local mData = oCbMgr:PackConfirmData(nil, {sContent=sMsg})
    oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mData, nil, function(oPlayer, mData)
        self:DoRename2(oPlayer, sNewName, mData.answer)
    end)
end

function CRenameMgr:DoRename2(oPlayer, sNewName, iAnswer)
    if iAnswer ~= 1 then return end

    local iCostItem, iCnt = 10178, 1 -- 改名卡
    local iCost, mFrozen = 580, nil
    local mCostInfo = {}
    if oPlayer:GetGrade() > 50 or oPlayer:GetRename() > 0 then
        if oPlayer:GetItemAmount(iCostItem) < iCnt then
            if not oPlayer:ValidGoldCoin(iCost) then
                return
            else
                mFrozen = oPlayer:FrozenGoldCoin(iCost, "改名")
            end
        end
    end

    local iPid = oPlayer:GetPid()
    local mInfo = {
        module = "namecounter",
        cmd = "InsertNewNameCounter",
        data = {name = sNewName},
    }
    gamedb.LoadDb(iPid, "common", "DbOperate", mInfo, function (mRecord, mData)
        self:DoRename3(iPid, sNewName, mFrozen, mData)
    end)
end

function CRenameMgr:DoRename3(iPid, sNewName, mFrozen, mData)
    local oPlayer = self:GetPlayer(iPid)
    if not oPlayer then
        self:DoRenameFail(iPid, mFrozen)
        return
    end
    if mData.success then
        self:DoRenameSuccess(oPlayer, sNewName, mFrozen)
    else
        self:DoRenameFail(iPid, mFrozen)
    end
end

function CRenameMgr:DoRenameSuccess(oPlayer, sNewName, mFrozen, bGm)
    local sOldName = oPlayer:GetName()
    oPlayer:SetData("name", sNewName)

    local iCnt = oPlayer:GetRename()
    if not bGm then
        oPlayer.m_oBaseCtrl:SetData("rename",  iCnt + 1)
    end

    oPlayer:SyncSceneInfo({name = sNewName})
    oPlayer:PropChange("name", "rename")

    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = "改名成功，你的名字已修改为#role"
    sMsg = oToolMgr:FormatColorString(sMsg, {role=sNewName})
    oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)

    local iCostItem, iCostCnt = 10178, 1 -- 改名卡
    if iCnt > 0 and oPlayer:GetItemAmount(iCostItem) > 0 then
        oPlayer:RemoveItemAmount(iCostItem, iCostCnt, "改名")
    end

    local iGoldCoin = 0
    if mFrozen and table_count(mFrozen)>0 then
        local oProfile = oPlayer:GetProfile()
        for _, sSession in ipairs(mFrozen or {}) do
            oProfile:UnFrozenMoney(sSession)
        end
        iGoldCoin = 580
        oPlayer:ResumeGoldCoin(iGoldCoin, "改名")
    end

    self:OnRenameSuccess(oPlayer, sOldName, sNewName)

    local mLogData = oPlayer:LogData()
    mLogData["old_name"] = sOldName
    mLogData["new_name"] = sNewName
    mLogData["goldcoin"] = iGoldCoin
    record.log_db("player", "rename", mLogData)
end

function CRenameMgr:DoRenameFail(iPid, mFrozen)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadProfile(iPid, function(o)
        self:DoRenameFail1(o, mFrozen)
    end)
end

function CRenameMgr:DoRenameFail1(oProfile, mFrozen)
    if not oProfile then return end
    
    if mFrozen then
        for _, sSession in ipairs(mFrozen) do
            oProfile:UnFrozenMoney(sSession)
        end
    end
    
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:Notify(oProfile:GetPid(), "名字已重复")
end

function CRenameMgr:OnRenameSuccess(oPlayer, sOldName, sNewName)
    local iPid = oPlayer:GetPid()
    self:RefreshDbName(iPid, sOldName, sNewName)

    local mInfo = {
        module = "namecounter",
        cmd = "DeleteName",
        cond = {name = sOldName},
    }
    gamedb.SaveDb(iPid, "common", "DbOperate", mInfo)

    local oTeam = oPlayer:HasTeam()
    if oTeam then
        local oMember = oTeam:GetMember(iPid)
        if oMember then
            oMember:Update({name=sNewName})
        end
    end

    local mFollowNpcs = oPlayer.m_oTaskCtrl:FollowersInfo()
    if mFollowNpcs and next(mFollowNpcs) then
        oPlayer.m_oTaskCtrl:RefreshFollowNpcs()
    end

    local oToolMgr = global.oToolMgr
    local oNotifyMgr = global.oNotifyMgr
    local mReplace = {oname=sOldName, nname=sNewName}
    
    -- oPlayer:SyncName2Org()
    local oOrgMgr = global.oOrgMgr
    local iOrgID = oOrgMgr:GetPlayerOrgId(iPid)
    if iOrgID and iOrgID > 0 then
        local sMsg ="#oname已把名字修改为#nname"
        sMsg = oToolMgr:FormatColorString(sMsg, mReplace)
        oNotifyMgr:SendOrgChat(sMsg, iOrgID, {pid=0})
    end

    local oFriendMgr = global.oFriendMgr
    oFriendMgr:RefreshFriendProfile(iPid, {pid=iPid, name=sNewName})

    local oMailMgr = global.oMailMgr
    local mInfo, sMail = oMailMgr:GetMailInfo(2004)
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, mReplace)
    local oFriendCtrl = oPlayer:GetFriend()
    oFriendCtrl:SendMailByDegree(0, sMail, mInfo)
end

function CRenameMgr:RefreshDbName(iPid, sOldName, sNewName)
    local oWorldMgr = global.oWorldMgr
    oWorldMgr:LoadProfile(iPid, function (oProfile)
        if oProfile then
            oProfile:SetName(sNewName)
        end
    end)

    local oOrgMgr = global.oOrgMgr
    oOrgMgr:SyncPlayerData(iPid, {name=sNewName})
    local iOrgID = oOrgMgr:GetPlayerOrgId(iPid)
    if iOrgID and iOrgID > 0 then
        local oOrg = oOrgMgr:GetNormalOrg(iOrgID)
        if oOrg:GetLeaderID() == iPid then
            global.oRankMgr:OnUpdateChairman(iOrgID, sNewName)
        end
        oOrg:SyncMemberData(iPid, {name=sNewName})
    end

    local oRankMgr = global.oRankMgr
    oRankMgr:OnUpdateName(iPid, sNewName)
    
    global.oEngageMgr:OnPlayerRename(iPid, sNewName)
    router.Send("cs", ".datacenter", "common", "UpdateRoleInfo", {
        name = sNewName,
        no_login = true
    })
end
