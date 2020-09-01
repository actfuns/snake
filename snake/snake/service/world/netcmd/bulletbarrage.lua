local global = require "global"

function C2GSWarBulletBarrage(oPlayer, mData)
    local oNowWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if not oNowWar then
        return
    end
    local sName = oPlayer:GetName()
    local mBulletBarrage = {}
    mBulletBarrage.name = sName
    mBulletBarrage.msg = mData.cmd
    oNowWar:WarBulletBarrage(oPlayer, mBulletBarrage)
end

function C2GSVideoBulletBarrage(oPlayer, mData)
    local iVideoId = mData.video_id
    local iWarType = mData.type
    local mContents = {}
    mContents.bout = mData.bout
    mContents.secs = mData.secs
    mContents.name = oPlayer:GetName()
    mContents.msg = mData.msg
    local oBulletBarrageMgr = global.oBulletBarrageMgr
    oBulletBarrageMgr:AddBulletBarrageContents(iVideoId, iWarType, mContents)
end

function C2GSOrgBulletBarrage(oPlayer, mData)
    local sMsg = mData.cmd
    local oChatMgr = global.oChatMgr
    oChatMgr:HandleOrgBulletBarrage(oPlayer,sMsg)
end

function C2GSStoryBulletBarrage(oPlayer, mData)
    local iStoryId = mData.story_id
    local iStoryType = 999
    local mContents = {}
    mContents.secs = mData.secs
    mContents.name = oPlayer:GetName()
    mContents.msg = mData.msg
    local oBulletBarrageMgr = global.oBulletBarrageMgr
    oBulletBarrageMgr:AddBulletBarrageContents(iStoryId, iStoryType, mContents)
end

function C2GSGetStoryBulletBarrage(oPlayer, mData)
    local iStoryType = 999
    local iStoryId = mData.story_id
    local oBulletBarrageMgr = global.oBulletBarrageMgr
    oBulletBarrageMgr:GetBulletBarrageData(oPlayer, iStoryId, iStoryType)
end

