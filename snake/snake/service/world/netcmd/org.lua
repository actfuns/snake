-- import module
local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"
local interactive = require "base.interactive"

local orgdefines = import(service_path("org.orgdefines"))

function C2GSOrgList(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

    local oOrgMgr = global.oOrgMgr
    if oPlayer:GetOrgID() ~= 0 then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1021))
        return
    end
    global.oVersionMgr:C2GSOrgList(oPlayer, mData.version)
    -- local mNet = {}
    -- for _, mOrgInfo in pairs(oOrgMgr:GetOrgListCache()) do
    --     local orgid = mOrgInfo.orgid
    --     local oOrg = oOrgMgr:GetNormalOrg(orgid)
    --     if oOrg then
    --         local mInfo = table_copy(mOrgInfo)
    --         local oMem = oOrg:GetApplyInfo(pid)
    --         if oMem and not oMem:VaildApplyTime() then
    --             oOrg:RemoveApply(pid)
    --         end 
    --         mInfo.hasapply = oOrg:HasApply(pid)
    --         if oPlayer:HasFriend(oOrg:GetLeaderID()) then
    --             mInfo.isfriend=1
    --         end
    --         table.insert(mNet, mInfo)
    --     end
    -- end
    -- oPlayer:Send("GS2COrgList",{infos=mNet, left_time=oOrgMgr:GetMulApplyLeftTime(pid)})
end

function C2GSSearchOrg(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

    local sText = mData.text
    local oOrgMgr = global.oOrgMgr
    local orgid = tonumber(sText)
    local mNet = {}
    local orgids = {}
    if orgid then
        local iRealId = oOrgMgr:GetOrgIdByShowId(orgid)
        local oOrg = oOrgMgr:GetNormalOrg(iRealId)
        if oOrg then
            local mInfo = oOrg:PackOrgListInfo()
            mInfo.hasapply = oOrg:HasApply(pid)
            table.insert(mNet, mInfo)
            orgids[iRealId] = true
        end
    end

    local l = {"(", ")", ".", "%", "+", "-", "*", "?", "[", "^", "$"}
    local sNewText = ""
    for i=1,#sText do
        local sChar = index_string(sText, i)
        if table_in_list(l, sChar) then
            sChar = "%"..sChar 
        end
        sNewText = sNewText..sChar
    end
    for iOrg, oOrg in pairs(oOrgMgr:GetNormalOrgs()) do
        local sName = oOrg:GetName()
        if not orgids[iOrg] and string.match(sName, sNewText) then
            local mInfo = oOrg:PackOrgListInfo()
            mInfo.hasapply = oOrg:HasApply(pid)
            table.insert(mNet, mInfo)
        end
    end
    oPlayer:Send("GS2COrgResultList",{infos=mNet})
end

-- 创建帮派
function C2GSCreateOrg(oPlayer, mData)
    local sName = mData.name
    local sAim = mData.aim

    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_CJ", oPlayer) then return end

    local oOrgMgr = global.oOrgMgr
    if oPlayer:GetOrgID() ~= 0 then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1021))
        return
    end
    -- TODO new createorg
    oOrgMgr:CreateNormalOrg(oPlayer, sName, sAim)
    -- oOrgMgr:CreateReadyOrg(oPlayer, sName, sAim)
end

-- 申请入帮
function C2GSApplyJoinOrg(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

    local iOrgID = mData.orgid
    local flag = mData.flag 
    
    local oOrgMgr = global.oOrgMgr
    if oPlayer:GetOrgID() ~= 0 then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1021))
        return
    end
    local oOrg = oOrgMgr:GetNormalOrg(iOrgID)
    if not oOrg then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1000))
        oPlayer:Send("GS2CDelOrgList", {orgids={iOrgID}})
        return
    end

    if flag == 0 then
        if oOrg:GetApplyInfo(oPlayer:GetPid()) then
            oOrg:RemoveApply(oPlayer:GetPid())
        end
    else
        if oOrgMgr:GetReadyOrgByPid(oPlayer:GetPid()) then
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1003))
            return
        end
        if not oOrg:GetApplyInfo(oPlayer:GetPid()) then
            oOrg:AddApply(oPlayer, orgdefines.ORG_APPLY.APPLY)
        end
    end
    oPlayer:Send("GS2CApplyJoinOrg",{flag=flag, orgid=iOrgID})
