module(..., package.seeall)
function main()
	local dOri = require("system.role.randomname")
	local d1 = require("system.role.randomjiebaititle")
	local d2 = require("system.role.randomjiebaiminghao")
	local First = {}
	local Male = {}
	local Female = {}
	local Specity = {}
	for k, v in pairs(dOri) do
		if v.firstName ~= "" then
			table.insert(First, v.firstName)
		end
		if v.maleName ~= "" then
			table.insert(Male, v.maleName)
		end
		if v.femaleName ~= "" then
			table.insert(Female, v.femaleName)
		end
		if v.specityName ~= "" then
			table.insert(Specity, v.specityName)
		end
	end
	local s = table.dump(First, "FIRST").."\n"..table.dump(Male, "MALE").."\n"..table.dump(Female, "FEMALE").."\n"..table.dump(Specity, "SPECITY")
	.. "\n" .. table.dump(d1, "JIEBAITITLE") .. "\n" .. table.dump(d2, "JIEBAIMINGHAO")
	SaveToFile("randomname", s)
end
