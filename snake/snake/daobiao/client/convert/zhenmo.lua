module(..., package.seeall)

function main()
	local d1 = require("system.zhenmo.layer_config")
	local d2 = require("system.zhenmo.scene")
	local d3 = require("system.zhenmo.text")

	local s = table.dump(d1, "CONFIG") .. "\n" .. table.dump(d2, "SCENE") .. "\n" .. table.dump(d3, "TEXT")
	SaveToFile("zhenmo", s)
end