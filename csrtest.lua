local Memory = dofile("/home/vm/mem.lua")
local CPU = dofile("/home/vm/cpu.lua")
local mem = Memory.new(4096)
local cpu = CPU.new(mem)
local prog = {
  0x02A00093,
  0x30509073,
  0x30502173,
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
print("x2 = " .. cpu:getReg(2) .. " (want 42)")
if cpu.trap then print("trap: " .. cpu.trap) end
