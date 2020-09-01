local global = require "global"

function NewAction(iAction,iWarId)
    local sPath = string.format("action/a%s",iAction)
    local oModule = import(service_path(sPath))
    local oAction = oModule.NewWarAction(iWarId)
    return oAction
end
