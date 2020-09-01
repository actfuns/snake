module(..., package.seeall)
function main()
    local d1 = table.dump(require("effect.enteraoi"), "ENTERAOI")
    local s = d1
    SaveToFile("effect", s)
end