module(..., package.seeall)
function main()
	local dOri = require("skill.active_school")
	local dPassiveOri = require("skill.passive_school")
	local dCultivation = require("skill.xiulian_passive")
	local dCultivationLimitTime = require("skill.learn_time")
	local dSe = require("skill.se")
	local orgskill = require("system.orgskill.skill")
	local orgskillupgrade = require("system.orgskill.upgrade")
	local SummonSkill = require("skill.summon")
	local dSchool = {}
	local dPassiveSch = {}
	local dActiveAttrSch = {}
	local xiulian_tips = require("skill.xiulian_text") 
	local d1 = require("skill.fuzhuan")
	local d2 = require("skill.text")
	local d3 = require("skill.config")
	local marry = require("skill.marry")
	local fabao = require("skill.fabao")
	local pFabao = require("perform.pflogic_fabao")

	local element_map = {
		["土"] = 1,
		["水"] = 2,
		["火"] = 3,
		["风"] = 4,
	}
	for k, v in pairs(dOri) do
		local iSchool = math.floor((k-1000) / 100)
		local iSort = k % 1000
		dSchool[k] = {
			id = k,
			name = v.name,
			icon = v.icon,
			type_desc = v.type,
			desc = v.desc,
			target_type = v.target_type,
			cost = v.cost,
			school = iSchool,
			sort = iSort,
			element = element_map[v.element_type],
			element_type = v.element_type,
			top_limit = v.top_limit,
			open_level = v.open_level,
			client_skillAttackType = v.client_skillAttackType,
			client_damageRatio = v.client_damageRatio,
			client_range = v.client_range,
			client_hpResume = v.client_hpResume,
			client_mpResume = v.client_mpResume,
			client_aura_resume = v.client_aura_resume,
			learn_limit = v.learn_limit,
			funcdesc = v.funcdesc,
			sortOrder = v.sortOrder,
			skillpoint_learn = v.skillpoint_learn,
			rolecreatedesc = v.rolecreatedesc,
		}

		local magics = {}
		for i, pfm in ipairs(v.pflist) do
			magics[pfm.pfid] = pfm.level
		end
		dSchool[k].magics = magics
	end
	for k, v in pairs(dPassiveOri) do
		dPassiveSch[k] = {
			id = k,
			icon = v.icon,
			name = v.name,
			open_level = v.open_level,
			element_type = v.element_type,
			skilltype = v.type,
			desc = v.desc,
			limit_level = v.limit_level,
			skill_effect = v.skill_effect,
		}
	end

	for k, v in pairs(fabao) do
		local p = pFabao[k]
		if p then	
			v.zhengqi = p.zhengqi_formula
		end
	end

	local s = table.dump(dSchool, "SCHOOL") .. "\n" .. table.dump(dCultivation, "CULTIVATION").."\n"..table.dump(dCultivationLimitTime, "CultivationLimitTime")
	.."\n"..table.dump(dSe, "SPECIAL_EFFC").."\n"..table.dump(dPassiveSch, "PASSIVE").."\n"..table.dump(orgskill, "ORGSKILL").."\n"..table.dump(orgskillupgrade, "ORGUPGRADE")
	.."\n"..table.dump(SummonSkill, "SummonSkill").."\n"..table.dump(xiulian_tips, "XILIANTIPS").."\n"..table.dump(d1, "FUZHUAN").."\n"..table.dump(d2, "TEXT").."\n"..table.dump(marry, "MARRY")
	.."\n"..table.dump(d3, "CONFIG").."\n"..table.dump(fabao, "FABAO")
	SaveToFile("skill", s)
end