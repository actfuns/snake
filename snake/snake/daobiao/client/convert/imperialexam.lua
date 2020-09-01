module(..., package.seeall)

function main()
	local d1 = require("huodong.imperialexam.firststage_question")
	local d2 = require("huodong.imperialexam.secondstage_question")
	local d3 = require("huodong.imperialexam.config")

	local s = table.dump(d1, "FRIST_QUESTIONS") .. "\n" .. table.dump(d2, "SECOND_QUESTIONS").. "\n" .. table.dump(d3, "CONFIG")
	SaveToFile("imperialexam", s)
end