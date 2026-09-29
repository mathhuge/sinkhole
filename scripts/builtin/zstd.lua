local floor, char, sub, concat = math.floor, string.char, string.sub, table.concat
local byte = string.byte

local function highbit32(v)
    local n = 0
    while v > 1 do v = v >> 1; n = n + 1 end
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
        local byte_from_end = pos >> 3
        local bit_in_byte = pos & 7
        local byte_idx = size - 1 - byte_from_end
        if byte_idx >= 0 then
            local b = (byte(data, byte_idx + 1) >> (7 - bit_in_byte)) & 1
            v = (v << 1) | b
        else
            v = v << 1
        end
        pos = pos + 1
    end
    self.pos = pos
    return v
end

local BW = {}
BW.__index = BW
local function bw_new() return setmetatable({ b = {}, a = 0, n = 0 }, BW) end
function BW:add(v, k)
    if k <= 0 then return end
    self.a = self.a | ((v & ((1 << k) - 1)) << self.n)
    self.n = self.n + k
    while self.n >= 8 do
        self.b = self.b + 1
        self.b[self.b] = char(self.a & 0xFF)
        self.a = self.a >> 8
        self.n = self.n - 8
    end
end
function BW:close()
    self:add(1, 1)
    while self.n > 0 do
        self.b = self.b + 1
        self.b[self.b] = char(self.a & 0xFF)
        self.a = self.a >> 8
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
local OF_BASE = {0,1,2,3,4,5,6,8,10,12,16,20,24,32,40,48,64,80,96,128,160,192,256,320,384,512,640,768,1024,1280,1536,2048}
local OF_BITS = {0,0,0,0,0,0,1,1,1,1,2,2,2,3,3,3,4,4,4,5,5,5,6,6,6,7,7,7,8,8,8,9}

local function ll_code(ll)
    for i = 35, 0, -1 do if ll >= LL_BASE[i + 1] then return i end end
    return 0
end
local function ml_code(ml)
    for i = 52, 0, -1 do if ml >= ML_BASE[i + 1] then return i end end
    return 0
end

local function build_ctable(dist, max_sym, table_log)
    local T = 1 << table_log
    local mask = T - 1
    local step = (T >> 1) + (T >> 3) + 3
    local sym = {}
    for i = 1, T do sym[i] = 0 end
    local hi = T - 1
    local cum = { 0 }
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
                pos = (pos + step) & mask
                while pos > hi do pos = (pos + step) & mask end
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
            tt[s] = { dNb = ((table_log + 1) << 16) - (1 << table_log), dFs = 0 }
        elseif nc == -1 or nc == 1 then
            tt[s] = { dNb = (table_log << 16) - (1 << table_log), dFs = total - 1 }
            total = total + 1
        else
            local max_out = table_log - highbit32(nc - 1)
            local min_plus = nc << max_out
            tt[s] = { dNb = (max_out << 16) - min_plus, dFs = total - nc }
            total = total + nc
        end
    end
    return { st = st, tt = tt, log = table_log }
end

local function build_dtable(dist, max_sym, table_log)
    local T = 1 << table_log
    local mask = T - 1
    local step = (T >> 1) + (T >> 3) + 3
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
                pos = (pos + step) & mask
                while pos > hi do pos = (pos + step) & mask end
            end
        end
    end
    local dt = {}
    for u = 0, T - 1 do
        local s = sym[u + 1]
        local ns = nxt[s]
        nxt[s] = ns + 1
        local nb = table_log - highbit32(ns)
        dt[u + 1] = { sym = s, nb = nb, newstate = (ns << nb) - T }
    end
    return { dt = dt, log = table_log }
end

local LL_DT = build_dtable(LL_DIST, 35, 6)
local ML_DT = build_dtable(ML_DIST, 52, 6)
local OF_DT = build_dtable(OF_DIST, 28, 5)

local function fse_init_d(br, dt)
    return br:read(dt.log)
end

local function fse_decode(br, dt, state)
    local e = dt.dt[state + 1]
    local low = br:read(e.nb)
    return e.sym, e.newstate + low
end

local function decode_raw_literals(data, pos, size)
    return sub(data, pos, pos + size - 1), pos + size
end

