local CPU = {}
CPU.__index = CPU

local function sext(val, bits)
  local m = 1 << (bits - 1)
  return (val ~ m) - m
end

local function u32(v)
  return v & 0xFFFFFFFF
end

function CPU.new(mem)
  local self = setmetatable({}, CPU)
  self.mem = mem
  self.x = {}
  for i = 0, 31 do self.x[i] = 0 end
  self.pc = 0x80000000
  self.running = true
  self.csr = {}
  self.priv = 3
  self.mtime_lo = 0
  self.mtime_hi = 0
  self.timermatch_lo = 0
  self.timermatch_hi = 0
  self.reservation = nil
  self.wfi = false
  return self
end

function CPU:setReg(i, v)
  if i ~= 0 then self.x[i] = u32(v) end
end

function CPU:getReg(i)
  return self.x[i]
end

function CPU:trapEnter(cause, tval)
  self.csr[0x341] = self.pc
  self.csr[0x342] = cause
  self.csr[0x343] = tval
  local ms = self.csr[0x300] or 0
  local mie = (ms >> 3) & 0x1
  ms = ms & u32(~(0x1 << 7))
  ms = ms | (mie << 7)
  ms = ms & u32(~(0x1 << 3))
  ms = (ms & u32(~(0x3 << 11))) | (self.priv << 11)
  self.csr[0x300] = ms
  self.priv = 3
  self.pc = (self.csr[0x305] or 0) & 0xFFFFFFFC
end

function CPU:tick(n)
  local lo = self.mtime_lo + n
  if lo >= 0x100000000 then
    lo = lo - 0x100000000
    self.mtime_hi = u32(self.mtime_hi + 1)
  end
  self.mtime_lo = lo

  local timer = false
  if (self.timermatch_lo ~= 0 or self.timermatch_hi ~= 0) then
    if self.mtime_hi > self.timermatch_hi or
       (self.mtime_hi == self.timermatch_hi and self.mtime_lo >= self.timermatch_lo) then
      timer = true
    end
  end

  local mip = self.csr[0x344] or 0
  if timer then
    mip = mip | 0x80
    self.wfi = false
  else
    mip = mip & u32(~0x80)
  end
  self.csr[0x344] = mip

  local ms = self.csr[0x300] or 0
  local mie = self.csr[0x304] or 0
  if (ms & 0x8) ~= 0 and (mie & 0x80) ~= 0 and (mip & 0x80) ~= 0 then
    self:trapEnter(0x80000007, 0)
    return
  end
end