end

-- 一键申请入帮
function C2GSMultiApplyJoinOrg(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

    local oOrgMgr = global.oOrgMgr
    if oPlayer:GetOrgID() ~= 0 then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1021))
        return
    end
    local iPid = oPlayer:GetPid()
    local oOrgMgr = global.oOrgMgr
    if oOrgMgr:GetReadyOrgByPid(iPid) then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1003))
        return
    end
    if oOrgMgr:GetMulApplyLeftTime(iPid)  > 0 and not oPlayer:Query("testman", 0) then
        oPlayer:NotifyMessage(string.format("冷却中 %s", get_second2string(oOrgMgr:GetMulApplyLeftTime(iPid))))
        return
    end
    oOrgMgr:SetMulApplyTime(iPid)
    local lNet, iText = oOrgMgr:MultiApplyJoinOrg(oPlayer)
    if not lNet then
        return
    end
    if #lNet <= 0 and not oPlayer:GetOrg() and iText then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(iText))
        return
    end
    oPlayer:Send("GS2CApplyJoinOrgResult",{orgids=lNet, left_time=oOrgMgr:GetMulApplyLeftTime(iPid)})
end

-- 请求待响应帮派列表
-- function C2GSReadyOrgList(oPlayer, mData)
--     local oToolMgr = global.oToolMgr
--     if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

--     if oPlayer:GetOrgID() ~= 0 then
--         return
--     end
--     local oOrgMgr = global.oOrgMgr
--     local pid = oPlayer:GetPid()
--     local mNet = {}
--     for orgid, oOrg in pairs(oOrgMgr:GetReadyOrgs()) do
--         local mInfo = oOrg:PackReadyOrgListInfo()
--         mInfo.hasrespond = oOrg:HasRespond(pid)
--         if oPlayer:HasFriend(oOrg:GetLeader()) then
--             mInfo.isfriend=1
--         end
--         table.insert(mNet, mInfo)
--     end
--     oPlayer:Send("GS2CReadyOrgList",{infos=mNet})
-- end

-- -- 请求待响应帮派信息
-- function C2GSReadyOrgInfo(oPlayer, mData)
--     local oToolMgr = global.oToolMgr
--     if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

--     local iOrgID = mData.orgid
--     local oOrgMgr = global.oOrgMgr
--     local oOrg = oOrgMgr:GetReadyOrg(iOrgID)
--     local mNet = {}
--     if not oOrg then
--         oPlayer:NotifyMessage("帮派已创建或创建失败")
--         table.insert(mNet, iOrgID)
--         oPlayer:Send("GS2CDelResponseList",{orgids=mNet})
--         return
--     end
--     mNet = oOrg:PackReadyOrgInfo()
--     oPlayer:Send("GS2CReadyOrgInfo", mNet)
-- end

-- -- 响应帮派
-- function C2GSRespondOrg(oPlayer, mData)
--     local oToolMgr = global.oToolMgr
--     if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

--     local oOrgMgr = global.oOrgMgr
--     if oPlayer:GetOrgID() ~= 0 then
--         oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1021))
--         return
--     end

--     local iPid = oPlayer:GetPid()
--     if oOrgMgr:GetReadyOrgByPid(iPid) then
--         oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1003))
--         return
--     end

--     local iOrgID = mData.orgid
--     local flag = mData.flag
--     local oReadyOrg = oOrgMgr:GetReadyOrg(iOrgID)
--     if not oReadyOrg then
--         oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1024))
--         return 
--     end
    
--     local mLog = oPlayer:LogData()
--     mLog["org_id"] = iOrgID
    
