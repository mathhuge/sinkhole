local MOD = 4294967296

local function to_u32(n)
    n = n % MOD
    if n < 0 then n = n + MOD end
    return math.floor(n)
end

local AND_T, OR_T, XOR_T = {}, {}, {}
for a = 0, 255 do
    AND_T[a], OR_T[a], XOR_T[a] = {}, {}, {}
end
for a = 0, 255 do
    for b = 0, 255 do
        local x, y = a, b
        local r_and, r_or, r_xor = 0, 0, 0
        local bit = 1
        for _ = 1, 8 do
            local xb, yb = x % 2, y % 2
            if xb == 1 and yb == 1 then r_and = r_and + bit end
            if xb == 1 or yb == 1 then r_or = r_or + bit end
            if xb ~= yb then r_xor = r_xor + bit end
            x = (x - xb) / 2
            y = (y - yb) / 2
            bit = bit * 2
        end
        AND_T[a][b] = r_and
        OR_T[a][b] = r_or
        XOR_T[a][b] = r_xor
    end
end

local function band2(a, b)
    local r, mul = 0, 1
    for _ = 1, 4 do
        local ab, bb = a % 256, b % 256
        r = r + AND_T[ab][bb] * mul
        a = (a - ab) / 256
        b = (b - bb) / 256
        mul = mul * 256
    end
    return r
end

local function bor2(a, b)
    local r, mul = 0, 1
    for _ = 1, 4 do
        local ab, bb = a % 256, b % 256
        r = r + OR_T[ab][bb] * mul
        a = (a - ab) / 256
        b = (b - bb) / 256
        mul = mul * 256
    end
    return r
end

local function bxor2(a, b)
    local r, mul = 0, 1
    for _ = 1, 4 do
        local ab, bb = a % 256, b % 256
        r = r + XOR_T[ab][bb] * mul
        a = (a - ab) / 256
        b = (b - bb) / 256
        mul = mul * 256
    end
    return r
end

local bit32 = {}

function bit32.band(...)
    local n = select('#', ...)
    if n == 0 then return MOD - 1 end
    local r = to_u32(select(1, ...))
    for i = 2, n do r = band2(r, to_u32(select(i, ...))) end
    return r
end

function bit32.bor(...)
    local n = select('#', ...)
    if n == 0 then return 0 end
    local r = to_u32(select(1, ...))
    for i = 2, n do r = bor2(r, to_u32(select(i, ...))) end
    return r
end

function bit32.bxor(...)
    local n = select('#', ...)
    if n == 0 then return 0 end
    local r = to_u32(select(1, ...))
    for i = 2, n do r = bxor2(r, to_u32(select(i, ...))) end
    return r
end

function bit32.bnot(a)
    return MOD - 1 - to_u32(a)
end

function bit32.lshift(a, b)
    b = b % 32
    if b < 0 then b = b + 32 end
    return (to_u32(a) * (2 ^ b)) % MOD
end

function bit32.rshift(a, b)
    b = b % 32
    if b < 0 then b = b + 32 end
    return math.floor(to_u32(a) / (2 ^ b))
end

function bit32.arshift(a, b)
    b = b % 32
    if b < 0 then b = b + 32 end
    a = to_u32(a)
    if a >= 2147483648 then
        local signed = a - MOD
        return math.floor(signed / (2 ^ b)) % MOD
    end
    return math.floor(a / (2 ^ b))
end

function bit32.lrotate(a, b)
    b = b % 32
    if b < 0 then b = b + 32 end
    if b == 0 then return to_u32(a) end
    a = to_u32(a)
    return ((a * (2 ^ b)) % MOD + math.floor(a / (2 ^ (32 - b)))) % MOD
end

function bit32.rrotate(a, b)
    b = b % 32
    if b < 0 then b = b + 32 end
    if b == 0 then return to_u32(a) end
    a = to_u32(a)
    return (math.floor(a / (2 ^ b)) + (a * (2 ^ (32 - b))) % MOD) % MOD
end

function bit32.btest(...)
    return bit32.band(...) ~= 0
end

function bit32.extract(n, field, width)
    width = width or 1
    return math.floor(to_u32(n) / (2 ^ field)) % (2 ^ width)
end

function bit32.replace(n, v, field, width)
    width = width or 1
    n = to_u32(n)
    local mask = (2 ^ width - 1) * (2 ^ field)
    local inv = (MOD - 1) - mask
    local cleared = band2(n, inv)
    local v_masked = to_u32(v) % (2 ^ width)
    return (cleared + v_masked * (2 ^ field)) % MOD
end

function bit32.countlz(n)
    n = to_u32(n)
    if n == 0 then return 32 end
    local count = 0
    while n < 2147483648 do
        n = n * 2
        count = count + 1
    end
    return count
end

function bit32.countrz(n)
    n = to_u32(n)
    if n == 0 then return 32 end
    local count = 0
    while n % 2 == 0 do
        n = n / 2
        count = count + 1
    end
    return count
end

return bit32
