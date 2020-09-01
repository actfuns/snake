module(..., package.seeall)
function main()
	local d1 = require("system.ride.rideinfo")
	local d2 = require("system.ride.upgrade")
	local d3 = require("skill.ride")
	local d4 = require("system.ride.buytime")
	local d5 = require("system.ride.other")
	local d6 = require("system.ride.text")
	local attrList = 
	{
		phy_attack = "物攻",
		phy_defense = "物防",
		mag_attack = "法攻",
		mag_defense = "法防",
		speed = "速度",
		max_hp = "气血",
		seal_ratio = "封印命中",
		res_seal_ratio = "封印抗性",
		phy_critical_ratio = "物理暴击",
		mag_critical_ratio = "法术暴击",
	}
	for k,v in pairs(d1) do
		for i,b in pairs(v.attr_effect) do
			for j,c in pairs(attrList) do
				local start = string.find(b,j)
				if start == 1 then
					local str = string.gsub(b, j,"")
					str = string.gsub(str, "=", "")
					if d1[k].attr == nil then
						d1[k].attr = {}
					end
					if d1[k].attr[j] == nil then
						d1[k].attr[j] = {}
					end
					d1[k].attr[j].val = str
					d1[k].attr[j].name = c
					break
				end 
			end
		end
	end
	local buyinfo = {}
	for k,v in pairs(d4) do
		if buyinfo[v.ride_id] == nil then
			buyinfo[v.ride_id] = {}		
		end
		table.insert(buyinfo[v.ride_id],v)
	end
	for k,v in pairs(buyinfo) do
		table.sort(v, function(v1, v2)
			return v1.valid_day < v2.valid_day
		end)
		table.insert(v, v[1])
		table.remove(v, 1)
	end
	local s = table.dump(d1, "RIDEINFO").."\n"..table.dump(d2,"UPGRADE").."\n"..table.dump(d3,"SKILL").."\n"..table.dump(buyinfo,"BUYINFO") .. "\n"..table.dump(d5,"OTHER") .. "\n"..table.dump(d6,"TEXT")
	SaveToFile("ride", s)
end
