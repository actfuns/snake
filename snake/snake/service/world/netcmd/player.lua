local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local res = require "base.res"
local extend = require "base.extend"
local net = require "base.net"

local waiguan = import(service_path("playerctrl.baseobj.waiguan"))

function C2GSSelectPointPlan(oPlayer, mData)
    if not oPlayer then
        return
    end
    local iNewPlan = mData["plan_id"]
    oPlayer.m_oBaseCtrl:StartPlanPoint(iNewPlan)
end

function C2GSAddPoint(oPlayer, mData)
    if not oPlayer then
        return
    end
    if next(mData) then
        oPlayer.m_oBaseCtrl:AddPlanPoint(mData["point_info"])
    end
end

function C2GSWashPoint(oPlayer, mData)
    if not oPlayer then
        return
    end
    local sProp = mData["prop_name"]
    local iFlag = mData["flag"]
    oPlayer.m_oBaseCtrl:WashPoint(sProp, iFlag)
end

function C2GSWashAllPoint(oPlayer, mData)
    if not oPlayer then
        return
    end
    oPlayer.m_oBaseCtrl:WashAllPoint()
end

function C2GSGetSecondProp(oPlayer, mData)
    if not oPlayer then
        return
    end
    local record = require "public.record"
    record.warning("liuzla-- C2GSGetSecondProp proto type need delete after client deal")
    local mPropInfo = {}
    local lSecondProp = {"speed","mag_defense","phy_defense","mag_attack","phy_attack","max_hp", "max_mp"}
    for _, sProp in pairs(lSecondProp) do
        local mData = {}
        mData.extra = oPlayer:GetAttrAdd(sProp) * 1000
        mData.ratio = oPlayer:GetBaseRatio(sProp) * 1000
        mData.name = sProp
        table.insert(mPropInfo, mData)
    end
    local mNet = {}
    mNet["prop_info"] = mPropInfo
    oPlayer:Send("GS2CGetSecondProp", mNet)
end

function _SendPlayerInfo(pid,oProfile)
    local oWorldMgr = global.oWorldMgr
    local oTeamMgr = global.oTeamMgr
    local oOrgMgr = global.oOrgMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oTeam = oPlayer:HasTeam()
    local mNet = {}
    mNet["pid"] = oProfile:GetInfo("pid")
    mNet["grade"] = oProfile.m_iGrade
    mNet["name"] = oProfile.m_sName
    mNet["icon"] = oProfile.m_iIcon
    mNet["school"] = oProfile.m_iSchool
    mNet["model_info"] = oProfile:GetModelInfo()
    mNet["position"] = oProfile:GetPosition()
    mNet["position_hide"] = oProfile:GetPositionHide()
    -- if oTeam then
    --     mNet["team_id"] = oTeam.m_ID
    --     mNet["team_size"] = oTeam:TeamSize()
    -- end
    local oOrg = oOrgMgr:GetNormalOrg(oProfile:GetOrgID())
    if oOrg then
        mNet["org_id"] = oOrg:OrgID()
        mNet["org_name"] = oOrg:GetName()
        mNet["org_level"] = oOrg:GetLevel()
        mNet["org_pos"] = oOrg:GetPosition(oProfile:GetInfo("pid"))
        mNet["org_chat"] = oOrg:GetChatStatus(oProfile:GetInfo("pid"))
    end
    oPlayer:Send("GS2CGetPlayerInfo", mNet)
end

function C2GSGetPlayerInfo(oPlayer, mData)
    if not oPlayer then
        return
    end
    local pid = oPlayer.m_iPid
    local target_pid = mData["pid"]
    local oWorldMgr = global.oWorldMgr
    local oOrgMgr = global.oOrgMgr
    local oAnotherPlayer = oWorldMgr:GetOnlinePlayerByPid(target_pid)
    local mNet = {}
    if oAnotherPlayer then
        mNet["pid"] = target_pid
        mNet["grade"] = oAnotherPlayer:GetGrade()
        mNet["name"] = oAnotherPlayer:GetName()
        mNet["icon"] = oAnotherPlayer:GetIcon()
        mNet["school"] = oAnotherPlayer:GetSchool()
        mNet["model_info"] = oAnotherPlayer:GetModelInfo()
        mNet["team_id"] = oAnotherPlayer:TeamID()
        mNet["team_size"] = oAnotherPlayer:GetTeamSize()
        mNet["position"] = oAnotherPlayer:GetPosition()
        mNet["position_hide"] = oAnotherPlayer:GetPositionHide()
        local oOrg
        if oOrgMgr then
            oOrg = oOrgMgr:GetNormalOrg(oAnotherPlayer:GetOrgID())
        end
        if oOrg then
            mNet["org_id"] = oOrg:OrgID()
            mNet["org_name"] = oOrg:GetName()
            mNet["org_level"] = oOrg:GetLevel()
            mNet["org_pos"] = oOrg:GetPosition(target_pid)
            mNet["org_chat"] = oOrg:GetChatStatus(target_pid)
        end
        oPlayer:Send("GS2CGetPlayerInfo", mNet)
    else
        if is_ks_server() then return end

        local func = function (oProfile)
            if oProfile then
                _SendPlayerInfo(pid,oProfile)
            end
        end
        oWorldMgr:LoadProfile(target_pid,func)
    end
