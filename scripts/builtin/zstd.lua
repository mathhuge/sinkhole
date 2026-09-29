local bit32 = loadstring(fetchurl('https://raw.githubusercontent.com/mathhuge/sinkhole/refs/heads/main/scripts/builtin/bit32.lua'))()

local band = bit32.band
local bor = bit32.bor
local bxor = bit32.bxor
local lshift = bit32.lshift
local rshift = bit32.rshift

local floor, char, sub, concat = math.floor, string.char, string.sub, table.concat
local byte = string.byte

local function highbit32(v)
    local n = 0
    while v > 1 do v = rshift(v, 1); n = n + 1 end
    return n
end

local BR = {}
BR.__index = BR
local function br_new(data)
    local n = #data
    if n == 0 then return setmetatable({ data = data, size = 0, pos = 0 }, BR) end
    local last = byte(data, n)
    local skip = 8 - highbit32(last)
    return setmetatable({ data = data, size = n, pos = skip }, BR)
end

function BR:read(n)
    local v = 0
    local pos = self.pos
    local size = self.size
    local data = self.data
    for _ = 1, n do
        local byte_from_end = rshift(pos, 3)
        local bit_in_byte = band(pos, 7)
        local byte_idx = size - 1 - byte_from_end
        if byte_idx >= 0 then
            local b = band(rshift(byte(data, byte_idx + 1), 7 - bit_in_byte), 1)
            v = bor(lshift(v, 1), b)
        else
            v = lshift(v, 1)
        end
        pos = pos + 1
    end
    self.pos = pos
    return v
end

local BW = {}
BW.__index = BW
local function bw_new() return setmetatable({ b = {}, bi = 0, a = 0, n = 0 }, BW) end
function BW:add(v, k)
    if k <= 0 then return end
    self.a = bor(self.a, lshift(band(v, lshift(1, k) - 1), self.n))
    self.n = self.n + k
    while self.n >= 8 do
        self.bi = self.bi + 1
        self.b[self.bi] = char(band(self.a, 0xFF))
        self.a = rshift(self.a, 8)
        self.n = self.n - 8
    end
end
function BW:close()
    self:add(1, 1)
    while self.n > 0 do
        self.bi = self.bi + 1
        self.b[self.bi] = char(band(self.a, 0xFF))
        self.a = rshift(self.a, 8)
        self.n = self.n - 8
    end
    return concat(self.b)
end

local LL_DIST = { 4,3,2,2,2,2,2,2,2,2,2,2,2,1,1,1, 2,2,2,2,2,2,2,2,2,3,2,1,1,1,1,1, -1,-1,-1,-1 }
local ML_DIST = { 1,4,3,2,2,2,2,2,2,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, -1,-1,-1,-1,-1 }
local OF_DIST = { 1,1,1,1,1,1,2,2,2,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, -1,-1,-1,-1,-1 }

local LL_BASE = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,18,20,22,24,28,32,40,48,64,128,256,512,1024,2048,4096,8192,16384,32768,65536}
local LL_BITS = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,2,2,3,3,4,6,7,8,9,10,11,12,13,14,15,16}
local ML_BASE = {3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,37,39,41,43,47,51,59,67,83,99,131,259,515,1027,2051,4099,8195,16387,32771,65539}
local ML_BITS = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,2,2,3,3,4,4,5,7,8,9,10,11,12,13,14,15,16}
local OF_BASE = {0, 1, 1, 5, 13, 29, 61, 125, 253, 509, 1021, 2045, 4093, 8189, 16381, 32765, 65533, 131069, 262141, 524285, 1048573, 2097149, 4194301, 8388605, 16777213, 33554429, 67108861, 134217725, 268435453, 536870909, 1073741821, 2147483645}
local OF_BITS = {0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7}

local function ll_code(ll)
    for i = 35, 0, -1 do if ll >= LL_BASE[i + 1] then return i end end
    return 0
end
local function ml_code(ml)
    for i = 52, 0, -1 do if ml >= ML_BASE[i + 1] then return i end end
    return 0
end
local function of_code(v)
    for i = 31, 0, -1 do if OF_BASE[i + 1] <= v then return i end end
    return 0
end

