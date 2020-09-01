local global = require "global"
local interactive = require "base.interactive"

--example
--function fix_servergrade()
--    local sCmd = [[
--        local res = require "base.res"
--        local record = require "public.record"
--        local extend = require "base.extend"
--        local global = require "global"
--        global.oWorldMgr:SetOpenDays(0)
--        global.oWorldMgr:CheckUpGrade()
--    ]]
--    for _, v in ipairs(global.mServiceNote[".world"]) do
--        interactive.Send(v, "default", "ExecuteString", {cmd = sCmd})
--    end
--end

function kick_fd()
    local sCmd = [[
        local global = require "global"
        local iFd = 28570
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByFd(iFd)
        if oPlayer then
            print("kickout", iFd, oPlayer:GetPid())
            oPlayer:HandleBadBoy("gm-kick")
        end
    ]]
    for _, v in ipairs(global.mServiceNote[".world"]) do
        interactive.Send(v, "default", "ExecuteString", {cmd = sCmd})
    end
end

function fix_deletemail()
    local sCmd = [[
        local global = require "global"
        local mPlayer = global.oWorldMgr:GetOnlinePlayerList()
        for _,oPlayer in pairs(mPlayer) do
            local oMailBox = oPlayer:GetMailBox()
            for iMail, oMail in pairs(oMailBox.m_mMailIDs) do
                if oMail:GetData("title") == "6月21日例行版本更新维护结束" then
                    oMailBox:DelMail(iMail)
                end            
            end
            global.oMailMgr:OnLogin(oPlayer)
        end
    ]]
    for _, v in ipairs(global.mServiceNote[".world"]) do
        interactive.Send(v, "default", "ExecuteString", {cmd = sCmd})
    end
end
