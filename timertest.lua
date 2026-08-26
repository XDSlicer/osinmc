local Memory = dofile("/home/vm/mem.lua")
local CPU = dofile("/home/vm/cpu.lua")
local mem = Memory.new(0x1000000)
local cpu = CPU.new(mem)

cpu.csr[0x305] = 0x100
cpu.csr[0x300] = 0x8
cpu.csr[0x304] = 0x80
cpu.mtimecmp = 20

mem:w32(0x100, 0x00000073)

local fired = false
for i = 1, 50 do
  cpu:step()
  if cpu.pc == 0x100 and not fired then
    fired = true
    print("timer fired at step " .. i)
    print("mcause = " .. string.format("%08X", cpu.csr[0x342]) .. " (want 80000007)")
    break
  end
end
if not fired then print("timer NEVER fired (bug)") end
