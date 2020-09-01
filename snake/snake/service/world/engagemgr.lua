local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local defines = import(service_path("offline.defines"))
local datactrl = import(lualib_path("public.datactrl"))
local gamedb = import(lualib_path("public.gamedb"))

function NewEngageMgr(...)
    return CEngageMgr:New(...)
end

local TYPE_SILVER = 1
local TYPE_GOLD = 2
local TYPE_DIAMOND = 3

local TITLE_ID = {
    [1] = 942,
    [2] = 943,
}

local STATUS_START = 1
local STATUS_CONFIRM = 2
local STATUS_SET_TEXT = 3

CEngageMgr = {}
CEngageMgr.__index = CEngageMgr
CEngageMgr.m_sTableName = "engageinfo"
inherit(CEngageMgr, datactrl.CDataCtrl)

function CEngageMgr:New()
    local o = super(CEngageMgr).New(self)
    o:Init()
    return o
end

function CEngageMgr:Init()
    self.m_iEngageNo = 0
    self.m_iDispatch = 0
    self.m_mEngage = {}
    self.m_mPid2Engage = {}
    self.m_mReadyPid = {}
end

function CEngageMgr:Save()
    return {
        engage_no = self.m_iEngageNo
    }
end

function CEngageMgr:Load(mData)
    if not mData then return end

    self.m_iEngageNo = mData.engage_no or 0
end

function CEngageMgr:ConfigSaveFunc()
    self:ApplySave(function ()
        local oEngageMgr = global.oEngageMgr
        oEngageMgr:_CheckSaveDb()
    end)
end

function CEngageMgr:_CheckSaveDb()
    assert(not is_release(self), "_CheckSaveDb fail")
    assert(self:IsLoaded(), "engagemgr save fail: is loading")
    if not self:IsDirty() then return end
    
    self:SaveDb()
end

function CEngageMgr:SaveDb()
    local mInfo = {
        module = "globaldb",
        cmd = "SaveGlobal",
        cond = {name = self.m_sTableName},
        data = {data = self:Save()},
    }
    gamedb.SaveDb("engage", "common", "DbOperate", mInfo)
    self:UnDirty()
end

function CEngageMgr:LoadDb()
    local mInfo = {
        module = "globaldb",
        cmd = "LoadGlobal",
        cond = {name = self.m_sTableName},
    }
    gamedb.LoadDb("engage", "common", "DbOperate", mInfo,
    function(mRecord, mData)
        self:Load(mData.data)
        self:OnLoaded()
    end)
end

function CEngageMgr:DispatchID()
    self.m_iDispatch = self.m_iDispatch + 1
    return self.m_iDispatch
end

function CEngageMgr:DispatchEngageNo()
    self:Dirty()
    self.m_iEngageNo = self.m_iEngageNo + 1
    return self.m_iEngageNo    
end

function CEngageMgr:ValidEngage(oPlayer, iType)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return 1002 end

    if not oPlayer:IsTeamLeader() then return 1003 end

    local mMemPid = oTeam:AllMember()
    local lMemPid = oTeam:GetTeamMember()
    if table_count(mMemPid) ~= 2 or #lMemPid ~= 2 then return 1004 end

    local oTarget = self:GetEngageTarget(oPlayer)
    if not oTarget or oTarget:GetSex() == oPlayer:GetSex() then return 1006 end

    if self.m_mReadyPid[oPlayer:GetPid()] ~= oTarget:GetPid() then
        return 1024
    end

    local oFriend = oPlayer:GetFriend()
    local iDegree = self:GetConfigInfo("re_marry_friend_piont")
    if oFriend:GetFriendDegree(oTarget:GetPid()) < iDegree then 
        return 1007, {amount=iDegree}
    end
    local oFriend2 = oTarget:GetFriend() 
    if oFriend2:GetFriendDegree(oPlayer:GetPid()) < iDegree then 
        return 1007, {amount=iDegree}
    end

    local iGrade = self:GetLimitGrade()
    if oPlayer:GetGrade() < iGrade then
        return 1008, {level=iGrade}
    end
    if oTarget:GetGrade() < iGrade then
        return 1009, {name=oTarget:GetName(), level=iGrade}
    end

    if self:HasCoupleOrEngage(oPlayer) then
        return 1010
    end 
    if self:HasCoupleOrEngage(oTarget) then
        if oTarget:GetSex() == gamedefines.SEX_TYPE.SEX_MALE then
            return 1035, {name=oTarget:GetName()}
        else
            return 1011, {name=oTarget:GetName()}
        end
    end
    return 1 
