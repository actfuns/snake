local global = require "global"
local extend = require "base/extend"

-----------------------------------------------C2GS--------------------------------------------
function C2GSOpenMail(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("MAIL_SYS", oPlayer) then
        return
    end

    global.oMailMgr:OpenMail(oPlayer, mData.mailid)
end

function C2GSAcceptAttach(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("MAIL_SYS", oPlayer) then
        return
    end

    global.oMailMgr:AcceptMailAttach(oPlayer, mData.mailid)
end

function C2GSAcceptAllAttach(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("MAIL_SYS", oPlayer) then
        return
    end

    global.oMailMgr:AcceptAllMailAttach(oPlayer) 
end

function C2GSDeleteMail(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("MAIL_SYS", oPlayer) then
        return
    end

    global.oMailMgr:DeleteMails(oPlayer, mData.mailids)
end

function C2GSDeleteAllMail(oPlayer, mData)
    if not global.oToolMgr:IsSysOpen("MAIL_SYS", oPlayer) then
        return
    end

    global.oMailMgr:DeleteAllMails(oPlayer, mData.cnt_only_client)
end