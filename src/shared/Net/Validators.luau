--!strict
-- Argument validators for remote handlers (docs/ARCHITECTURE.md 6.2).
-- A validator never errors: it returns false and a short reason for anything unexpected.

export type Validator = (value: any) -> (boolean, string?)
export type TupleValidator = (count: number, ...any) -> (boolean, string?)

local MAX_STRING_LENGTH = 256

local Validators = {}

function Validators.isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Validators.number(min: number, max: number): Validator
	return function(value: any): (boolean, string?)
		if not Validators.isFiniteNumber(value) then
			return false, "not a finite number"
		end
		if value < min or value > max then
			return false, "number out of range"
		end
		return true
	end
end

function Validators.integer(min: number, max: number): Validator
	local inRange = Validators.number(min, max)
	return function(value: any): (boolean, string?)
		local ok, reason = inRange(value)
		if not ok then
			return false, reason
		end
		if value % 1 ~= 0 then
			return false, "not an integer"
		end
		return true
	end
end

function Validators.boolean(): Validator
	return function(value: any): (boolean, string?)
		if type(value) ~= "boolean" then
			return false, "not a boolean"
		end
		return true
	end
end

function Validators.string(maxLength: number): Validator
	local limit = math.min(maxLength, MAX_STRING_LENGTH)
	return function(value: any): (boolean, string?)
		if type(value) ~= "string" then
			return false, "not a string"
		end
		if #value > limit then
			return false, "string too long"
		end
		if utf8.len(value) == nil then
			return false, "invalid utf8"
		end
		return true
	end
end

function Validators.enumString(values: { string }): Validator
	local allowed: { [string]: boolean } = {}
	local longest = 0
	for _, v in values do
		allowed[v] = true
		longest = math.max(longest, #v)
	end
	local isString = Validators.string(longest)
	return function(value: any): (boolean, string?)
		local ok, reason = isString(value)
		if not ok then
			return false, reason
		end
		if not allowed[value] then
			return false, "unknown value"
		end
		return true
	end
end

-- Validates the full argument list: exactly #validators arguments, each passing its validator.
function Validators.tuple(...: Validator): TupleValidator
	local validators = { ... }
	local expected = #validators
	return function(count: number, ...: any): (boolean, string?)
		if count ~= expected then
			return false, `expected {expected} arguments, got {count}`
		end
		local args = { ... }
		for i, validate in validators do
			local ok, reason = validate(args[i])
			if not ok then
				return false, `arg {i}: {reason or "invalid"}`
			end
		end
		return true
	end
end

-- No arguments allowed.
Validators.none = Validators.tuple()

return Validators