end

function CEngageMgr:HasCoupleOrEngage(oPlayer)
    local oFriend = oPlayer:GetFriend()
    local mCouple = oFriend:GetRelation(defines.RELATION_COUPLE)
    if table_count(mCouple) > 0 then return true end

    if oPlayer.m_oMarryCtrl:GetMarryStatus() > 0 then return true end

    return false    
end

function CEngageMgr:GetEngageTarget(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if not oTeam then return end

    local mMemPid = oTeam:AllMember()
    if table_count(mMemPid) ~= 2 then return end

    local oTarget = nil
    for iPid,_ in pairs(mMemPid) do
        if iPid ~= oPlayer:GetPid() then
            oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            break
        end
    end
    return oTarget
end

function CEngageMgr:GetEngageCondition(oPlayer, iType)
    local oTeam = oPlayer:HasTeam()
    if not oTeam or #oTeam:GetTeamMember() < 2 then
        oPlayer:NotifyMessage(self:GetText(1004))
        return 
    end

    self:GS2CEngageCondition(oPlayer, iType)
end

function CEngageMgr:GS2CEngageCondition(oPlayer, iType)
    local oTeam = oPlayer:HasTeam()
    local oTarget = self:GetEngageTarget(oPlayer)

    local lMembers = {}
    if oTarget then
        table.insert(lMembers, self:PackCondition(oPlayer, oTarget:GetPid()))
        table.insert(lMembers, self:PackCondition(oTarget, oPlayer:GetPid()))
        if oPlayer:IsTeamLeader() then
            self.m_mReadyPid[oPlayer:GetPid()] = oTarget:GetPid()
        end
    else
        table.insert(lMembers, self:PackCondition(oPlayer))
    end

    local iStatus = 0
    local oEngage = self:GetEngageByPid(oPlayer:GetPid())
    if oEngage then
        iStatus = oEngage:Status()
    end
    oPlayer:Send("GS2CEngageCondition", {members=lMembers, type=iType, status=iStatus})
end

function CEngageMgr:PackCondition(oPlayer, iPid)
    local mNet = {}
    mNet["pid"] = oPlayer:GetPid()
    mNet["name"] = oPlayer:GetName()
    mNet["grade"] = oPlayer:GetGrade()
    mNet["sex"] = oPlayer:GetSex()

    local oFriend = oPlayer:GetFriend()
    mNet["degree"] = oFriend:GetFriendDegree(iPid)
    if not self:HasCoupleOrEngage(oPlayer) then
        mNet["couple"] = 1                                    
    end 
    return mNet    
end

function CEngageMgr:C2GSCancelEngage(iPid)
    local oEngage = self:GetEngageByPid(iPid)
    if not oEngage then return end

    local iMale = oEngage:MalePid()
    local iFemale = oEngage:FemalePid()
    self:RemoveEngage(oEngage)
    local oMale = global.oWorldMgr:GetOnlinePlayerByPid(iMale)
    if oMale then
        oMale:Send("GS2CCancelEngage", {})
    end
    local oFeMale = global.oWorldMgr:GetOnlinePlayerByPid(iFemale)
    if oFeMale then
        oFeMale:Send("GS2CCancelEngage", {}) 
    end

    if oMale and oFeMale then
        if iPid == iMale then
            oMale:NotifyMessage(self:GetText(1025, {role=oFeMale:GetName()}))
            oFeMale:NotifyMessage(self:GetText(1030, {role=oMale:GetName()}))    
        else
            oMale:NotifyMessage(self:GetText(1030, {role=oFeMale:GetName()}))
            oFeMale:NotifyMessage(self:GetText(1025, {role=oMale:GetName()}))    
        end
    end
end

function CEngageMgr:StartEngage(oPlayer, iType)
    local oEngage = self:GetEngageByPid(oPlayer:GetPid())
    if oEngage then
        self:RemoveEngage(oEngage)        
    end

    local iSid = self:GetCostSid(iType)
    if not iSid then return end

    if oPlayer:GetItemAmount(iSid) < 1 then
        oPlayer:NotifyMessage(self:GetText(1001)) 
        return
    end
    
    local iText, mReplace = self:ValidEngage(oPlayer, iType)
    if iText ~= 1 then
        oPlayer:NotifyMessage(self:GetText(iText, mReplace)) 
        return
    end
    
    local oTarget = self:GetEngageTarget(oPlayer)
    if not oTarget then return end

    local iEid = self:DispatchID()
    local iMale, iFemale
    if oPlayer:GetSex() == 1 then
        iMale = oPlayer:GetPid()
        iFemale = oTarget:GetPid()
    else
        iMale = oTarget:GetPid()
        iFemale = oPlayer:GetPid()
    end
    local oEngage = NewEngageObj(iEid, iType, oPlayer:GetPid(), iMale, iFemale)
    self:OnPlayerEngage(oPlayer)
    self:AddEngage(oEngage)
    self:GS2CEngageCondition(oTarget, iType)
    oEngage:SetStatus(STATUS_CONFIRM)
    oPlayer:Send("GS2CStartEngageResult", {})
end

function CEngageMgr:OnPlayerEngage(oPlayer)
    local oTeam = oPlayer:HasTeam()
    if oTeam:AutoMatching() then
        interactive.Send(".autoteam", "team", "CancleTeamAutoMatch", {
            targetid = oTeam:GetTargetID(),
            teamid = oTeam:TeamID(),
        })
        oPlayer:NotifyMessage(self:GetText(1022))
    end
end

function CEngageMgr:ConfirmEngage(oPlayer, bAgree)
    local oEngage = self:GetEngageByPid(oPlayer:GetPid())
    if not oEngage or oEngage:Status() ~= STATUS_CONFIRM then return end

    local iTarget = oEngage:TragetPid()
    if oPlayer:GetPid() ~= iTarget then return end

    if bAgree then
        if oEngage:Type() == TYPE_SILVER then
            oEngage:SetMaleText(self:GetText(1013))
            oEngage:SetFeMaleText(self:GetText(1013))
            self:SuccessEngage(oEngage)
        else
            local oRunner = global.oWorldMgr:GetOnlinePlayerByPid(oEngage:RunnerPid())
            if oRunner then
                oEngage:SetStatus(STATUS_SET_TEXT) 
                oPlayer:Send("GS2CSetEngageTextUI", {})
                oRunner:Send("GS2CSetEngageTextUI", {})
            end
        end       
    else
        self:RemoveEngage(oEngage)
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
        if oTarget then
            oTarget:NotifyMessage(self:GetText(1012))
            oTarget:Send("GS2CCancelEngage", {})
            return
        end 
    end
end

function CEngageMgr:SetEngageText(oPlayer, sText)
    if not sText or #sText <= 0 then
        oPlayer:NotifyMessage(self:GetText(1014))
        return 
    end
    if #sText > 30 then
        oPlayer:NotifyMessage(self:GetText(1015))
        return
    end
    local oEngage = self:GetEngageByPid(oPlayer:GetPid())
    if not oEngage or oEngage:Status() ~= STATUS_SET_TEXT then return end

    if oEngage:MalePid() == oPlayer:GetPid() then
        oEngage:SetMaleText(sText)
        if oEngage:GetEngageText(oEngage:FemalePid()) then
            self:SuccessEngage(oEngage)
        end
    else
        oEngage:SetFeMaleText(sText)
        if oEngage:GetEngageText(oEngage:MalePid()) then
            self:SuccessEngage(oEngage)
        end 
    end
    oPlayer:Send("GS2CSetEngageTextRusult", {}) 
end

function CEngageMgr:SuccessEngage(oEngage)
    local iMale = oEngage:MalePid()
    local iFemale = oEngage:FemalePid()
    local iRunner = oEngage:RunnerPid()
    local oMale = global.oWorldMgr:GetOnlinePlayerByPid(iMale)
    local oFemale = global.oWorldMgr:GetOnlinePlayerByPid(iFemale)
    local oRunner = global.oWorldMgr:GetOnlinePlayerByPid(iRunner)
    if not oMale or not oFemale then
        self:RemoveEngage(oEngage)
        return 
    end

    local iType = oEngage:Type()
    local iSid = self:GetCostSid(iType)
    if oRunner:GetItemAmount(iSid) < 1 then return end

    oRunner:RemoveItemAmount(iSid, 1, "订婚", {cancel_tip=true})

    local iEngageNo = self:DispatchEngageNo()
    local sMaleText = oEngage:GetEngageText(iMale)
    local sFemaleText = oEngage:GetEngageText(iFemale)
    self:OnEngageSuccess(oMale, oFemale, iType, iEngageNo, sMaleText, sFemaleText, iRunner)
    self:SendEngageReward(oMale, oFemale, iType)
    self:RemoveEngage(oEngage)
    if iType == TYPE_DIAMOND then
        self:SendRedPacket(oMale, oFemale)
    end
    self:SendEngageMsg(oMale, oFemale, iType, iEngageNo, sMaleText, sFemaleText)
    self:SendEngageMail(oMale, oFemale, iType, iEngageNo, sMaleText, sFemaleText)
end

function CEngageMgr:SendRedPacket(oMale, oFemale)
    local mArgs = {}
    mArgs.bless_replace = {role={oMale:GetName(), oFemale:GetName()}}
    mArgs.name_replace = {role={oMale:GetName(), oFemale:GetName()}}
    global.oRedPacketMgr:SysAddRedPacket(3002, nil, mArgs)
end

function CEngageMgr:SendEngageReward(oMale, oFemale, iType)
    local lReward = self:GetRewards(iType)
    if #lReward <= 0 then return end

    local mReward = {}
    for _,m in pairs(lReward) do
        mReward[m["sid"]] = m["num"]
    end

    local oMailMgr = global.oMailMgr
    local mData, sName = oMailMgr:GetMailInfo(1001)
    local mInfo = table_copy(mData)
    if not oMale:ValidGive(mReward) then
        local lItems = {}
        for iSid, iAmount in pairs(mReward) do
            local oItem = global.oItemLoader:Create(iSid)
            oItem:SetAmount(iAmount)
            oItem:Bind(oMale:GetPid())
            table.insert(lItems, oItem)
        end
        oMailMgr:SendMail(0, sName, oMale:GetPid(), mInfo, 0, lItems)
    else
        oMale:GiveItem(mReward, "订婚", {cancel_tip=true})        
    end
    if not oFemale:ValidGive(mReward) then
        local lItems = {}
        for iSid, iAmount in pairs(mReward) do
            local oItem = global.oItemLoader:Create(iSid)
            oItem:SetAmount(iAmount)
            oItem:Bind(oFemale:GetPid())
            table.insert(lItems, oItem)
        end
        oMailMgr:SendMail(0, sName, oFemale:GetPid(), mInfo, 0, lItems)
    else
        oFemale:GiveItem(mReward, "订婚", {cancel_tip=true})        
    end
end

function CEngageMgr:OnEngageSuccess(oMale, oFemale, iType, iEngageNo, sMaleText, sFemaleText, iRunner)
    local iMale = oMale:GetPid()
    local iFemale = oFemale:GetPid()

    local iEquipSid = self:GetRewardEquipSid(iType)
    local oMaleFriend = oMale:GetFriend()
    local iMaleDegree = oMaleFriend:GetFriendDegree(iFemale)
    local oFemaleFriend = oFemale:GetFriend()
    local iFemaleDegree = oFemaleFriend:GetFriendDegree(iMale)
    local oItem1 = global.oItemLoader:Create(iEquipSid, {engage_text=sFemaleText,degree=iMaleDegree})
    local oItem2 = global.oItemLoader:Create(iEquipSid, {engage_text=sMaleText,degree=iFemaleDegree})

    local oMaleFriend = oMale:GetFriend()
    local oFemaleFriend = oFemale:GetFriend()
    oMaleFriend:SetRelation(iFemale, defines.RELATION_ENGAGE)
    oFemaleFriend:SetRelation(iMale, defines.RELATION_ENGAGE)

    oMale.m_oMarryCtrl:SetEngageRelation(oFemale, iType, (iRunner==iMale), oItem1)
    oFemale.m_oMarryCtrl:SetEngageRelation(oMale, iType, (iRunner==iFemale), oItem2)
    oMaleFriend:AddSaveMerge(oFemaleFriend)
    global.oTitleMgr:AddTitle(oMale:GetPid(), self:GetTitleBySex(oMale:GetSex()))
    global.oTitleMgr:AddTitle(oFemale:GetPid(), self:GetTitleBySex(oFemale:GetSex()))
    oMale.m_oSkillCtrl:AddMarsySkill(8501)
    oMale.m_oSkillCtrl:GS2CMarrySkill(oMale)
    oFemale.m_oSkillCtrl:AddMarsySkill(8501)
    oFemale.m_oSkillCtrl:GS2CMarrySkill(oFemale)

    oMale:PropChange("engage_info")
    oMale:SyncSceneInfo({engage_pid=oFemale:GetPid()})
    oFemale:PropChange("engage_info")
    oFemale:SyncSceneInfo({engage_pid=oMale:GetPid()})
    oMale:Send("GS2CEngageSuccess", {type=iType})
    oFemale:Send("GS2CEngageSuccess", {type=iType})
    oMale:NotifyMessage(self:GetText(1016))
    oFemale:NotifyMessage(self:GetText(1016))
    oMale:MarkGrow(48)
    oFemale:MarkGrow(48)

    local mLogData = oMale:LogData()
    mLogData["type"] = iType
    mLogData["engage_pid"] = oFemale:GetPid()
    record.log_db("friend", "engage", mLogData)
end

function CEngageMgr:SendEngageMsg(oMale, oFemale, iType, iEngageNo, sMaleText, sFemaleText)
    local sMaleName, sFemaleName = oMale:GetName(), oFemale:GetName()
    local sHorse = self:GetText(1018, {role={sMaleName, sFemaleName}, amount=iEngageNo})
    global.oChatMgr:HandleSysChat(sHorse, gamedefines.SYS_CHANNEL_TAG.RUMOUR_TAG, 1)
    
    local sChat = self:GetText(1019)
    sChat = string.format(sChat, sMaleName, sFemaleName, iEngageNo, 
        sMaleName, sFemaleName, sMaleText, sFemaleName, sMaleName, sFemaleText)
    global.oChatMgr:SendMsg2World(sChat)        
end

function CEngageMgr:SendEngageMail(oMale, oFemale, iType, iEngageNo)
    local oMailMgr = global.oMailMgr
    local oToolMgr = global.oToolMgr

    local lMails = self:GetSuccessMails(iType)
    local iMaleMail, iFemaleMail = lMails[1], lMails[2]
    local mData, sName = oMailMgr:GetMailInfo(iMaleMail)
    local mInfo = table_copy(mData)
    local mReplace = {role=oFemale:GetName()}
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, mReplace)
    oMailMgr:SendMail(0, sName, oMale:GetPid(), mInfo, 0)

    local mData, sName = oMailMgr:GetMailInfo(iFemaleMail)
    local mInfo = table_copy(mData)
    local mReplace = {role=oMale:GetName()}
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, mReplace)
    oMailMgr:SendMail(0, sName, oFemale:GetPid(), mInfo, 0)