local function decode_sequences(data, seq_start, seq_size, literal_size)
    local bw = br_new(sub(data, seq_start, seq_start + seq_size - 1))
    local nbseq = bw:read(8)
    if nbseq == 0 then
        return {}, 0
    elseif nbseq < 128 then
    elseif nbseq < 0xFF00 then
        nbseq = (nbseq << 8) | bw:read(8) - 0x80 << 8
        nbseq = ((bw:read(8) << 8) | (bw:read(8))) + 0x80
    end
    local modes = bw:read(8)
    local ll_mode = modes & 0x3
    local of_mode = (modes >> 2) & 0x3
    local ml_mode = (modes >> 4) & 0x3

    if ll_mode > 2 or of_mode > 2 or ml_mode > 2 then
        error("custom FSE tables not supported by this decoder")
    end

    local ll_dt, ml_dt, of_dt = LL_DT, ML_DT, OF_DT

    local sLL = fse_init_d(bw, ll_dt)
    local sOF = fse_init_d(bw, of_dt)
    local sML = fse_init_d(bw, ml_dt)

    local seqs = {}
    for i = 1, nbseq do
        local ll_sym, of_sym, ml_sym

        ll_sym, sLL = fse_decode(bw, ll_dt, sLL)
        of_sym, sOF = fse_decode(bw, of_dt, sOF)
        ml_sym, sML = fse_decode(bw, ml_dt, sML)

        local ll = LL_BASE[ll_sym + 1] + bw:read(LL_BITS[ll_sym + 1])
        local ml = ML_BASE[ml_sym + 1] + bw:read(ML_BITS[ml_sym + 1])
        local of = OF_BASE[of_sym + 1] + bw:read(OF_BITS[of_sym + 1])

        seqs[i] = { ll = ll, ml = ml, of = of }
    end

    return seqs
end

