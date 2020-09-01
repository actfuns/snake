module(..., package.seeall)
function main()
    local nameList = {"type", "info", "prop", "upper", "quality", "suilt", "text", "exp", "partnerequip", "upgrade_cost", "strength_cost"}
    local s

    local function sum(n, name)
        local t = table.dump(n, string.upper(name))
        if s then
            s = s .. "\n" .. t
            return
        end
        s = t
    end

    for _,v in ipairs(nameList) do
        local t = require("system.partner." .. v)
        sum(t, v)
    end

    local partnerequip = require("system.partner.partnerequip")
    local pos2equip = {}
    local equipcostitem = {}
    for i,v in ipairs(partnerequip) do
        pos2equip[v.equip_sid] = i
        local itemsid = v.upgrade_cost_sid
        equipcostitem[itemsid] = true
    end
    sum(pos2equip, "pos2equip")
    sum(equipcostitem, "equipcostitem")

    local skillOri = require("skill.partner")
    sum(skillOri, "skill")
    local protect_skill_list = {}
    for k,v in pairs(skillOri) do
        if v.protect == 1 then
            table.insert(protect_skill_list, v.id)
        end 
    end
    local function sort(data1, data2)
        return data1 < data2
    end
    table.sort(protect_skill_list, sort)
    sum(protect_skill_list, "protectSkillLlist")

    local pointOri = require("system.partner.point")
    local point = {}
    for _,v in ipairs(pointOri) do
        if not point[v.partner] then
            point[v.partner] = {}
        end
        point[v.partner][v.quality] = v
    end
    sum(point, "point")

    local upperLimitOri = require("system.partner.upperlimit")
    local upperLimit = {}
    for _,v in ipairs(upperLimitOri) do
        if not upperLimit[v.partner] then
            upperLimit[v.partner] = {}
        end
        upperLimit[v.partner][v.upper] = v
    end
    sum(upperLimit, "upperLimit")

    local qualityCostOri = require("system.partner.qualitycost")
    local qualityCost = {}
    for _,v in ipairs(qualityCostOri) do
        if not qualityCost[v.partner] then
            qualityCost[v.partner] = {}
        end
        qualityCost[v.partner][v.quality] = v
    end
    sum(qualityCost, "qualityCost")

    local skillUnlockOri = require("system.partner.skillunlock")
    local skillUnlock = {}
    for _,v in ipairs(skillUnlockOri) do
        if not skillUnlock[v.partner] then
            skillUnlock[v.partner] = {}
        end
        skillUnlock[v.partner][v.class] = v
    end
    sum(skillUnlock, "skillUnlock")

    local skillUpgradeOri = require("system.partner.skillupgrade")
    local skillUpgrade = {}
    for _,v in ipairs(skillUpgradeOri) do
        if not skillUpgrade[v.skill_id] then
            skillUpgrade[v.skill_id] = {}
        end
        skillUpgrade[v.skill_id][v.level] = v
    end
    sum(skillUpgrade, "skillUpgrade")

    local protectOri = require("system.partner.protect_skill")
    sum(protectOri, "protectSkill")
	SaveToFile("partner", s)
end