end

function CEngageMgr:DissolveEngage(oPlayer, bGm)
    local oFriend = oPlayer:GetFriend()
    local iTarget = oPlayer:GetCouplePid()
    local sTargetName = oPlayer:GetCoupleName()
    local iType = oPlayer:GetEngageType()
    if not iTarget then
        oPlayer:NotifyMessage(self:GetText(1017))
        return 
    end 

    local iSilver = self:GetDissolveSliver(iType, oPlayer.m_oMarryCtrl:IsActive())
    if not bGm then
        if not oPlayer:ValidSilver(iSilver) then return end

        oPlayer:ResumeSilver(iSilver, "解除订婚")
    end
    self:OnDissolveEngage(oPlayer)
    local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if oTarget then
        self:OnDissolveEngage(oTarget)                
    else
        global.oPubMgr:OnlineExecute(iTarget, "DissolveEngage", {})
    end

    local oMailMgr = global.oMailMgr
    local oToolMgr = global.oToolMgr
    local lMails = self:GetDissolveMails(iType)
    local iMail1, iMail2 = lMails[1], lMails[2]
    local mData, sName = oMailMgr:GetMailInfo(iMail1)
    local mInfo = table_copy(mData)
    local mReplace = {role=sTargetName}
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, mReplace)
    oMailMgr:SendMail(0, sName, oPlayer:GetPid(), mInfo, 0)

    local mData, sName = oMailMgr:GetMailInfo(iMail2)
    local mInfo = table_copy(mData)
    local mReplace = {role=oPlayer:GetName()}
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, mReplace)
    oMailMgr:SendMail(0, sName, iTarget, mInfo, 0)
    oPlayer:NotifyMessage(self:GetText(1023, {role=sTargetName}))

    local mLogData = oPlayer:LogData()
    mLogData["silver"] = iSilver
    mLogData["engage_pid"] = iTarget
    mLogData["type"] = iType
    record.log_db("friend", "dissolve_engage", mLogData)
