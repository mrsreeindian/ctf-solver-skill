# Cryptography — bi0s Wiki Methodology

> Source: wiki.bi0s.in/crypto | CTF Crypto Playbook

## Step 1: Identify the Cryptosystem

Look for these patterns in challenge files/descriptions:

| Clue | Likely Cryptosystem |
|---|---|
| `n, e, c` (large numbers) | RSA |
| `p, q` (primes) + `n` | RSA with weak key |
| Block of hex / base64, fixed length | AES / block cipher |
| Keystream XOR'd with plaintext | Stream cipher / OTP |
| Letters shifted by fixed amount | Caesar / ROT |
| Substitution table given | Substitution cipher |
| Two ciphertexts, same key | Two-time pad (XOR) |
| Padded output, oracle available | Padding oracle |
| `c = m^e mod n`, many ciphertexts same e | Common broadcast attack |

---

## Phase A: Classical Ciphers

### A1. Caesar / ROT
```python
for shift in range(26):
    dec = ''.join(chr((ord(c) - 65 + shift) % 26 + 65) if c.isupper()
                  else chr((ord(c) - 97 + shift) % 26 + 97) if c.islower()
                  else c for c in ciphertext)
    if 'flag' in dec.lower(): print(f"ROT{shift}: {dec}")
```

### A2. Frequency Analysis (Substitution / Vigenere)
- Use quipqiup.com for automatic substitution solving
- Measure Index of Coincidence for Vigenere key length:
```python
def ic(text):
    text = [c.upper() for c in text if c.isalpha()]
    n = len(text)
    from collections import Counter
    return sum(v*(v-1) for v in Counter(text).values()) / (n*(n-1))
# IC ~0.065 → monoalphabetic; ~0.038 → polyalphabetic (Vigenere)
```

### A3. Vigenere Kasiski + Friedman
```python
# Find repeating sequences → GCD of distances → key length
from math import gcd
from functools import reduce
# Then use frequency analysis on each nth character
```

---

## Phase B: RSA Attacks

### B1. Quick Check: Factor n
```bash
# Small n (< 512 bits): try factordb.com
# Or local: factor $(python3 -c "print(N)")

# Automated:
RsaCtfTool --publickey key.pem --attack all --uncipherfile cipher.txt
RsaCtfTool -n N -e E -c C --attack all
```

### B2. Small e (e=3) — Low Public Exponent
```python
from gmpy2 import iroot
m, is_perfect = iroot(c, e)    # If m^e < n, c = m^e exactly
if is_perfect:
    print(long_to_bytes(m))
```

### B3. Common Modulus Attack
```python
# Given: c1 = m^e1 mod n, c2 = m^e2 mod n, gcd(e1,e2) = 1
from math import gcd
from Crypto.Util.number import long_to_bytes
def egcd(a, b):
    if b == 0: return a, 1, 0
    g, x, y = egcd(b, a % b)
    return g, y, x - (a // b) * y

g, s1, s2 = egcd(e1, e2)
if g != 1: raise ValueError("gcd(e1,e2) != 1")
m = (pow(c1, s1, n) * pow(c2, s2, n)) % n
print(long_to_bytes(m))
```

### B4. Wiener's Attack (large d, e > n^0.25)
```bash
RsaCtfTool -n N -e E --attack wiener
```

### B5. Known p & q
```python
from Crypto.Util.number import inverse, long_to_bytes
phi = (p - 1) * (q - 1)
d = inverse(e, phi)
m = pow(c, d, n)
print(long_to_bytes(m))
```

### B6. p ≈ q (Fermat Factorization)
```python
from gmpy2 import isqrt, is_perfect_power
a = isqrt(n) + 1
b2 = a * a - n
while not isqrt(b2) ** 2 == b2:
    a += 1; b2 = a * a - n
p, q = a - isqrt(b2), a + isqrt(b2)
```

---

## Phase C: AES / Block Ciphers

### C1. ECB Mode (No IV, identical blocks → identical ciphertext)
```python
# Detect ECB:
blocks = [ct[i:i+16] for i in range(0, len(ct), 16)]
if len(blocks) != len(set(blocks)):
    print("ECB detected!")

# ECB cut-and-paste: rearrange ciphertext blocks
# ECB byte-at-a-time: encrypt(attacker_prefix + unknown_byte)
```

### C2. CBC Bit-Flip Attack
```python
# Flip bit in ciphertext block i → flips corresponding bit in plaintext block i+1
# Useful to change '|user=alice|' to '|user=admin|'
ct = bytearray(ct)
ct[BLOCK_OFFSET + BYTE_OFFSET] ^= ord('a') ^ ord('a')  # flip to target value
```

### C3. Padding Oracle Attack
```bash
# Use padbuster or write custom oracle:
# If server returns different error for bad padding vs bad MAC → vulnerable
python3 paddingoracle_exploit.py  # custom script
# Or: pip install paddingoracle; python3 -m paddingoracle
```

### C4. Two-Time Pad (XOR with same key)
```python
# XOR both ciphertexts: c1 XOR c2 = m1 XOR m2
# Crib-drag to recover key/plaintext
xored = bytes(a ^ b for a, b in zip(c1, c2))
# Known plaintext fragment: if we know part of m1, recover m2
```

---

## Phase D: Hash Cracking

```bash
# MD5
hashcat -m 0 hash.txt /usr/share/wordlists/rockyou.txt

# SHA256
hashcat -m 1400 hash.txt /usr/share/wordlists/rockyou.txt

# bcrypt
hashcat -m 3200 hash.txt /usr/share/wordlists/rockyou.txt

# John
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
john --format=raw-md5 hash.txt

# Online: https://crackstation.net  |  https://hashes.com
```

---

## Phase E: Z3 / Constraint Solving

```python
from z3 import *
x, y = Ints('x y')
s = Solver()
s.add(x + y == 100)
s.add(x * y == 2400)
if s.check() == sat:
    print(s.model())
```

Use when: binary does mathematical checks on flag bytes (common in Rev too)

---

## Useful Resources
- `https://cyberchef.org` — encode/decode/analyze anything
- `https://factordb.com` — factor n online
- `https://quipqiup.com` — substitution cipher solver
- `https://libc.rip` — not for crypto, but useful reference
- SageMath: `sage -c "print(factor(N))"`
