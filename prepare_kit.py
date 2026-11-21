#!/usr/bin/env python3
"""Create a local test kit from the user's official updater ZIP and stock DAT."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent
STOCK = 'b6badf8a7ecb4c2a63be78bae3b01000b9f7a43f148806c996b948533290691a'
EXPECTED = {
    '8BitDo Firmware Updater.exe': '5880c67c092f6d6e658f5a3a10c87dd42a439d561de75384599befe7b905916c',
    '8BitDoFirmwareUpdaterTools.dll': 'b38ffa61b12af29d41dc55212e5ba44e509130facf6e3c4db9a7141aa313f974',
    'J2i.Net.XInputWrapper.dll': '96fd1b4ec4d3d2907e92220413b59e7b14af263976cc222b407c589ec289d08b',
    'data/Autoupdate.exe': '6ae8ceb83b42e590a5c920d03fe227841a817bdf671b1fe81f902f405d6b01c5',
    'data/ICSharpCode.SharpZipLib.dll': '8ac42e07dfc4f53bbcfc9d34bd170ab7278a724cfdfb14d87aa8979542d0affa',
    'data/versions.txt': 'ca3c9abacd39bbd9b5116e39cb38c500083f814406268ccd1cd40ffafc3825a6',
}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('updater', type=Path)
    p.add_argument('stock', type=Path)
    p.add_argument('output', type=Path)
    a = p.parse_args()
    if a.output.exists():
        sys.exit('FAIL_CLOSED: output directory must not exist')
    stock = a.stock.read_bytes()
    if len(stock) != 86044 or sha(stock) != STOCK:
        sys.exit('FAIL_CLOSED: unexpected stock firmware')
    files = {}
    with zipfile.ZipFile(a.updater) as z:
        for name, expected in EXPECTED.items():
            if z.namelist().count(name) != 1:
                sys.exit('FAIL_CLOSED: missing or ambiguous updater file: ' + name)
            data = z.read(name)
            if sha(data) != expected:
                sys.exit('FAIL_CLOSED: unsupported updater version: ' + name)
            files[name] = data
    a.output.mkdir(parents=True, exist_ok=False)
    fw = a.output/'Firmware'
    fw.mkdir()
    original = fw/'80NC_V101_ORIGINAL.dat'
    original.write_bytes(stock)
    subprocess.run([sys.executable, str(ROOT/'build_patch.py'), str(original), str(fw/'80NC_V101_XINPUT_EXPERIMENTAL.dat')], check=True)
    for name, data in files.items():
        dest = a.output/'Updater'/name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
    cache = a.output/'Updater'/'updateFile'
    cache.mkdir()
    (cache/'b1e151e4-c14b-4ae4-80ce-f64d23457a0d.dat').write_bytes(stock)
    for file in (ROOT/'flash').iterdir():
        if file.is_file():
            shutil.copyfile(file, a.output/file.name)
    shutil.copyfile(ROOT/'README.md', a.output/'README.md')
    print('Local kit created:', a.output)
    print('WARNING: tested on ONE physical 80NC unit only. Read README before flashing.')

if __name__ == '__main__':
    main()
