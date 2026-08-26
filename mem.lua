local Memory = {}
Memory.__index = Memory

local UART_ADDR = 0x10000000
local CHUNK = 65536

function Memory.new(size)
  local self = setmetatable({}, Memory)
  self.size = size
  self.chunks = {}
  return self
end

function Memory:w8(addr, val)
  val = val & 0xFF
  if addr == UART_ADDR then
    io.write(string.char(val))
    return
  end
  local ci = addr >> 16
  local off = addr & 0xFFFF
  local c = self.chunks[ci]
  if not c then
    c = {}
    self.chunks[ci] = c
  end
  c[off] = val
end

function Memory:r8(addr)
  if addr == UART_ADDR + 5 then
    return 0x60
  end
  local c = self.chunks[addr >> 16]
  if not c then return 0 end
  return c[addr & 0xFFFF] or 0
end

function Memory:r16(addr)
  return self:r8(addr) | (self:r8(addr + 1) << 8)
end

function Memory:w16(addr, val)
  self:w8(addr, val & 0xFF)
  self:w8(addr + 1, (val >> 8) & 0xFF)
end

function Memory:r32(addr)
  return self:r8(addr)
    | (self:r8(addr + 1) << 8)
    | (self:r8(addr + 2) << 16)
    | (self:r8(addr + 3) << 24)
end

function Memory:w32(addr, val)
  self:w8(addr, val & 0xFF)
  self:w8(addr + 1, (val >> 8) & 0xFF)
  self:w8(addr + 2, (val >> 16) & 0xFF)
  self:w8(addr + 3, (val >> 24) & 0xFF)
end

return Memory
