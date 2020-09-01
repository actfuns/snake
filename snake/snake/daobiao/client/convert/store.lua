module(..., package.seeall)
function main()
	local d1 = require("economic.store.goldcoinstore")
	local d2 = require("economic.store.goldstore")
	local d3 = require("economic.store.silverstore")
	local d4 = require("economic.store.exchangemoney")
	local dNew1 = {}
	local dNew2 = {}
	local dNew3 = {}

	for k, v in pairs(d1) do
		local value = {
			first_reward = v.first_reward,
			RMB = v.RMB,
			gold_coin_gains = v.gold_coin_gains,
			reward_gold_coin = v.reward_gold_coin,
			tag = v.tag,
			id = v.id,
			icon = v.icon,
		}
		dNew1[k] = value
	end

	for k,v in pairs(d2) do
		local value = {
			gold_coin_cost = v.gold_coin_cost,
			icon = v.icon,
			id = v.id,
			gold_gains = v.gold_gains,
		}
		dNew2[k] = value
	end

	for k,v in pairs(d3) do
		local value = {
			icon = v.icon,
			gold_cost = v.gold_cost,
			id = v.id,
			reward_silver = v.reward_silver,
			sliver_gains_formula = v.sliver_gains_formula,
		}
	end
	local s = table.dump(d1, "GOLDCOINSTORE").."\n"..table.dump(d2, "GOLDSTORE").."\n"..table.dump(d3, "SILVERSTORE").."\n"..table.dump(d4, "EXCHANGEMONEY")
	SaveToFile("store", s)
end