local global = require "global"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"

local taskobj = import(service_path("task/taskobj"))
local taskdefines = import(service_path("task/taskdefines"))

local LIMIT_SIZE = 3
local MONSTER_TYPE = {10001,}

function NewTask(taskid)
    local o = CTask:New(taskid)
    return o
end

CTask = {}
CTask.__index = CTask
CTask.m_sName = "jyfuben"
CTask.m_sTempName = "精英副本"
CTask.m_iAutoFightOnStart = 0
inherit(CTask, taskobj.CTeamTask)

function CTask:New(taskid)
    local o = super(CTask).New(self,taskid)
    return o
end

function CTask:ValidFight(pid,npcobj,iFight)
    local oTeam = self:GetTeamObj()
    if not oTeam then
        return
    end
    if oTeam:MemberSize() < LIMIT_SIZE then
        oTeam:TeamNotify(string.format("队伍不足%s人",LIMIT_SIZE))
        return false
    end
    local iOpenLevel = global.oToolMgr:GetSysOpenPlayerGrade("JYFUBEN")

    local function FilterCannotFightMember(oMember)
        if oMember:GetGrade() < iOpenLevel then
            return oMember:GetName()
        end
    end

    local lName = oTeam:FilterTeamMember(FilterCannotFightMember)
    if next(lName) then
        local oToolMgr = global.oToolMgr
        local oHuodongMgr = global.oHuodongMgr
        local oHuodong = oHuodongMgr:GetHuodong("jyfuben")
        if not oHuodong then
            return false
        end
        local sMsg = oHuodong:GetTextData(1006)
        sMsg = oToolMgr:FormatColorString(sMsg,{role=table.concat(lName, "、"), level = iOpenLevel})
        npcobj:Say(pid, sMsg, nil,nil,true)
        return false
    end
    local bResult = super(CTask).ValidFight(self,pid,npcobj,iFight)
    return bResult
end

function CTask:OtherScript(pid,npcobj,s,mArgs)
    local sScriptFunc = string.match(s, "^([$%a]+)")
    if sScriptFunc == "OVER" then
        local oHD = global.oHuodongMgr:GetHuodong(self.m_sName)
        local oTeam = self:GetTeamObj()
        oHD:FloorEnd(oTeam,self.m_ID)
        return true
    end
end

function CTask:TransMonsterAble(oWar,sAttr,mArgs)
    mArgs = mArgs or {}
    mArgs.env = mArgs.env or {}
    local oTeam = self:GetTeamObj()
    local lCurFinish = oTeam.m_JYTask or {}
    mArgs.env.floor = #lCurFinish+1
    local iValue =  super(CTask).TransMonsterAble(self,oWar,sAttr,mArgs)
    return iValue
end

function CTask:AutoFindNpcPath(pid, npctype)
    local oNpc = self:GetNpcObjByType(npctype)
    if not oNpc then
        return
    end
    local iMap = oNpc:MapId()
    local oPlayer  = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    local oTeam  = oPlayer:HasTeam()
    if not oTeam then
        return
    end
    local oNowScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oNowScene:MapId() ~= iMap then
        if not oTeam.m_oJYFubenSure:CheckEnterSure() then
            return
        end
    end
    super(CTask).AutoFindNpcPath(self,pid, npctype)
end

function CTask:IsLogWarWanfa()
    return true
end

function CTask:WarFightEnd(oWar, iPid, oNpc, mArgs)
    if mArgs.win_side ==1 then
        local oHD = global.oHuodongMgr:GetHuodong(self.m_sName)
        if oHD then
            local oTeam = self:GetTeamObj()
            if oTeam then
                oHD:AddJYFBBout(oTeam,mArgs.bout_cnt or 0)
            end
        end
    end
    super(CTask).WarFightEnd(self, oWar, iPid, oNpc, mArgs)
end