end

function CEngageMgr:OnDissolveEngage(oPlayer)
    global.oTitleMgr:RemoveTitles(oPlayer:GetPid(), table_value_list(TITLE_ID))

    local oFriend = oPlayer:GetFriend()
    local iTarget = oPlayer:GetCouplePid()
    local iType = oPlayer:GetEngageType()
    if not iTarget then return end

    local oFriend = oPlayer:GetFriend()
    oFriend:ResetRelation(iTarget, defines.RELATION_ENGAGE)
    oPlayer.m_oMarryCtrl:ResetRelation()
    oPlayer:PropChange("engage_info")
    oPlayer:SyncSceneInfo({engage_pid=0})
    oPlayer.m_oSkillCtrl:RemoveMarrySkill(8501)
    oPlayer.m_oSkillCtrl:GS2CMarrySkill(oPlayer)

    local oTeam = oPlayer:HasTeam()
    if oTeam then
        local oMember = oTeam:GetMember(oPlayer:GetPid())
        if oMember then
            oMember:Update({engage=0})
        end
    end
end

function CEngageMgr:OnPlayerRename(iPid, sNewName)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        local iTarget = oPlayer:GetCouplePid()
        self:UpdateCoupleName(iTarget, sNewName)
    else
        oWorldMgr:LoadProfile(iPid, function (oProfile)
            if oProfile then
                local iTarget = oProfile:GetCouplePid()
                self:UpdateCoupleName(iTarget, sNewName)
            end
        end)
    end
