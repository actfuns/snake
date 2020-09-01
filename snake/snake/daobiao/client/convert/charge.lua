module(..., package.seeall)
function main()
    local nameList ={
        {path = "day_gift", name = "DAILY"},
        {path = "goldcoin_gift", name = "YUANBAO"},
        {path = "grade_gift", name = "BIGPROFIT"},
        {path = "text", name = "TEXT"},
    }

    local s
    for _, v in ipairs(nameList) do
        local d = table.dump(require("huodong.charge."..v.path), v.name)
        if not s then
            s = d
        else
            s = s .. "\n" .. d
        end
    end
    SaveToFile("charge", s)
end