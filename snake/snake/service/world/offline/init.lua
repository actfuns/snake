local skynet = require "skynet"

local profilectrl = import(service_path("offline.profilectrl"))
local friendctrl = import(service_path("offline.friendctrl"))
local mailbox = import(service_path("offline.mailbox"))
local jjcctrl = import(service_path("offline.jjcctrl"))
local challengectrl = import(service_path("offline.challengectrl"))
local wanfactrl = import(service_path("offline.wanfactrl"))
local privacyctrl = import(service_path("offline.privacyctrl"))
local feedbackctrl = import(service_path("offline.feedbackctrl"))
if is_ks_server() then
    profilectrl = import(service_path("offline.kuafu.profilectrl"))
    friendctrl = import(service_path("offline.kuafu.friendctrl"))
    mailbox = import(service_path("offline.kuafu.mailbox"))
    jjcctrl = import(service_path("offline.kuafu.jjcctrl"))
    challengectrl = import(service_path("offline.kuafu.challengectrl"))
    wanfactrl = import(service_path("offline.kuafu.wanfactrl"))
    privacyctrl = import(service_path("offline.kuafu.privacyctrl"))
    feedbackctrl = import(service_path("offline.kuafu.feedbackctrl"))
end


function NewProfileCtrl(...)
    return profilectrl.CProfileCtrl:New(...)
end

function NewFriendCtrl(...)
    return friendctrl.CFriendCtrl:New(...)
end

function NewMailBox(...)
    return mailbox.CMailBox:New(...)
end

function NewJJCCtrl(...)
    return jjcctrl.CJJCCtrl:New(...)
end

function NewChallengeCtrl( ... )
    return challengectrl.CChallengeCtrl:New(...)
end

function NewWanfaCtrl(...)
    return wanfactrl.CWanfaCtrl:New(...)
end

function NewPrivacyCtrl( ... )
    return privacyctrl.CPrivacyCtrl:New(...)
end

function NewFeedBackCtrl(...)
    return feedbackctrl.CFeedBackCtrl:New(...)
end