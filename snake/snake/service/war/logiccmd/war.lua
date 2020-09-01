--import module
local global = require "global"
local skynet = require "skynet"
local netproto = require "base.netproto"
local playersend = require "base.playersend"
local pfload = import(service_path("perform.pfload"))

ForwardNetcmds = {}

function ForwardNetcmds.C2GSWarSkill(oPlayer, mData)
        local l1 = mData.action_wlist
        local l2 = mData.select_wlist
        local iSkill = mData.skill_id

        local iWid = l1[1]

        local oWar = oPlayer:GetWar()
        local oAction = oWar:GetWarrior(iWid)
        if oAction then
            oWar:AddBoutCmd(iWid, {
                cmd = "skill",
                data = {
                    action_wlist = l1,
                    select_wlist = l2,
                    skill_id = iSkill,
                }
            })
        end
        local oPerform = pfload.GetPerform(iSkill)
        if oAction and oPerform and not oPerform:IsSE() then
            oAction:SetData("auto_perform", iSkill)
            oAction:StatusChange("auto_perform")
        end
end

function ForwardNetcmds.C2GSWarNormalAttack(oPlayer, mData)
        local iActionWid = mData.action_wid
        local iSelectWid = mData.select_wid

        local oWar = oPlayer:GetWar()
        local oAction = oWar:GetWarrior(iActionWid)
        if oAction then
            oWar:AddBoutCmd(iActionWid, {
                cmd = "normal_attack",
                data = {
                    action_wid = iActionWid,
                    select_wid = iSelectWid,
                }
            })

            oAction:SetData("auto_perform", 101)
            oAction:StatusChange("auto_perform")
        end
end

function ForwardNetcmds.C2GSWarEscape(oPlayer, mData)
        local iActionWid = mData.action_wid

        local oWar = oPlayer:GetWar()
        local oAction = oWar:GetWarrior(iActionWid)
        if oAction then
            oWar:AddBoutCmd(iActionWid, {
                cmd = "escape",
                data = {
                    action_wid = iActionWid,
                }
            })
        end
end

function ForwardNetcmds.C2GSWarDefense(oPlayer, mData)
        local iActionWid = mData.action_wid

        local oWar = oPlayer:GetWar()
        local oAction = oWar:GetWarrior(iActionWid)
        if oAction then
            oWar:AddBoutCmd(iActionWid, {
                cmd = "defense",
                data = {
                    action_wid = iActionWid,
                }
            })
            oAction:SetData("auto_perform", 102)
            oAction:StatusChange("auto_perform")
        end
end

function ForwardNetcmds.C2GSWarProtect(oPlayer, mData)
        local iActionWid = mData.action_wid
        local iSelectWid = mData.select_wid

        local oWar = oPlayer:GetWar()
        local oAction = oWar:GetWarrior(iActionWid)
        if oAction then
            oWar:AddBoutCmd(iActionWid, {
                cmd = "protect",
                data = {
                    action_wid = iActionWid,
                    select_wid = iSelectWid,
                }
            })
        end
end

function ForwardNetcmds.C2GSWarSummon(oPlayer,mData)
    local iActionWid = mData.action_wid
    local mSumData = mData.sumdata
    local oWar = oPlayer:GetWar()
    local oAction = oWar:GetWarrior(iActionWid)
    if oAction then
        oWar:AddBoutCmd(iActionWid,{
            cmd = "summon",
            data = {
                action_wid = iActionWid,
                sumdata = mSumData,
            }
            })
    end
end

function ForwardNetcmds.C2GSWarUseItem(oPlayer,mData)
    local iActionWid = mData.action_wid
    local iSelectWid = mData.select_wid
    local mItemData = mData.itemdata

    local oWar = oPlayer:GetWar()
    local oAction = oWar:GetWarrior(iActionWid)
    if oAction then
        oWar:AddBoutCmd(iActionWid,{
            cmd = "useitem",
            data = {
                action_wid = iActionWid,
                select_wid = iSelectWid,
                pid = oPlayer:GetPid(),
                itemdata = mItemData,
            }
        })
    end
end

function ForwardNetcmds.C2GSWarAutoFight(oPlayer,mData)
    local iType = mData.type
    local iAIType = mData.aitype
    if iType == 0 then
        oPlayer:CancleAutoFight()
    elseif iType == 1 then
        oPlayer:StartAutoFight(iAIType)
    end
end

