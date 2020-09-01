local global = require "global"
local skynet = require "skynet"

-- 
function C2GSTryEnterKS(oPlayer, mData)
    global.oKuaFuMgr:TryEnterKS(oPlayer, mData.ks, {hdname=mData.hdname})
end

function C2GSTryBackGS(oPlayer, mData)
    global.oWorldMgr:TryBackGS(oPlayer)
end

