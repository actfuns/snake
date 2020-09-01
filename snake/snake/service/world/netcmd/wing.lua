local global = require "global"
local skynet = require "skynet"

--装备
function C2GSWingWield(oPlayer, mData)
    global.oWingMgr:WieldWing(oPlayer)
end

--升星
function C2GSWingUpStar(oPlayer, mData)
    global.oWingMgr:WingUpStar(oPlayer, mData.goldcoin)
end

--升阶
function C2GSWingUpLevel(oPlayer, mData)
    global.oWingMgr:WingUpLevel(oPlayer, mData.goldcoin)
end

--激活幻化翅膀
function C2GSActiveWing(oPlayer, mData)
    global.oWingMgr:ActiveWing(oPlayer, mData.wing_id)
end

--翅膀续费
function C2GSAddWingTime(oPlayer, mData)
    global.oWingMgr:AddWingTime(oPlayer, mData.wing_id, mData.time)
end

--设置翅膀造型
function C2GSSetShowWing(oPlayer, mData)
    global.oWingMgr:SetShowWing(oPlayer, mData.wing_id)
end

--打开翅膀UI，记录
function C2GSOpenWingUI(oPlayer, mData)
    oPlayer.m_oWingCtrl:SetData("open_wing_ui", 1)
end
