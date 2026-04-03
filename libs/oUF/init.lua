local _, ns = ...
ns.oUF = {}
ns.oUF.Private = {}

-- Polyfill C_Secrets.CanCompareUnitTokens for WoW builds that don't have it yet
if not C_Secrets or not C_Secrets.CanCompareUnitTokens then
	C_Secrets = C_Secrets or {}
	C_Secrets.CanCompareUnitTokens = function()
		return true
	end
end
