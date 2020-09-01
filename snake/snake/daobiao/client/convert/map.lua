module(..., package.seeall)
function main()
	local dMap = require("system.map.map")
	local dScene = require("system.map.scene")
	local d3 =  require("system.map.scene_effect")
	local d4 =  require("system.map.water_walk")
	local s = table.dump(dMap, "MAP") .. "\n" .. table.dump(dScene, "SCENE") .. "\n" .. table.dump(d3, "SCENEEFFECT") .. "\n" .. table.dump(d4, "WATERWALK")
	SaveToFile("map", s)
end


