local _, ns = ...
local oUF = { Private = {} }
ns.oUF = oUF

-- Upvalue secret functions (may be nil on Classic)
local issecretvalue = issecretvalue
local issecrettable = issecrettable
local canaccessvalue = canaccessvalue

local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitIsVisible = UnitIsVisible
local UnitThreatSituation = UnitThreatSituation
local ShouldUnitIdentityBeSecret = C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret
local CanCompareUnitTokens = C_Secrets and C_Secrets.CanCompareUnitTokens

-- Secret Value Helpers (modeled after ElvUI's approach by Simpy)
-- These provide safe wrappers that never propagate secret values to callers.

function oUF:IsSecretValue(value)
	return issecretvalue and issecretvalue(value)
end

function oUF:NotSecretValue(value)
	return not oUF:IsSecretValue(value)
end

function oUF:IsSecretTable(object)
	return issecrettable and issecrettable(object)
end

function oUF:NotSecretTable(object)
	return not oUF:IsSecretTable(object)
end

function oUF:CanAccessValue(value)
	return not canaccessvalue or canaccessvalue(value)
end

function oUF:CanNotAccessValue(value)
	return not oUF:CanAccessValue(value)
end

function oUF:HasSecretValues(object)
	return object.HasSecretValues and object:HasSecretValues()
end

-- Safe UnitIsUnit - returns nil if comparison is blocked by secrets
function oUF:UnitIsUnit(unit1, unit2)
	if CanCompareUnitTokens and not CanCompareUnitTokens(unit1, unit2) then
		return
	end

	local isUnit = UnitIsUnit(unit1, unit2)
	if oUF:NotSecretValue(isUnit) then
		return isUnit
	end
end

function oUF:UnitNotUnit(unit1, unit2)
	return oUF:UnitIsUnit(unit1, unit2) == false
end

function oUF:UnitExists(unit)
	return unit and (UnitExists(unit) or UnitIsVisible(unit))
end

-- Safe UnitThreatSituation - non-existent *target or *pet units cause errors
function oUF:GetThreatSituation(unit, feedbackUnit)
	if not unit or not oUF:UnitExists(unit) then
		return
	end

	if feedbackUnit and feedbackUnit ~= unit and oUF:UnitExists(feedbackUnit) then
		return UnitThreatSituation(feedbackUnit, unit)
	else
		return UnitThreatSituation(unit)
	end
end

function oUF:UnpackAuraData(data)
	if not data then
		return
	end

	local name, icon, applications, dispelName, duration, expirationTime, sourceUnit, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossAura, isFromPlayerOrPlayerPet, nameplateShowAll, timeMod =
		data.name,
		data.icon,
		data.applications,
		data.dispelName,
		data.duration,
		data.expirationTime,
		data.sourceUnit,
		data.isStealable,
		data.nameplateShowPersonal,
		data.spellId,
		data.canApplyAura,
		data.isBossAura,
		data.isFromPlayerOrPlayerPet,
		data.nameplateShowAll,
		data.timeMod
	if oUF:NotSecretTable(data.points) then
		return name,
			icon,
			applications,
			dispelName,
			duration,
			expirationTime,
			sourceUnit,
			isStealable,
			nameplateShowPersonal,
			spellId,
			canApplyAura,
			isBossAura,
			isFromPlayerOrPlayerPet,
			nameplateShowAll,
			timeMod,
			unpack(data.points)
	else
		return name,
			icon,
			applications,
			dispelName,
			duration,
			expirationTime,
			sourceUnit,
			isStealable,
			nameplateShowPersonal,
			spellId,
			canApplyAura,
			isBossAura,
			isFromPlayerOrPlayerPet,
			nameplateShowAll,
			timeMod
	end
end