local function build_ctable(dist, max_sym, table_log)
    local T = lshift(1, table_log)
    local mask = T - 1
    local step = rshift(T, 1) + rshift(T, 3) + 3
    local sym = {}
    for i = 1, T do sym[i] = 0 end
    local hi = T - 1
    local cum = {}
    cum[0] = 0
    for u = 1, max_sym + 1 do
        local c = dist[u]
        if c == -1 then
            cum[u] = cum[u - 1] + 1
            sym[hi + 1] = u - 1
            hi = hi - 1
        else
            cum[u] = cum[u - 1] + c
        end
    end
    cum[max_sym + 1] = T + 1
    local pos = 0
    for s = 0, max_sym do
        local f = dist[s + 1]
        if f > 0 then
            for _ = 1, f do
                sym[pos + 1] = s
                pos = band(pos + step, mask)
                while pos > hi do pos = band(pos + step, mask) end
            end
        end
    end
    local st = {}
    for u = 0, T - 1 do
        local s = sym[u + 1]
        st[cum[s] + 1] = T + u
        cum[s] = cum[s] + 1
    end
    local tt = {}
    local total = 0
    for s = 0, max_sym do
        local nc = dist[s + 1]
        if nc == 0 then
            tt[s] = { dNb = lshift(table_log + 1, 16), dFs = 0 }
        elseif nc == -1 or nc == 1 then
            tt[s] = { dNb = lshift(table_log, 16) - lshift(1, table_log), dFs = total - 1 }
            total = total + 1
        else
            local max_out = table_log - highbit32(nc - 1)
            local min_plus = lshift(nc, max_out)
            tt[s] = { dNb = lshift(max_out, 16) - min_plus, dFs = total - nc }
            total = total + nc
        end
    end
    return { st = st, tt = tt, log = table_log }
end

local function build_dtable(dist, max_sym, table_log)
    local T = lshift(1, table_log)
    local mask = T - 1
    local step = rshift(T, 1) + rshift(T, 3) + 3
    local sym = {}
    for i = 1, T do sym[i] = 0 end
    local hi = T - 1
    local nxt = {}
    for s = 0, max_sym do
        local c = dist[s + 1]
        if c == -1 then
            sym[hi + 1] = s
            hi = hi - 1
            nxt[s] = 1
        else
            nxt[s] = c
        end
    end
    local pos = 0
    for s = 0, max_sym do
        local f = dist[s + 1]
        if f > 0 then
            for _ = 1, f do
                sym[pos + 1] = s
                pos = band(pos + step, mask)
                while pos > hi do pos = band(pos + step, mask) end
            end
        end
    end
    local dt = {}
    for u = 0, T - 1 do
        local s = sym[u + 1]
        local ns = nxt[s]
        nxt[s] = ns + 1
        local nb = table_log - highbit32(ns)
        local nstate = lshift(ns, nb) - T
        if nstate < 0 then nstate = nstate + lshift(1, 16) end
        dt[u + 1] = { sym = s, nb = nb, newstate = nstate }
    end
    return { dt = dt, log = table_log }
end

local LL_CT = build_ctable(LL_DIST, 35, 6)
local ML_CT = build_ctable(ML_DIST, 52, 6)
local OF_CT = build_ctable(OF_DIST, 28, 5)

local LL_DT = build_dtable(LL_DIST, 35, 6)
local ML_DT = build_dtable(ML_DIST, 52, 6)
local OF_DT = build_dtable(OF_DIST, 28, 5)

local function fse_init_d(br, dt)
    return br:read(dt.log)
end

local function fse_decode(br, dt, state)
    local e = dt.dt[state + 1]
    local low = br:read(e.nb)
    local ns = e.newstate + low
    local sz = lshift(1, dt.log)
    if ns >= sz then ns = ns - lshift(1, 16) end
    return e.sym, ns
end