end

function C2GSPlayerItemInfo(oPlayer, mData)
    if not oPlayer then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iTargetPid = mData["pid"]
    local itemid = mData["itemid"]
    local pid = oPlayer:GetPid()
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
    if oTarget then
        local oItem = oTarget.m_oItemCtrl:HasItem(itemid, true)
        if oItem then
            local mNet = {}
            mNet["pid"] = iTargetPid
            mNet["itemdata"] = oItem:PackShowItemInfo(oTarget)
            oPlayer:Send("GS2CPlayerItemInfo", mNet)
        else
            oNotifyMgr:Notify(pid, "该链接已经失效")
        end
    else
        oNotifyMgr:Notify(pid, "该链接已经失效")
    end
end

function C2GSPlayerSummonInfo(oPlayer, mData)
    if not oPlayer then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr
    local iTargetPid = mData["pid"]
    local summonid = mData["summonid"]
    local pid = oPlayer:GetPid()
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTargetPid)
    if oTarget then
        local oSummon = oTarget.m_oSummonCtrl:GetSummon(summonid)
        if oSummon then
            local mNet = {}
            mNet["pid"] = iTargetPid
            mNet["summondata"] = oSummon:SummonInfo()
            oPlayer:Send("GS2CPlayerSummonInfo", mNet)
        else
            oNotifyMgr:Notify(pid, "该链接已经失效")
        end
    else
        oNotifyMgr:Notify(pid, "该链接已经失效")
    end
end

function C2GSPlayerPartnerInfo(oPlayer, mData)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local iTarget = mData.pid
    local iPid = oPlayer:GetPid()
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)
    if not oTarget then
        oNotifyMgr:Notify(iPid, "该链接已经失效")
        return
    end
    local iPartner = mData.partner
    local oPartner = oTarget.m_oPartnerCtrl:GetPartner(iPartner)
    if not oPartner then
        oNotifyMgr:Notify(iPid, "该链接已经失效")
        return
    end
    
    local mNet = {}
    mNet.pid = iTarget
    mNet.partnerdata = oPartner:PartnerInfo()
    oPlayer:Send("GS2CPlayerPartnerInfo", mNet)
end

function C2GSNameCardInfo(oPlayer, mData)
    local iTargetPid = mData["pid"]
    local oFriendMgr = global.oFriendMgr
    oFriendMgr:SendNameCardInfo(oPlayer, iTargetPid)
end

function C2GSUpvotePlayer(oPlayer, mData)
    local oWorldMgr = global.oWorldMgr
    local oNotifyMgr = global.oNotifyMgr

    local iPid = oPlayer:GetPid()
    if oPlayer:GetGrade() < 30 then
        oNotifyMgr:Notify(iPid, "点赞需要等级达到30级")
        return
    end

    if is_ks_server() then return end

    local iTarget = mData.pid
    oWorldMgr:LoadProfile(iTarget, function (obj)
        if obj then
            obj:AddUpvote(iPid)
        end
    end)
end

function C2GSPlayerUpvoteInfo(oPlayer, mData)
    if is_ks_server() then
        oPlayer:NotifyMessage("跨服无法查看")
        return
    end
    local oWorldMgr = global.oWorldMgr
    local pid = oPlayer:GetPid()
    local iTarget = mData["pid"]
    oWorldMgr:LoadProfile(iTarget, function(obj)
        C2GSPlayerUpvoteInfo1(pid, obj)
    end)
end

