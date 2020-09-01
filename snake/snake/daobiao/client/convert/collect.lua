module(..., package.seeall)
function main()
    local nameList ={
        {path = "collect_gift", name = "GIFT"},
        {path = "collect_config", name = "CONFIG"},
        {path = "collect_item", name = "ITEM"},
        {path = "text", name = "TEXT"},
    }

    local s
    for _, v in ipairs(nameList) do
        local d = table.dump(require("huodong.collect."..v.path), v.name)
        if not s then
            s = d
        else
            s = s .. "\n" .. d
        end
    end
    SaveToFile("collect", s)
end