local function decode_sequences(data, seq_start, seq_size)
    local bw = br_new(sub(data, seq_start, seq_start + seq_size - 1))
    local b0 = bw:read(8)
    local nbseq
    if b0 == 0 then
        return {}
    elseif b0 < 128 then
        nbseq = b0
    elseif b0 < 255 then
        local b1 = bw:read(8)
        nbseq = lshift(b0 - 128, 8) + b1
    else
        local b1 = bw:read(8)
        local b2 = bw:read(8)
        nbseq = b1 + lshift(b2, 8) + 0x7F00
    end

    local modes = bw:read(8)
    local ll_mode = band(modes, 0x3)
    local of_mode = band(rshift(modes, 2), 0x3)
    local ml_mode = band(rshift(modes, 4), 0x3)

    if ll_mode > 2 or of_mode > 2 or ml_mode > 2 then
        error("custom FSE tables not supported")
    end

    local sLL = fse_init_d(bw, LL_DT)
    local sOF = fse_init_d(bw, OF_DT)
    local sML = fse_init_d(bw, ML_DT)

    local seqs = {}
    for i = 1, nbseq do
        local ll_sym, of_sym, ml_sym
        ll_sym, sLL = fse_decode(bw, LL_DT, sLL)
        of_sym, sOF = fse_decode(bw, OF_DT, sOF)
        ml_sym, sML = fse_decode(bw, ML_DT, sML)

        local ll = LL_BASE[ll_sym + 1] + bw:read(LL_BITS[ll_sym + 1])
        local ml = ML_BASE[ml_sym + 1] + bw:read(ML_BITS[ml_sym + 1])
        local of = OF_BASE[of_sym + 1] + bw:read(OF_BITS[of_sym + 1])

        seqs[i] = { ll = ll, ml = ml, of = of }
    end
    return seqs
end

local function decode_compressed_block(data, pos, size, out)
    local b0 = byte(data, pos)
    local lit_type = band(b0, 0x3)
    local size_format = band(rshift(b0, 2), 0x3)

    if lit_type ~= 0 and lit_type ~= 1 then
        error("only raw/RLE literals supported")
    end

    local lit_regen, header_len
    if size_format == 0 or size_format == 2 then
        lit_regen = band(rshift(b0, 3), 0x1F)
        header_len = 1
    elseif size_format == 1 then
        lit_regen = bor(band(rshift(b0, 4), 0x0F), lshift(byte(data, pos + 1), 4))
        header_len = 2
    else
        lit_regen = bor(bor(band(rshift(b0, 4), 0x0F), lshift(byte(data, pos + 1), 4)), lshift(byte(data, pos + 2), 12))
        header_len = 3
    end

    local literals
    if lit_type == 0 then
        literals = sub(data, pos + header_len, pos + header_len + lit_regen - 1)
    else
        literals = string.rep(sub(data, pos + header_len, pos + header_len), lit_regen)
    end

    local lit_comp = lit_regen
    local seq_start = pos + header_len + lit_comp
    local seq_size = size - (seq_start - pos)
    local seqs = decode_sequences(data, seq_start, seq_size)

    local work = concat(out)
    local litpos = 1
    for i = 1, #seqs do
        local s = seqs[i]
        if s.ll > 0 then
            work = work .. sub(literals, litpos, litpos + s.ll - 1)
            litpos = litpos + s.ll
        end
        if s.ml > 0 then
            local src_start = #work - s.of
            for j = 0, s.ml - 1 do
                work = work .. sub(work, src_start + j, src_start + j)
            end
        end
    end
    work = work .. sub(literals, litpos)
    out[1] = work
    for i = #out, 2, -1 do out[i] = nil end
end

