module(..., package.seeall)
define = {}
define.Maigc = {
	Element = {
		Soil = 1,
		Water = 2,
		Fire = 3,
		Wind = 4,
	},
	Action = {
		Attack = 1,
		Seal = 2,
		Assist = 3,
		Cure = 4,
	},
	Target = {
		Ally = 1,
		Enemy = 2,
		Self = 3,
	},
	Stauts = {
		Alive = 1,
		Die = 2,
	},
	AttackType = {
		Phy = 1,
		Mag = 2,
	}
}

function main()
	local dSchool = require("perform.school")
	local dSchoolLogic = require("perform.pflogic_school")

	local dSummon = require("perform.sumperform")
	local dSummonLogic = require("perform.pflogic_summon")
	local dSummonPassive = require("perform.summon_passive")

	local dPartner = require("perform.partner")
	local dPartnerLogic = require("perform.pflogic_partner")

	local dNpc = require("perform.npc")
	local dNpcLogic = require("perform.pflogic_npc")
	-- local dNpcPassive = require("perform.summon_passive")

	local dSe = require("perform.se")
	local dSeLogic = require("perform.pflogic_se")

	local dMarry = require("perform.marry")
	local dMarryLogic = require("perform.pflogic_marry")

	local dFabao = require("perform.fabao")
	local dFabaoLogic = require("perform.pflogic_fabao")

	local d = {}
	local dMain = {school = dSchool, summon = dSummon, partner = dPartner, npc = dNpc, se = dSe, marry = dMarry, fabao = dFabao}
	local dLogic = {school = dSchoolLogic, summon = dSummonLogic, partner = dPartnerLogic, npc = dNpcLogic, se = dSeLogic, marry = dMarryLogic, fabao = dFabaoLogic}
	local dPassive = {summon = dSummonPassive, marry = dMarry}

	local elemet_map = {
		[1] = 1,
		[2] = 2,
		[3] = 3,
		[4] = 4,
	}
	local action_map = {
		[51] = 1,
		[52] = 2,
		[53] = 3,
		[54] = 4,
	}
	local attacktype_map = {
		[21] = 1,
		[22] = 2,
	}
	local function build(k, v, name)
		local logicTable = dLogic[name]
		local pflogic = logicTable[v.pflogic]
		local dOne = {
			magic_type = name,
			name = v.name,
			desc = v.desc,
			type_desc = v.type_desc,
			skill_icon = (v.skill_icon ~= 0) and v.skill_icon or nil,
			-- 作用目标类型,1:己方,2:敌方,3:自己
			target_type = pflogic.targetType or 1,
			-- 作用目标状态要求（1.存活，2.死亡）
			target_status = pflogic.useTargetStatus or 1,
			element = elemet_map[v.skillElementType],
			damage_ratio = pflogic.damageRatio or 100,
			cost = {
				mp = pflogic.mpResume~="" and pflogic.mpResume or nil,
				hp = pflogic.hpResume~="" and pflogic.hpResume or nil,
				aura = pflogic.aura_resume~="0" and pflogic.aura_resume~="" and pflogic.aura_resume or nil,
				sp = pflogic.sp_resume~="" and pflogic.sp_resume or nil,
			},
			-- 1物理 2法术
			is_physic = (pflogic.skillAttackType == 1),
		}
		if name == "fabao" then
			dOne.is_active = v.is_active == 1
			dOne.zhengqi = pflogic.zhengqi_formula
		end
		d[k] = dOne
	end

	for k,v in pairs(dMain) do
		for k2,v2 in pairs(v) do
			build(k2, v2, k)
		end
	end

	local p = {}
	for _,t in pairs(dPassive) do
		for k,v in pairs(t) do
			p[k] = v
		end
	end
	
	local s = table.dump(d, "DATA") .. "\n" .. table.dump(p, "PASSIVE")
	SaveToFile("magic", s)
end
