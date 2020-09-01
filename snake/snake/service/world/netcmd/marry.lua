local global = require "global"
local skynet = require "skynet"


-- 结婚支付
function C2GSMarryPay(oPlayer, mData)
    local iFlag = mData.flag
    global.oMarryMgr:PayForMarry(oPlayer, iFlag)
end

-- 取消结婚
function C2GSCancelMarry(oPlayer, mData)
    global.oMarryMgr:CancelMarry(oPlayer)
end

-- 结婚照url
function C2GSSetMarryPic(oPlayer, mData)
    local sUrl = mData.url
    global.oMarryMgr:SetMarryPic(oPlayer, sUrl)
end

-- 赠送喜糖
function C2GSPresentXT(oPlayer, mData)
    local iAmount = mData.amount
    local iTarget = mData.targetpid
    local sContent = mData.content
    global.oMarryMgr:PresentPlayerXT(oPlayer, iTarget, iAmount, sContent)
end

-- 赠送喜糖
function C2GSMarryWeddingEnd(oPlayer, mData)
    global.oMarryMgr:DoMarryWeddingEnd(oPlayer)
end

-- 组队展示婚礼
function C2GSTeamShowWedding(oPlayer, mData)
    global.oMarryMgr:TeamShowWedding(oPlayer)
end

-- 确认结婚
function C2GSMarryConfirm(oPlayer, mData)
    local iFlag = mData.flag
    global.oMarryMgr:DoConfirmMarry(oPlayer, iFlag)
end

function C2GSMarryReScene(oPlayer)
    global.oSceneMgr:ReEnterScene(oPlayer)
end
