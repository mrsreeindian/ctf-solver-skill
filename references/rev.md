# Reverse Engineering — bi0s Wiki Methodology

> Source: wiki.bi0s.in/reversing | CTF Rev Playbook

## Phase 1: Initial Static Analysis

### 1.1 File Identification
```bash
file ./chal               # architecture, format
readelf -h ./chal         # ELF header
strings -n 6 ./chal | head -60

# Interesting string categories:
# - "Correct! / Wrong / Try again" → password check
# - "Congratulations" → solution indicator
# - URL / IP addresses → C2 / flag submission
# - Flag fragment (might be XOR'd or split)
```

### 1.2 Packing / Obfuscation Check
```bash
upx -l ./chal             # UPX check
# If packed: upx -d ./chal

# Entropy check (high entropy = packed/encrypted):
# Section entropy > 7.5 → suspicious
binwalk -E ./chal         # entropy graph
```

### 1.3 Symbol Analysis
```bash
nm -n ./chal 2>/dev/null | grep " [Tt] "   # local functions
nm ./chal | grep " U "                       # imported functions

# Key imported functions to notice:
# strcmp, memcmp, strncmp → compare user input to secret
# printf with format string from user → format string vuln
# system, execve → shell execution target
```

### 1.4 Anti-Debug Check
```bash
strings ./chal | grep -iE 'ptrace|IsDebuggerPresent|RDTSC|cpuid|debugger'
objdump -d ./chal | grep -E 'ptrace|cpuid|rdtsc'
```

---

## Phase 2: Disassembly & Decompilation

### 2.1 Radare2 Workflow
```bash
r2 ./chal
> aaa              # analyze all (functions, symbols)
> afl              # list all functions
> pdf @main        # disassemble main
> pdf @sym.check_flag  # decompile specific function
> s main; V        # visual mode
> dc               # run binary
```

### 2.2 Ghidra Workflow (GUI)
1. Open binary in Ghidra → Auto-analyze
2. Navigate to `main()` in Symbol Tree
3. Use Decompiler window (right panel)
4. Rename variables for clarity (right-click → Rename)
5. Look for: conditionals on user input, XOR operations, comparison loops

### 2.3 GDB Dynamic Analysis
```bash
gdb ./chal
(gdb) info functions       # list functions
(gdb) b strcmp             # break on strcmp
(gdb) run <<< "AAAA"       # run with input
(gdb) x/s $rdi             # view first argument (expected string)
(gdb) x/s $rsi             # view second argument (user input)
```

### 2.4 ltrace / strace
```bash
# Library call trace — BEST for strcmp/memcmp challenges:
ltrace -e 'strcmp+memcmp+strncmp+strcasecmp' ./chal <<< "test_input"
# Output: strcmp("test_input", "secret_flag123") = -...
# → The second argument IS the expected password/flag

# System call trace:
strace ./chal <<< "test" 2>&1 | head -30
```

---

## Phase 3: Common Rev Patterns

### 3.1 Simple Password Compare (strcmp)
```bash
# ltrace will reveal:
# strcmp("user_input", "expected_password") = -X
# → Just provide the expected_password
```

### 3.2 Character-by-Character Check
Look for a loop like:
```c
for (int i = 0; i < 32; i++) {
    if (input[i] ^ key[i] != expected[i]) { puts("Wrong"); return; }
}
```
Reconstruct: `flag[i] = expected[i] ^ key[i]`

```python
expected = [0x41, 0x52, ...]  # from decompiled code
key      = [0x12, 0x34, ...]
flag     = bytes(a ^ b for a, b in zip(expected, key))
print(flag)
```

### 3.3 Custom VM / Bytecode Interpreter
- Look for: a large switch-case on `opcode` values
- Strategy: Trace execution, map opcodes to operations
- Tools: angr (symbolic execution) for automated solving

### 3.4 Angr Symbolic Execution (automation)
```python
import angr, claripy

proj = angr.Project('./chal', auto_load_libs=False)
flag_chars = [claripy.BVS(f'flag_{i}', 8) for i in range(32)]
flag = claripy.Concat(*flag_chars)

state = proj.factory.full_init_state(stdin=flag)
for c in flag_chars:
    state.solver.add(c >= 0x20, c <= 0x7e)  # printable ASCII

sm = proj.factory.simulation_manager(state)

# Find success state, avoid crash/exit states
GOOD_ADDR = 0xDEAD  # address of puts("Correct!")
BAD_ADDR  = 0xBEEF  # address of puts("Wrong!")
sm.explore(find=GOOD_ADDR, avoid=BAD_ADDR)

if sm.found:
    solution = sm.found[0].solver.eval(flag, cast_to=bytes)
    print(f"Flag: {solution}")
```

### 3.5 CRC / Hash-Based Check
```python
import itertools, hashlib
# If we know: sha256(flag) == HASH, flag format is flag{XXXX-XXXX}
# Brute force the unknown part:
TARGET = "KNOWN_HASH"
CHARSET = "abcdefghijklmnopqrstuvwxyz0123456789"
for combo in itertools.product(CHARSET, repeat=4):
    attempt = f"flag{{'{'}" + ''.join(combo) + "}"
    if hashlib.sha256(attempt.encode()).hexdigest() == TARGET:
        print(f"Flag: {attempt}")
        break
```

---

## Phase 4: Binary Patching

### 4.1 Patch a Jump (NOP out a check)
```bash
# In GDB:
(gdb) set *(short*)0xADDRESS = 0x9090   # NOP NOP

# In radare2:
r2 -w ./chal
(r2) s 0xADDRESS
(r2) wa nop; nop
(r2) q

# Using Python + binary struct:
with open('./chal', 'r+b') as f:
    f.seek(FILE_OFFSET)
    f.write(b'\x90\x90')  # NOP
```

### 4.2 Patch a Conditional Jump
```
je  (74) → jne (75)
jne (75) → je  (74)
jz  (74) → jnz (75)
```

---

## Useful Tools Summary

| Tool | Command | Use |
|---|---|---|
| Ghidra | GUI | Decompile, rename, annotate |
| radare2 | `r2 -A ./chal` | Disassemble, patch, scripting |
| GDB+pwndbg | `gdb ./chal` | Dynamic debugging, memory |
| ltrace | `ltrace ./chal` | Library call interception |
| strace | `strace ./chal` | Syscall tracing |
| angr | Python | Symbolic execution, auto-solve |
| upx | `upx -d ./chal` | Unpack packed binaries |
| strings | `strings -n 5 ./chal` | Quick static hints |
