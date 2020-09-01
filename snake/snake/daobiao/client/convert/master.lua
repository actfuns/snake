module(..., package.seeall)
function main()
	local d1 = require("system.mentoring.question")
	local d2 = require("system.mentoring.answer")	
	local d3 = require("system.mentoring.task")
	local d4 = require("system.mentoring.step_result")
	local d5 = require("system.mentoring.text")
	local d6 = require("system.mentoring.progress_reward")
	local d7 = require("system.mentoring.config")
	
	local s = table.dump(d1, "QUESTION").. "\n" .. table.dump(d2, "ANSWER").. "\n" .. table.dump(d3, "TASK").. "\n" .. table.dump(d4, "STEPRESULT")
	.. "\n" .. table.dump(d5, "TEXT").. "\n" .. table.dump(d6, "PROGRESS").. "\n" .. table.dump(d7, "CONFIG")
	SaveToFile("master", s)
end