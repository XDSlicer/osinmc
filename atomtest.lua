local Memory = dofile("/home/vm/mem.lua")
local CPU = dofile("/home/vm/cpu.lua")
local mem = Memory.new(4096)
local cpu = CPU.new(mem)
mem:w32(0x100, 40)
local prog = {
  0x10000093,
  0x00200113,
  0x0020A1AF,
}
local addr = 0
for _, word in ipairs(prog) do
  mem:w32(addr, word)
  addr = addr + 4
end
for i = 1, 3 do cpu:step() end
print("x1 = " .. cpu:getReg(1))
print("x2 = " .. cpu:getReg(2))
print("x3 = " .. cpu:getReg(3))
print("mem = " .. mem:r32(0x100))
