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

io.write("loading image...")
local addr = 0x80000000
local loaded = 0
while true do
  local block = f:read(8192)
  if not block then break end
  for i = 1, #block do
    mem:w8(addr, block:byte(i))
    addr = addr + 1
  end
  loaded = loaded + #block
end
f:close()
print(" " .. loaded .. " bytes")

cpu.x[10] = 0
cpu.x[11] = 0
cpu.pc = 0x80000000

print("booting...")

local INSTR_PER_FLIP = 1024

while cpu.running do
  cpu:tick(INSTR_PER_FLIP)
  for i = 1, INSTR_PER_FLIP do
    cpu:step()
    if not cpu.running then break end
  end
  if mem.syscon == 0x5555 then
    print("\n[poweroff]")
    break
  end
  local ev, _, ch = event.pull(0)
  if ev == "key_down" and ch and ch > 0 then
    mem:pushChar(ch)
  end
  if ev == "interrupted" then
    print("\n[stopped]")
    break
  end
end
