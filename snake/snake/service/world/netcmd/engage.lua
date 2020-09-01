local global = require "global"


function C2GSEngageCondition(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("ENGAGE_SYS", oPlayer) then
        return
    end
    local iType = mData.type
    global.oEngageMgr:GetEngageCondition(oPlayer, iType)
end

function C2GSStartEngage(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("ENGAGE_SYS", oPlayer) then
        return
    end
    local iType = mData.type
    global.oEngageMgr:StartEngage(oPlayer, iType)
end

function C2GSConfirmEngage(oPlayer, mData)
    local iAgree = mData.agree
    global.oEngageMgr:ConfirmEngage(oPlayer, iAgree > 0)                
end

function C2GSSetEngageText(oPlayer, mData)
    local sText = mData.text
    global.oEngageMgr:SetEngageText(oPlayer, sText)
end

function C2GSDissolveEngage(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("ENGAGE_SYS", oPlayer) then
        return
    end
    global.oEngageMgr:DissolveEngage(oPlayer)
end

function C2GSCancelEngage(oPlayer, mData)
    global.oEngageMgr:C2GSCancelEngage(oPlayer:GetPid()) 
end
