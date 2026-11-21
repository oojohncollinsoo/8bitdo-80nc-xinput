#!/usr/bin/env python3
"""Build and verify 80NC V1.01 X+Home candidate. Never accesses USB."""
from pathlib import Path
import argparse
import hashlib
import random
import struct
import cryptdo8

ROOT = Path(__file__).resolve().parent
STOCK_SHA = 'b6badf8a7ecb4c2a63be78bae3b01000b9f7a43f148806c996b948533290691a'
CANDIDATE_SHA = '64de40596324ef55d66ed7bf46f36c3cd7f6d81a777ebd13b39ebc46d0e0cf51'
PLAIN_SHA = '1bf1a4aad9cb2e3c322e880c8a83cb5bf4c91a49b65f83f00dec50ec6f0422ac'
OFFSET = 0x5760
BEFORE = bytes.fromhex('014604480078002801d0012070470020fce70000')
AFTER = bytes.fromhex('c10605d403480078002800d00120704703207047')
BASE = 0x01018000

def sha(data):
    return hashlib.sha256(data).hexdigest()

def check(ok, label):
    if not ok:
        raise SystemExit('FAIL_CLOSED: '+label)

def simulate(code, mask, flag):
    # Independent small interpreter for actual replacement instruction words.
    r = [mask, 0]; pc = OFFSET; n = z = False
    for _ in range(12):
        op = struct.unpack_from('<H', code, pc)[0]
        pos = pc; pc += 2
        if op & 0xf800 == 0:
            rd, rm, shift = op & 7, (op >> 3) & 7, (op >> 6) & 31
            r[rd] = (r[rm] << shift) & 0xffffffff
            n, z = bool(r[rd] & 0x80000000), not r[rd]
        elif op & 0xff00 in (0xd400, 0xd000):
            if (n if op & 0xff00 == 0xd400 else z):
                delta = op & 255
                pc = pos + 4 + 2 * (delta if delta < 128 else delta - 256)
        elif op & 0xf800 == 0x4800:
            rd = (op >> 8) & 7
            r[rd] = struct.unpack_from('<I', code, ((pos + 4) & ~3) + 4*(op & 255))[0]
        elif op == 0x7800:
            check(r[0] == 0x20187, 'unexpected RAM address')
            r[0] = flag
        elif op == 0x2800:
            z, n = r[0] == 0, bool(r[0] & 0x80000000)
        elif op & 0xf800 == 0x2000:
            rd = (op >> 8) & 7; r[rd] = op & 255
            z, n = r[rd] == 0, False
        elif op == 0x4770:
            return r[0]
        else:
            raise SystemExit(f'Unexpected opcode {op:04x} at {pos:04x}')
    raise SystemExit('Selector did not return')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stock', type=Path, help='Your unmodified 80NC V1.01 .dat')
    parser.add_argument('output', type=Path, help='New patched .dat path (must not overwrite other files)')
    args = parser.parse_args()
    check(args.stock.resolve() != args.output.resolve(), 'input and output must differ')
    stock = args.stock.read_bytes()
    check(sha(stock) == STOCK_SHA, 'original SHA256')
    check(len(stock) == 86044, 'original size')
    check(struct.unpack('<7I',stock[:28]) == (101,BASE,0x15000,0x301a,0,0,0), 'header')
    sections = cryptdo8.parse_image(stock)
    check(len(sections) == 1, 'section count')
    cipher = cryptdo8.CIPHERS['yichip']
    p = cryptdo8.decrypt_section(stock, sections[0], cipher)
    check(sha(p) == PLAIN_SHA, 'plaintext SHA256')
    check(cryptdo8.build_section(p,cipher,101,BASE,len(p),0x301a)==stock, 'roundtrip original')
    check(p[OFFSET:OFFSET+20] == BEFORE, 'exact selector baseline')
    check(p[OFFSET+20:OFFSET+24] == bytes.fromhex('87010200'), 'literal')
    q = p[:OFFSET] + AFTER + p[OFFSET+20:]
    changed = [i for i,(a,b) in enumerate(zip(p,q)) if a!=b]
    check(all(OFFSET<=i<OFFSET+20 for i in changed), 'protected bytes')
    # Every possible low byte and every flag, plus deterministic full-width samples.
    cases = 0
    for mask in range(256):
        for flag in range(256):
            check(simulate(q,mask,flag)==(3 if mask&0x10 else int(flag!=0)), 'selector truth table')
            cases += 1
    rng = random.Random(80)
    for _ in range(10000):
        mask, flag = rng.getrandbits(32), rng.randrange(256)
        check(simulate(q,mask,flag)==(3 if mask&0x10 else int(flag!=0)), '32-bit mask')
        cases += 1
    candidate = cryptdo8.build_section(q,cipher,101,BASE,len(p),0x301a)
    check(candidate[:28]==stock[:28] and len(candidate)==len(stock), 'preserved header and size')
    check(cryptdo8.decrypt_section(candidate,sections[0],cipher)==q, 'candidate encrypt/decrypt')
    check(sha(candidate) == CANDIDATE_SHA, 'exact hardware-tested candidate SHA256')
    out = args.output
    if out.exists():
        check(out.read_bytes()==candidate, 'existing candidate differs')
    else:
        out.write_bytes(candidate)
    print(f'Original SHA256: {sha(stock)}\nCandidate SHA256: {sha(candidate)}\nPlain SHA256: {sha(q)}')
    print(f'Changed plaintext bytes: {len(changed)}; span 0x{OFFSET:x}..0x{OFFSET+19:x}')
    print(f'Selector instruction tests: {cases}/{cases} PASS')
    print('OFFLINE PASS / exact candidate previously tested on one 80NC unit only')

if __name__ == '__main__':
    main()
