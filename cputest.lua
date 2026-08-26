local Memory = dofile("/home/vm/mem.lua")
local CPU = dofile("/home/vm/cpu.lua")

local mem = Memory.new(4096)
local cpu = CPU.new(mem)

local prog = {
  0x00500093,
  0x02500113,
  0x002081B3,
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

print("steps: " .. steps)
print("x1 = " .. cpu:getReg(1) .. " (want 5)")
print("x2 = " .. cpu:getReg(2) .. " (want 37)")
print("x3 = " .. cpu:getReg(3) .. " (want 42)")
if cpu.trap then print("trap: " .. cpu.trap) end