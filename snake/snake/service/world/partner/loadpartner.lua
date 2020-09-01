mPartnerTable = {}

function CreatePartner(sid, iPid, ...)
    local mModule = import(service_path("partner.partnerobj"))
    local oPartner = mModule.NewPartner(sid, iPid)
    oPartner:Create(...)
    return oPartner
end

function LoadPartner(sid, iPid, mData)
    local mModule = import(service_path("partner.partnerobj"))
    local oPartner = mModule.NewPartner(sid, iPid)
    oPartner:Load(mData)
    oPartner:Setup()
    return oPartner
end

function GetPartner(iSid)
    if not mPartnerTable[iSid] then
        local oPartner = CreatePartner(iSid, 0)
        mPartnerTable[iSid] = oPartner
    end
    return mPartnerTable[iSid]
end