function C2GSPlayerUpvoteInfo1(iPid, oProfile)
    if not oProfile then return end

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local lUpvote = oProfile:GetUpvoteList()
    if #lUpvote < 1 then
        oPlayer:Send("GS2CPlayerUpvoteInfo",{info = {}})
        return
    end

    table.sort(lUpvote, function(x, y)
        return x[2] > y[2]
    end)

    local iCount = math.min(10, #lUpvote)
    local lPack = {}
    for i = 1, iCount do
        local mInfo = lUpvote[i]
        local iTarget = mInfo[1]

        local oTarget = oWorldMgr:GetOnlinePlayerByPid(iTarget)
        if oTarget then
            SendUpvoteInfo(iPid, i, iCount, lPack, oTarget)
        else
            oWorldMgr:LoadProfile(iTarget, function(obj)
                SendUpvoteInfo(iPid, i, iCount, lPack, obj)
            end)
        end
    end
end

function SendUpvoteInfo(iPid, idx, iCount, lPack, obj)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end

    local mData = {
        pid = obj:GetPid(),
        name = obj:GetName(),
        grade = obj:GetGrade(),
        model_info = obj:GetModelInfo(),
        school = obj:GetSchool(),
    }
    lPack[idx] = mData
    if table_count(lPack) >= iCount then
        oPlayer:Send("GS2CPlayerUpvoteInfo",{info = lPack})
    end
end

function C2GSUpvoteReward(oPlayer, mData)
    if is_ks_server() then return end

    local idx = mData.idx
    local oProfile = oPlayer:GetProfile()
    oProfile:C2GSUpvoteReward(idx)
end

function C2GSRename(oPlayer, mData)
    if is_ks_server() then return end

    local oRenameMgr = global.oRenameMgr
    oRenameMgr:DoRename(oPlayer, mData.rename)
end

function C2GSHidePosition(oPlayer, mData)
    if not oPlayer then
        return
    end
    local iHide = mData["hide"]
    local iOld = oPlayer:GetPositionHide()
    if iHide == iOld then
        return
    end
    if iHide == 0 then
        oPlayer.m_oBaseCtrl:SetData("position_hide", 0)
    else
        oPlayer.m_oBaseCtrl:SetData("position_hide", 1)
    end
    oPlayer:PropChange("position_hide")
end

function C2GSObserverWar(oPlayer, mData)
    if oPlayer:HasTeam() and not oPlayer:IsTeamLeader() and not oPlayer:IsSingle() then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), "请暂离队伍后再进行观战")
        return
    end
    if oPlayer.m_oActiveCtrl:GetNowWar() then
        global.oNotifyMgr:Notify(oPlayer:GetPid(), "请结束战斗后再进行观战")
        return
    end

    local iCamp = mData.camp_id
    local iNpc = mData.npc_id
    if iNpc and iNpc > 0 then
        local oNpc = global.oNpcMgr:GetObject(iNpc)
        if not oNpc then
            global.oNotifyMgr:Notify(oPlayer:GetPid(), "战斗已结束")
            return
        end
        local oWar = oNpc:InWar()
        if not oWar then
            global.oNotifyMgr:Notify(oPlayer:GetPid(), "战斗已结束")
            return
        end

        local mArgs = {camp_id = iCamp, npc_id = iNpc}
        if oPlayer:IsSingle() then
            global.oWarMgr:ObserverEnterWar(oPlayer, oWar:GetWarId(), mArgs)
        else
            global.oWarMgr:TeamObserverEnterWar(oPlayer, oWar:GetWarId(), mArgs)
        end
    end
    local iTarget = mData.target
    if iTarget and iTarget > 0 then
        local oTarget = global.oWorldMgr:GetOnlinePlayerByPid(iTarget)
        if not oTarget then return end
        local oWar = oTarget.m_oActiveCtrl:GetNowWar()
        if not oWar then
            global.oNotifyMgr:Notify(oPlayer:GetPid(), "战斗已结束")
            return
        end

        local mArgs = {camp_id = iCamp, target = iTarget}
        if oPlayer:IsSingle() then
            global.oWarMgr:ObserverEnterWar(oPlayer, oWar:GetWarId(), mArgs)
        else
            global.oWarMgr:TeamObserverEnterWar(oPlayer, oWar:GetWarId(), mArgs)
        end
    end
end

function C2GSLeaveObserverWar(oPlayer, mData)
    local iWar = mData.war_id
    local oWar = global.oWarMgr:GetWar(iWar)
    if not oWar then return end

    if oWar.m_mObservers[oPlayer:GetPid()] then
        if oPlayer:IsTeamLeader() then
            global.oWarMgr:TeamLeaveObserverWar(oPlayer, true)
        else
            global.oWarMgr:LeaveWar(oPlayer, true)
        end
    end
end

function C2GSSysConfig(oPlayer, mData)
    -- mData = net.UnMask("C2GSSysConfig", mData)
    if is_ks_server() then
        oPlayer:NotifyMessage("跨服暂不支持此操作")
        return
    end
    oPlayer.m_oBaseCtrl.m_oSysConfigMgr:CallChangeConfig(mData.on_off, mData.values)