--     if flag == 0 then
--         if not oReadyOrg:GetRespondInfo(iPid) then return end
            
--         oReadyOrg:DelRespond(iPid)
--         oPlayer:Send("GS2CRespondOrg", {flag=flag, orgid=iOrgID, respondcnt=oReadyOrg:RespondCnt()})
        
--         mLog["flag"] = 0    
--         record.log_db("org", "org_response", mLog)
--     else
--         if oReadyOrg:GetRespondInfo(iPid) then
--             oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1023))
--             return
--         end
--         oReadyOrg:AddRespond(oPlayer)
--         oPlayer:Send("GS2CRespondOrg", {flag=flag, orgid=iOrgID, respondcnt=oReadyOrg:RespondCnt()})
--         if oReadyOrg:RespondCnt() + oPlayer:Query("testman", 0) >= oOrgMgr:GetMaxRespondCnt() then
--             oPlayer:Send("GS2CJoinOrgResult", {flag=1, orgid=iOrgID})
--             oOrgMgr:CreateNormalOrg(oReadyOrg)
--         end
--         mLog["flag"] = 1
--         record.log_db("org", "org_response", mLog)        
--     end
    
--     local oInterfaceMgr = global.oInterfaceMgr
--     oInterfaceMgr:RefreshOrgRespond({infos={oReadyOrg:PackRespondInfo()}})
-- end

-- -- 一键响应
-- function C2GSMultiRespondOrg(oPlayer, mData)
--     local oToolMgr = global.oToolMgr
--     if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

--     local oOrgMgr = global.oOrgMgr
--     if oPlayer:GetOrgID() ~= 0 then
--         oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1021))
--         return
--     end
--     local iPid = oPlayer:GetPid()
--     if oOrgMgr:GetReadyOrgByPid(iPid) then
--         oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1003))
--         return
--     end
--     local mNet = {}
--     local flag = false

--     local mLog = oPlayer:LogData()
--     for orgid, oReadyOrg in pairs(oOrgMgr:GetReadyOrgs()) do
--         if not oReadyOrg:GetRespondInfo(iPid) then    
--             oReadyOrg:AddRespond(oPlayer)
--             flag = true
--             table.insert(mNet, oReadyOrg:PackRespondInfo())
--             oPlayer:Send("GS2CRespondOrg", {flag=1, orgid=orgid, respondcnt=oReadyOrg:RespondCnt()})
--             if oReadyOrg:RespondCnt() >= oOrgMgr:GetMaxRespondCnt() then
--                 oPlayer:Send("GS2CJoinOrgResult", {flag=1, orgid=orgid})
--                 oOrgMgr:CreateNormalOrg(oReadyOrg)
--                 flag = false
--                 break
--             end
--             mLog["org_id"] = orgid
--             mLog["flag"] = 1
--             record.log_db("org", "org_response", mLog)
--         end        
--     end
--     if flag then
--         local oInterfaceMgr = global.oInterfaceMgr
--         oInterfaceMgr:RefreshOrgRespond({infos=mNet})
--     end
-- end

