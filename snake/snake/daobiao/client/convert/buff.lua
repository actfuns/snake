module(..., package.seeall)
function main()
	local dOri = require("buff.buff")
	local dAll= {}
	local typeMap = {
		["封印法术"] = 1,
		["封印物理"] = 2,
		["不能行动"] = 3,
	}
	local eventMap = {
		["攻击开始"] = 1,
		["受击动作"] = 2,
		["攻击结束"] = 3,
	}
	for k, v in pairs(dOri) do
		local dOne = {
			name = v.name,
			trans = v.trans,
			desc = v.desc,
			type = typeMap[v.type],
			event = eventMap[v.event],
			color = v.color,
			icon = v.icon,
		}
		dAll[k] = dOne
	end
	local s = table.dump(dAll, "DATA")
	SaveToFile("buff", s)
end