end

function C2GSRewardGradeGift(oPlayer, mData)
    oPlayer.m_oActiveCtrl.m_oGiftMgr:CallRewardGradeGift(mData.grade)
end

function C2GSRewardPreopenGift(oPlayer, mData)
    oPlayer.m_oActiveCtrl.m_oGiftMgr:CallRewardPreopenGift(mData.sys_id)
end

function C2GSGetScore(oPlayer,mData)
    if mData.op == 1 then
        oPlayer:Send("GS2CGetScore",{op = mData.op,score = oPlayer:GetScore()})
    elseif mData.op == 2 then
        oPlayer:Send("GS2CGetScore",{op = mData.op,score = oPlayer:GetRoleScore()})
    elseif mData.op == 3 then
        oPlayer:Send("GS2CGetScore",{op = mData.op,score = oPlayer.m_oSummonCtrl:GetMaxScore()})
    elseif mData.op == 4 then
        oPlayer:Send("GS2CGetScore",{op = mData.op,score = oPlayer.m_oThisWeek:Query("flower", 0)})
    elseif mData.op > 200 then
        local mRank = res["daobiao"]["rank"][mData.op]
        if not mRank then
            oPlayer:Send("GS2CGetScore",{op = mData.op,score = 0})
        else
            local sKey = mRank.name .. "cnt"
            local mNet = {
                op = mData.op,
                score = oPlayer.m_oTodayMorning:Query(sKey, 0),
            }
            oPlayer:Send("GS2CGetScore", mNet)
        end
    end
end

function C2GSGetPromote(oPlayer,mData)
    oPlayer.m_mPromoteCtrl:TriggerPromote(oPlayer,3)
end

function C2GSPlayerRanSe(oPlayer,mData)
    local clothcolor = mData.clothcolor
    local haircolor = mData.haircolor 
    local pantcolor = mData.pantcolor 
    local iFlag = mData.flag
    if not global.oToolMgr:IsSysOpen("RANSE",oPlayer) then    
        return 
    end
    waiguan.PlayerRanse(oPlayer,clothcolor,haircolor,pantcolor,iFlag)
end

function C2GSOpenShiZhuang(oPlayer,mData)
    local iType = mData.type 
    local iSZ = mData.sz 
    if not global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer) then    
        return 
    end
    if is_ks_server() then
        oPlayer:NotifyMessage("跨服暂不支持此操作")
        return
    end
    waiguan.OpenShiZhuang(oPlayer,iSZ,iType)
end

function C2GSSetSZ(oPlayer,mData)
    local iSZ = mData.sz 
    if not global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer) then    
        return 
    end
    waiguan.SetCurSZ(oPlayer,iSZ)
end

function C2GSSZRanse(oPlayer,mData)
    local iSZ = mData.sz
    local iFlag = mData.flag
    local clothcolor = mData.clothcolor
    local haircolor = mData.haircolor 
    local pantcolor = mData.pantcolor 
    if not global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer) then    
        return 
    end
    waiguan.SetShiZhuangRanse(oPlayer, iSZ, clothcolor, haircolor, pantcolor, iFlag)
    -- waiguan.UnLockSZRanse(oPlayer,iSZ,iColor, iFlag)
end

function C2GSSetSZColor(oPlayer,mData)
    print("error not find C2GSSetSZColor")
    -- local iSZ = mData.sz
    -- local iColor = mData.color 
    -- if not global.oToolMgr:IsSysOpen("SHIZHUANG",oPlayer) then    
    --     return 
    -- end
    -- waiguan.SetSZColor(oPlayer,iSZ,iColor)
end

function C2GSGamePushConfig(oPlayer, mData)
    oPlayer.m_oBaseCtrl.m_oGamePushMgr:CallChangeConfig(mData.values)
end

function C2GSGetAllSZInfo(oPlayer,mData)
    local oNotifyMgr = global.oNotifyMgr
    local sMsg = res["daobiao"]["ranse"]["text"][3006]["text"]
    local LIMIT_SZ_GRADE = res["daobiao"]["open"]["SHIZHUANG"]["p_level"]
    sMsg = string.gsub(sMsg,"#level",LIMIT_SZ_GRADE)
    if not global.oToolMgr:IsSysOpen("SHIZHUANG", oPlayer, false, {plevel_tips=sMsg}) then   
        return
    end
    oPlayer.m_oBaseCtrl.m_oWaiGuan:GS2CAllShiZhuang()
end

function C2GSSyncPosition(oPlayer, mData)
    oPlayer.m_oBaseCtrl:SetData("position", mData.position)
    oPlayer:PropChange("position")
end
