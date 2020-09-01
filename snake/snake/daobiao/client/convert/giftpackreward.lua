module(..., package.seeall)
function main()
	local d = require("reward.giftpack_itemreward")
	for i,dGift in ipairs(d) do
		local tArg
    	local iSid = dGift.sid
    	if tonumber(iSid) then
        	dGift.sid = tonumber(iSid)
    	else
        	iSid,tArg = string.match(iSid,"(%d+)(.+)")
        	dGift.sid = tonumber(iSid)
        	dGift.itemarg = tArg
    	end
	end
    local s = table.dump(d, "DATA")
	SaveToFile("giftpackreward", s)
end

