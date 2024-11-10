--!strict

local Helper = {}
local settings = require(script.Parent.settings)

-- // Services
local TweenService = game:GetService("TweenService")
----------------------------------------------------

-- // Types
export type TweenArray = {
	Time: number,
	EasingStyle: Enum.EasingStyle,
	EasingDirection: Enum.EasingDirection,
	RepeatCount: number,
	Reverses: boolean,
	DelayTime: number,
}

function Helper.isTweenable(value: any): boolean
	return table.find(settings.TWEENABLE, typeof(value)) ~= nil
end

function Helper.getProperty(object: Instance, property: string): any?
	local success, value = pcall(function()
		return (object :: any)[property]
	end)

	if not success then
		return nil
	else
		return value
	end
end

function Helper.countProperties(properties: { [string]: any }): number
	local counter: number = 0
	
	for _ in properties do
		counter += 1
	end
	
	return counter
end

function Helper.getPropertyAtCurrentTime(start: number?, delta: number, tween: (TweenInfo | TweenArray)?, original: any, final: any)
	if not start then return original end
	if not tween then return final end
	
	local delta = (workspace:GetServerTimeNow() - start) + delta

	local alpha: number = (tween ~= nil) 
		and Helper.getAlpha(tween, delta) or 1

	return Helper.lerp(
		alpha, original, final
	)
end

function Helper.getAllProperties(original: { [string]: any }, object: Instance, properties: { [string]: any })
	for property, value in pairs(properties) do
		if original[property] then continue end
		original[property] = Helper.getProperty(object, property)
	end
end

function Helper.changeProperty(object: Instance, property: string, value: any)
	local success = pcall(function()
		(object :: any)[property] = value
	end)

	if not success then
		warn(
			("Property %s is not valid for class %s."):format(property, object.ClassName)
		)
	end
end

function Helper.bulkChangePropertyWithAlpha(object: Instance, original: { [string]: any }, final: { [string]: any }, alpha: number)
	for property, value in pairs(final) do
		Helper.changeProperty(object, property,
			value and Helper.lerp(alpha, original[property], value) or original[property]
		)
	end
end

function Helper.tweenToArray(tween: TweenInfo | TweenArray): TweenArray
	if typeof(tween) == "table" then
		return tween
	end

	local array: TweenArray = {
		Time = tween.Time,
		EasingStyle = tween.EasingStyle,
		EasingDirection = tween.EasingDirection,
		RepeatCount = tween.RepeatCount,
		Reverses = tween.Reverses,
		DelayTime = tween.DelayTime
	}

	return array
end

function Helper.modifyTween(tween: TweenInfo | TweenArray, index: string, value: any): TweenInfo
	local array = Helper.tweenToArray(tween)
	array[index] = value
	return Helper.arrayToTween(array)
end

function Helper.arrayToTween(array: TweenInfo | TweenArray): TweenInfo
	if typeof(array) == "TweenInfo" then
		return array
	end

	return TweenInfo.new(
		array.Time,
		Enum.EasingStyle[array.EasingStyle.Name],
		Enum.EasingDirection[array.EasingDirection.Name],
		array.RepeatCount,
		array.Reverses,
		array.DelayTime
	)
end

function Helper.getCycleTweenTime(tween: TweenInfo | TweenArray): number
	local base: number = tween.Time
	if tween.Reverses then
		base *= 2
	end

	return base + tween.DelayTime
end

function Helper.getFullTweenTime(tween: TweenInfo | TweenArray): number
	return Helper.getCycleTweenTime(tween) * (
		tween.RepeatCount + 1
	)
end

function Helper.getAlpha(tween: TweenInfo | TweenArray, diff: number): (number, boolean)
	local alpha: number = 0
	local new_rel: number = 0

	local sway: number = tween.Time
	local cycle: number = Helper.getCycleTweenTime(tween)
	local total: number = Helper.getFullTweenTime(tween)
	local relative: number = diff % cycle
	
	if total > 0 then
		if diff > total then
			if tween.Reverses then
				return 0, true
			else
				return 1, true
			end
		end
	end

	if relative < tween.DelayTime then
		alpha = 0
	else
		new_rel = relative - tween.DelayTime
		if new_rel < sway then
			alpha = new_rel / sway
		else
			alpha = 1 - (new_rel - sway) / sway
		end
	end

	alpha = TweenService:GetValue(alpha, tween.EasingStyle, tween.EasingDirection)

	return alpha, false
end

function Helper.getFinalAlpha(tween: (TweenInfo | TweenArray)?)
	local alpha: number
	if tween then
		if tween.Reverses then
			alpha = 0
		else
			alpha = 1
		end
	else
		alpha = 1
	end

	return alpha
end

function Helper.lerp(alpha: number, start: any, final: any): any
	if not table.find(settings.SUPPORTED_TYPES, typeof(start)) then
		return alpha >= 0.5 and final or start
	end
	
	if typeof(start) == "number" then
		return start + (final - start) * alpha
	else
		return start:Lerp(final, alpha)
	end
end

return Helper