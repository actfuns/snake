#!/usr/bin/python
# -*- coding:utf-8 -*-

import sys
import json
import copy
import traceback
import os
sys.path.append(os.path.abspath("./shell"))
import pyutils.dbdata as db

class CONFIG():
    task_json_file = "maintain/datafile/task_pieces_data.json"


gClient = db.GetConnection()

# {key:[1,2,3]}类型的merge
def MergeTable(mDest, mSrc):
    bChanged = False
    datatype = type(mSrc)
    if datatype == list:
        for v in mSrc:
            if v not in mDest:
                bChanged = True
                mDest.append(v)
    elif datatype == dict:
        for k, v in mSrc.items():
            mDv = mDest.get(k)
            if not mDv:
                bChanged = True
                mDest[k] = copy.deepcopy(v)
            else:
                bChanged = bChanged or MergeTable(mDv, v)
    return bChanged

def MergeChapterPieceSaveData(mTaskChapterSaveData, mCorrPieceInfo):
    mLoadedData = db.AfterLoad(mTaskChapterSaveData)
    if MergeTable(mLoadedData, mCorrPieceInfo):
        mPackedCorr = db.BeforeSave(mLoadedData)
        return mPackedCorr

def ReadTaskPiecesInfo():
    lines = []
    confirm = raw_input("确认json文件%s是最新的吗? [y/n] " % CONFIG.task_json_file)
    if confirm <> 'y':
        return None

    with open(CONFIG.task_json_file, "rb") as f:
        lines = f.readlines()
    mReadData = json.loads("".join(lines))
    return mReadData["pieces"]

def ParseTaskPiecesInfo(mAllPiecesInfo):
    mParsedPiecesInfo = {}
    for sTaskId, mChPieces in mAllPiecesInfo.items():
        mParsedPiecesInfo[sTaskId] = {sChapter:[int(sPieceId) for sPieceId in lChPieces] for sChapter, lChPieces in mChPieces.items()}
    return mParsedPiecesInfo

def GetParsedTaskPiecesInfo():
    mAllPiecesInfo = ReadTaskPiecesInfo()
    if not mAllPiecesInfo:
        return None
    return ParseTaskPiecesInfo(mAllPiecesInfo)

def ReportHits(hitChanged):
    hitCnt = len(hitChanged)
    print "--- 共处理 %d人 ---" % hitCnt
    if hitCnt > 0:
        print " pid\t| taskId"
        print "----------------------"
        for pid, taskid in hitChanged.items():
            print "%d\t| %s" % (pid, taskid)

if __name__ == "__main__":
    mParsedPiecesInfo = GetParsedTaskPiecesInfo()
    if not mParsedPiecesInfo:
        print "未读取到json数据"
        exit(1)

    coll = gClient.game.player
    print "coll:", coll
    curinfo = None
    hitChanged = {}
    try:
        curinfo = {}
        docs = coll.find({})
        for doc in docs:
            pid = doc["pid"]
            curinfo['pid'] = pid
            mCorrPieceInfo = None
            if not doc.get("task_info"):
                print "null task player:", pid
                continue
            if not doc["task_info"].get("TaskData"):
                print "null task data player:", pid
                continue
            for sTaskId, mTaskData in doc["task_info"]["TaskData"].items():
                curinfo['task'] = sTaskId
                sCurTaskId = sTaskId
                mCorrPieceInfo = mParsedPiecesInfo.get(sTaskId, None)
                if mCorrPieceInfo:
                    # 主线任务只有一个
                    mTaskChapterSaveData = doc["task_info"].get("chapter_pieces", {})
                    mMergedCorrSaveData = MergeChapterPieceSaveData(mTaskChapterSaveData, mCorrPieceInfo)
                    if mMergedCorrSaveData:
                        doc["task_info"]["chapter_pieces"] = mMergedCorrSaveData
                        coll.save(doc, check_keys=True)
                        # hitChanged[pid] = sTaskId + ': ' + str(mMergedCorrSaveData)
                        hitChanged[pid] = sTaskId
                    break

    except Exception, reason:
        print "异常发生:", reason
        print " | 当前处理:", curinfo
        print " | traceback: ->"
        traceback.print_exc(sys.exc_info()[2])
    finally:
        ReportHits(hitChanged)

gClient.close()

