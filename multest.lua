local Memory = dofile("/home/vm/mem.lua")
local CPU = dofile("/home/vm/cpu.lua")
local mem = Memory.new(4096)
local cpu = CPU.new(mem)
local prog = {
  0x00600093,
  0x00700113,
  0x022081B3,
  0x00000073,
}
local addr = 0
for _, word in ipairs(prog) do
  mem:w32(addr, word)
  addr = addr + 4
end
local steps = 0
while cpu.running and steps < 100 do
  cpu:step()
  steps = steps + 1
end
print("x3 = " .. cpu:getReg(3) .. " (want 42)")
if cpu.trap then print("trap: " .. cpu.trap) end
