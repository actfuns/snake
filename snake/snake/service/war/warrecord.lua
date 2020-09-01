local global = require "global"

CWarRecord = {}
CWarRecord.__index = CWarRecord
inherit(CWarRecord,logic_base_cls())

function CWarRecord:New(iWarId)
    local o = super(CWarRecord).New(self)
    o.m_iWarId = iWarId
    o.m_mAttack = {}
    o.m_mAttacked = {}
    o.m_mMonsterCnt = {}
    o.m_mDamage = {}
    o.m_mDamaged = {}
    o.m_mNpcDamaged = {}
    o.m_mMonsterDead = {}
    o.m_mMonsterDeadWid = {}
    --战斗录像
    o.m_mBoutCmd = {}
    o.m_mClientPacket = {}
    o.m_mBoutTime = {}
    return o
end

function CWarRecord:GetWarId()
    return self.m_iWarId
end

function CWarRecord:GetWar()
    local oWarMgr = global.oWarMgr
    return oWarMgr:GetWar(self:GetWarId())
end

function CWarRecord:AddAttack(oAttack,oVictim,iDamage)
    if  oAttack:IsPlayer() then
        local iPid = oAttack:GetData("pid",0)
        local iAttackCnt = self.m_mAttack[iPid] or 0
        self.m_mAttack[iPid] = iAttackCnt + 1
        local iTotalDamage = self.m_mDamage[iPid] or 0
        self.m_mDamage[iPid] = iTotalDamage + iDamage
    end
    if oVictim:IsPlayer() then
        local iPid = oVictim:GetData("pid",0)
        local iAttacked = self.m_mAttacked[iPid] or 0
        self.m_mAttacked[iPid] = iAttacked + 1
        local iTotalDamaged = self.m_mDamaged[iPid] or 0
        self.m_mDamaged[iPid] = iTotalDamaged + iDamage
    end
    if oVictim:IsNpc() then
        local iType = oVictim:GetData("type", 0)
        local iOld = self.m_mNpcDamaged[iType] or 0
        self.m_mNpcDamaged[iType] = iOld + iDamage
    end
end

function CWarRecord:AddMonster(iCamp, iMonsterIdx)
    local mMonsterCamp = table_get_set_depth(self.m_mMonsterCnt, {iCamp})
    mMonsterCamp[iMonsterIdx] = (mMonsterCamp[iMonsterIdx] or 0) + 1
end

function CWarRecord:AddMonsterDead(iCamp, iMonster)
    local mMonsterCamp = table_get_set_depth(self.m_mMonsterDead, {iCamp})
    mMonsterCamp[iMonster] = (mMonsterCamp[iMonster] or 0) + 1
end

--不包括中途召唤, 不包括中途复活
function CWarRecord:AddMonsterByWid(oWar, iCamp, iWid)
    if oWar:CurBout() > 0 then return end
    local mMonsterCamp = table_get_set_depth(self.m_mMonsterDeadWid, {iCamp})
    mMonsterCamp[iWid] = 0
end

function CWarRecord:AddMonsterDeadByWid(iCamp, iWid)
    local mMonsterCamp = self.m_mMonsterDeadWid[iCamp]
    if not mMonsterCamp then return end
    
    if not mMonsterCamp[iWid] or mMonsterCamp[iWid] > 0 then
        return
    end

    mMonsterCamp[iWid] = 1
end

function CWarRecord:GetMonsterDeadWidRecord()
    local mResult = {}
    for iCamp, mMonsterCamp in pairs(self.m_mMonsterDeadWid) do
        mResult[iCamp] = 0
        for iWid, iDead in pairs(mMonsterCamp) do
            mResult[iCamp] = mResult[iCamp] + iDead
        end
    end
    return mResult
end

-- @return: nil or {monster_cnt: {<int>iCamp: <int>iMonsterIdx : cnt}}
function CWarRecord:PackRecordMonster()
    local mRet = {}

    if next(self.m_mMonsterDead) then
        mRet.monster_dead = self.m_mMonsterDead
    end

    local mMonsterCnt = self.m_mMonsterCnt
    if next(mMonsterCnt) then
        mRet.monster_cnt = mMonsterCnt
    end

    mRet.monster_wid_dead = self:GetMonsterDeadWidRecord()

    if not next(mRet) then
        return nil
    else
        return mRet
    end
end

function CWarRecord:PackRecordInfo(pid)
    return {
        attack_cnt = self.m_mAttack[pid] or 0,
        attacked_cnt = self.m_mAttacked[pid] or 0,
    }
end

function CWarRecord:PackDamageInfo()
    return {
        damage_info = self.m_mDamage,
        damaged_info = self.m_mDamaged,
        npc_damaged_info = self.m_mNpcDamaged,
    }
end

function CWarRecord:AddBoutCmd(sMessage, mData)
    local oWar = self:GetWar()
    local iBoutStartTime = oWar:GetExtData("bout_start")
    iBoutStartTime = iBoutStartTime or get_time()
    local iBout = tostring(oWar.m_iBout)
    local iSecs = tostring(get_time() - iBoutStartTime)

    local lBout = table_get_set_depth(self.m_mBoutCmd, {iBout, iSecs})
    table.insert(lBout, {sMessage, mData})
end

--记录发给客户端协议
function CWarRecord:AddClientPacket(sMessage, mData)
    local oWar = self:GetWar()
    local iBout = tostring(oWar.m_iBout)

    local iBoutStartTime = oWar:GetExtData("bout_start")
    iBoutStartTime = iBoutStartTime or get_time()
    local iSecs = get_time() - iBoutStartTime
    iSecs = tostring(math.max(0,math.min(iSecs,30)))

    local lPacket = table_get_set_depth(self.m_mClientPacket, {iBout, iSecs})
    table.insert(lPacket, {sMessage, mData})
end

--下回合开始时间
function CWarRecord:AddBoutTime(iBout,iTime)
    iBout = tostring(iBout)
    self.m_mBoutTime[iBout] = iTime
end

function CWarRecord:PackVideoData()
    local oWar = self:GetWar()
    if oWar:IsWarRecord() then  
        return {
            bout_cmd = self.m_mBoutCmd,
            client_packet = self.m_mClientPacket,
            bout_time = self.m_mBoutTime,
            bout_end = oWar.m_iBout,
            type = oWar:GetWarType(),
        }
    end
end


function NewRecord(iWarId)
    local o = CWarRecord:New(iWarId)
    return o
end