function ForwardNetcmds.C2GSChangeAutoPerform(oPlayer,mData)
    local iWid = mData.wid
    local iAutoPerform = mData.auto_perform
    local oWar = oPlayer:GetWar()
    if not oWar then return end

    if iWid == oPlayer:GetWid() then
        oPlayer:SetAutoPerform(iAutoPerform)
    else
        local oSumm = oWar:GetWarrior(iWid)
        if not oSumm or not oSumm:IsSummon() then
            return
        end
        oSumm:SetAutoPerform(iAutoPerform)
    end
end

function ForwardNetcmds.C2GSWarCommandOP(oPlayer,mData)
    local oWar = oPlayer:GetWar()
    if not oWar then
        return
    end
    local oAction = oWar:GetWarrior(mData.action_wid)
    if oAction then
        local oCamp = oWar:GetCampObj(oAction:GetCampId())
        if oCamp then
            oCamp:ChangeAppointOP(oAction:GetPid(),mData.op)
        end
    end
end

function ForwardNetcmds.C2GSWarCommand(oPlayer, mNet)
    local oWar = oPlayer:GetWar()
    if not oWar then
        return
    end
    local mData = mNet.data
    local iType = mNet.type
    local pid = oPlayer:GetPid()
    if iType ==1 then
        local iActionWid = mData.action_wid
        local iSelectWid = mData.select_wid
        local sCmd = mData.scmd

        local oAction = oWar:GetWarrior(iActionWid)
        local oSAction = oWar:GetWarrior(iSelectWid)
        if oAction and oSAction then
            local iCamp = oAction:GetCampId()
            local oCamp = oWar:GetCampObj(iCamp)
            if oCamp and oCamp.m_Appoint == pid then
                oWar:BroadWarCommand(iCamp,iSelectWid,sCmd)
            end
        end
    elseif iType == 2 then
        local iAppoint = mData.appoint
        local oWarrior = oWar:GetPlayerWarrior(pid)
        if oWarrior then
            local oCamp = oWar:GetCampObj(oWarrior:GetCampId())
            oCamp:UpdateAppoint(oWar,iAppoint)
        end
    end
end

function ForwardNetcmds.C2GSWarAnimationEnd(oPlayer, mData)
    local oWar = oPlayer:GetWar()
    if not oWar then return end

    oWar:C2GSWarAnimationEnd(oPlayer, mData.bout_id)
end

function ConfirmRemote(mRecord, mData)
    local iWarId = mData.war_id
    local iWarType = mData.war_type
    local mWarInfo = mData.war_info
    local iSysType = mData.sys_type
    local oWarMgr = global.oWarMgr
    oWarMgr:ConfirmRemote(iWarId, iWarType, iSysType, mWarInfo)
end

function RemoveRemote(mRecord, mData)
    local iWarId = mData.war_id
    local oWarMgr = global.oWarMgr
    oWarMgr:RemoveWar(iWarId)
end

function EnterPlayer(mRecord, mData)
    local iWarId = mData.war_id
    local iPid = mData.pid
    local iCamp = mData.camp_id
    local mInfo = mData.data
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    assert(oWar, string.format("EnterPlayer error war: %d %d", iWarId, iPid))
    playersend.ReplacePlayerMail(iPid)
    oWar:EnterPlayer(iPid, iCamp, mInfo)
end

function LeavePlayer(mRecord, mData)
    local iWarId = mData.war_id
    local iPid = mData.pid
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        oWar:LeavePlayer(iPid)
    end
end

function ReEnterPlayer(mRecord, mData)
    local iWarId = mData.war_id
    local iPid = mData.pid
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    assert(oWar, string.format("ReEnterPlayer error war: %d %d", iWarId, iPid))
    playersend.ReplacePlayerMail(iPid)
    oWar:ReEnterPlayer(iPid)
end

function NotifyDisconnected(mRecord, mData)
    local iWarId = mData.war_id
    local iPid = mData.pid
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        local oPlayerWarrior = oWar:GetPlayerWarrior(iPid)
        if oPlayerWarrior then
            oPlayerWarrior:Disconnected()
        end
        local oObserver = oWar:GetObserverByPid(iPid)
        if oObserver then
            oObserver:Disconnected()
        end
    end
end

function EnterPartnerList(mRecord, mData)
    local iWarId = mData.war_id
    local iPid = mData.pid
    local iCamp = mData.camp_id
    local lInfo = mData.data
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    assert(oWar, string.format("EnterPlayer error war: %d %d", iWarId, iPid))
    oWar:EnterPartnerList(iPid, iCamp, lInfo)
end

