local global = require "global"
local res = require "base.res"
local extend = require "base.extend"
local record = require "public.record"
local interactive = require "base.interactive"

local datactrl = import(lualib_path("public.datactrl"))
local gamedefines = import(lualib_path("public.gamedefines"))
local gamedb = import(lualib_path("public.gamedb"))

function NewMentoring()
    return CMentoring:New()
end

CMentoring = {}
CMentoring.__index = CMentoring
inherit(CMentoring, logic_base_cls())

function CMentoring:New()
    local o = super(CMentoring).New(self)
    o.m_mMentor = {}
    o.m_mApprentice = {}
    o.m_mOnline = {}
    return o
end

function CMentoring:Release()
    super(CMentoring).Release(self)
end

function CMentoring:BuildShareObj(mShare)
    self.m_mMentor = mShare.mentor or {}
    self.m_mApprentice = mShare.apprentice or {}
end

function CMentoring:UpdateMentorInfo(iPid, mInfo)
    self.m_mMentor[iPid] = mInfo
end

function CMentoring:UpdateApprenticeInfo(iPid, mInfo)
    self.m_mApprentice[iPid] = mInfo
end

function CMentoring:UpdateOnline(iPid, mData)
    local mOnline = {
        ret_friend_cnt = mData.ret_friend_cnt or 0,
        cd_time = mData.cd_time or 0,
        black_list = mData.black_list or {},
    }
    self.m_mOnline[iPid] = mOnline
end

function CMentoring:UpdateOffline(iPid)
    self.m_mOnline[iPid] = nil
end

function CMentoring:GetAllMentor()
    return self.m_mMentor
end

function CMentoring:GetAllApprentice()
    return self.m_mApprentice
end

function CMentoring:MatchMentor(iPid, iSchool)
    local mApprentice = self:GetAllApprentice()
    if not mApprentice[iPid] then
        return
    end
    local mConfig = res["daobiao"]["mentoring"]["config"][1]
    local mMentor = self:GetAllMentor()
    local lArray, iLimit = {}, 4
    local lOption1 = mApprentice[iPid].option
    for iMentor, mInfo in pairs(mMentor) do
        if not self.m_mOnline[iMentor] then
            goto continue
        end
        if self.m_mOnline[iMentor].cd_time >= get_time() then
            goto continue
        end
        if self.m_mOnline[iMentor].ret_friend_cnt < 1 then
            goto continue
        end
        if self.m_mOnline[iMentor].black_list[iPid] then
            goto continue
        end
        if (mInfo.count or 0) >= mConfig.apprentice_cnt then
            goto continue
        end
        local lOption2 = mInfo.option
        if not lOption2 then goto continue end

        local iPoint = self:CalPoint(lOption1, lOption2, self.m_mOnline[iMentor], iSchool)
        local mUnit = {pid=iMentor, point=iPoint}
        if #lArray < iLimit then
            self:HeapInsert(lArray, mUnit, iLimit)
        else
            if math.min(mUnit.point, lArray[2].point, lArray[3].point) == mUnit.point then
                self:HeapInsert(lArray, mUnit, 4)
            end
        end
        ::continue::
    end
    return lArray
end

function CMentoring:CalPoint(lOption1, lOption2, mMentor, iSchool)
    local mOption1, mOption2 = {}, {}
    for _, mUnit in ipairs(lOption1) do
        mOption1[mUnit.question_id] = mUnit.answer
        --徒弟
    end
    for _, mUnit in ipairs(lOption2) do
        mOption2[mUnit.question_id] = mUnit.answer
        --师傅
    end
    local mAllQuestion = res["daobiao"]["mentoring"]["question"]
    local mAnswer = res["daobiao"]["mentoring"]["answer"]
    local iPoint = 0

    for _, iQues in ipairs({3,5,6}) do
        local mQuestion = mAllQuestion[iQues]
        if not mQuestion then goto continue end

        local iAnswer1, iAnswer2 = mOption1[iQues], mOption2[iQues]
        if iAnswer1 == iAnswer2 then
            iPoint = iPoint + (mQuestion.point or 0)
        else
            if mAnswer[iAnswer1].match_all == 1 then
                iPoint = iPoint + (mQuestion.point or 0)
            elseif mAnswer[iAnswer2].match_all == 1 then
                iPoint = iPoint + (mQuestion.point or 0)
            end
        end
        ::continue::
    end
    local iAnswer1, iAnswer2 = mOption1[2], mOption2[1]
    if iAnswer1 % 2 == iAnswer2 % 2 or mAnswer[iAnswer1].match_all == 1 then
        iPoint = iPoint + mAllQuestion[2].point
    end
    local iAsnwer1, iAnswer2 = mOption2[2], mOption1[1]
    if iAnswer1 % 2 == iAnswer2 % 2 or mAnswer[iAnswer1].match_all == 1 then
        iPoint = iPoint + mAllQuestion[2].point
    end
    local iAnswer1 = mOption1[4]
    if mAnswer[iAnswer1].match_all == 1 then
        iPoint = iPoint + mAllQuestion[4].point
    else
        if iAnswer1 == 10 and gamedefines.ASSISTANT_SCHOOL[mMentor.school] then
            iPoint = iPoint + mAllQuestion[4].point
        elseif iAnswer1 ~= 10 and not gamedefines.ASSISTANT_SCHOOL[mMentor.school] then
            iPoint = iPoint + mAllQuestion[4].point
        end
    end
    local iAnswer2 = mOption2[4]
    if mAnswer[iAnswer2].match_all == 1 then
        iPoint = iPoint + mAllQuestion[4].point
    else
        if iAnswer2 == 10 and gamedefines.ASSISTANT_SCHOOL[iSchool] then
            iPoint = iPoint + mAllQuestion[4].point
        elseif iAnswer2 ~= 10 and not gamedefines.ASSISTANT_SCHOOL[iSchool] then
            iPoint = iPoint + mAllQuestion[4].point
        end
    end
    return iPoint
end

function CMentoring:HeapAdjust(lArray, iBegin, iEnd)
    local iLeft = 2*iBegin
    while iLeft <= iEnd do
        if iLeft < iEnd and lArray[iLeft].point < lArray[iLeft+1].point then
            iLeft = iLeft + 1
        end
        if lArray[iLeft].point <= lArray[iBegin].point then
            break
        end

        self:Swap(lArray, iBegin, iLeft)
        iBegin = iLeft
        iLeft = 2*iBegin
    end
end

function CMentoring:HeapInsert(lArray, mUnit, iLimit)
    lArray[#lArray+1] = mUnit
    self:HeapAdjust(lArray, 1, #lArray)

    for i = iLimit, #lArray do
        lArray[i] = nil
    end
end

function CMentoring:Swap(lArray, i, j)
    local tmp = lArray[i]
    lArray[i] = lArray[j]
    lArray[j] = tmp
end


