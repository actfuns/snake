--import module

local global = require "global"
local res = require "base.res"

local buildbase = import(service_path("org/build/buildbase"))

function NewBuild(...)
    return CBuildFane:New(...)
end

CBuildFane = {}
CBuildFane.__index = CBuildFane
inherit(CBuildFane, buildbase.CBuildBase)

function CBuildFane:New(iBid, iOrgId)
    local o = super(CBuildFane).New(self, iBid, iOrgId)
    return o
end

function CBuildFane:GetBoonSignRatio()
    local mData = self:GetBuildData()
    if not mData or not mData["effect2"][1] then return 0 end

    return mData["effect2"][1]["val"] or 0
end

function CBuildFane:GetBoonBousRatio()
    local mData = self:GetBuildData()
    if not mData or not mData["effect2"][2] then return 0 end

    return mData["effect2"][2]["val"] or 0
end

function CBuildFane:GetBoonPosRatio()
    local mData = self:GetBuildData()
    if not mData or not mData["effect2"][3] then return 0 end

    return mData["effect2"][3]["val"] or 0
end

function CBuildFane:ClickBuild(oPlayer)
    local lInfoList = {}
    local mData = res["daobiao"]["org"]["orgactivity"]
    for iActive, mInfo in pairs(mData) do
        local mUnit = {}
        local oHuodong = global.oHuodongMgr:GetHuodong(mInfo["hd"])
        if oHuodong then
            mUnit.active_id = iActive
            mUnit.extra_msg = oHuodong:PackSimpleInfo(oPlayer)
            table.insert(lInfoList, mUnit)
        end
    end
    local mNet = {
        info_list = lInfoList,
    }
    oPlayer:Send("GS2COrgFaneActiveInfo", mNet)
end

