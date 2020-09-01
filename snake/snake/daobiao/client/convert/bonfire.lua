module(..., package.seeall)
function main()
	local custom_choice = require("huodong.orgcampfire.custom_choice")
	local fixed_choice = require("huodong.orgcampfire.fixed_choice")
	local fill_in = require("huodong.orgcampfire.fill_in")
	local config  = require("huodong.orgcampfire.global_config")
	local text  = require("huodong.orgcampfire.text")
	local topic = {}
	for k, v in pairs(custom_choice) do
		topic[k] = v.title
	end
	for k, v in pairs(fixed_choice) do
		topic[k] = v.title
	end
	for k, v in pairs(fill_in) do
		topic[k] = v.title
	end
	local configs = {}
	for k, v in pairs(config) do
		for c, b in pairs(v) do
			configs[c] = b
		end
	end
	local s = table.dump(topic, "TOPIC").."\n"..table.dump(configs, "CONFIG").."\n"..table.dump(text, "TEXT")
	SaveToFile("bonfire", s)
end