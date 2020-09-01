local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"
local extend = require "base.extend"


function NewFmtObj(iFmt, mInfo, ...)
    assert(iFmt>0 and iFmt<10, string.format("illegal fmt_id %d", iFmt))
    
    local o = CFormat:New(iFmt, mInfo, ...)
    return o
end


CFormat = {}
CFormat.__index = CFormat
inherit(CFormat, logic_base_cls())

function CFormat:New(iFmt, mInfo)
    local o = super(CFormat).New(self)
    if tostring(iFmt) == "1.0" then
        record.error("fmtid not a integer %s", extend.Table.serialize(mInfo))
    end
    o.m_iFmt = math.floor(iFmt)         --阵法id
    o.m_iGrade = mInfo.grade            --阵法等级
    o.m_iPid = mInfo.pid                --阵法owner
    o.m_lPlayer = mInfo.player_list or {}     --成员站位顺序
    o.m_lPartner = mInfo.partner_list or {}   --伙伴站位顺序
    o.m_iNpcCnt = 0
    return o
end

function CFormat:GetOwner()
    return self.m_iPid
end

function CFormat:GetGrade()
    return self.m_iGrade
end

function CFormat:GetFmtId()
    return self.m_iFmt
end

function CFormat:IsNpcFmt()
    return not next(self.m_lPartner) and not next(self.m_lPlayer)
end

function CFormat:GetPlayerFmtIdx(iPid)
    for idx, iVal in ipairs(self.m_lPlayer or {}) do
        if iVal == iPid then
            return idx
        end
    end
end

function CFormat:GetPartnerFmtIdx(iPid)
    for idx, iVal in ipairs(self.m_lPartner or {}) do
        if iVal == iPid then
            return idx + #self.m_lPlayer
        end
    end
end

function CFormat:GetWarPos(obj)
    local lWarPos = self:GetWarPosList()
    if obj:IsPlayerLike() then
        local iPid = obj:GetPid()
        local iIdx = self:GetPlayerFmtIdx(iPid)
        if iIdx then
            return lWarPos[iIdx]
        else
            table.insert(self.m_lPlayer, iPid)
            return self:GetWarPos(obj)
        end
    end
    if obj:IsPartnerLike() then
        local iPid = obj:GetPid()
        local iIdx = self:GetPartnerFmtIdx(iPid)
        if iIdx then
            return lWarPos[iIdx]
        end
    end
    if self:IsNpcFmt() and obj:IsNpc() then
        self.m_iNpcCnt = self.m_iNpcCnt + 1
        if self.m_iNpcCnt <= #lWarPos then
            return lWarPos[self.m_iNpcCnt]
        else
            return nil
        end
    end
end

function CFormat:GetWarPosList()
    local mBaseInfo = self:GetBaseInfo()
    if not self:IsNpcFmt() then
        return mBaseInfo[self.m_iFmt]["pos"]
    else
        local lResult = table_copy(mBaseInfo[self.m_iFmt]["pos"])
        return list_combine(lResult, {6,7,8,9,10})
    end
end

function CFormat:GetWarPos2Idx()
    local lPosList = self:GetWarPosList()
    local mResult = {}
    for idx, iPos in ipairs(lPosList) do
        mResult[iPos] = idx
    end
    return mResult
end

function CFormat:GetBaseEffect(idx)
    local iFmt = self.m_iFmt
    local mResult = {}
    if iFmt == 1 then
        return mResult
    end
    
    local iGrade = self:GetGrade()
    local mAttrInfo = self:GetAttrInfo()
    local mDetail = mAttrInfo[iFmt][idx]
    
    for idx, mInfo in pairs(mDetail.base_attr) do
        local sAttrName = mInfo.attr_name
        local sFormula = mInfo.formula

        if not mResult[sAttrName] then
            mResult[sAttrName] = 0
        end
        local iVal = formula_string(sFormula, {lv=iGrade})
        mResult[sAttrName] = mResult[sAttrName] + iVal
    end

    return mResult
end