function C2GSOrgMainInfo(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

    local mNet = {}
    if not flag or flag == 0 then
        mNet = oOrg:PackOrgMainInfo(oPlayer:GetPid())
    else
        mNet = oOrg:PackOrgSampleInfo(oPlayer:GetPid())
    end
    local net = require "base.net"
    mNet = net.Mask("GS2COrgMainInfo", mNet)
    oPlayer:Send("GS2COrgMainInfo", mNet)
end

-- 请求成员列表
function C2GSOrgMemberList(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local oVersionMgr = global.oVersionMgr
    oVersionMgr:C2GSOrgMemberList(oPlayer, mData.version)
    -- oPlayer:Send("GS2COrgMemberInfo", {infos=oOrg:PackOrgMemList()})
end

-- 打开入帮申请界面
function C2GSOrgApplyJoinList(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iFlag = mData.flag or 0
    if iFlag > 0 then
        local bExpire = oOrg.m_oApplyMgr:CheckApplyExpire()
        if bExpire then
            oPlayer:NotifyMessage(global.oOrgMgr:GetOrgText(1144))
        end
    end
    oPlayer:Send("GS2COrgApplyJoinInfo", {infos=oOrg:PackOrgApplyInfo(), auto_join=oOrg:GetAutoJoin()})
end

-- 入帮申请处理
function C2GSOrgDealApply(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iPid = mData.pid
    local iDeal = mData.deal   -- 1.同意,0.不同意
    local oOrgMgr = global.oOrgMgr
    if not oOrg:HasDealJoinAuth(oPlayer:GetPid()) then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1057))
        return
    end

    if iDeal == 1 then
        if oOrg:IsMember(iPid) or oOrg:IsXueTu(iPid) then 
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1059))
            oOrg:RemoveApply(iPid)
            oPlayer:Send("GS2CDelApplyOrg", {pids={iPid}})
            return 
        end

        local oMem = oOrg:GetApplyInfo(iPid)
        if not oMem then
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1061))
            oPlayer:Send("GS2CDelApplyOrg", {pids={iPid}})
            return
        end

        local bAuto = oOrg:IsAutoJoinXT()
        if not oMem:VaildApplyTime() or oOrgMgr:GetPlayerOrgId(iPid) then
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1059))
            oOrg:RemoveApply(iPid)
        else
            local flag = oOrgMgr:AcceptMember(oOrg:OrgID(), iPid)
            if not flag then
                oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1058))
                return
            end
        end
        if bAuto and not oOrg:IsAutoJoinXT() then
            oPlayer:Send("GS2CSetAutoJoin", {auto_join = 0})
        end
    else
        oOrg:RemoveApply(iPid)
    end
    oPlayer:Send("GS2CDelApplyOrg", {pids={iPid}})
end

-- 全部同意入帮
function C2GSAgreeAllApply(oPlayer, mData)
    local oOrgMgr = global.oOrgMgr
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    if not oOrg:HasDealJoinAuth(oPlayer:GetPid()) then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1057))
        return
    end

    if oOrg:GetApplyCnt() <= 0 then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1064))
        return
    end    

    local mNet = {}
    for pid,oMem in pairs(oOrg:GetApplyListInfo()) do
        if not oMem:VaildApplyTime() then
            oOrg:RemoveApply(pid)
            table.insert(mNet, pid)
        else
            local flag = oOrgMgr:AcceptMember(oPlayer:GetOrgID(), pid)
            if flag then
                table.insert(mNet, pid)
            end            
        end
    end
    
    if #mNet <= 0 then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1058))
        return
    end
    oPlayer:Send("GS2CDelApplyOrg",{pids=mNet})
end

-- 设置职位
function C2GSOrgSetPosition(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iTarPid = mData.pid
    local iPosition = mData.position
    local oOrgMgr = global.oOrgMgr
    if iPosition == orgdefines.ORG_POSITION.LEADER then
        oOrg:GiveLeader2Other(oPlayer, iTarPid)

    elseif iPosition == orgdefines.ORG_POSITION.XUETU then
        -- 
    elseif iPosition == orgdefines.ORG_POSITION.MEMBER then
        if oOrg:IsXueTu(iTarPid) then
            -- 学徒转正
            if not oOrg:HasXueTu2MemAuth(oPlayer:GetPid()) then return end

            if not oOrg:IsXueTu(iTarPid) then return end

            if oOrg:GetMemberCnt()  >= oOrg:GetMaxMemberCnt() then
                oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1067))
                return
            end

            oOrg:ChangeXueTu2Mem(iTarPid)
            oPlayer:Send("GS2CSetPositionResult", {pid=iTarPid, position=iPosition})
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1153))
        else
            -- 降职
            oOrg:SetMemPosition(oPlayer, iTarPid, iPosition)    
        end  
    else
        oOrg:SetMemPosition(oPlayer, iTarPid, iPosition)
    end           
end

