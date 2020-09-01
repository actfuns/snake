function _GetServStateModule(sId)
    local sPath = string.format("serverstate/%s", sId)
    local oModule = import(service_path(sPath))
    assert(oModule, string.format("build ServState err, id:%s", sId))
    return oModule
end

function CreateServState(sId, pid, mArgs)
    local oModule = _GetServStateModule(sId)
    local oState = oModule.NewServState(sId, pid)
    if oState then
        oState:Init(mArgs)
    end
    return oState
end

function LoadServState(sId, pid, mStateSave)
    local oModule = _GetServStateModule(sId)
    local oState = oModule.NewServState(sId, pid)
    oState:Load(mStateSave)
    return oState
end

function CreateTeamServState(sId, teamid, mArgs)
    local oModule = _GetServStateModule(sId)
    local oState = oModule.NewTeamServState(sId, teamid)
    if oState then
        oState:Init(mArgs)
    end
    return oState
end
