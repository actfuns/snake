module(..., package.seeall)
function main()
	local newTable = nil
	local oriTable = nil
	local itemReward = nil
	local summonReward = nil

	local nameList = {"test", "story", "shimen", "fengyao", "trapmine", "yibao", "ghost", "side"
	, "gradegift", "preopen", "everydaytask", "charge", "bottle", "welfare", "collect", "lead", "newbie", "orgtask", "schoolpass"
	, "kaifudianli", "returngoldcoin", "baotu", "orgcampfire", "runring", "onlinegift", "everydaycharge", "sevenlogin", "xuanshang"
	, "fumo", "fumo_hard", "jingsan", "jingsan_hard", "drawcard", "continuouscharge", "continuousexpense", "goldcoinparty", "mentoring","jyfuben"
	, "joyexpense", "zeroyuan", "duanwuqifu"}

	-- 有宠物奖励表的要加进来
	local summonContentList = {"welfare","lead","newbie","test"}
	local summonContentDict = {}
	for _, key in ipairs(summonContentList) do
		summonContentDict[key] = true
	end

	for _,name in ipairs(nameList) do
		oriTable = require("reward." .. name .. "_reward")
		itemReward = require("reward." .. name .. "_itemreward")
		if summonContentDict[name] then
			summonReward = require("reward." .. name .. "_summonreward")
		end
		for _,t in pairs(oriTable) do
			local itemList = t.item --  item = {1997, 1998, 1999, 2000},
			t.item = {}
			for _, i in ipairs(itemList) do 
				for _,v in ipairs(itemReward) do-- v -> [1] = { amount = 1,bind = 0,check_equip_role = 0,idx = 1001,ratio = 2500,sid = "10001",sys = 0,type = 0,},
					local tArg
					local iSid = v.sid
			    	if tonumber(iSid) then
			        	v.sid = tonumber(iSid)
			    	else
			        	iSid,tArg = string.match(iSid,"(%d+)(.+)")
			        	v.sid = tonumber(iSid)
			        	v.itemarg = tArg
			    	end

					if i == v.idx then
						table.insert(t.item, v)
					end
				end
			end 
			-- 宠物调整
			if summonContentDict[name] then
				local summonList = t.summon
				t.summon = {}
				for _, i in ipairs(summonList) do
					for _, v in ipairs(summonReward) do
						if i == v.idx then
							table.insert(t.summon, v)
						end
					end
				end
			end
		end
		newTable = (newTable or "") .. "\n" .. table.dump(oriTable, string.upper(name))
	end

	-- 不需要遍历处理的奖励表
	local nList = {"activepoint"}
	for _,v in ipairs(nList) do
		local oriTable = require("reward." .. v .. "_itemreward")
		newTable = (newTable or "") .. "\n" .. table.dump(oriTable, string.upper(v))
	end

	local d1 = require("reward.baike_reward")
	local d2 = require("reward.baike_itemreward")
	local d3 = require("reward.hfdm_itemreward")
	local d4 = require("reward.signin_reward_set")
	local d5 = require("reward.signin_itemreward")
	local d6 = require("reward.grow_itemreward")
	local d7 = require("reward.grow_reward")
	local d8 = require("reward.welfare_summonreward") 

	local d9 = require("reward.shootcraps_itemreward")
	local d10 = require("reward.dayexpense_itemreward")
	local d12 = require("reward.totalcharge_itemreward")
	local d13 = require("reward.fightgiftbag_itemreward")

	local d14 = require("reward.qifu_reward")
	local d15 = require("reward.qifu_itemreward")
	local d16 = require("reward.signin_firstmonth_special")


	local zhenmo_itemreward = require("reward.zhenmo_itemreward")
	local d17 = {}
	for i, v in ipairs(zhenmo_itemreward) do
		d17[v.idx] = v
	end

	local d18 = require("reward.treasureconvoy_reward")

	newTable = newTable.."\n" .. table.dump(d1 ,"baike_reward")..
	"\n" .. table.dump(d2 ,"baike_itemreward")..
	"\n" .. table.dump(d3 ,"HFDMREWARD") ..
	"\n" .. table.dump(d4 ,"signin_reward_set") ..
	"\n" .. table.dump(d5 ,"signin_item_reward")..
	"\n"..table.dump(d6 ,"GROW_ITEMREWARD")..
	"\n"..table.dump(d7 ,"GROWREWARD")..
	"\n"..table.dump(d8 ,"WELFARESUMMONREWARD")..
	"\n"..table.dump(d9, "SHOOTCRAPREWARD")..
	"\n"..table.dump(d10, string.upper("dayexpense_itemreward"))..
	"\n"..table.dump(d12, string.upper("totalcharge"))..
	"\n"..table.dump(d13, string.upper("fightgiftbag")) ..
	"\n"..table.dump(d14, string.upper("qifureward")) .. 
	"\n"..table.dump(d15, string.upper("qifuitemreward"))..
	"\n" .. table.dump(d16 ,"signin_firstmonth_special")..
	"\n" .. table.dump(d17 , string.upper("zhenmo")) ..
	"\n" .. table.dump(d18 , string.upper("treasureconvoy"))
	SaveToFile("reward", newTable)
end