function CTask:TransferClick(oPlayer)
    local npctype = self:Target()
    if npctype then
        if oPlayer:IsSingle() or oPlayer:IsTeamLeader() then
            local oNpc = self:GetNpcObjByType(npctype)
            if not oNpc then
                return
            end
            local iMap = oNpc:MapId()
            local oHD = global.oHuodongMgr:GetHuodong("jyfuben")
            local oScene = oHD:GetSceneByMapID(oPlayer:GetPid(),iMap)
            global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId())
        end 
    end
end

function CTask:OnPackWarriorsAttr(mFriend,mEnemy,oWar,npcobj)
    local mAllMonster = {}
    if self.m_ID == 74001 then
        local oMonster = self:CreateMonster(oWar, 10003, npcobj) 
        assert(oMonster,self.m_sName)
        oMonster = self:PackMonster(oMonster)
        mAllMonster[oMonster.type] = oMonster
        for _,oEnemy in ipairs(mEnemy) do
            if 10001== oEnemy.type then
                oEnemy.all_monster = mAllMonster
            end
        end
    elseif self.m_ID == 74005 then
        local oMonster = self:CreateMonster(oWar, 10010, npcobj) 
        assert(oMonster,self.m_sName)
        oMonster = self:PackMonster(oMonster)
        mAllMonster[oMonster.type] = oMonster
        for _,oEnemy in ipairs(mEnemy) do
            local iType = oEnemy.type
            if iType == 10009 then
                oEnemy.all_monster = mAllMonster
            end
        end
    elseif self.m_ID == 74023 then
        local oMonster = self:CreateMonster(oWar, 10101, npcobj) 
        assert(oMonster,self.m_sName)
        oMonster = self:PackMonster(oMonster)
        mAllMonster[oMonster.type] = oMonster
        for _,oEnemy in ipairs(mEnemy) do
            local iType = oEnemy.type
            if iType == 10100 then
                oEnemy.all_monster = mAllMonster
            end
        end
    elseif self.m_ID == 74029 then
        local oMonster1 = self:CreateMonster(oWar, 10101, npcobj) 
        assert(oMonster1,self.m_sName)
        oMonster1 = self:PackMonster(oMonster1)
        mAllMonster[oMonster1.type] = oMonster1
        local oMonster2 = self:CreateMonster(oWar, 10125, npcobj) 
        assert(oMonster2,self.m_sName)
        oMonster2 = self:PackMonster(oMonster2)
        if oMonster2["perform"] and oMonster2["perform"][3024] then
            oMonster2["perform"][3024] = nil
        end
        mAllMonster[oMonster2.type] = oMonster2        
        for _,oEnemy in ipairs(mEnemy) do
            local iType = oEnemy.type
            if iType == 10125 then
                oEnemy.all_monster = mAllMonster
            end
        end
    elseif self.m_ID == 74021 then
        local oMonster = self:CreateMonster(oWar, 10088, npcobj) 
        assert(oMonster,self.m_sName)
        oMonster = self:PackMonster(oMonster)
        mAllMonster[oMonster.type] = oMonster
        oMonster = self:CreateMonster(oWar, 10089, npcobj) 
        assert(oMonster,self.m_sName)
        oMonster = self:PackMonster(oMonster)
        mAllMonster[oMonster.type] = oMonster
        for _,oEnemy in ipairs(mEnemy) do
            local iType = oEnemy.type
            if iType == 10085 then
                oEnemy.all_monster = mAllMonster
            end
        end
    end
    return mFriend,mEnemy
end

function CTask:BuildExtApplyInfo()
    return {floor=self.m_iTrueFloor}
end

function CTask:NextTask(iTaskid, pid, npcobj, mArgs)
    local iTrueFloor = self.m_iTrueFloor
    super(CTask).NextTask(self,iTaskid, pid, npcobj, mArgs)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    local oTeam = oPlayer:HasTeam()
    if oTeam then
        local oNextTask = oTeam:GetTask(iTaskid)
        if oNextTask then
            oNextTask.m_iTrueFloor = iTrueFloor
            oNextTask:Refresh({ext_apply_info=true})
        end
    end 
end