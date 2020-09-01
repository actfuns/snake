local global = require "global"

-- 擂台玩法
function C2GSArenaFight(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oArena = oHuodongMgr:GetHuodong("arena")
    oArena:CheckConpetation(oPlayer, mData.enemy)
end

function C2GSArenaViewList(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oArena = oHuodongMgr:GetHuodong("arena")
    if not oArena then
        return
    end
    oArena:SendViewFightList(oPlayer)
end

function C2GSArenaFightList(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oArena = oHuodongMgr:GetHuodong("arena")
    local lPidLst = mData["pidlst"]
    local bTeam = mData["team"]
    oArena:ProcessFightList(oPlayer, lPidLst,bTeam)
end

function C2GSShootCrapOpen(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oNotifyMgr = global.oNotifyMgr
    local obj = oHuodongMgr:GetHuodong("shootcraps")
    if obj then
        obj:OpenUI(oPlayer)
    end
end

function C2GSShootCrapStart(oPlayer)
    local oHuodongMgr = global.oHuodongMgr
    local oNotifyMgr = global.oNotifyMgr
    local obj = oHuodongMgr:GetHuodong("shootcraps")
    if obj then
        obj:RunStart(oPlayer)
    end
end

function C2GSShootCrapEnd(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local obj = oHuodongMgr:GetHuodong("shootcraps")
    if obj then
        obj:RunOver(oPlayer,false)
    end
end

function C2GSDanceStart(oPlayer, mData)
    local iFlag = mData.flag
    local oHuodongMgr = global.oHuodongMgr
    local oDance = oHuodongMgr:GetHuodong("dance")
    if not oDance then
        return
    end

    oDance:CheckStartDance(oPlayer, iFlag)
end

function C2GSDanceAuto(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local oDance = oHuodongMgr:GetHuodong("dance")
    if not oDance then
        return
    end
    oDance:AutoFindDanceArea(oPlayer)
end

function C2GSCampfireAnswer(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgcampfire")
    if not oHuodong then
        return
    end
    oHuodong.m_oQuestionMgr:Answer(oPlayer, mData.id, mData.answer, mData.fill_answer)
end

function C2GSCampfireDesireQuestion(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgcampfire")
    if not oHuodong then
        return
    end
    oHuodong.m_oQuestionMgr:DesireQuestion(oPlayer)
end

function C2GSCampfireDrink(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgcampfire")
    if not oHuodong then
        return
    end
    oHuodong.m_oDrinkMgr:CallDrink(oPlayer, mData.amount)
end

function C2GSCampfireGiftOut(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgcampfire")
    if not oHuodong then
        return
    end
    oHuodong.m_oTieMgr:CallGive(oPlayer, mData.target, mData.quick)
end

function C2GSCampfireThankGift(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgcampfire")
    if not oHuodong then
        return
    end
    oHuodong.m_oTieMgr:ThankGift(oPlayer, mData.target)
end

function C2GSCampfireQueryGiftables(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgcampfire")
    if not oHuodong then
        return
    end
    oHuodong.m_oTieMgr:QueryGiftables(oPlayer)
end

-- 每日签到活动
function C2GSSignInDone(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local oSignIn = oHuodongMgr:GetHuodong("signin")
    if not oSignIn then return end
    oSignIn:DoSignIn(oPlayer)
end

function C2GSSignInReplenish(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local oSignIn = oHuodongMgr:GetHuodong("signin")
    if not oSignIn then return end
    oSignIn:DoExtraSign(oPlayer)
end

function C2GSSignInLottery(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local oSignIn = oHuodongMgr:GetHuodong("signin")
    if not oSignIn then return end
    oSignIn:Lottery(oPlayer)
end

function C2GSSignInMainInfo(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local oSignIn = oHuodongMgr:GetHuodong("signin")
    if not oSignIn then return end
    oSignIn:GS2CSignInMainInfo(oPlayer)
end

-- --刷新运势的策划未决定
-- function C2GSSignInRefreshFortune(oPlayer,mData)
--     local oHuodongMgr = global.oHuodongMgr
--     local oSignIn = oHuodongMgr:GetHuodong("signin")
--     if not oSignIn then return end
--     oSignIn:RefreshFortune(oPlayer)
-- end

function C2GSMengzhuOpenPlayerRank(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oMengzhu = oHuodongMgr:GetHuodong("mengzhu")
    if not oMengzhu then return end
    oMengzhu:OpenPlayerRank(oPlayer)
end

function C2GSMengzhuOpenOrgRank(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oMengzhu = oHuodongMgr:GetHuodong("mengzhu")
    if not oMengzhu then return end
    oMengzhu:OpenOrgRank(oPlayer)
end

function C2GSMengzhuOpenPlunder(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oMengzhu = oHuodongMgr:GetHuodong("mengzhu")
    if not oMengzhu then return end

    oMengzhu:OpenPlunder(oPlayer)
end

function C2GSMengzhuStartFightBoss(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oMengzhu = oHuodongMgr:GetHuodong("mengzhu")
    if not oMengzhu then return end

    oMengzhu:FightBoss(oPlayer)
end

function C2GSMengzhuStartPlunder(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oMengzhu = oHuodongMgr:GetHuodong("mengzhu")
    if not oMengzhu then return end

    oMengzhu:ValidStartPlunder(oPlayer, mData.target)
end

function C2GSMengzhuMainUI(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oMengzhu = oHuodongMgr:GetHuodong("mengzhu")
    if not oMengzhu then return end

    oMengzhu:OpenMengzhuMainUI(oPlayer)
end

function C2GSBWRank(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHdobj = oHuodongMgr:GetHuodong("biwu")
    oHdobj:GetAllRankInfo(oPlayer)
end

function C2GSBWMakeTeam(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local iOP = mData.op
    local oHdobj = oHuodongMgr:GetHuodong("biwu")
    oHdobj:SetMakeTeam(oPlayer,iOP)
end

function C2GSSchoolPassClickNpc(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("schoolpass")
    if not oHuodong then return end
    oHuodong:FindNpcPath(oPlayer:GetPid())
end

function C2GSOrgTaskRandTask(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("orgtask")
    if not oHuodong then return end
    oHuodong:RandTask(oPlayer)
end

function C2GSOrgTaskResetStar(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("orgtask")
    if not oHuodong then return end
    oHuodong:ResetStar(oPlayer)
end

function C2GSOrgTaskReceiveTask(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("orgtask")
    if not oHuodong then return end
    oHuodong:ReceiveTask(oPlayer)
end

function C2GSOrgTaskFindNPC(oPlayer,mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("orgtask")
    if not oHuodong then return end
    oHuodong:FindOrgZhongGuan(oPlayer)
end

function C2GSChargeRewardGradeGift(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("charge")
    if not oHuodong then return end

    local sType = mData.type
    local iGrade = mData.grade
    oHuodong:TryRewardGradeGift(oPlayer, sType, iGrade)
end

function C2GSChargeRewardGoldCoinGift(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("charge")
    if not oHuodong then return end

    local sType = mData.type
    oHuodong:TryRewardGoldCoinGift(oPlayer, sType)
end

function C2GSChargeGetDayReward(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("charge")
    if not oHuodong then return end

    local sKeyWord = mData.reward_key
    oHuodong:TryRewardDayGift(oPlayer, sKeyWord)
end

function C2GSChargeCheckBuy(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("charge")
    if not oHuodong then return end

    local sKeyWord = mData.reward_key
    oHuodong:CheckCanBuyGift(oPlayer, sKeyWord)
end

function C2GSBottleDetail(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("bottle")
    if not oHuodong then return end

    oHuodong:C2GSBottleDetail(oPlayer, mData.bottle)
end

function C2GSBottleSend(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("bottle")
    if not oHuodong then return end

    oHuodong:C2GSBottleSend(oPlayer, mData.bottle, mData.content)
end

function C2GSBaikeOpenUI(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("baike")
    if not oHuodong then return end
    oHuodong:OpenUI(oPlayer)
end

function C2GSBaikeChooseAnswer(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("baike")
    if not oHuodong then return end
    oHuodong:ChooseAnswer(oPlayer, mData)
end

function C2GSBaikeLinkAnswer(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("baike")
    if not oHuodong then return end
    oHuodong:LinkAnswer(oPlayer, mData)
end

function C2GSBaikeGetNextQuestion(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("baike")
    if not oHuodong then return end
    oHuodong:GetNextQuestion(oPlayer)
end

function C2GSBaikeWeekRank(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("baike")
    if not oHuodong then return end
    oHuodong:GetWeekRankData(oPlayer)
end

function C2GSLMLookInfo(oPlayer,mData)
    local iSchool = mData.school or 0
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("liumai")
    if not oHuodong then return end
    oHuodong:LookInfo(oPlayer,iSchool)
end

--灵犀------------
function C2GSLingxiPaticipate(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("lingxi")
    if not oHuodong then return end
    oHuodong:Paticipate(oPlayer)
end

function C2GSLingxiClickAcceptTask(oPlayer, mData)
    global.oHuodongMgr:CallHuodongFunc("lingxi", "GiveTask", oPlayer)
end

function C2GSLingxiClickMatch(oPlayer, mData)
    global.oHuodongMgr:CallHuodongFunc("lingxi", "QuickTeamup", oPlayer)
end

function C2GSLingxiStopMatch(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("lingxi")
    if not oHuodong then return end
    oHuodong:StopMatch(oPlayer)
end
------------------

function C2GSRewardFirstPayGift(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("welfare")
    if not oHuodong then return end

    local iType = mData.type or 1
    oHuodong:TryRewardFirstPayGift(oPlayer, iType)
end

function C2GSRewardWelfareGift(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("welfare")
    if not oHuodong then return end

    local sType = mData["type"]
    local sKey = mData["gift_key"]
    if sType == "rebate" then
        oHuodong:TryRewardRebateGift(oPlayer, sKey)    
    elseif sType == "login" then
        oHuodong:TryRewardLoginGift(oPlayer, sKey)
    else
        -- 
    end
end

--精英副本--
function C2GSJoinJYFuben(oPlayer, mData)
    local oHuodongMgr = global.oHuodongMgr
    local oHuodong = oHuodongMgr:GetHuodong("jyfuben")
    if not oHuodong then return end

    oHuodong:JoinGame(oPlayer)
end
--精英副本--

function C2GSRedeemCollectGift(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("collect")
    if not oHuodong then return end

    local sKey = mData["gift_key"]
    oHuodong:TryRewardCollectGift(oPlayer, sKey)    
end

function C2GSCaishenStartChoose(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("caishen")
    if not oHuodong then return end

    oHuodong:C2GSCaishenStartChoose(oPlayer, mData)
end

function C2GSCaishenOpenUI(oPlayer,mData)
    local iTime = mData.time or 0
    local oHuodong = global.oHuodongMgr:GetHuodong("caishen")
    if not oHuodong then return end
    oHuodong:C2GSTryOpenCaishenUI(oPlayer,iTime)
end

function C2GSCaishenRefreshRecordList(oPlayer,mData)
    local iLastTime = mData.time
    local oHuodong = global.oHuodongMgr:GetHuodong("caishen")
    if not oHuodong then return end
    oHuodong:C2GSRefreshRewardRecord(oPlayer,iLastTime)
end

function C2GSOrgWarOpenMatchList(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    if not oHuodong then return end

    oHuodong:C2GSOrgWarOpenMatchList(oPlayer, mData)
end

function C2GSOrgWarTryGotoNpc(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    if not oHuodong then return end

    oHuodong:C2GSOrgWarTryGotoNpc(oPlayer)
end

function C2GSOrgWarOpenTeamUI(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    if not oHuodong then return end

    oHuodong:C2GSOrgWarOpenTeamUI(oPlayer)
end

function C2GSOrgWarOpenWarScoreUI(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    if not oHuodong then return end

    oHuodong:C2GSOrgWarOpenWarScoreUI(oPlayer, mData)
end

function C2GSOrgWarStartFight(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgwar")
    if not oHuodong then return end

    oHuodong:C2GSOrgWarStartFight(oPlayer, mData.target)
end

function C2GSOrgTaskStarReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("orgtask")
    if not oHuodong then return end

    oHuodong:C2GSOrgTaskStarReward(oPlayer, mData)
end

function C2GSTrialOpenUI(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("trial")
    if not oHuodong then return end

    oHuodong:C2GSTrialOpenUI(oPlayer)
end

function C2GSTiralStartFight(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("trial")
    if not oHuodong then return end

    oHuodong:C2GSTiralStartFight(oPlayer)
end

function C2GSTrialGetReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("trial")
    if not oHuodong then return end

    oHuodong:C2GSTrialGetReward(oPlayer, mData.pos)
end

-- 画舫灯谜
function C2GSHfdmEnter(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("hfdm")
    if not oHuodong then return end
    if not oHuodong:EnterRoom(oPlayer) then
        oHuodong:OpenHDSchedule(oPlayer:GetPid())
    end
end

function C2GSHfdmSelect(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("hfdm")
    if not oHuodong then return end
    oHuodong:SelectAnswer(oPlayer, mData.ques_id, mData.answer)
end

function C2GSHfdmUseSkill(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("hfdm")
    if not oHuodong then return end
    oHuodong:UseSkill(oPlayer, mData.id, mData.target, mData.my_answer)
end
------------------
function C2GSGrowReward(oPlayer,mData)
    if not global.oToolMgr:IsSysOpen("ZHIYIN", oPlayer) then
        return
    end

    local index = mData.index
    oPlayer.m_oBaseCtrl.m_oGrow:GiveReward(oPlayer,index)
end

function C2GSReturnGoldCoinGetReturn(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("returngoldcoin")
    if not oHuodong then return end
    
    oHuodong:C2GSReturnGoldCoinGetReturn(oPlayer, mData.key)
end

function C2GSReturnGoldCoinGetFreeGift(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("returngoldcoin")
    if not oHuodong then return end
    
    oHuodong:C2GSReturnGoldCoinGetFreeGift(oPlayer)
end

function C2GSReturnGoldCoinBuyGift(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("returngoldcoin")
    if not oHuodong then return end

    oHuodong:C2GSReturnGoldCoinBuyGift(oPlayer, mData.key)
end

function C2GSKFGetTXRank(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if not oHuodong then return end
    oHuodong:GS2CKFTouxianRank(oPlayer)
end

function C2GSKFGetOrgLevelReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if not oHuodong then return end
    oHuodong:GetOrglevelReward(oPlayer,mData.level)
end

function C2GSKFGetOrgCntReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if not oHuodong then return end
    oHuodong:GetOrgCntReward(oPlayer,mData.cnt)
end

function C2GSKFGetScoreReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if not oHuodong then return end
    oHuodong:GetScoreReward(oPlayer,mData.score)
end

function C2GSKFGetGradeReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if not oHuodong then return end
    oHuodong:GetUpGradeReward(oPlayer,mData.grade)
end

function C2GSKFGetRankReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("kaifudianli")
    if not oHuodong then return end
    oHuodong:GS2CKaiFuRankReward(oPlayer)
end

function C2GSSevenDayGetReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("sevenlogin")
    if not oHuodong then return end
    oHuodong:GetReward(oPlayer,mData.day)
end

function C2GSEveryDayChargeGetReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("everydaycharge")
    if not oHuodong then return end
    oHuodong:GetReward(oPlayer,mData.flag,mData.day)
end

function C2GSOnlineGift(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("onlinegift")
    if not oHuodong then return end
    oHuodong:C2GSOnlineGift(oPlayer,mData.key)
end

function C2GSSuperRebateGetReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("superrebate")
    if not oHuodong then return end
    oHuodong:GetReward(oPlayer)
end

function C2GSSuperRebateGetRecord(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("superrebate")
    if not oHuodong then return end
    oHuodong:GS2CSuperRebateRecord(oPlayer)
end

function C2GSSuperRebateLottery(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("superrebate")
    if not oHuodong then return end
    oHuodong:Lottery(oPlayer)
end

function C2GSTotalChargeGetReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("totalcharge")
    if not oHuodong then return end
    oHuodong:GetReward(oPlayer,mData.level)
end

function C2GSTotalChargeSetChoice(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("totalcharge")
    if not oHuodong then return end
    oHuodong:SetChoice(oPlayer,mData.level,mData.slot,mData.index)
end

function C2GSFightGiftbagSetChoice(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("fightgiftbag")
    if not oHuodong then return end
    oHuodong:SetChoice(oPlayer,mData.score,mData.slot,mData.index)
end

function C2GSFightGiftbagGetReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("fightgiftbag")
    if not oHuodong then return end
    oHuodong:GetReward(oPlayer,mData.score)
end

function C2GSFightGiftbagGetInfo(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("fightgiftbag")
    if not oHuodong then return end
    oHuodong:GS2CGameReward(oPlayer)
end

function C2GSDayExpenseGetReward(oPlayer,mData)
    local sGroupKey = mData.group_key
    local iRewardKey = mData.reward_key
    local oHuodong = global.oHuodongMgr:GetHuodong("dayexpense")
    if not oHuodong then return end
    oHuodong:GetReward(oPlayer,sGroupKey,iRewardKey)
end

function C2GSDayExpenseSetRewardOption(oPlayer,mData)
    local sGroupKey = mData.group_key
    local iRewardKey = mData.reward_key
    local iGrid = mData.grid
    local iOption = mData.option
    local oHuodong = global.oHuodongMgr:GetHuodong("dayexpense")
    if not oHuodong then return end
    oHuodong:SetGridChoice(oPlayer,sGroupKey,iRewardKey,iGrid,iOption)
end

function C2GSDayExpenseOpenRewardUI(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("dayexpense")
    if not oHuodong then return end
    oHuodong:TryOpenRewardUI(oPlayer)
end

function C2GSOpenFuYuanBox(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("fuyuanbox")
    if not oHuodong then return end

    local iBoxIdx = mData.box_idx
    local iTimes = mData.times
    local bUseGoldCoin = mData.use_goldcoin == 1
    oHuodong:C2GSOpenFuYuanBox(oPlayer, iBoxIdx, iTimes, bUseGoldCoin)
end

function C2GSThreeBWGetFirstReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("threebiwu")
    if not oHuodong then return end
    oHuodong:GetFirstReward(oPlayer)
end

function C2GSThreeBWGetFiveReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("threebiwu")
    if not oHuodong then return end
    oHuodong:GetFiveReward(oPlayer)
end

function C2GSThreeBWGetRankInfo(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("threebiwu")
    if not oHuodong then return end
    oHuodong:PushNomalRank(oPlayer)
end

function C2GSThreeSetMatch(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("threebiwu")
    if not oHuodong then return end
    oHuodong:SetMatch(oPlayer,mData.match)
end

function C2GSRewardSecondPayGift(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("welfare")
    if not oHuodong then return end

    oHuodong:TryRewardSecondPayGift(oPlayer)
end

function C2GSQiFuGetDegreeReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("qifu")
    if not oHuodong then return end
    oHuodong:GetDegreeReward(oPlayer,mData.degree)
end

function C2GSQiFuGetLotteryReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("qifu")
    if not oHuodong then return end
    oHuodong:GetLotteryReward(oPlayer,mData.flag)
end

function C2GSOpenJuBaoPenView(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jubaopen")
    if not oHuodong then return end
    oHuodong:C2GSOpenJuBaoPenView(oPlayer)
end

function C2GSJuBaoPen(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jubaopen")
    if not oHuodong then return end
    oHuodong:C2GSJuBaoPen(oPlayer, mData.times)
end

function C2GSJuBaoPenScoreReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jubaopen")
    if not oHuodong then return end
    oHuodong:C2GSJuBaoPenScoreReward(oPlayer, mData.score)
end

function C2GSOpenActivePointGiftView(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("activepoint")
    if not oHuodong then return end
    oHuodong:C2GSOpenActivePointGiftView(oPlayer)
end

function C2GSSetActivePointGiftGridOption(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("activepoint")
    if not oHuodong then return end

    local iPointKey = mData.point_key
    local iGrid = mData.grid_id
    local iOption = mData.option
    oHuodong:SetGridChoice(oPlayer, iPointKey, iGrid, iOption)
end

function C2GSGetActivePointGift(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("activepoint")
    if not oHuodong then return end

    local iPointKey = mData.point_key
    oHuodong:GetReward(oPlayer, iPointKey)
end

function C2GSGetActivePointGiftByGoldCoin(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("activepoint")
    if not oHuodong then return end

    local iPointKey = mData.point_key
    oHuodong:GetRewardByGoldCoin(oPlayer, iPointKey)
end

function C2GSDrawCardOpenView(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("drawcard")
    if not oHuodong then return end

    oHuodong:C2GSDrawCardOpenView(oPlayer)
end

function C2GSDrawCardReset(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("drawcard")
    if not oHuodong then return end

    oHuodong:C2GSDrawCardReset(oPlayer)
end

function C2GSDrawCardStart(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("drawcard")
    if not oHuodong then return end

    oHuodong:C2GSDrawCardStart(oPlayer)
end

function C2GSDrawCardOpenOne(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("drawcard")
    if not oHuodong then return end

    local iCard = mData.card_id
    oHuodong:C2GSDrawCardOpenOne(oPlayer, iCard)
end

function C2GSDrawCardOpenList(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("drawcard")
    if not oHuodong then return end

    oHuodong:C2GSDrawCardOpenList(oPlayer)
end

function C2GSDrawCardBuyTimes(oPlayer)
    local oHuodong = global.oHuodongMgr:GetHuodong("drawcard")
    if not oHuodong then return end

    oHuodong:C2GSDrawCardBuyTimes(oPlayer)
end

function C2GSFengYaoAutoFindNPC(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("fengyao")
    if not oHuodong then return end

    oHuodong:AutoFindNPC(oPlayer)
end

function C2GSContinuousChargeSetChoice(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("continuouscharge")
    if not oHuodong then return end

    local oHuodong = global.oHuodongMgr:GetHuodong("continuouscharge")
    if not oHuodong then return end
    local iType = mData.type
    local iDay = mData.day
    local iSlot = mData.slot
    local iIndex = mData.index
    if iType and iDay and iSlot and iIndex then
        oHuodong:C2GSContinuousChargeSetChoice(oPlayer, mData)
    end
end

function C2GSContinuousChargeReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("continuouscharge")
    if not oHuodong then return end
    oHuodong:C2GSContinuousChargeReward(oPlayer, mData.day)
end

function C2GSContinuousChargeTotalReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("continuouscharge")
    if not oHuodong then return end
    oHuodong:C2GSContinuousChargeTotalReward(oPlayer, mData.day)
end

function C2GSContinuousExpenseSetChoice(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("continuousexpense")
    if not oHuodong then return end
    local iType = mData.type
    local iDay = mData.day
    local iSlot = mData.slot
    local iIndex = mData.index
    if iType and iDay and iSlot and iIndex then
        oHuodong:C2GSContinuousExpenseSetChoice(oPlayer, mData)
    end
end

function C2GSContinuousExpenseReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("continuousexpense")
    if not oHuodong then return end
    local iDay = mData.day
    oHuodong:C2GSContinuousExpenseReward(oPlayer, iDay)
end

function C2GSContinuousExpenseTotalReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("continuousexpense")
    if not oHuodong then return end
    local iDay = mData.day
    oHuodong:C2GSContinuousExpenseTotalReward(oPlayer, iDay)
end

function C2GSShootCrapsExchangeCnt(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("shootcraps")
    if not oHuodong then return end
    oHuodong:ExchangeCnt(oPlayer)
end

function C2GSNianShouFindNPC(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("nianshou")
    if not oHuodong then return end
    oHuodong:FindNPC(oPlayer)
end

function C2GSGoldCoinPartyGetDegreeReward(oPlayer,mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("goldcoinparty")
    if not oHuodong then return end
    oHuodong:GetDegreeReward(oPlayer,mData.degree)
end

function C2GSGoldCoinPartyGetLotteryReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("goldcoinparty")
    if not oHuodong then return end
    oHuodong:GetLotteryReward(oPlayer,mData.lottery,mData.flag)
end

function C2GSGoldCoinPartyGetRewardInfo(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("goldcoinparty")
    if not oHuodong then return end
    oHuodong:GS2CGameReward(oPlayer)
end

function C2GSMysticalboxOperateBox(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("mysticalbox")
    if not oHuodong then return end
    local iOperator = mData.operator
    oHuodong:C2GSMysticalboxOperateBox(oPlayer, iOperator)
end

function C2GSLuanShiMoYing(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("luanshimoying")
    if not oHuodong then return end
    oHuodong:FindPathToBoss(oPlayer)
end

function C2GSJoyExpenseBuyGood(oPlayer, mData)
    local iShop = mData.shop
    local iGood = mData.goodid
    local iMoneyType = mData.moneytype
    local iAmount = mData.amount
    local oHuodong = global.oHuodongMgr:GetHuodong("joyexpense")
    if not oHuodong then return end
    oHuodong:C2GSJoyExpenseBuyGood(oPlayer, iShop, iGood, iMoneyType, iAmount)
end

function C2GSJoyExpenseGetReward(oPlayer, mData)
    local iExpenseKey = mData.expense_id
    local oHuodong = global.oHuodongMgr:GetHuodong("joyexpense")
    if not oHuodong then return end
    oHuodong:C2GSJoyExpenseGetReward(oPlayer, iExpenseKey)
end

function C2GSJieBaiCreate(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:TryCreateJieBai(oPlayer)
end

function C2GSJBInvite(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:TryInviteMember(oPlayer,mData.target)
end

function C2GSJBArgeeInvite(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:ArgeeInvite(oPlayer)
end

function C2GSJBDisgrgeeInvite(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:DisargeeInvite(oPlayer)
end

function C2GSJBKickInvite(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:KickInvite(oPlayer,mData.target)
end

function C2GSQuitJieBai(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:QuitJieBai(oPlayer)
end

function C2GSReleaseJieBai(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:ReleaseJieBai(oPlayer)
end


function C2GSJBPreStart(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:JBPreStart(oPlayer)
end

function C2GSJBJoinYiShi(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:JoinYiShi(oPlayer)
end

function C2GSJBSetTitle(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:SetTitle(oPlayer,mData.title)
end

function C2GSJBSetMingHao(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:SetMingHao(oPlayer,mData.minghao)
end

function C2GSJBJingJiu(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:JingJiu(oPlayer)
end

function C2GSJBEnounce(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:SetEnounce(oPlayer,mData.enounce)
end

function C2GSJBKickMember(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:KickMember(oPlayer,mData.pid)
end

function C2GSJBVoteKickMember(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    if mData.op == 1 then
        oHuodong:ArgeeKickMember(oPlayer)
    elseif mData.op == 2 then
        oHuodong:DisArgeeKickMember(oPlayer)
    end
end

function C2GSJBGetValidInviter(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:GetValidInviteList(oPlayer)
end

function C2GSJBClickRedPoint(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("jiebai")
    if not oHuodong then return end
    oHuodong:ClickRedPoint(oPlayer, mData.type_list)
end

function C2GSItemInvest(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("iteminvest")
    if not oHuodong then return end
    oHuodong:C2GSItemInvest(oPlayer, mData.invest_id)
end

function C2GSItemInvestReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("iteminvest")
    if not oHuodong then return end
    oHuodong:C2GSItemInvestReward(oPlayer, mData.invest_id)
end

function C2GSItemInvestDayReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("iteminvest")
    if not oHuodong then return end
    oHuodong:C2GSItemInvestDayReward(oPlayer, mData.invest_id, mData.day)
end

function C2GSSingleWarStartMatch(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("singlewar")
    if oHuodong then
        oHuodong:PlayerStartMatch(oPlayer)
    end
end

function C2GSSingleWarStopMatch(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("singlewar")
    if oHuodong and oHuodong:InHuodongTime() then
        oHuodong:PlayerStopMatch(oPlayer)
    end
end

function C2GSSingleWarGetRewardFirst(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("singlewar")
    if oHuodong then
        oHuodong:GetRewardFirst(oPlayer)
    end
end

function C2GSSingleWarGetRewardFive(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("singlewar")
    if oHuodong then
        oHuodong:GetRewardFive(oPlayer)
    end
end

function C2GSSingleWarRank(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("singlewar")
    if oHuodong then
        oHuodong:RefreshRankByGroup(oPlayer, mData.group_id)
    end
end


function C2GSImperialexamAnswerQuestion(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("imperialexam")
    if not oHuodong then return end
    local iQuestion = mData.question_id
    local iAnswer = mData.answer
    oHuodong:C2GSImperialexamAnswerQuestion(oPlayer, iQuestion, iAnswer)
end

function C2GSBuyDiscountSale(oPlayer, mData)
    local iDay = mData.day
    local oHuodong = global.oHuodongMgr:GetHuodong("discountsale")
    if oHuodong then
        oHuodong:TryBuy(oPlayer, iDay)
    end
end

function C2GSTreasureConvoySelectTask(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("treasureconvoy")
    if oHuodong then
        local iType = mData.type
        oHuodong:C2GSTreasureConvoySelectTask(oPlayer, iType)
    end
end

function C2GSTreasureConvoyRob(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("treasureconvoy")
    if oHuodong then
        local iPid = mData.pid
        oHuodong:C2GSTreasureConvoyRob(oPlayer, iPid)
    end
end

function C2GSTreasureConvoyMatchRob(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("treasureconvoy")
    if oHuodong then
        oHuodong:C2GSTreasureConvoyMatchRob(oPlayer)
    end
end

function C2GSTreasureConvoyEnterNpcArea(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("treasureconvoy")
    if oHuodong then
        local iNpcId = mData.npcid
        oHuodong:C2GSTreasureConvoyEnterNpcArea(oPlayer:GetPid(), iNpcId)
    end
end

function C2GSTreasureConvoyExitNpcArea(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("treasureconvoy")
    if oHuodong then
        local iNpcId = mData.npcid
        oHuodong:C2GSTreasureConvoyExitNpcArea(oPlayer:GetPid(), iNpcId)
    end
end

function C2GSZeroYuanBuy(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("zeroyuan")
    if oHuodong then
        local iType = mData.type
        oHuodong:C2GSZeroYuanBuy(oPlayer, iType)
    end
end

function C2GSZeroYuanReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("zeroyuan")
    if oHuodong then
        local iType = mData.type
        oHuodong:C2GSZeroYuanReward(oPlayer, iType)
    end
end

function C2GSRetrieveExp(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("retrieveexp")
    if oHuodong then
        local iType = mData.type
        local lSchedules = mData.scheduleids
        local iNowTime = mData.nowtime
        oHuodong:TryRetrieveExp(oPlayer, lSchedules, iType, iNowTime)
    end
end

function C2GSZongziOpenUI(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("zongzigame")
    if oHuodong then
        oHuodong:RefreshZongziGame(oPlayer)
    end
end

function C2GSZongziExchange(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("zongzigame")
    if oHuodong then
        oHuodong:ZongziExchange(oPlayer, mData.type, mData.goldcoin==1)
    end
end

function C2GSDuanwuQifuOpenUI(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("duanwuqifu")
    if oHuodong then
        oHuodong:RefreshDuanquQifu(oPlayer)
    end
end

function C2GSDuanwuQifuSubmit(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("duanwuqifu")
    if oHuodong then
        oHuodong:SubmitItem(oPlayer)
    end
end

function C2GSDuanwuQifuReward(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("duanwuqifu")
    if oHuodong then
        oHuodong:StepReward(oPlayer, mData.step)
    end
end

function C2GSEnterOrgHuodong(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong(mData.name)
    if not oHuodong then return end

    if not oHuodong:TryEnterOrgScene(oPlayer) then
        oHuodong:OpenHDSchedule(oPlayer:GetPid())
    end
end

function C2GSWorldCupSingle(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("worldcup")
    if oHuodong then
        oHuodong:C2GSWorldCupSingle(oPlayer, mData.game_id, mData.team_id)
    end
end

function C2GSWorldCupChampion(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("worldcup")
    if oHuodong then
        oHuodong:C2GSWorldCupChampion(oPlayer, mData.type, mData.team_id)
    end
end

function C2GSWorldCupHistory(oPlayer, mData)
    local oHuodong = global.oHuodongMgr:GetHuodong("worldcup")
    if oHuodong then
        oHuodong:C2GSWorldCupHistory(oPlayer)
    end
end