-- 脱离帮派
function C2GSLeaveOrg(oPlayer, mData)
    local iOrgID = oPlayer:GetOrgID()
    if iOrgID == 0 then
        return
    end
    local oOrgMgr = global.oOrgMgr
    local oOrg = oOrgMgr:GetNormalOrg(iOrgID)
    if not oOrg then
        return
    end
    if not oOrg:CanLeaveOrg(oPlayer) then
        return
    end

    local iPid = oPlayer:GetPid()
    if oOrg:IsLeader(iPid) then
        if oOrg:GetMemberCnt()  > 1 or oOrg:GetXueTuCnt() > 0 then
            local oNotifyMgr = global.oNotifyMgr
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1054)) 
            return
        end
        safe_call(oOrgMgr.LogAnalyInfo, oOrgMgr, iPid, iOrgID, 2)
        oOrgMgr:LeaveOrg(iPid, iOrgID, "离开")
        -- oOrgMgr:DeleteNormalOrg(oOrg)
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1066))
    else
        safe_call(oOrgMgr.LogAnalyInfo, oOrgMgr, iPid, iOrgID, 2)
        oOrgMgr:LeaveOrg(iPid, iOrgID, "离开")
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1056))
    end
    local iVal = math.floor(oPlayer:GetOffer() / 2)
    if iVal > 0 then
        oPlayer:AddOrgOffer(-oPlayer:GetOffer(), "leave org", {cancel_tip=true})
        oPlayer:AddFreezeOrgOffer(iVal)
    end
    oPlayer:Send("GS2CDelMember", {pid=iPid})
end

function C2GSRequestOrgAim(oPlayer, mData)
    local iOrgID = mData.orgid
    local oOrgMgr = global.oOrgMgr
    local oOrg = oOrgMgr:GetNormalOrg(iOrgID)
    if not oOrg then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1000)) 
        oPlayer:Send("GS2CDelOrgList", {orgids={iOrgID}})
        return
    end
    oPlayer:Send("GS2COrgAim", {orgid=iOrgID, aim=oOrg:GetAim()})
end

-- 世界频道宣传帮派
function C2GSSpreadOrg(oPlayer)
    local oNotifyMgr = global.oNotifyMgr
    if oPlayer:GetOrgID() ~= 0 then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1012)) 
        return
    end
    local oOrgMgr = global.oOrgMgr
    local iPid = oPlayer:GetPid()
    local oOrg = oOrgMgr:GetReadyOrgByPid(iPid)
    if not oOrg then return end
        
    if oOrg:GetSpreadLeftTime() > 0 then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1029)) 
        return
    end
    local iVal = res["daobiao"]["org"]["others"][1]["world_ad_energy"]
    if oPlayer:GetEnergy() < iVal then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1028)) 
        return
    end

    local mLog = oPlayer:LogData()
    mLog["org_id"] = oOrg:OrgID()
    mLog["org_name"] = oOrg:GetName()
    mLog["old_energy"] = oPlayer:GetEnergy()

    oPlayer:AddEnergy(-iVal, "帮派宣传")

    mLog["new_energy"] = oPlayer:GetEnergy()
    record.log_db("org", "spread_org", mLog)

    oOrg:SetSpreadTime()
    oPlayer:PropChange("energy")
    local sMsg = string.format("%s {link11, %d, %d}", oOrgMgr:GetOrgText(1020), oOrg:OrgID(), oPlayer:GetPid())
    local oChatMgr = global.oChatMgr
    oChatMgr:SendMsg2World(sMsg, oPlayer)
    -- oPlayer:NotifyMessage("宣传成功") 
    oPlayer:Send("GS2CSpreadOrgResult", {orgid=iOrgID, spread_cd=oOrg:GetSpreadLeftTime()})
end

