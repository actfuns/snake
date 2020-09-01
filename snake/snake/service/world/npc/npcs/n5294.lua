--import module
local res = require "base.res"
local global = require "global"
local npcobj = import(service_path("npc.npcobj"))
local handlenpc = import(service_path("npc.handlenpc"))
local gamedefines = import(lualib_path("public.gamedefines"))

mOption2Func = {
    [1] = "DoIntroduce",
    [2] = "BuildRelationShip",
    [3] = "ApprenticeGrowup",
    [4] = "DismissRelationship",
    [5] = "ToBeMentor",
    [6] = "CancelBeMentor",
    [7] = "ToBeApprentice",
    [8] = "FindMentor",
    [9] = "ForceApprenticeGrowup",
    [10] = "SureForceApprenticeGrowup",
}

function NewGlobalNpc(iNpcType)
    local o = CNpc:New(iNpcType)
    return o
end

CNpc = {}
CNpc.__index = CNpc
inherit(CNpc,npcobj.CGlobalNpc)

function CNpc:do_look(oPlayer)
    if not global.oToolMgr:IsSysOpen("MENTORING",oPlayer,true) then
        super(CNpc).do_look(self, oPlayer)
        return
    end

    local iPid = oPlayer:GetPid()
    local sText  = res["daobiao"]["dialog_npc"][self.m_iDialog]["dialogContent1"]
    local lMenu = {
        [1] = {"怎么样拜师或收徒", 1},
        [2] = {"带徒弟拜师", 2},
        [3] = {"带徒弟出师", 3},
        [4] = {"解除师徒关系", 4},
        [5] = {"申请强制出师", 9},
        [6] = {"强制出师确认", 10},
    }
    local mConfig = global.oMentoring:GetConfig()
    if oPlayer:GetGrade() >= mConfig.mentor_grade_min then
        if global.oMentoring:GetMentorByPid(iPid) then
            table.insert(lMenu, 2, {"取消报名", 6})
        else
            table.insert(lMenu, 2, {"报名当师傅", 5})
        end
    else
        if global.oMentoring:GetApprenticeByPid(iPid) then
            table.insert(lMenu, 2, {"推荐师傅", 8})
        else
            table.insert(lMenu, 2, {"寻找师傅", 7})
        end
    end
    local lOption = {}
    for _, mOption in ipairs(lMenu) do
        table.insert(lOption, mOption[1])
    end
    sText = sText .. "&Q" .. table.concat(lOption, "&Q")
    local iNpc = self:ID()
    self:SayRespond(iPid, sText, nil, function(oPlayer, mData)
        local oNpcMgr = global.oNpcMgr
        local oNpc = oNpcMgr:GetObject(iNpc)
        if oNpc then
            oNpc:Respond(oPlayer, mData, lMenu)
        end
    end)
end

function CNpc:Respond(oPlayer, mData, lMenu)
    if not global.oToolMgr:IsSysOpen("MENTORING", oPlayer) then
        return
    end

    local iAnswer = mData.answer
    local sOption, iOption = table.unpack(lMenu[iAnswer])
    local sFunc = mOption2Func[iOption]
    if not iOption then return end

    self[sFunc](self, oPlayer, mData)
end

function CNpc:DoIntroduce(oPlayer, mData)
    --说明
    oPlayer:Send("GS2CHuodongIntroduce", {id=10060})
end

function CNpc:BuildRelationShip(oPlayer, mData)
    --带徒弟拜师
    global.oMentoring:TryBuildRelationShip(oPlayer)
end

function CNpc:ApprenticeGrowup(oPlayer, mData)
    --带徒弟出师
    global.oMentoring:TryApprenticeGrowup(oPlayer)
end

function CNpc:ForceApprenticeGrowup(oPlayer, mData)
    --强制出师
    global.oMentoring:TryForceApprenticeGrowup(oPlayer)
end

function CNpc:SureForceApprenticeGrowup(oPlayer, mData)
    --强制出师确认
    global.oMentoring:SureForceApprenticeGrowup(oPlayer)
end

function CNpc:DismissRelationship(oPlayer, mData)
    --解除师徒关系
    global.oMentoring:TryDismissRelationship(oPlayer)
end

function CNpc:ToBeMentor(oPlayer, mData)
    --登记成为师傅
    local iPid = oPlayer:GetPid()
    local iRet, mReplace = global.oMentoring:ValidToBeMentor(oPlayer)
    if iRet ~= 1 then
        global.oMentoring:Notify(iPid, iRet, mReplace)
        return
    end
    local mNet = {
        option_list = oPlayer:Query("mentor_option"),
        type = 1,
    }
    oPlayer:Send("GS2CMentoringStartAnswer", mNet)
end

function CNpc:CancelBeMentor(oPlayer, mData)
    --取消登记成为师傅
    local mData = global.oToolMgr:GetTextData(1007, {"mentoring"})
    mData = global.oCbMgr:PackConfirmData(nil, mData)
    global.oCbMgr:SetCallBack(oPlayer:GetPid(), "GS2CConfirmUI", mData, nil,
    function(oPlayer, mData)
        if mData.answer == 1 then
            global.oMentoring:CancelBeMentor(oPlayer)
        end
    end)
end

function CNpc:ToBeApprentice(oPlayer, mData)
    --登记成为学徒
    local iPid = oPlayer:GetPid()
    local iRet, mReplace = global.oMentoring:ValidToBeApprentice(oPlayer)
    if iRet ~= 1 then
        global.oMentoring:Notify(iPid, iRet, mReplace)
        return
    end
    local mNet = {
        option_list = oPlayer:Query("apprentice_option"),
        type = 2,
    }
    oPlayer:Send("GS2CMentoringStartAnswer", mNet)
end

function CNpc:FindMentor(oPlayer, mData)
    --推荐师傅
    global.oMentoring:TryFindMentor(oPlayer)
end

