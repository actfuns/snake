ATTRS = {"physique", "magic", "strength", "endurance", "agility"}
APTITUDES = {"attack", "defense", "health", "mana", "speed"}
APTITUDE_NAMES = {attack="攻击资质", defense="防御资质", health="体力资质", mana="法力资质", speed="速度资质"}

KEY_BIND = 1

TYPE_WILD = 1
TYPE_NORMALBB = 2
TYPE_BIANYIBB = 3
TYPE_XIYOUBB = 4
TYPE_HOLYBB = 5
TYPE_ZHENSHOU = 6
TYPE_XYHOLY = 7
TYPE_XYZHENSHOU = 8


function IsBB(iType)
    return iType == TYPE_NORMALBB or iType == TYPE_BIANYIBB or iType == TYPE_XIYOUBB
end

function NotNormalBB(iType)
    return iType == TYPE_BIANYIBB or iType == TYPE_XIYOUBB
end

function IsImmortalBB(iType)
    return IsShenShouBB(iType) or IsZhenShouBB(iType)
end

function IsShenShouBB(iType)
    return table_in_list({TYPE_HOLYBB, TYPE_XYHOLY}, iType)   
end

function IsZhenShouBB(iType)
    return table_in_list({TYPE_ZHENSHOU, TYPE_XYZHENSHOU}, iType)   
end

function IsXYZhenShouBB(iType)
    return table_in_list({TYPE_XYZHENSHOU}, iType)
end

RACE_REN = 1
RACE_XIAN = 2
RACE_YAO = 3

ITEM_WASH = 10031
ITEM_BOOK_QIANLI = 30000
ITEM_SKILL_STONE = 10032
ITEM_SUMMON_EXPBOOK = 10033
ITEM_SUMMON_EXP = {11188, 10033}

EXP_PER_BOOK = 40000

ITEM_COMBINE = 11189
ITEM_SHENSHOU_STONE = 11176
ITEM_XYZHENSHOU_STONE = 10181

RIDE_ATTR_SOURCE = 99

-- 不扣除死亡寿命系统 
NOT_SUB_DEAD_LIFE = {
    ["liumai"] = true,
    ["orgwar"] = true,
    ["moneytree"] = true,
    ["schoolpass"] = true,
    ["biwu"] = true,
    ["mengzhu"] = true,
    ["jjc"] = true,
    ["trial"] = true,
    ["arena"] = true,
}

CH_NUM_MAP = {
    [1] = "一",
    [2] = "二",
    [3] = "三",
    [4] = "四",
    [5] = "五",
    [6] = "六",
    [7] = "七",
    [8] = "八",
    [9] = "九",
}
