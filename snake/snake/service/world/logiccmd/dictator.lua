--import module
local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

function CloseGS(mRecord, mData)
    local oWorldMgr = global.oWorldMgr
   
    if is_production_env() then
        oWorldMgr:CloseGS()
    else
        if mData.notify ~= "notify" then
            oWorldMgr:CloseGS()
            return
        end
        TryDelayCloseGS(15)
    end
end

function TryDelayCloseGS(iDelay)
    local mData = {
        sContent = iDelay.."s后关闭服务器，不允许关服吗？",
        sConfirm = "不允许",
        sCancle = "允许",
        time = iDelay,
        default = 0,
    }
    local mRes = res["daobiao"]["developer"]
    local func = function(oPlayer, mData)
        ResponseDelayCloseGS(oPlayer, mData)
    end
    for iPid, oPlayer in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
        local sMac = oPlayer:GetTrueMac()
        if mRes[sMac] then
            local mNet = global.oCbMgr:PackConfirmData(nil, mData)
            global.oCbMgr:SetCallBack(iPid, "GS2CConfirmUI", mNet, nil, func)
        end
    end
    global.oWorldMgr:DelTimeCb("DelayCloseGS")
    global.oWorldMgr:AddTimeCb("DelayCloseGS", (iDelay+2)*1000, function()
        global.oWorldMgr:CloseGS()
    end)
end

function ResponseDelayCloseGS(oPlayer, mData)
    local mRes = res["daobiao"]["developer"]
    local sMac = oPlayer:GetTrueMac()

    if mData.answer == 1 and mRes[sMac] then
        global.oWorldMgr:DelTimeCb("DelayCloseGS")
        local sMsg = string.format("%s(%s)拒绝重启",mRes[sMac]["name"],mRes[sMac]["role"])
        for iPid, oTarget in pairs(global.oWorldMgr:GetOnlinePlayerList()) do
            local sMac = oTarget:GetTrueMac()
            if mRes[sMac] then
                global.oNotifyMgr:Notify(iPid,sMsg)
            end
        end
    end
end

function SetGateOpenStatus(mRecord, mData)
    global.oWorldMgr:SetOpenStatus(mData.status)
end

