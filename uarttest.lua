local Memory = dofile("/home/vm/mem.lua")
local CPU = dofile("/home/vm/cpu.lua")

local mem = Memory.new(4096)
local cpu = CPU.new(mem)

local prog = {
  0x100002B7,
  0x04800313,
  0x00628023,
  0x04900313,
  0x00628023,
  0x00A00313,
  0x00628023,
  0x00000073,
}

local addr = 0
for _, word in ipairs(prog) do
  mem:w32(addr, word)
  addr = addr + 4
end

io.write("output: ")
local steps = 0
while cpu.running and steps < 100 do
  cpu:step()
  steps = steps + 1
end
print("")
print("steps: " .. steps)
if cpu.trap then print("trap: " .. cpu.trap) end