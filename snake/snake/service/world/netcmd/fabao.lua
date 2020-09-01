local global = require "global"

function C2GSCombineFaBao(oPlayer,mData)
    local oFaBaoMgr = global.oFaBaoMgr
    oFaBaoMgr:ComBineFaBao(oPlayer,mData.op,mData.fabao)
end

function C2GSWieldFaBao(oPlayer,mData)
    local oFaBaoMgr = global.oFaBaoMgr
    oFaBaoMgr:WieldFaBao(oPlayer,mData.id)
end

function C2GSUnWieldFaBao(oPlayer,mData)
    local oFaBaoMgr = global.oFaBaoMgr
    oFaBaoMgr:UnWieldFaBao(oPlayer,mData.id)
end

function C2GSDeComposeFaBao(oPlayer,mData)
    local oFaBaoMgr = global.oFaBaoMgr
    oFaBaoMgr:DeComposeFaBao(oPlayer,mData.id)
end

function C2GSUpGradeFaBao(oPlayer,mData)
    local oFaBaoMgr = global.oFaBaoMgr
    oFaBaoMgr:UpGradeFaBao(oPlayer,mData.id)
end

function C2GSXianLingFaBao(oPlayer,mData)
    local oFaBaoMgr = global.oFaBaoMgr
    oFaBaoMgr:XianLingFaBao(oPlayer,mData.id,mData.op,mData.attr)
end

function C2GSJueXingFaBao(oPlayer,mData)
    local oFaBaoMgr = global.oFaBaoMgr
    oFaBaoMgr:JueXingFaBao(oPlayer,mData.id)
end

function C2GSJueXingUpGradeFaBao(oPlayer,mData)
    local oFaBaoMgr = global.oFaBaoMgr
    oFaBaoMgr:JueXingUpGradeFaBao(oPlayer,mData.id)
end

function C2GSJueXingHunFaBao(oPlayer,mData)
    local oFaBaoMgr = global.oFaBaoMgr
    oFaBaoMgr:JueXingHunFaBao(oPlayer,mData.id,mData.hun)
end