function WarStart(mRecord, mData)
    local iWarId = mData.war_id
    local mInfo = mData.info
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        oWar:WarStart(mInfo)
    end
end

function WarPrepare(mRecord, mData)
    local iWarId = mData.war_id
    local mInfo = mData.info
    local mConfig = mData.config
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        oWar:WarPrepare(mInfo, mConfig)
    end
end

function PrepareCamp(mRecord, mData)
    local iWarId = mData.war_id
    local mInfo = mData.info
    local iCamp = mData.camp

    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        oWar:PrepareCamp(iCamp, mInfo)
    end
end

function EnterObserver(mRecord, mData)
    local iWarId = mData.war_id
    local iPid = mData.pid
    local mArgs = mData.args

    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    assert(oWar, string.format("EnterObserver error war: %d %d", iWarId, iPid))
    playersend.ReplacePlayerMail(iPid)
    oWar:EnterObserver(iPid, mArgs)
end

function LeaveObserver(mRecord, mData)
    local iWarId = mData.war_id
    local iPid = mData.pid

    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    assert(oWar, string.format("EnterObserver error war: %d %d", iWarId, iPid))
    oWar:LeaveObserver(iPid)
end

function WarBulletBarrage(mRecord, mData)
    local iWarId = mData.war_id
    local iPid = mData.pid
    local mArgs = mData.args
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    local sName = mArgs.name
    local sMsg = mArgs.msg
    assert(oWar, string.format("WarBulletBarrage error war: %d %d", iWarId, iPid))
    oWar:WarBulletBarrage(sName,sMsg)
end

function TestCmd(mRecord, mData)
    local iWarId = mData.war_id
    local iPid = mData.pid
    local sCmd = mData.cmd
    local m = mData.data

    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        if sCmd == "wartimeover" then
            oWar:BoutProcess()
        elseif sCmd == "warend" then
            oWar.m_iWarResult = 1
            oWar:WarEnd()
        elseif sCmd == "warfail" then
            oWar.m_iWarResult = 2
            oWar:WarEnd()
        elseif sCmd == "setwarattr" then
            local oPlayer = oWar:GetPlayerWarrior(iPid)
            if oPlayer then
                oPlayer:SetTestData(m["attr"], m["val"])
            end
        elseif sCmd == "addaura" then
            local oPlayer = oWar:GetPlayerWarrior(iPid)
            oPlayer:AddAura(3)
        elseif sCmd == "addbuff" then
            local oPlayer = oWar:GetPlayerWarrior(iPid)
            if oPlayer then
                local mEnv = {level=5, action_wid=oPlayer:GetWid()}
                oPlayer.m_oBuffMgr:AddBuff(m.buff_id, m.bout, mEnv)
            end
        elseif sCmd == "addzhenqi" then
            local oPlayer = oWar:GetPlayerWarrior(iPid)
            if oPlayer then
                oPlayer:SetData("zhenqi", m.val)
                oPlayer:StatusChange("zhenqi")
            end
        end
    end
end

function Forward(mRecord, mData)
    local iWarId = mData.war_id
    local iPid = mData.pid
    local sCmd = mData.cmd
    local m = netproto.ProtobufFunc("default", sCmd, mData.data)

    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        local oPlayer = oWar:GetPlayerWarrior(iPid)
        if oPlayer then
            local func = ForwardNetcmds[sCmd]
            if func then
                func(oPlayer, m)
            end
        end
    end
end

function WarChat(mRecord, mData)
    local iWarId = mData.war_id
    local mNet = mData.net
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        oWar:SendAll("GS2CChat", mNet)
    end
end

function ForceRemoveWar(mRecord,mData)
    local iWarId = mData.war_id
    local iWarResult = mData.war_result
    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        oWar.m_iWarResult = iWarResult or 2
        oWar:WarEnd()
    end
end

function EnterRoPlayer(mRecord,mData)
    local iWarId = mData.war_id
    local iCamp = mData.camp_id
    local mInfo = mData.data

    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        oWar:EnterRoPlayer(iCamp, mInfo)
    end
end

function EnterRoPartnerList(mRecord,mData)
    local iWarId = mData.war_id
    local iCamp = mData.camp_id
    local lInfo = mData.data

    local oWarMgr = global.oWarMgr
    local oWar = oWarMgr:GetWar(iWarId)
    if oWar then
        oWar:EnterRoPartnerList(iCamp, lInfo)
    end
end

function ForceWarEnd(mRecord, mData)
    local iWarId = mData.war_id
    global.oWarMgr:ForceWarEnd(iWarId)
end