-- 修改宣言
function C2GSUpdateAim(oPlayer, mData)
    local aim = mData.aim
    local oOrgMgr = global.oOrgMgr
    local iPid = oPlayer:GetPid()
    local oOrg = oOrgMgr:GetNormalOrg(oPlayer:GetOrgID())
    if not oOrg then
        return
    end
    if not oOrg:HasUpdateAimAuth(iPid) then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1057)) 
        return
    end
    local iLeftTime = oOrg:GetSetAimCD()
    if iLeftTime > 0 then
        local iHour, iMins, iSec = global.oToolMgr:ConvertSeconds(iLeftTime)
        if iSec > 0 then
            iMins = iMins + 1
        end
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1180, {HH=iHour, MM=iMins})) 
        return
    end

    oOrg:SetAim(aim)
    oOrg.m_oBaseMgr:SetAimTime()
    oOrg:ChangeOrgMainInfo(oPlayer, {left_aim_cd = oOrg:GetSetAimCD()})
    oPlayer:Send("GS2CUpdateAimResult", {})
end

-- 踢出帮派
function C2GSKickMember(oPlayer, mData)
    local iKickPid = mData.pid
    local oOrgMgr = global.oOrgMgr
    local iPid = oPlayer:GetPid()
    local oOrg = oOrgMgr:GetNormalOrg(oPlayer:GetOrgID())
    if not oOrg then
        return
    end
    if not oOrg:HasKickAuth(iPid, iKickPid) then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1057)) 
        return
    end
    if not oOrg:CanKickMember(oPlayer, iKickPid) then
        return
    end
    safe_call(oOrgMgr.LogAnalyInfo, oOrgMgr, iKickPid, oPlayer:GetOrgID(), 3)
    oOrgMgr:LeaveOrg(iKickPid, oPlayer:GetOrgID(), "被踢")
    oPlayer:Send("GS2CDelMember", {pid=iKickPid})
    oOrgMgr:SendMail4BeKicked(iKickPid, oOrg:GetName())
    
    local oWorldMgr = global.oWorldMgr
    local oTarget = oWorldMgr:GetOnlinePlayerByPid(iKickPid)
    if oTarget then
        oTarget:NotifyMessage(oOrgMgr:GetOrgText(1073))
    end
end

-- 自荐帮主
function C2GSApplyOrgLeader(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local oOrgMgr = global.oOrgMgr
    if oOrg:IsLeader(oPlayer:GetPid()) then return end

    local iVal = res["daobiao"]["org"]["others"][1]["self_apply_sliver"]
    if not oPlayer:ValidSilver(iVal)  then return end

    if oOrg:HasApplyLeader() then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1041)) 
        oPlayer:Send("GS2CApplyLeaderResult", oOrg:PackApplyLeaderInfo(oPlayer:GetPid()))
        return
    end

    if oOrg:CanApplyLeader(oPlayer:GetPid()) ~= 1 then return end

    local mLog = oOrg:LogData()
    mLog["pid"] = oPlayer:GetPid()
    mLog["name"] = oPlayer:GetName()
    mLog["old_silver"] = oPlayer.m_oActiveCtrl:GetData("silver")

    oPlayer:ResumeSilver(iVal, "自荐帮主")

    mLog["new_silver"] = oPlayer.m_oActiveCtrl:GetData("silver")
    record.log_db("org", "apply_leader", mLog)

    oOrg:ApplyLeader(oPlayer:GetPid())
    oOrg:SendMail4ApplyLeader(oOrg:GetLeaderID(), oPlayer:GetPid())
    oPlayer:NotifyMessage("成功发起自荐") 
    oPlayer:Send("GS2CApplyLeaderResult", oOrg:PackApplyLeaderInfo(oPlayer:GetPid()))
    
    local sMsg = oOrgMgr:GetOrgText(1114, {role=oPlayer:GetName()})
    oOrgMgr:SendMsg2Org(oOrg:OrgID(), sMsg)
end

