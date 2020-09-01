
local extend = require('extend')
local res = require('data')

local fight = {}


function InitFightData()
    local mData = {}
    mData.hp = 500000
    mData.mag_attack = "lv*5+30"
    mData.mag_defense = "lv*2+20"
    mData.mp = 5000
    mData.dodge_rate = 2
    mData.passive_skills = "0"
    mData.monster_id = 11001
    mData.fmt_id = 1
    mData.weather = 2
    mData.bosswar_type = "1,2000,1"

    mData.phy_attack = "lv*5+30"
    mData.phy_defense = "lv*2+20"
    mData.speed = "lv*2+20"
    mData.crit_rate = 1
    mData.active_skills = ChoosePerform()
    mData.count = 5
    mData.level = 1
    mData.fmt_grade = 1
    mData.sky_war = 0
    mData.aitype = 101
    return mData
end

fight.GS2CLoginSkill = function(self, args)
    local mActive = args.active_skill or {}
    local mPassive = args.passive_skill or {}
    local lSkill = {}
    for _, mInfo in pairs(mActive) do
        table.insert(lSkill, mInfo.sk)
    end
    self.m_lActiveSkill = lSkill

    self:sleep(math.random(12, 14))
    local mFight = InitFightData()
    self:run_cmd("C2GSTestWar", mFight)
end

fight.GS2CWarBoutStart = function(self, args)
    print ("回合开始"..args.war_id)
    local iWarId = args.war_id
    if not self.m_iAutoWar then
        self.m_iAutoWar = 1
        self:run_cmd("C2GSWarAutoFight", {type=1, war_id=iWarId, aitype=101})
    end
end

fight.GS2CWarResult = function (self, args)
    self:sleep(math.random(8, 12))
    local mFight = InitFightData()
    self:run_cmd("C2GSTestWar", mFight)
end

function GetPerformList()
    local lPerform = {}
    for _, mData in pairs(res.perform) do
        if (mData.id > 1000 and mData.id < 3000) or
            (mData.id > 5900 and mData.id < 6000) or
            (mData.id > 9501 and mData.id < 9600) then  
            table.insert(lPerform, mData.id)
        end
    end
    return lPerform
end

function ChoosePerform()
    local lPerform = GetPerformList()
    local lChoose = extend.Random.random_size(lPerform, 10)
    local lResult = {}
    for _, iPerform in pairs(lChoose) do
        local iLevel = math.random(1, 5)
        table.insert(lResult, iPerform.."|"..iLevel)
    end
    return table.concat(lResult, ",")
end

return fight