function CPU:step()
  if self.wfi then return end
  local mem = self.mem
  local pc = self.pc
  local inst = mem:r32(pc)

  local opcode = inst & 0x7F
  local rd = (inst >> 7) & 0x1F
  local funct3 = (inst >> 12) & 0x7
  local rs1 = (inst >> 15) & 0x1F
  local rs2 = (inst >> 20) & 0x1F
  local funct7 = (inst >> 25) & 0x7F

  local nextpc = u32(pc + 4)

  if opcode == 0x33 then
    local a = self.x[rs1]
    local b = self.x[rs2]
    local r
    if funct7 == 0x01 then
      local sa = sext(a, 32)
      local sb = sext(b, 32)
      if funct3 == 0x0 then r = u32(sa * sb)
      elseif funct3 == 0x1 then r = u32((sa * sb) >> 32)
      elseif funct3 == 0x2 then r = u32((sa * b) >> 32)
      elseif funct3 == 0x3 then r = u32((a * b) >> 32)
      elseif funct3 == 0x4 then
        if b == 0 then r = 0xFFFFFFFF
        elseif sa == -2147483648 and sb == -1 then r = u32(sa)
        else r = u32(sa // sb) end
      elseif funct3 == 0x5 then
        if b == 0 then r = 0xFFFFFFFF else r = u32(a // b) end
      elseif funct3 == 0x6 then
        if b == 0 then r = u32(sa)
        elseif sa == -2147483648 and sb == -1 then r = 0
        else r = u32(sa - (sa // sb) * sb) end
      elseif funct3 == 0x7 then
        if b == 0 then r = u32(a) else r = u32(a - (a // b) * b) end
      end
    else
      if funct3 == 0x0 then
        if funct7 == 0x20 then r = a - b else r = a + b end
      elseif funct3 == 0x7 then r = a & b
      elseif funct3 == 0x6 then r = a | b
      elseif funct3 == 0x4 then r = a ~ b
      elseif funct3 == 0x1 then r = a << (b & 0x1F)
      elseif funct3 == 0x5 then
        if funct7 == 0x20 then r = sext(a,32) >> (b & 0x1F) else r = a >> (b & 0x1F) end
      elseif funct3 == 0x2 then r = (sext(a,32) < sext(b,32)) and 1 or 0
      elseif funct3 == 0x3 then r = (a < b) and 1 or 0
      end
    end
    self:setReg(rd, r)

  elseif opcode == 0x13 then
    local a = self.x[rs1]
    local imm = sext((inst >> 20) & 0xFFF, 12)
    local shamt = (inst >> 20) & 0x1F
    local r
    if funct3 == 0x0 then r = a + imm
    elseif funct3 == 0x7 then r = a & u32(imm)
    elseif funct3 == 0x6 then r = a | u32(imm)
    elseif funct3 == 0x4 then r = a ~ u32(imm)
    elseif funct3 == 0x1 then r = a << shamt
    elseif funct3 == 0x5 then
      if funct7 == 0x20 then r = sext(a,32) >> shamt else r = a >> shamt end
    elseif funct3 == 0x2 then r = (sext(a,32) < imm) and 1 or 0
    elseif funct3 == 0x3 then r = (a < u32(imm)) and 1 or 0
    end
    self:setReg(rd, r)

  elseif opcode == 0x37 then
    self:setReg(rd, inst & 0xFFFFF000)

  elseif opcode == 0x17 then
    self:setReg(rd, u32(pc + (inst & 0xFFFFF000)))

  elseif opcode == 0x6F then
    local imm = ((inst >> 31) & 0x1) << 20
    imm = imm | (((inst >> 21) & 0x3FF) << 1)
    imm = imm | (((inst >> 20) & 0x1) << 11)
    imm = imm | (((inst >> 12) & 0xFF) << 12)
    imm = sext(imm, 21)
    self:setReg(rd, nextpc)
    nextpc = u32(pc + imm)

  elseif opcode == 0x67 then
    local imm = sext((inst >> 20) & 0xFFF, 12)
    local target = u32(self.x[rs1] + imm) & 0xFFFFFFFE
    self:setReg(rd, nextpc)
    nextpc = target

  elseif opcode == 0x63 then
    local imm = ((inst >> 31) & 0x1) << 12
    imm = imm | (((inst >> 25) & 0x3F) << 5)
    imm = imm | (((inst >> 8) & 0xF) << 1)
    imm = imm | (((inst >> 7) & 0x1) << 11)
    imm = sext(imm, 13)
    local a = self.x[rs1]
    local b = self.x[rs2]
    local take = false
    if funct3 == 0x0 then take = (a == b)
    elseif funct3 == 0x1 then take = (a ~= b)
    elseif funct3 == 0x4 then take = (sext(a,32) < sext(b,32))
    elseif funct3 == 0x5 then take = (sext(a,32) >= sext(b,32))
    elseif funct3 == 0x6 then take = (a < b)
    elseif funct3 == 0x7 then take = (a >= b)
    end
    if take then nextpc = u32(pc + imm) end

  elseif opcode == 0x03 then
    local imm = sext((inst >> 20) & 0xFFF, 12)
    local addr = u32(self.x[rs1] + imm)
    local r
    if funct3 == 0x0 then r = sext(mem:r8(addr), 8)
    elseif funct3 == 0x1 then r = sext(mem:r16(addr), 16)
    elseif funct3 == 0x2 then r = mem:r32(addr)
    elseif funct3 == 0x4 then r = mem:r8(addr)
    elseif funct3 == 0x5 then r = mem:r16(addr)
    end
    self:setReg(rd, r)

  elseif opcode == 0x23 then
    local imm = ((inst >> 25) & 0x7F) << 5
    imm = imm | ((inst >> 7) & 0x1F)
    imm = sext(imm, 12)
    local addr = u32(self.x[rs1] + imm)
    local v = self.x[rs2]
    if funct3 == 0x0 then mem:w8(addr, v)
    elseif funct3 == 0x1 then mem:w16(addr, v)
    elseif funct3 == 0x2 then mem:w32(addr, v)
    end

  elseif opcode == 0x0F then

  elseif opcode == 0x2F then
    local a = u32(self.x[rs1])
    local funct5 = (funct7 >> 2) & 0x1F
    local mval = mem:r32(a)
    local b = self.x[rs2]
    if funct5 == 0x02 then
      self.reservation = a
      self:setReg(rd, mval)
    elseif funct5 == 0x03 then
      if self.reservation == a then
        mem:w32(a, b) self:setReg(rd, 0)
      else self:setReg(rd, 1) end
      self.reservation = nil
    else
      local r
      if funct5 == 0x00 then r = u32(mval + b)
      elseif funct5 == 0x01 then r = b
      elseif funct5 == 0x04 then r = mval ~ b
      elseif funct5 == 0x08 then r = mval | b
      elseif funct5 == 0x0C then r = mval & b
      elseif funct5 == 0x10 then r = (sext(mval,32)<sext(b,32)) and mval or b
      elseif funct5 == 0x14 then r = (sext(mval,32)<sext(b,32)) and b or mval
      elseif funct5 == 0x18 then r = (mval<b) and mval or b
      elseif funct5 == 0x1C then r = (mval<b) and b or mval
      else r = mval end
      mem:w32(a, u32(r))
      self:setReg(rd, mval)
    end

  elseif opcode == 0x73 then
    local imm12 = (inst >> 20) & 0xFFF
    if funct3 == 0x0 then
      if imm12 == 0x000 then
        self:trapEnter(11, 0) return
      elseif imm12 == 0x001 then
        self:trapEnter(3, 0) return
      elseif imm12 == 0x302 then
        local ms = self.csr[0x300] or 0
        local mpp = (ms >> 11) & 0x3
        local mpie = (ms >> 7) & 0x1
        ms = (ms & u32(~(0x1 << 3))) | (mpie << 3)
        ms = ms | (0x1 << 7)
        self.csr[0x300] = ms
        self.priv = mpp
        self.pc = self.csr[0x341] or 0
        return
      elseif imm12 == 0x105 then
        self.wfi = true
        self.pc = nextpc
        return
      else
        self.pc = nextpc
        return
      end
    else
      local csraddr = imm12
      local old = self.csr[csraddr] or 0
      local src
      if funct3 >= 0x5 then src = rs1 else src = self.x[rs1] end
      local newval = old
      if funct3 == 0x1 or funct3 == 0x5 then newval = src
      elseif funct3 == 0x2 or funct3 == 0x6 then newval = old | src
      elseif funct3 == 0x3 or funct3 == 0x7 then newval = old & u32(~src)
      end
      if rd ~= 0 then self:setReg(rd, old) end
      if not ((funct3 == 0x2 or funct3 == 0x6 or funct3 == 0x3 or funct3 == 0x7) and rs1 == 0) then
        self.csr[csraddr] = u32(newval)
      end
    end

  else
    self:trapEnter(2, inst)
    return
  end

  self.pc = nextpc
end

return CPU
