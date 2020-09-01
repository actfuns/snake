--import module
local global  = require "global"
local extend = require "base.extend"
local res = require "base.res"
local record = require "public.record"
local geometry = require "base.geometry"
local interactive = require "base.interactive"

local huodongbase = import(service_path("huodong.huodongbase"))
local gamedefines = import(lualib_path("public.gamedefines"))
local loaditem = import(service_path("item.loaditem"))
local handleteam = import(service_path("team.handleteam"))
local datactrl = import(lualib_path("public.datactrl"))

local YISHI_STATE = {0,1,2,3,4} -- 0.预开启 1.收集box 2.取称谓 3.取名号 4.喝酒
local NPC_TYPE = {1001,1002}

function NewYiShi(iJBID)
    return CYiShi:New(iJBID)
end

CYiShi = {}
CYiShi.__index = CYiShi
inherit(CYiShi, datactrl.CDataCtrl)

function CYiShi:New(iJBID)
    local o = super(CYiShi).New(self)
    o.m_iJBID = iJBID
    o.m_iSceneID = nil 
    o.m_mNpc = {}
    o.m_iState = YISHI_STATE[1]
    o.m_iCollectBox = 0
    o.m_iStateTime = 0
    return o
end

function CYiShi:Release()
    self:ClearTimer()
    self:RemovePlayer()
    self:RemoveNPC()
    self:RemoveScene()
end

function CYiShi:ClearTimer()
    self:DelTimeCb("CheckCollectBox")
    self:DelTimeCb("CheckCollectBoxTip")
    self:DelTimeCb("CheckYiShiPreStart")
    self:DelTimeCb("CheckSetTitle")
    self:DelTimeCb("CheckSetMingHao")
    self:DelTimeCb("CheckSetHejiu")
end

function CYiShi:GetHD()
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    return oHD
end

function CYiShi:GetJieBai()
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    return oHD:GetJieBai(self.m_iJBID)
end

function CYiShi:GetConfigData()
    local oHD = self:GetHD()
    return oHD:GetConfigData()
end

function CYiShi:GetTextData(iText,mReplace)
    local oHD = self:GetHD()
    return oHD:GetTextData(iText,mReplace)
end

function CYiShi:GetScene()
    return global.oSceneMgr:GetScene(self.m_iSceneID)
end

function CYiShi:State()
    return self.m_iState
end

function CYiShi:JoinYiShi(pid)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return 
    end
    local oScene = self:GetScene()
    global.oSceneMgr:DoTransfer(oPlayer, oScene:GetSceneId())
end

function CYiShi:RemovePlayer()
    local iLeaveMapID = 101000
    local oScene = self:GetScene()
    local oDesScene = global.oSceneMgr:SelectDurableScene(iLeaveMapID)
    local plist = oScene:GetAllPlayerIds()
    for _,pid in pairs(plist) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            global.oSceneMgr:DoTransfer(oPlayer, oDesScene:GetSceneId())
        end
    end
end

function CYiShi:RemoveNPC()
    local oHD = self:GetHD()
    local mNPC = self.m_mNpc
    self.m_mNpc = {}
    for nid ,_ in pairs(mNPC) do
        local oNPC = oHD:GetNpcObj(nid)
        if oNPC then
            oHD:RemoveTempNpc(oNPC)
        end
    end
end

function CYiShi:RemoveScene()
    if self.m_iSceneID then
        global.oSceneMgr:RemoveScene(self.m_iSceneID)
        self.m_iSceneID = nil
    end
end

--仪式失败
function CYiShi:Fail()
    local jbobj = self:GetJieBai()
    local oScene = self:GetScene()
    local plist = oScene:GetAllPlayerIds()
    for _,pid in pairs(plist) do
        local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
        if oPlayer then
            global.oNotifyMgr:Notify(pid,self:GetTextData(1020))
        end
    end
    jbobj:FailYiShi()
end

--预开启
function CYiShi:PreStart(iOwner)
    self.m_iStateTime = get_time()
    self:CreateScene()
    self:CreateNPC()
    local mConfig = self:GetConfigData()
    self:AddPreStartCb(mConfig.yishi_prestart_time)
    self:JoinYiShi(iOwner)
    local jbobj = self:GetJieBai()
    jbobj:RefreshJieBai()
end

function CYiShi:AddPreStartCb(iTime)
    local iJBID = self.m_iJBID
    self:DelTimeCb("CheckYiShiPreStart")
    self:AddTimeCb("CheckYiShiPreStart", iTime*1000, function ()
        _CheckYiShiPreStart(iJBID)
    end)
end