end

function CEngageMgr:UpdateCoupleName(iTarPid, sName)
    if not iTarPid or iTarPid <= 0 then return end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iTarPid)
    if oPlayer then
        oPlayer:SyncMarryCoupleName(sName)
        oPlayer:PropChange("engage_info")
        local iTit = self:GetTitleBySex(oPlayer:GetSex())
        global.oTitleMgr:SyncTitleName(iTarPid, iTit) 
    else
        local oPubMgr = global.oPubMgr
        oPubMgr:OnlineExecute(iTarPid, "SyncMarryCoupleName", {sName})
    end
end

function CEngageMgr:OnLogin(oPlayer, bReEnter)
    self:CheckEngage(oPlayer)
end

function CEngageMgr:CheckEngage(oPlayer)
    local oEngage = self:GetEngageByPid(oPlayer:GetPid())
    if not oEngage then return end

    if oEngage:Status() == STATUS_CONFIRM then
        self:GS2CEngageCondition(oPlayer, oEngage:Type())
    elseif oEngage:Status() == STATUS_SET_TEXT then
        oPlayer:Send("GS2CSetEngageTextUI", {})
    end      
end

function CEngageMgr:OnLeaveTeam(iPid)
    local oEngage = self:GetEngageByPid(iPid)
    if not oEngage then return end

    local iMale = oEngage:MalePid()
    local iFemale = oEngage:FemalePid()
    self:RemoveEngage(oEngage)
    local oMale = global.oWorldMgr:GetOnlinePlayerByPid(iMale)
    if oMale then
        oMale:Send("GS2CCancelEngage", {})
        if iPid ~= iMale then
            oMale:NotifyMessage(self:GetText(1029))
        end
    end
    local oFeMale = global.oWorldMgr:GetOnlinePlayerByPid(iFemale)
    if oFeMale then
        oFeMale:Send("GS2CCancelEngage", {}) 
        if iPid ~= iFemale then
           oMale:NotifyMessage(self:GetText(1029)) 
        end
    end