local function decode_frame(data)
    if #data < 4 then error("truncated frame") end
    if byte(data, 1) ~= 0x28 or byte(data, 2) ~= 0xB5 or byte(data, 3) ~= 0x2F or byte(data, 4) ~= 0xFD then
        error("bad zstd magic")
    end
    local pos = 5
    local fhd = byte(data, pos); pos = pos + 1
    local fcs_flag = band(rshift(fhd, 6), 0x3)
    local single_segment = band(rshift(fhd, 5), 1)
    local checksum_flag = band(rshift(fhd, 2), 1)
    local dict_flag = band(fhd, 0x3)

    local dict_size = ({ 0, 1, 2, 4 })[dict_flag + 1]
    if single_segment == 0 then pos = pos + 1 end
    pos = pos + dict_size

    local fcs_size
    if fcs_flag == 0 then fcs_size = (single_segment == 1) and 1 or 0
    elseif fcs_flag == 1 then fcs_size = 2
    elseif fcs_flag == 2 then fcs_size = 4
    else fcs_size = 8 end
    pos = pos + fcs_size

    local out = {}
    local last = false
    while not last do
        if pos + 3 > #data then error("truncated block header") end
        local hdr = bor(bor(byte(data, pos), lshift(byte(data, pos + 1), 8)), lshift(byte(data, pos + 2), 16))
        pos = pos + 3
        last = band(hdr, 1) == 1
        local btype = band(rshift(hdr, 1), 0x3)
        local bsize = rshift(hdr, 3)

        if btype == 0 then
            out[#out + 1] = sub(data, pos, pos + bsize - 1)
            pos = pos + bsize
        elseif btype == 1 then
            out[#out + 1] = string.rep(sub(data, pos, pos), bsize)
            pos = pos + 1
        elseif btype == 2 then
            decode_compressed_block(data, pos, bsize, out)
            pos = pos + bsize
        else
            error("reserved block type")
        end
    end
    if checksum_flag == 1 then pos = pos + 4 end
    return concat(out)
end

local function find_sequences(src)
    local n = #src
    local seqs = {}
    local lit_start = 1
    if n < 8 then return seqs, src end
    local HLOG = 15
    local HSIZE = lshift(1, HLOG)
    local head = {}
    local prev = {}
    local function hash(p)
        local a, b, c, d = byte(src, p, p + 3)
        return band(rshift(a * 506832829 + b * 1973 + c * 131 + d, 32 - HLOG), HSIZE - 1)
    end
    local pos = 1
    while pos + 4 <= n do
        local h = hash(pos)
        local cand = head[h]
        head[h] = pos
        prev[pos] = cand
        if not cand then
            pos = pos + 1
        else
            local best_len, best_off = 0, 0
            local c = cand
            local tries = 0
            while c and tries < 8 do
                tries = tries + 1
                local l = 0
                while pos + l <= n and src:byte(c + l) == src:byte(pos + l) do l = l + 1 end
                if l >= 3 and l > best_len then
                    best_len = l
                    best_off = pos - c
                    if best_len >= 128 then break end
                end
                c = prev[c]
            end
            if best_len >= 3 then
                seqs[#seqs + 1] = { ll = pos - lit_start, ml = best_len - 3, of = best_off - 1 }
                for k = pos, pos + best_len - 1 do
                    if k + 4 > n then break end
                    local hh = hash(k)
                    prev[k] = head[hh]
                    head[hh] = k
                end
                pos = pos + best_len
                lit_start = pos
            else
                pos = pos + 1
            end
        end
    end
    return seqs, sub(src, lit_start)
end

local function fse_init_c(ct, symbol)
    local t = ct.tt[symbol]
    local nb = rshift(t.dNb + 0x8000, 16)
    local value = lshift(nb, 16) - t.dNb
    local sz = lshift(1, ct.log)
    local idx = rshift(value, nb) + t.dFs
    idx = idx % sz
    if idx < 0 then idx = idx + sz end
    return { ct = ct, v = ct.st[idx + 1] }
end

local function fse_enc_c(bw, st, symbol)
    local t = st.ct.tt[symbol]
    local nb = rshift(st.v + t.dNb, 16)
    bw:add(st.v, nb)
    local sz = lshift(1, st.ct.log)
    local idx = rshift(st.v, nb) + t.dFs
    idx = idx % sz
    if idx < 0 then idx = idx + sz end
    st.v = st.ct.st[idx + 1]
end

local function encode_nbseq(n)
    if n < 128 then return char(n) end
    if n < 0x7F00 then return char(0x80 + rshift(n, 8), band(n, 0xFF)) end
    local v = n - 0x7F00
    return char(0xFF, band(v, 0xFF), band(rshift(v, 8), 0xFF))
end

local function encode_sequences(seqs, tail_lit)
    local ns = #seqs
    if ns == 0 then return char(0) end
    local out = { encode_nbseq(ns), char(0) }
    local bw = bw_new()
    local llc, mlc, ofc = {}, {}, {}
    local llv, mlv, ofv = {}, {}, {}
    for i = 1, ns do
        local s = seqs[i]
        local ll = s.ll + (i == ns and tail_lit or 0)
        llv[i], mlv[i], ofv[i] = ll, s.ml, s.of
        llc[i] = ll_code(ll)
        mlc[i] = ml_code(s.ml)
        ofc[i] = of_code(s.of)
    end
    local sLL = fse_init_c(LL_CT, llc[ns])
    local sML = fse_init_c(ML_CT, mlc[ns])
    local sOF = fse_init_c(OF_CT, ofc[ns])
    bw:add(llv[ns] - LL_BASE[llc[ns] + 1], LL_BITS[llc[ns] + 1])
    bw:add(mlv[ns] - ML_BASE[mlc[ns] + 1], ML_BITS[mlc[ns] + 1])
    bw:add(ofv[ns] - OF_BASE[ofc[ns] + 1], OF_BITS[ofc[ns] + 1])
    fse_enc_c(bw, sOF, ofc[ns])
    fse_enc_c(bw, sML, mlc[ns])
    fse_enc_c(bw, sLL, llc[ns])
    for i = ns - 1, 1, -1 do
        bw:add(llv[i] - LL_BASE[llc[i] + 1], LL_BITS[llc[i] + 1])
        bw:add(mlv[i] - ML_BASE[mlc[i] + 1], ML_BITS[mlc[i] + 1])
        bw:add(ofv[i] - OF_BASE[ofc[i] + 1], OF_BITS[ofc[i] + 1])
        fse_enc_c(bw, sOF, ofc[i])
        fse_enc_c(bw, sML, mlc[i])
        fse_enc_c(bw, sLL, llc[i])
    end
    bw:add(sML.v, 6)
    bw:add(sOF.v, 5)
    bw:add(sLL.v, 6)
    out[#out + 1] = bw:close()
    return concat(out)
end

local function encode_raw_literals(lit)
    local n = #lit
    if n == 0 then return "" end
    if n < 32 then
        return char(lshift(n, 3)) .. lit
    elseif n < 4096 then
        local v = 4 + lshift(n, 4)
        return char(band(v, 0xFF), band(rshift(v, 8), 0xFF)) .. lit
    else
        local v = 12 + lshift(n, 4)
        return char(band(v, 0xFF), band(rshift(v, 8), 0xFF), band(rshift(v, 16), 0xFF)) .. lit
    end
end

local function encode_compressed_block(src, is_last)
    local seqs, tail = find_sequences(src)
    if #seqs == 0 then return nil end
    local lit = {}
    local pos = 1
    for i = 1, #seqs do
        local s = seqs[i]
        lit[#lit + 1] = sub(src, pos, pos + s.ll - 1)
        pos = pos + s.ll + s.ml + 3
    end
    lit[#lit + 1] = tail
    local litstr = concat(lit)
    local body = encode_raw_literals(litstr) .. encode_sequences(seqs, #tail)
    local size = #body
    local hdr = bor(bor((is_last and 1 or 0), lshift(2, 1)), lshift(size, 3))
    return char(band(hdr, 0xFF), band(rshift(hdr, 8), 0xFF), band(rshift(hdr, 16), 0xFF)) .. body
end

local function encode_raw_block(src, is_last)
    local n = #src
    local hdr = bor((is_last and 1 or 0), lshift(n, 3))
    return char(band(hdr, 0xFF), band(rshift(hdr, 8), 0xFF), band(rshift(hdr, 16), 0xFF)) .. src
end

local function encode_frame(src)
    local n = #src
    local parts = {}
    parts[#parts + 1] = char(0x28, 0xB5, 0x2F, 0xFD)
    parts[#parts + 1] = char(0xE0)
    local fcs = {}
    local t = n
    for _ = 1, 8 do
        fcs[#fcs + 1] = char(band(t, 0xFF))
        t = rshift(t, 8)
    end
    parts[#parts + 1] = concat(fcs)
    if n < 128 * 1024 then
        local blk = encode_compressed_block(src, true)
        if blk and #blk < #src + 3 then
            parts[#parts + 1] = blk
        else
            parts[#parts + 1] = encode_raw_block(src, true)
        end
    else
        local pos = 1
        while pos <= n do
            local sz = math.min(128 * 1024, n - pos + 1)
            local last = (pos + sz - 1 == n)
            parts[#parts + 1] = encode_raw_block(sub(src, pos, pos + sz - 1), last)
            pos = pos + sz
        end
    end
    return concat(parts)
end

return {
    encode = function(data)
        if type(data) ~= "string" then data = tostring(data) end
        if #data == 0 then
            return char(0x28, 0xB5, 0x2F, 0xFD, 0xE0, 0,0,0,0,0,0,0,0, 0x01, 0x00, 0x00)
        end
        return encode_frame(data)
    end,
    decode = function(data)
        if type(data) ~= "string" then error("expected string") end
        return decode_frame(data)
    end,
}
