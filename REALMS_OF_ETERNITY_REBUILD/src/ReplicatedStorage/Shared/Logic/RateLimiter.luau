--!strict
--[[
	RateLimiter — token bucket keyed by arbitrary strings (e.g. "userId:RemoteName").
	`capacity` tokens refill at `refillPerSecond`. Pure Luau; time is injectable for tests.
]]

export type RateLimiter = {
	Allow: (self: RateLimiter, key: string, cost: number?) -> boolean,
	Reset: (self: RateLimiter, key: string) -> (),
	ResetPrefix: (self: RateLimiter, prefix: string) -> (),
}

type Bucket = { tokens: number, stamp: number }

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(capacity: number, refillPerSecond: number, clock: (() -> number)?): RateLimiter
	local self = setmetatable({
		_capacity = capacity,
		_refill = refillPerSecond,
		_clock = clock or os.clock,
		_buckets = {} :: { [string]: Bucket },
	}, RateLimiter)
	return (self :: any) :: RateLimiter
end

function RateLimiter:Allow(key: string, cost: number?): boolean
	local amount = cost or 1
	local now: number = self._clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._capacity, stamp = now }
		self._buckets[key] = bucket
	else
		local elapsed = math.max(0, now - bucket.stamp)
		bucket.tokens = math.min(self._capacity, bucket.tokens + elapsed * self._refill)
		bucket.stamp = now
	end
	if bucket.tokens >= amount then
		bucket.tokens -= amount
		return true
	end
	return false
end

function RateLimiter:Reset(key: string)
	self._buckets[key] = nil
end

function RateLimiter:ResetPrefix(prefix: string)
	for key in self._buckets do
		if string.sub(key, 1, #prefix) == prefix then
			self._buckets[key] = nil
		end
	end
end

return RateLimiter