local function decode_compressed_block(data, pos, size, out)
    local lit_hdr_start = pos
    local b0 = byte(data, pos)
    local lit_type = b0 & 0x3
    local size_format = (b0 >> 2) & 0x3

    local lit_regen, lit_comp, header_len

    if lit_type == 0 or lit_type == 1 then
        if size_format == 0 or size_format == 2 then
            lit_regen = (b0 >> 3) & 0x1F
            header_len = 1
        elseif size_format == 1 then
            lit_regen = ((b0 >> 4) & 0x0F) | (byte(data, pos + 1) << 4)
            header_len = 2
        else
            lit_regen = ((b0 >> 4) & 0x0F) | (byte(data, pos + 1) << 4) | (byte(data, pos + 2) << 12)
            header_len = 3
        end
        lit_comp = lit_regen
    elseif lit_type == 2 or lit_type == 3 then
        local b1 = byte(data, pos + 1)
        local b2 = byte(data, pos + 2)
        if size_format <= 1 then
            lit_regen = ((b0 >> 4) & 0x0F) | (b1 << 4) | ((b2 & 0x3F) << 12)
            lit_comp = (b2 >> 6) | (byte(data, pos + 3) << 2)
            header_len = 4
        elseif size_format == 2 then
            lit_regen = ((b0 >> 4) & 0x0F) | (b1 << 4) | ((b2 & 0x3F) << 12)
            lit_comp = (b2 >> 6) | (byte(data, pos + 3) << 2) | (byte(data, pos + 4) << 10)
            header_len = 5
        else
            lit_regen = ((b0 >> 4) & 0x0F) | (b1 << 4) | (b2 << 12) | (byte(data, pos + 3) << 20)
            lit_comp = byte(data, pos + 4) | (byte(data, pos + 5) << 8) | (byte(data, pos + 6) << 16)
            header_len = 7
        end
    else
        error("unknown literals type " .. lit_type)
    end

    local literals
    if lit_type == 0 then
        literals = sub(data, pos + header_len, pos + header_len + lit_regen - 1)
    elseif lit_type == 1 then
        literals = string.rep(sub(data, pos + header_len, pos + header_len), lit_regen)
    else
        error("Huffman literals not supported by this decoder")
    end

    pos = pos + header_len + lit_comp

    local seq_size = size - (pos - lit_hdr_start)
    local seqs = decode_sequences(data, pos, seq_size, lit_regen)

    local litpos = 1
    for i = 1, #seqs do
        local s = seqs[i]
        if s.ll > 0 then
            out[#out + 1] = sub(literals, litpos, litpos + s.ll - 1)
            litpos = litpos + s.ll
        end
        if s.ml > 0 then
            local start = #concat(out) - s.of
            local copy = {}
            for j = 1, s.ml do
                local from = #concat(out) - s.of + j
                out[#out + 1] = string.sub(concat(out), from, from)
            end
        end
    end
    out[#out + 1] = sub(literals, litpos)
end

local function decode_frame(data)
    if #data < 4 then error("truncated frame") end
    if byte(data, 1) ~= 0x28 or byte(data, 2) ~= 0xB5 or byte(data, 3) ~= 0x2F or byte(data, 4) ~= 0xFD then
        error("not a zstd frame (bad magic)")
    end
    local pos = 5
    local fhd = byte(data, pos); pos = pos + 1
    local fcs_flag = (fhd >> 6) & 0x3
    local single_segment = (fhd >> 5) & 1
    local checksum_flag = (fhd >> 2) & 1
    local dict_flag = fhd & 0x3

    local dict_size = { 0, 1, 2, 4 }[dict_flag + 1]
    if not single_segment then
        pos = pos + 1
    end
    pos = pos + dict_size

    local fcs_size
    if fcs_flag == 0 then
        fcs_size = single_segment and 1 or 0
    elseif fcs_flag == 1 then
        fcs_size = 2
    elseif fcs_flag == 2 then
        fcs_size = 4
    else
        fcs_size = 8
    end
    pos = pos + fcs_size

    local out = {}
    local last = false
    while not last do
        if pos + 3 > #data then error("truncated block header") end
        local hdr = byte(data, pos) | (byte(data, pos + 1) << 8) | (byte(data, pos + 2) << 16)
        pos = pos + 3
        last = (hdr & 1) == 1
        local btype = (hdr >> 1) & 0x3
        local bsize = hdr >> 3

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

    if checksum_flag then pos = pos + 4 end

    return concat(out)
end

local function find_sequences(src)
    local n = #src
    local seqs = {}
    local lit_start = 1
    if n < 8 then return seqs, src end
    local HLOG = 15
    local HSIZE = 1 << HLOG
    local head = {}
    local prev = {}
    local function hash(p)
        local a, b, c, d = byte(src, p, p + 3)
        return ((a * 506832829 + b * 1973 + c * 131 + d) >> (32 - HLOG)) & (HSIZE - 1)
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
    local nb = (t.dNb + 0x8000) >> 16
    if nb <= 12 then
        local idx = ((nb << 16) - t.dNb) >> 16
        return { ct = ct, v = ct.st[idx + 1] }
    else
        return { ct = ct, v = t.dFs }
    end
end

local function fse_enc_c(bw, st, symbol)
    local t = st.ct.tt[symbol]
    local nb = (st.v + t.dNb) >> 16
    bw:add(st.v, nb)
    local idx = (st.v >> nb) + t.dFs
    local table_size = 1 << st.ct.log
    idx = idx % table_size
    if idx < 0 then idx = idx + table_size end
    st.v = st.ct.st[idx + 1]
end

local function encode_nbseq(n)
    if n < 0x80 then return char(n) end
    if n < 0x4000 then return char(0x80 | (n >> 8), n & 0xFF) end
    if n < 0x200000 then return char(0xC0 | (n >> 16), (n >> 8) & 0xFF, n & 0xFF) end
    return char(0xE0 | ((n >> 24) & 0xFF), (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF)
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
        ofc[i] = highbit32(s.of)
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

local LL_CT = build_ctable(LL_DIST, 35, 6)
local ML_CT = build_ctable(ML_DIST, 52, 6)
local OF_CT = build_ctable(OF_DIST, 28, 5)

local function encode_raw_literals(lit)
    local n = #lit
    if n == 0 then return "" end
    if n < 32 then
        return char(n << 3) .. lit
    elseif n < 4096 then
        local v = 4 + (n << 4)
        return char(v & 0xFF, (v >> 8) & 0xFF) .. lit
    else
        local v = 12 + (n << 4)
        return char(v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF) .. lit
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
    local hdr = (is_last and 1 or 0) | (2 << 1) | (size << 3)
    return char(hdr & 0xFF, (hdr >> 8) & 0xFF, (hdr >> 16) & 0xFF) .. body
end

local function encode_raw_block(src, is_last)
    local n = #src
    local hdr = (is_last and 1 or 0) | (0 << 1) | (n << 3)
    return char(hdr & 0xFF, (hdr >> 8) & 0xFF, (hdr >> 16) & 0xFF) .. src
end

local function encode_frame(src)
    local n = #src
    local parts = {}
    parts[#parts + 1] = char(0x28, 0xB5, 0x2F, 0xFD)
    parts[#parts + 1] = char(0xE0)
    local fcs = {}
    local t = n
    for _ = 1, 8 do
        fcs[#fcs + 1] = char(t & 0xFF)
        t = t >> 8
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
    encode = function(data, level)
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
