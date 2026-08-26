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
  self.pc = 0
  self.running = true
  self.csr = {}
  self.priv = 3
  self.mtime = 0
  self.mtimecmp = 0xFFFFFFFFFFFF
  return self
end

function CPU:setReg(i, v)
  if i ~= 0 then
    self.x[i] = u32(v)
  end
end

function CPU:getReg(i)
  return self.x[i]
end

function CPU:trapEnter(cause, tval)
  self.csr[0x341] = self.pc
  self.csr[0x342] = cause
  self.csr[0x343] = tval
  local mstatus = self.csr[0x300] or 0
  local mie = (mstatus >> 3) & 0x1
  mstatus = mstatus & u32(~(0x1 << 7))
  mstatus = mstatus | (mie << 7)
  mstatus = mstatus & u32(~(0x1 << 3))
  mstatus = (mstatus & u32(~(0x3 << 11))) | (self.priv << 11)
  self.csr[0x300] = mstatus
  self.priv = 3
  local tvec = self.csr[0x305] or 0
  self.pc = tvec & 0xFFFFFFFC
end

function CPU:step()
  local mem = self.mem

  self.mtime = self.mtime + 1
  local mstatus = self.csr[0x300] or 0
  local mie = self.csr[0x304] or 0
  if self.mtime >= self.mtimecmp then
    self.csr[0x344] = (self.csr[0x344] or 0) | 0x80
  end