-- 自荐帮主的投票
function C2GSVoteOrgLeader(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local flag = mData.flag
    local oOrgMgr = global.oOrgMgr
    if not oOrg:HasApplyLeader() then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1045)) 
        return
    end

    if not oOrg:IsMember(oPlayer:GetPid()) then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1074)) 
        return
    end

    if flag == 0 then
        local iApplyPid = oOrg:GetApplyLeader()
        local mLog = oOrg:LogData()
        mLog["againstid"] = oPlayer:GetPid()
        mLog["applyid"] = iApplyPid
        record.log_db("org", "against_apply_leader", mLog)

        oOrg:RemoveApplyLeader()
        oOrg:SendMail4ApplyLeaderFail(iApplyPid)
        oPlayer:Send("GS2CApplyLeaderResult", oOrg:PackApplyLeaderInfo(oPlayer:GetPid()))
        oOrg:GS2COrgApplyLeaderFlag()

        local oMem = oOrg:GetMember(iApplyPid)
        local sMsg = oOrgMgr:GetOrgText(1118, {role=oMem:GetName()})
        oOrgMgr:SendMsg2Org(oOrg:OrgID(), sMsg)
        local sMsg = oOrgMgr:GetOrgText(1162, {role=oMem:GetName()})
        oOrg:AddLog(0, sMsg)
    end
end

-- 邀请入帮
function C2GSInvited2Org(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local invitePid = mData.pid
    local oOrgMgr = global.oOrgMgr
    local oWordMgr = global.oWorldMgr
    local oInPlayer = oWordMgr:GetOnlinePlayerByPid(invitePid)
    if not oInPlayer then
        oPlayer:NotifyMessage("对方不在线") 
        return
    end
    if oInPlayer:GetOrgID() ~= 0 then
        oPlayer:NotifyMessage("对方已有帮派") 
        return
    end
    if oOrgMgr:GetReadyOrgByPid(invitePid) then
        oPlayer:NotifyMessage("对方的帮派正在等待响应") 
        return
    end
    -- if oInPlayer:GetGrade() < 15 then
    --     oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1122)) 
    --     return
    -- end

    if oOrg:GetXueTuCnt() >= oOrg:GetMaxXuetuCnt() then
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1058)) 
        return
    end
    local mData = {}
    mData.orgId = oPlayer:GetOrgID()
    oInPlayer:SetOrgInviteInfo(oPlayer:GetPid(), mData)
    oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1124)) 
    oInPlayer:Send("GS2CInvited2Org", {pid=oPlayer:GetPid(), pname=oPlayer:GetName(), org_name=oOrg:GetName(), org_level=oOrg:GetLevel()})
end

-- 处理帮派邀请信息
function C2GSDealInvited2Org(oPlayer, mData)
    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("ORG_SYS", oPlayer) then return end

    local invitePid = mData.pid
    local flag = mData.flag
    local oOrgMgr = global.oOrgMgr
    local oWorldMgr = global.oWorldMgr
    local oInvite = oPlayer:GetOrgInviteInfo(invitePid)
    if not oInvite then return end
        
    local oOrg = oOrgMgr:GetNormalOrg(oInvite.orgId)
    if not oOrg then return end

    if flag == 0 then
        oPlayer:RemoveOrgInviteInfo(invitePid)
        local oInPlayer = oWorldMgr:GetOnlinePlayerByPid(invitePid)
        if oInPlayer then
            oInPlayer:NotifyMessage(oOrgMgr:GetOrgText(1126, {role=oPlayer:GetName()}))
        end
        oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1127, {bpname=oOrg:GetName()}))
    else
        if oPlayer:GetOrgID() ~= 0 then
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1021)) 
            return
        end
        -- if oPlayer:GetGrade() < 15 then
        --     oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1011, {grade=15}))
        --     return
        -- end
        if oOrgMgr:GetReadyOrgByPid(oPlayer:GetPid()) then
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1003)) 
            return
        end

        local position = oOrg:GetPosition(invitePid)
        local isAdd = false
        if table_in_list({1, 2, 3}, position) then
            isAdd = oOrgMgr:AddForceMember(oInvite.orgId, oPlayer)
        end
        if not isAdd then
            oOrg:AddApply(oPlayer, orgdefines.ORG_APPLY.INVITED)
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1125, {bpname=oOrg:GetName()}))
        else
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1131, {bpname=oOrg:GetName()}))
        end
    end