function CYiShi:CreateScene()
    local oSceneMgr = global.oSceneMgr
    local oHD = self:GetHD()
    local mRes = res["daobiao"]["huodong"]["jiebai"]["scene"]
    local iJBID = self.m_iJBID
    for iIndex , mInfo in pairs(mRes) do
        local mData ={
            map_id = mInfo.map_id,
            url = {"huodong", "jiebai", "scene", iIndex},
            team_allowed = mInfo.team_allowed,
            deny_fly = mInfo.deny_fly,
            is_durable =mInfo.is_durable==1,
            has_anlei = mInfo.has_anlei == 1,
        }
        local oScene = oSceneMgr:CreateVirtualScene(mData)
        oScene.m_HDName = oHD.m_sName
        self.m_iSceneID = oScene:GetSceneId()

        local fCbEnter 
        fCbEnter = function (iEvType,mData)
            local oPlayer = mData.player
            local oToScene = mData.scene
            _OnPlayerEnterScene(oPlayer, oToScene,iJBID)
        end
        oScene:AddEvent(self, gamedefines.EVENT.PLAYER_ENTER_SCENE, fCbEnter)

        break
    end
end

function CYiShi:CreateNPC()
    local oHD = self:GetHD()
    local oScene = self:GetScene()
    assert(oScene,"CreateNPC")
    for _,npctype in pairs(NPC_TYPE) do
        local npcobj  = oHD:CreateTempNpc(npctype)
        assert(npcobj,"CreateNPC")
        oHD:Npc_Enter_Scene(npcobj,oScene:GetSceneId())
        self.m_mNpc[npcobj:ID()] = true
    end
end

function CYiShi:CheckYiShiPreStart()
    local jbobj = self:GetJieBai()
    if self.m_iState == YISHI_STATE[1] then
        self:Fail()
    end
end

--开启
function CYiShi:Start()
    self:DelTimeCb("CheckYiShiPreStart")
    self.m_iStateTime = get_time()
    self.m_iState = YISHI_STATE[2]
    self:RefreshBox()
    local mConfig = self:GetConfigData()
    self:AddStartCb(mConfig.collect_box_time)
    local jbobj = self:GetJieBai()
    jbobj:RefreshJieBai()
end

function CYiShi:AddStartCb(iTime)
    local iJBID = self.m_iJBID
    self:DelTimeCb("CheckCollectBox")
    self:AddTimeCb("CheckCollectBox", iTime*1000, function ()
        _CheckCollectBox(iJBID)
    end)

    local iTipTime = iTime - 2*60
    self:DelTimeCb("CheckCollectBoxTip")
    if iTipTime > 0 then
        self:AddTimeCb("CheckCollectBoxTip", iTipTime*1000, function ()
            _CheckCollectBoxTip(iJBID)
        end)
    end
end

function CYiShi:CheckCollectBox()
    if self.m_iState ~= YISHI_STATE[2] then
        return 
    end
    local jbobj = self:GetJieBai()
    jbobj:NotifyAll(1030)
    self:Fail()
end

function CYiShi:CheckCollectBoxTip()
    if self.m_iState ~= YISHI_STATE[2] then return end
    local jbobj = self:GetJieBai()
    jbobj:NotifyAll(1065)
end

function CYiShi:RefreshBox()
    local oHD = self:GetHD()
    local oScene = self:GetScene()
    local mConfig = self:GetConfigData()
    local iRefreshCnt = mConfig.collect_box_cnt
    assert(oScene,"CreateNPC")
    for i=1,iRefreshCnt do
        local npcobj  = oHD:CreateTempNpc(1003)
        assert(npcobj,"CreateNPC")
        local x,y = global.oSceneMgr:RandomPos2(oScene:MapId())
        local mPosInfo  = npcobj:PosInfo()
        mPosInfo.x=x
        mPosInfo.y=y
        oHD:Npc_Enter_Scene(npcobj,oScene:GetSceneId())
        self.m_mNpc[npcobj:ID()] = true
    end
end

function CYiShi:CollectBox(nid)
    local oHD = self:GetHD()
    local oNPC = oHD:GetNpcObj(nid)
    if  not oNPC then
        return 
    end
    oHD:RemoveTempNpc(oNPC)
    self.m_iCollectBox = self.m_iCollectBox + 1
    local mConfig = self:GetConfigData()
    if self.m_iCollectBox >= mConfig.collect_box_cnt then
        self:SetTitle()
    end
end

--选取称谓
function CYiShi:SetTitle()
    self.m_iStateTime = get_time()
    local mConfig = self:GetConfigData()
    self:DelTimeCb("CheckCollectBox")
    self:DelTimeCb("CheckCollectBoxTip")
    self:RemoveBox()
    self.m_iState = YISHI_STATE[3]
    self:AddSetTitleCb(mConfig.settitle_time)
    local jbobj = self:GetJieBai()
    jbobj:RefreshJieBai()
