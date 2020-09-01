module(..., package.seeall)
function main()
    local nameList ={
        {path = "first_pay_gift", name = "FIRSTPAY"},
        {path = "second_pay_gift", name = "SECONDPAY"},
        {path = "rebate_gift", name = "REBATE"},
        {path = "login_gift", name = "LOGIN"},
        {path = "text", name = "TEXT"},
    }

    local s
    for _, v in ipairs(nameList) do
        local d = table.dump(require("huodong.welfare."..v.path), v.name)
        if not s then
            s = d
        else
            s = s .. "\n" .. d
        end
    end
    SaveToFile("welfare", s)
end