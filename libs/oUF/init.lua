local _, ns = ...
ns.oUF = {}
ns.oUF.Private = {}

-- Safe wrapper for C_Secrets.CanCompareUnitTokens.
-- The real API can return a secret boolean in tainted/lockdown contexts,
-- and secret booleans cannot be used in if/and/or/not tests without erroring.
-- We replace the global so all oUF element code gets the safe version automatically.
-- Uses issecretvalue (objective check) instead of canaccessvalue (context-dependent)
-- because the wrapper may execute in a less-tainted context than its caller.
C_Secrets = C_Secrets or {}
if C_Secrets.CanCompareUnitTokens then
	local _originalCanCompareUnitTokens = C_Secrets.CanCompareUnitTokens
	C_Secrets.CanCompareUnitTokens = function(...)
		local ok, result = pcall(_originalCanCompareUnitTokens, ...)
		if not ok or (issecretvalue and issecretvalue(result)) then
			return false
		end
		return result
	end
else
	C_Secrets.CanCompareUnitTokens = function()
		return true
	end
end
