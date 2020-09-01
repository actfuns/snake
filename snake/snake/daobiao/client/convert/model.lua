module(..., package.seeall)
function main()
	local dExcel = require("system.role.model")
	local dConfig = {}
	for i, v in pairs(dExcel) do
		dConfig[v.figure] = {
			model = v.model,
			scale = v.scale,
			posy = v.posy,
			mutate_color = v.mutate_color,
			mutate_texture = v.mutate_texture,
			color = v.color,
			wpmodel = v.wpmodel,
			atk_trick = v.atk_trick,
			shout_trick = v.shout_trick,
			hit_trick = v.hit_trick,
			talkscale = v.talkscale,
			collider_radius = v.collider_radius,
			sprite = v.sprite
		}
	end
	local dCollider = require("system.role.model_collider")
	local s = table.dump(dConfig, "CONFIG").."\n"..table.dump(dCollider, "COLLIDER")
	SaveToFile("model", s)
end