end

function C2GSClearApplyAndRespond(oPlayer, mData)
    local oOrgMgr = global.oOrgMgr
    oOrgMgr:OnJoinDelResponds(oPlayer:GetPid())
    oOrgMgr:OnJoinDelApplys(oPlayer:GetPid())
end

function C2GSGetOnlineMember(oPlayer, mData)
    local bAll = mData.flag == 1
    local oOrg = oPlayer:GetOrg()
    if not oOrg  then return end
    
    oOrg:GS2CGetOnlineMember(oPlayer, bAll)
end

function C2GSGetBuildInfo(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    oOrg:GS2CGetBuildInfo(oPlayer)
end

function C2GSUpGradeBuild(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iBid = mData.bid
    oOrg:UpGradeBuild(oPlayer, iBid)
end

function C2GSQuickBuild(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end
    
    local iBid = mData.bid
    local iQuick = mData.quickid
    oOrg:QuickBuild(oPlayer, iBid, iQuick)
end

function C2GSGetShopInfo(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end
    
    oOrg:GS2CGetShopInfo(oPlayer)    
end

function C2GSBuyItem(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iItem = mData.itemid
    local iCnt = mData.cnt
    oOrg:BuyItem(oPlayer, iItem, iCnt)
end

function C2GSGetBoonInfo(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    oOrg:GS2CGetBoonInfo(oPlayer)
end

function C2GSOrgSign(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local sMsg = mData.msg
    oOrg:DoSign(oPlayer, sMsg)
end

function C2GSReceiveBonus(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    oOrg:ReceiveBonus(oPlayer)    
end

function C2GSReceivePosBonus(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    oOrg:ReceivePosBonus(oPlayer)    
end

function C2GSGetAchieveInfo(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    oOrg:GS2CGetAchieveInfo(oPlayer)    
end

function C2GSReceiveAchieve(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iAch = mData.achid
    oOrg:ReceiveAchieve(oPlayer, iAch)
end

function C2GSEnterOrgScene(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end
    if oPlayer:InWar() then
        oPlayer:NotifyMessage("您在战斗中，不能操作")
        return
    end
    if oPlayer:IsFixed() then
        return
    end
    local oTeam = oPlayer:HasTeam()
    if oTeam and not oPlayer:IsTeamLeader() and not oTeam:IsShortLeave(oPlayer:GetPid()) then
        oPlayer:NotifyMessage("您在队伍中，不能操作")
        return
    end
    oOrg:EnterOrgScene(oPlayer)
end

function C2GSNextPageLog(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iLastId = mData.lastid
    oOrg:GS2CNextPageLog(oPlayer, iLastId)
end

function C2GSChatBan(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iBinId = mData.banid
    local iFlag = mData.flag
    oOrg:ChatBan(oPlayer, iBinId, iFlag)
end

function C2GSClickOrgBuild(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local iBuild = mData.build_id
    local oBuild = oOrg.m_oBuildMgr:GetBuildById(iBuild)
    if oBuild then
        oBuild:ClickBuild(oPlayer)
    end
end

function C2GSSetAutoJoin(oPlayer, mData)
    local iFlag = mData.flag

    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end
    oOrg:SetAutoJoin(oPlayer, iFlag)
end

function C2GSClearApplyList(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end
    oOrg:ClearApplyList(oPlayer)
end

function C2GSOrgPrestigeInfo(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    local mInfo = {}
    if oOrg then
        mInfo.orgid = oOrg:OrgID()
        mInfo.pid = oPlayer:GetPid()
    end
    interactive.Send(".rank", "rank", "GS2COrgPrestigeInfo", mInfo)
end

function C2GSSendOrgMail(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end

    oOrg:SendOrgMail2Member(oPlayer, mData.context)        
end

function C2GSRenameNormalOrg(oPlayer, mData)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end
    
    global.oOrgMgr:RenameNormalOrg(oPlayer, oOrg:OrgID(), mData.name)
end
