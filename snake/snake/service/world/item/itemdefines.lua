ITEM_KEY_BIND = 1                               --绑定
ITEM_KEY_TIME = 1<<1                            --时效道具

local mApplyName = {
    ["mag_attack"] = "法术攻击",
    ["phy_attack"] = "物理攻击",
    ["cure_power"] = "治疗强度",
    ["max_mp"] = "魔法上限",
    ["phy_defense"] = "物理防御",
    ["mag_defense"] = "法术防御",
    ["max_hp"] = "气血上限",
    ["speed"] = "速度",
}

function GetApplyName(sAttr)
    return mApplyName[sAttr] or ""
end

EQUIP_WEAPON  =  1 --武器
EQUIP_HAT = 2 --帽子
EQUIP_NECK = 3 --项链
EQUIP_CLOTH = 4 --铠甲
EQUIP_BELT = 5 --腰带
EQUIP_SHOE = 6 --鞋子

function GetEquipName(iEquipPos)
    local res = require "base.res" 
    local sName = res["daobiao"]["equipposname"][iEquipPos]["name"]
    return sName
end

--[[ 单独用的两个
WING_POS = 7
ARTIFACT_POS = 8
STRENGTH_MASTER = 91
]]
ApplyDefines = {
    ["apply"] = 1,
    ["ratio"] = 2,
    ["attach"] = 3,
    ["strength"] = 4,
    ["shenhun"] = 5,
    ["shenhunext"] = 6,
    ["hunshi"] = 7,
    ["fuzhuan"] = 8,
    ["strengthmaster"] = 9, --占位,强化大师的,已经用了下边的STRENGTH_MASTER,防止被覆盖
    ["treasureconvoy"] = 10,
}

function GetApplySource(iPos, sType)
    local iDefines = ApplyDefines[sType] or 0
    return iDefines * 10 + iPos
end

-- 强化大师的效果设定POS编号(用于equipMgr)
STRENGTH_MASTER = 91


-- 最低打造40级装备，对应MIN=LV/10-1
EQUIP_MAKE_MIN_LEVEL = 3

--藏宝图类型 普通为1,高级为2
TREASUREMAP_TYPE_NORMAL = 101
TREASUREMAP_TYPE_HIGH = 102

--藏宝图对应的场景组ID
TREASUREMAP_SCENEGROUP ={
    [TREASUREMAP_TYPE_NORMAL] = 103,
    [TREASUREMAP_TYPE_HIGH] = 104,
}

--藏宝图事件总权重
TREASUREEVENT_TOTOALWEIGHT = 100

function GetEquipLevelData()
    local res = require "base.res"
    return res["daobiao"]["equiplevel"]
end

function GetEquipLevels()
    local res = require "base.res"
    return res["daobiao"]["equiplevels"] or {}
end

--获取装备对应的符纸, 这依赖配置id
function GetEquipFus(iEquipLv, iPos)
    --打造符,裁缝符,炼金
    local iMinSid
    if table_in_list({EQUIP_WEAPON, EQUIP_NECK, EQUIP_BELT}, iPos) then
        iMinSid = 12000        
    elseif table_in_list({EQUIP_HAT, EQUIP_CLOTH, EQUIP_SHOE}, iPos) then
        iMinSid = 12030 
    else
        iMinSid = 12060
    end

    local lFuSids = {}
    for _, iLv in pairs(GetEquipLevels()) do
        if iEquipLv <= iLv then
            local iFuSid = iMinSid + iLv // 10 - EQUIP_MAKE_MIN_LEVEL 
            table.insert(lFuSids, iFuSid)
        end
    end
    return lFuSids
end

function GetShenHun(iEquipLv)
    return 12100 + (iEquipLv - 60) // 10
end

function GetFuHunStore(iEquipLv, iPos)
    local iMinSid
    if table_in_list({EQUIP_WEAPON, EQUIP_NECK, EQUIP_BELT}, iPos) then
        iMinSid = 12120        
    elseif table_in_list({EQUIP_HAT, EQUIP_CLOTH, EQUIP_SHOE}, iPos) then
        iMinSid = 12140 
    end
    return iMinSid + (iEquipLv - 60) // 10
end

-- 宠物装备类型
SUMMON_EQUIP_XQ = 1
SUMMON_EQUIP_ZJ = 2
SUMMON_EQUIP_HF = 3

CONTAINER_MAP = {
    ITEM_CTRL = 1,
    ITEM_TMP_CTRL = 2,
    WH_CTRL = 3,
}

