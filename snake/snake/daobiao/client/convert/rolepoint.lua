module(..., package.seeall)
function main()
	local d1 = require("system.role.point")
	local d2 = require("system.role.washpoint")
	local d3 = require("system.role.roleprop")
	local d4 = require("system.role.rolebasicscore")
	local dNew = {}
	for k, v in pairs(d1) do
		local key = v.macro
		local value = {
			max_hp = v.max_hp_add,
			max_mp = 0,
			speed = v.speed_add,
			phy_attack = v.phy_attack_add,
			mag_attack = v.mag_attack_add,
			phy_defense = v.phy_defense_add,
			mag_defense = v.mag_defense_add,

		}
		dNew[key] = value
	end
	local s = table.dump(dNew, "ROLEPOINT").."\n"..table.dump(d2, "LEVEL").."\n"..table.dump(d3, "INIT").."\n"..table.dump(d4, "ROLEBASICSCORE")
	SaveToFile("rolepoint", s)
end