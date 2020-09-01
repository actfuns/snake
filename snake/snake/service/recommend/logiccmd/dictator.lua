--import module

local global = require "global"
local skynet = require "skynet"

function CloseGS(mRecord, mData)
    local oChallengeObj = global.oChallengeObj
    if oChallengeObj then
        oChallengeObj:OnCloseGS()
    end
    if global.oTrialMatchMgr then
        global.oTrialMatchMgr:OnCloseGS()
    end
end
