--import module

local global = require "global"
local skynet = require "skynet"


function C2GSUpgradeTouxian(oPlayer, mData)
    oPlayer.m_oTouxianCtrl:CheckUpGrade()
end
