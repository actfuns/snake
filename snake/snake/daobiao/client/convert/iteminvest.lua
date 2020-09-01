module(..., package.seeall)

function main()
	-- path 表名称 name 导出数据表关键字
	local d1 = require("huodong.iteminvest.new_reward")
    local d2 = require("huodong.iteminvest.old_reward")
    local d3 = require("huodong.iteminvest.text")

    local new_reward = {}
    for i, v in pairs(d1) do
    	local t = {}
    	t.invest_id = v.invest_id
    	t.sid = v.item
    	t.price = v.price
    	t.sort = v.rank

        t.amount = {}
        for j=1, 10 do
            local key = "day"..tostring(j)
            t.amount[j] = v[key]
        end

    	table.insert(new_reward, t)
    end

    local old_reward = {}
    for i, v in pairs(d2) do
    	local t = {}
    	t.invest_id = v.invest_id
    	t.sid = v.item
    	t.price = v.price
    	t.sort = v.rank

        t.amount = {}
        for j=1, 10 do
            local key = "day"..tostring(j)
            t.amount[j] = v[key]
        end

    	table.insert(old_reward, t)
    end

	local s = table.dump(new_reward, "NEW_ITEM").. "\n" .. table.dump(old_reward, "OLD_ITEM")
		.. "\n" .. table.dump(d3, "TEXT")
    SaveToFile("iteminvest", s)
end
