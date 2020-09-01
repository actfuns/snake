local global = require "global"
local res = require "base.res"

local huodongbase = import(service_path("huodong.huodongbase"))

function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "内容预告"
inherit(CHuodong, huodongbase.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:GetConfigData()
    return res["daobiao"]["huodong"]["foreshow"]["show_config"]
end

-- 八天登录奖励预告
function CHuodong:GetLoginGiftShowIdList(oPlayer)
    local iLoginVal = oPlayer:Query("login_gift_days", 0)
    local iLoginGift = oPlayer.m_oToday:Query("login_gift_flag", 0)
    if iLoginGift <= 0 then
        iLoginVal = iLoginVal + 1
    end
    local mConfig = self:GetConfigData()
    local mGiftDay = mConfig["giftday"][iLoginVal]
    local lShowIdList = {}
    if not mGiftDay then
        return lShowIdList
    end
    for _, mData in pairs(mConfig["giftday"][iLoginVal]) do
        table.insert(lShowIdList, {content_id = mData.id, show_type = mData.show_type})
    end
    return lShowIdList
end

function CHuodong:GetActivePointShowIdList(oPlayer)
    local mConfig = self:GetConfigData()
    local lShowIdList = {}
    if  oPlayer:Query("exchange_4001", 0) > 0 then
        local mData = mConfig["activepoint"][2002]
        table.insert(lShowIdList, { content_id = 2002, show_type = mData.show_type })
    else
        local mData = mConfig["activepoint"][2001]
        table.insert(lShowIdList, {content_id = 2001, show_type = mData.show_type})
    end
    return lShowIdList 
end

function CHuodong:GetWeekDayShowIdList(oPlayer)
    local iGrade = oPlayer:GetGrade()
    local iWday = get_weekday()
    local mConfig = self:GetConfigData()
    local mWeekDay = mConfig["weekday"][iWday]
    local lShowIdList = {}
    if not mWeekDay then
        return lShowIdList
    end
    for _, mData in pairs(mConfig["weekday"][iWday]) do
        if mData.grade <= iGrade then
            table.insert(lShowIdList, {content_id = mData.id, show_type = mData.show_type})
        end
    end
    return lShowIdList
end

function CHuodong:GetShowIdList(oPlayer)
    local lShowList = self:GetLoginGiftShowIdList(oPlayer)
    list_combine(lShowList, self:GetActivePointShowIdList(oPlayer))
    list_combine(lShowList, self:GetWeekDayShowIdList(oPlayer))
    return lShowList
end

function CHuodong:OnLogin(oPlayer, bReEnter)
    if not global.oToolMgr:IsSysOpen("ADVANCE", oPlayer, true) then return end
    if oPlayer:IsFirstLogin() then
        self:GS2CForeShowInfo(oPlayer)
    end
end

function CHuodong:GS2CForeShowInfo(oPlayer)
    local mNet = {}
    local mInfoList = self:GetShowIdList(oPlayer)
    mNet.info_list = mInfoList
    oPlayer:Send("GS2CForeShowInfo",mNet)
end