function CFormat:GetExtEffect(idx)
    local iFmt = self.m_iFmt
    local mResult = {}
    if iFmt == 1 then
        return mResult
    end

    local iGrade = self:GetGrade()
    local mAttrInfo = self:GetAttrInfo()
    local mDetail = mAttrInfo[iFmt][idx]
    
    for idx, mInfo in pairs(mDetail.ext_attr) do
        local iLimit = mInfo.level
        local sAttrName = mInfo.attr_name
        local iRatio = mInfo.ratio

        if iGrade >= iLimit then
            if not mResult[sAttrName] then
                mResult[sAttrName] = 0
            end
            mResult[sAttrName] = mResult[sAttrName] + iRatio
        end
    end

    return mResult
end

function CFormat:GetIdxEffect(idx, oCamp)
    local mResult = {}
    if idx and idx <= 5 then
        local mBase = self:GetBaseEffect(idx)
        local mExt = self:GetExtEffect(idx)
    
        for sAttr, iEffect in pairs(mBase) do
            if not mResult[sAttr] then
                mResult[sAttr] = 0
            end
            mResult[sAttr] = mResult[sAttr] + iEffect
        end
    
        for sAttr, iEffect in pairs(mExt) do
            if not mResult[sAttr] then
                mResult[sAttr] = 0
            end
            mResult[sAttr] = mResult[sAttr] + iEffect
        end
    end

    if oCamp and oCamp.m_iFmtEffect and oCamp.m_iFmtEffect ~= 0 then
        local sAttr = 'damage_ratio'
        if not mResult[sAttr] then
            mResult[sAttr] = 0
        end
        mResult[sAttr] = mResult[sAttr] + oCamp.m_iFmtEffect
    end

    return mResult
end

function CFormat:OnEnterFormation(obj)
    obj:AddFunction("OnWarStart", self.m_iFmt, function (obj)
            local oWar = obj:GetWar()
            if not oWar then return end
            local oCamp = oWar:GetCampObj(obj:GetCampId())
            if not oCamp then return end
            if oCamp.m_oFormation then
                oCamp.m_oFormation:OnWarStart(obj)
            end
        end)
end

function CFormat:GetCampObj(obj)
    local oWar = obj:GetWar()
    local iCamp = obj:GetCampId()
    return oWar:GetCampObj(iCamp)
end

function CFormat:OnWarStart(obj)
    local oCamp = self:GetCampObj(obj)
    local iWarPos = obj:GetPos()
    local mPos2Idx = self:GetWarPos2Idx()
    local idx = mPos2Idx[iWarPos]
    local mInfo = self:GetIdxEffect(idx, oCamp)
    for sAttr, iVal in pairs(mInfo) do
        if sAttr == "speed" then
            obj.m_oBuffMgr:SetAttrBaseRatio(sAttr, self.m_iFmt, iVal)
        else
            obj.m_oBuffMgr:SetAttrAddValue(sAttr, self.m_iFmt, iVal)
        end
    end
end

function CFormat:CalFormationEffect(oFmt1)
    local iFmt1, iGrade1 = 1, 0
    if oFmt1 then
        iFmt1, iGrade1 = oFmt1:GetFmtId(), oFmt1:GetGrade()
    end

    local mBaseInfo = self:GetBaseInfo()
    local mFmtInfo = mBaseInfo[self.m_iFmt]
    local mFmtInfo1 = mBaseInfo[iFmt1]

    local mMutex = mFmtInfo.mutex
    local iEffect = mMutex[iFmt1]
    if not iEffect or iEffect == 0 then
        return 0
    end

    if iEffect > 0 then
        local sPositive = mFmtInfo.positive
        local iPositive = formula_string(sPositive, {lv=self:GetGrade()})
        local sPassive = mFmtInfo1.passive
        local iPassive = formula_string(sPassive, {lv=iGrade1})
        return math.max(0, iEffect + iPositive - iPassive)
    else
        local sPositive = mFmtInfo1.positive
        local iPositive = formula_string(sPositive, {lv=iGrade1})
        local sPassive = mFmtInfo.passive
        local iPassive = formula_string(sPassive, {lv=self:GetGrade()})
        return math.min(0, iEffect - iPositive + iPassive)
    end

    return 0
end

function CFormat:GetBaseInfo()
    return res["daobiao"]["formation"]["base_info"]
end

function CFormat:GetAttrInfo()
    return res["daobiao"]["formation"]["attr_info"]
end



