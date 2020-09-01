module(..., package.seeall)
function main()
    local nameList = {
        {path = "itemexchangeclient",      name = "item"},
        {path = "itemexchangeserver",      name = "exchange"},
    }
    local s
    for _,v in ipairs(nameList) do
        local t = table.dump(require("item." .. v.path), string.upper(v.name))
        if not s then
            s = t
        else
            s = s .. "\n" .. t
        end
    end
    SaveToFile("itemexchange", s)
end