end

function CYiShi:AddSetTitleCb(iTime)
    local iJBID = self.m_iJBID
    self:DelTimeCb("CheckSetTitle")
    self:AddTimeCb("CheckSetTitle",iTime*1000,function ()
        _CheckSetTitle(iJBID)
    end)
end

function CYiShi:RemoveBox()
    self.m_iCollectBox = 0
    local oHD = self:GetHD()
    local mDel = {}
    for nid ,_ in pairs(self.m_mNpc) do
        local oNPC = oHD:GetNpcObj(nid)
        if oNPC and oNPC:Type() == 1003 then
            mDel[nid] = true
            oHD:RemoveTempNpc(oNPC)
        end
    end
    for nid ,_ in pairs(mDel) do
        self.m_mNpc[nid] = nil
    end
end

function CYiShi:CheckSetTitle()
    if self.m_iState ~= YISHI_STATE[3] then
        return 
    end
    local jbobj = self:GetJieBai()
    jbobj:AutoSetTitle()
    self:SetMingHao()
end

--设置名号
function CYiShi:SetMingHao()
    self.m_iStateTime = get_time()
    self:DelTimeCb("CheckSetTitle")
    self.m_iState  = YISHI_STATE[4]
    local mConfig = self:GetConfigData()
    self:AddSetMingHaoCb(mConfig.setminghao_time)
    local jbobj = self:GetJieBai()
    jbobj:RefreshJieBai()
end

function CYiShi:AddSetMingHaoCb(iTime)
    local iJBID = self.m_iJBID
    self:DelTimeCb("CheckSetMingHao")
    self:AddTimeCb("CheckSetMingHao", iTime*1000, function ()
        _CheckSetMingHao(iJBID)
    end)
end

function CYiShi:CheckSetMingHao()
    if self.m_iState ~= YISHI_STATE[4] then
        return 
    end
    local jbobj = self:GetJieBai()
    jbobj:AutoSetMingHao()
    self:SetHejiu()
end

--喝酒
function CYiShi:SetHejiu()
    self.m_iStateTime = get_time()
    self:DelTimeCb("CheckSetMingHao")
    self.m_iState  = YISHI_STATE[5]
    local mConfig = self:GetConfigData()
    self:AddSetHejiuCb(mConfig.sethejiu_time)
    local jbobj = self:GetJieBai()
    jbobj:RefreshJieBai()
end

function CYiShi:AddSetHejiuCb(iTime)
    local iJBID = self.m_iJBID
    self:DelTimeCb("CheckSetHejiu")
    self:AddTimeCb("CheckSetHejiu", iTime*1000,function ()
        _CheckSetHejiu(iJBID)
    end)
end

function CYiShi:CheckSetHejiu()
    if self.m_iState ~= YISHI_STATE[5] then
        return 
    end
    local jbobj = self:GetJieBai()
    jbobj:AutoFinishHejiu()
end

function CYiShi:GetStateTime()
    return self.m_iStateTime
end

function _GetYiShi(iJbId)
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHD then return end
    local oJbObj = oHD:GetJieBai(iJbId)
    if not oJbObj then return end
    local oYsOjb = oJbObj:GetYiShi()
    return oYsOjb
end

function _CheckYiShiPreStart(iJbId)
    local oYsOjb = _GetYiShi(iJbId)
    if oYsOjb then
        oYsOjb:CheckYiShiPreStart()
    end
end

function _OnPlayerEnterScene(oPlayer,oScene,iJBID)
    local oHD = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHD then
        return 
    end
    local jbobj = oHD:GetJieBai(iJBID)
    if not jbobj then
        return 
    end
    local ysobj = jbobj:GetYiShi()
    if not ysobj then
        return 
    end
    oHD:ChecKYiShiMember(jbobj)
end

function _CheckCollectBox(iJbId)
    local oYsOjb = _GetYiShi(iJbId)
    if oYsOjb then
        oYsOjb:CheckCollectBox()
    end
end

function _CheckCollectBoxTip(iJbId)
    local oYsOjb = _GetYiShi(iJbId)
    if oYsOjb then
        oYsOjb:CheckCollectBoxTip()
    end
end

function _CheckSetTitle(iJbId)
    local oYsOjb = _GetYiShi(iJbId)
    if oYsOjb then
        oYsOjb:CheckSetTitle()
    end
end

function _CheckSetMingHao(iJbId)
    local oYsOjb = _GetYiShi(iJbId)
    if oYsOjb then
        oYsOjb:CheckSetMingHao()
    end
end

function _CheckSetHejiu(iJbId)
    local oYsOjb = _GetYiShi(iJbId)
    if oYsOjb then
        oYsOjb:CheckSetHejiu()
    end
end
