--!strict
-- Token bucket per key: `count` actions per `per` seconds, refilled continuously.

export type RateLimiter = {
	Allow: (self: RateLimiter, key: any) -> boolean,
	Forget: (self: RateLimiter, key: any) -> (),
}

type Bucket = { tokens: number, last: number }

local RateLimiter = {}

function RateLimiter.new(count: number, per: number, clock: (() -> number)?): RateLimiter
	assert(count > 0 and per > 0, "RateLimiter: count and per must be positive")
	local now = clock or os.clock
	local buckets: { [any]: Bucket } = {}
	local refillPerSecond = count / per

	local self = {} :: RateLimiter

	function self.Allow(_: RateLimiter, key: any): boolean
		local t = now()
		local bucket = buckets[key]
		if bucket == nil then
			bucket = { tokens = count, last = t }
			buckets[key] = bucket
		else
			bucket.tokens = math.min(count, bucket.tokens + (t - bucket.last) * refillPerSecond)
			bucket.last = t
		end
		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end
		return false
	end

	function self.Forget(_: RateLimiter, key: any)
		buckets[key] = nil
	end

	return self
end

return RateLimiter