end

function CEngageMgr:GetEngageByPid(iPid)
    return self.m_mPid2Engage[iPid]
end

function CEngageMgr:AddEngage(oEngage)
    self.m_mEngage[oEngage:EID()] = oEngage
    self.m_mPid2Engage[oEngage:MalePid()] = oEngage
    self.m_mPid2Engage[oEngage:FemalePid()] = oEngage
end

function CEngageMgr:RemoveEngage(oEngage)
    self.m_mEngage[oEngage:EID()] = nil 
    self.m_mPid2Engage[oEngage:MalePid()] = nil
    self.m_mPid2Engage[oEngage:FemalePid()] = nil
    baseobj_delay_release(oEngage)
end

function CEngageMgr:MergeFrom(mFromData)
    if not mFromData then return true end
    
    print("CEngageMgr merger............... ", self.m_iEngageNo)
    self:Dirty()
    self.m_iEngageNo = self.m_iEngageNo + mFromData.engage_no
    print("CEngageMgr merger............... ", self.m_iEngageNo)
    return true
end

function CEngageMgr:GetTitleBySex(iSex)
    return TITLE_ID[iSex]
end

function CEngageMgr:GetDissolveSliver(iType, bActive)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    if bActive then
        return mData["dissolve_silver"]
    else
        return mData["dissolve_silver2"]
    end
