module(..., package.seeall)
function main()
	local sourcebook = {[1]="equipdes",[2]= "equipfujiades",[3]="summondes",[4]="summonkind",
					[5] = "upgradesecondary",[6]="upgrade",[7] = "gametechcontent",[8]="gametech",
					[9] = "cambatskill", [10]="cambatcontent",[11] = "partnerbook",
					[12] = "helpskill", [13]= "helpskillcontent"
				}
	local s 
	for i,v in ipairs(sourcebook) do
		local  t = table.dump(require ("system.sourcebook."..v), string.upper(v))
		if not s then
			s = t 
		else
			s = s.."\n" .. t
		end
	end

	SaveToFile("sourcebook", s)
end