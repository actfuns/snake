module(..., package.seeall)
function main()
	local  t = table.dump(require ("huodong.hfdm.text"), "HFDMTEXT")

	SaveToFile("hfdm", t)
end