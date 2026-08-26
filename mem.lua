local Memory = {}
Memory.__index = Memory

local RAM_BASE = 0x80000000
local CHUNK = 65536

function Memory.new(size)
  local self = setmetatable({}, Memory)
  self.size = size
  self.chunks = {}
  self.uart_lsr = 0x60
  self.uart_rx = nil
  self.syscon = 0
  self.cpu = nil
  return self
end

function Memory:setCPU(cpu)
  self.cpu = cpu
end

function Memory:pushChar(c)
  self.uart_rx = c
end

function Memory:_mmio_w8(addr, val)
  if addr == 0x10000000 then
    io.write(string.char(val))
    io.flush()
    return true
  end
  return false
end

function Memory:_mmio_r8(addr)
  if addr == 0x10000000 then
    local c = self.uart_rx
    self.uart_rx = nil
    return c or 0
  elseif addr == 0x10000005 then
    local r = 0x60
    if self.uart_rx then r = r | 0x01 end
    return r
  end
  return nil
end

function Memory:_mmio_w32(addr, val)
  if addr == 0x11100000 then
    self.syscon = val
    return true
  end
  if self.cpu then
    if addr == 0x1100bff8 then self.cpu.mtime_lo = val return true
    elseif addr == 0x1100bffc then self.cpu.mtime_hi = val return true
    elseif addr == 0x11004000 then self.cpu.timermatch_lo = val return true
    elseif addr == 0x11004004 then self.cpu.timermatch_hi = val return true
    end
  end
  return false
end

function Memory:_mmio_r32(addr)
  if self.cpu then
    if addr == 0x1100bff8 then return self.cpu.mtime_lo
    elseif addr == 0x1100bffc then return self.cpu.mtime_hi
    elseif addr == 0x11004000 then return self.cpu.timermatch_lo
    elseif addr == 0x11004004 then return self.cpu.timermatch_hi
    end
  end
  return nil
end

function Memory:w8(addr, val)
  val = val & 0xFF
  if addr >= 0x10000000 and addr < 0x80000000 then
    if self:_mmio_w8(addr, val) then return end
  end
  local off = addr - RAM_BASE
  local ci = off >> 16
  local c = self.chunks[ci]
  if not c then c = {} self.chunks[ci] = c end
  c[off & 0xFFFF] = val
end

function Memory:r8(addr)
  if addr >= 0x10000000 and addr < 0x80000000 then
    local v = self:_mmio_r8(addr)
    if v ~= nil then return v end
  end
  local off = addr - RAM_BASE
  local c = self.chunks[off >> 16]
  if not c then return 0 end
  return c[off & 0xFFFF] or 0
end

function Memory:r16(addr)
  return self:r8(addr) | (self:r8(addr+1) << 8)
end

function Memory:w16(addr, val)
  self:w8(addr, val & 0xFF)
  self:w8(addr+1, (val >> 8) & 0xFF)
end

function Memory:r32(addr)
  if addr >= 0x10000000 and addr < 0x80000000 then
    local v = self:_mmio_r32(addr)
    if v ~= nil then return v end
  end
  return self:r8(addr) | (self:r8(addr+1) << 8) | (self:r8(addr+2) << 16) | (self:r8(addr+3) << 24)
end

function Memory:w32(addr, val)
  if addr >= 0x10000000 and addr < 0x80000000 then
    if self:_mmio_w32(addr, val) then return end
  end
  self:w8(addr, val & 0xFF)
  self:w8(addr+1, (val >> 8) & 0xFF)
  self:w8(addr+2, (val >> 16) & 0xFF)
  self:w8(addr+3, (val >> 24) & 0xFF)
end

return Memory
