module(..., package.seeall)
function main()
	local d1 = require("huodong.lingxi.flower_use_pos")
	local d2 = require("huodong.lingxi.choose_question")
	local d3 = require("huodong.lingxi.poem")
	local d4 = require("huodong.lingxi.global_config")
	
	local s = table.dump(d1, "USEPOS").. "\n" .. table.dump(d2, "QUESTION").. "\n" .. table.dump(d3, "POEM").. "\n" .. table.dump(d4, "GLOBAL")
	SaveToFile("lingxi", s)
end