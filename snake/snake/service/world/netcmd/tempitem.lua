local global = require "global"
local skynet = require "skynet"

function C2GSTranToItemBag(oPlayer, mData)
    local itemid = mData["id"]
    if itemid > 0 then
        local itemobj = oPlayer.m_mTempItemCtrl:HasItem(itemid)
        if not itemobj then
            return
        end
        oPlayer.m_mTempItemCtrl:TranToItemBag(itemid)
    elseif itemid ==0 then
        oPlayer.m_mTempItemCtrl:TranAllToItemBag()
    end
end

function C2GSOpenTempItemUI(oPlayer,mData)
    oPlayer.m_mTempItemCtrl:ReSort()
    oPlayer:Send("GS2COpenTempItemUI",{})
end