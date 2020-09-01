module(..., package.seeall)

function main()
	local d1 = require("system.engage.engagetype")
	local d2 = require("system.engage.text")

	local config = require("system.engage.config")
	local d3 = {}
	for k, v in pairs(config[1]) do
		d3[k] = v
	end

	local d4 = require("system.engage.upgrade")

	local s = table.dump(d1, "TYPE") .. "\n" .. table.dump(d2, "TEXT").. "\n" .. table.dump(d3, "CONFIG")
		.. "\n" .. table.dump(d4, "UPGRADE")
	SaveToFile("engage", s)
end