end

function CEngageMgr:GetCostSid(iType)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    return mData["cost"]
end

function CEngageMgr:GetRewardEquipSid(iType)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    return mData["reward_equip"]
end

function CEngageMgr:GetRewards(iType)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    return mData["reward"]
end

function CEngageMgr:GetSuccessMails(iType)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    return mData["success_mail"]
end

function CEngageMgr:GetDissolveMails(iType)
    local mData = res["daobiao"]["engage"]["engagetype"][iType]
    return mData["dissolve_mail"]
end

function CEngageMgr:GetLimitGrade()
    local mData = res["daobiao"]["open"]["ENGAGE_SYS"]
    return mData["p_level"] 
end

function CEngageMgr:GetConfigInfo(sKey)
    local mData = res["daobiao"]["engage"]["config"][1]
    return mData[sKey]
end

function CEngageMgr:GetText(iText, mReplace)
    return global.oToolMgr:GetSystemText({"engage"}, iText, mReplace)
end

------------------------------

function NewEngageObj(...)
    return CEngageObj:New(...)
end

CEngageObj = {}
CEngageObj.__index = CEngageObj
inherit(CEngageObj, datactrl.CDataCtrl)

function CEngageObj:New(iEid, iType, iRunner, iMale, iFemale)
    local o = super(CEngageObj).New(self)
    o.m_iEid = iEid
    o.m_iType = iType
    o.m_iRunner = iRunner
    o.m_iMalePid = iMale
    o.m_iFemalePid = iFemale
    o.m_mEngageText = {}
    o.m_iCreateTime = get_time()
    o.m_iStatus = STATUS_START
    return o
end

function CEngageObj:EID()
    return self.m_iEid
end

function CEngageObj:Type()
    return self.m_iType
end

function CEngageObj:RunnerPid()
    return self.m_iRunner
end

function CEngageObj:TragetPid()
    if self.m_iMalePid == self.m_iRunner then
        return self.m_iFemalePid
    else
        return self.m_iMalePid
    end
end

function CEngageObj:MalePid()
    return self.m_iMalePid
end

function CEngageObj:FemalePid()
    return self.m_iFemalePid
end

function CEngageObj:SetMaleText(sText)
    self.m_mEngageText[self.m_iMalePid] = sText
end

function CEngageObj:SetFeMaleText(sText)
    self.m_mEngageText[self.m_iFemalePid] = sText
end

function CEngageObj:GetEngageText(iPid)
    return self.m_mEngageText[iPid]
end

function CEngageObj:Status()
    return self.m_iStatus
end

function CEngageObj:SetStatus(iStatus)
    self.m_iStatus = iStatus
end

