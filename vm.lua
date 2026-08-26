local component = require("component")
local computer = require("computer")
local event = require("event")

local Memory = dofile("/home/vm/mem.lua")
local CPU = dofile("/home/vm/cpu.lua")

local IMAGE = "/home/vm/linux.img"
local RAM_SIZE = 0x4000000

local f = io.open(IMAGE, "rb")
if not f then
  print("no image at " .. IMAGE)
  return
end

local mem = Memory.new(RAM_SIZE)
local cpu = CPU.new(mem)
mem:setCPU(cpu)

local addr = 0x80000000
while true do
  local block = f:read(4096)
  if not block then break end
  for i = 1, #block do
    mem:w8(addr, block:byte(i))
    addr = addr + 1
  end
end
f:close()

cpu.x[10] = 0
cpu.x[11] = RAM_SIZE - 0x1000
cpu.pc = 0x80000000

print("booting...")

local INSTR_PER_FLIP = 1024
local running = true

while cpu.running and running do
  cpu:tick(INSTR_PER_FLIP)
  for i = 1, INSTR_PER_FLIP do
    cpu:step()
    if not cpu.running then break end
  end
  if mem.syscon == 0x5555 then
    print("\n[poweroff]")
    running = false
  end
  local ev, _, ch = event.pull(0)
  if ev == "key_down" and ch and ch > 0 then
    mem:pushChar(ch)
  end
  if computer.freeMemory() < 20000 then
    os.sleep(0)
  end
end
