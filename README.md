# 8BitDo Ultimate 2C Bluetooth (80NC) — native XInput firmware patch

**v0.1.0 — experimental; hardware validation on ONE specific physical controller only.**

This project enables the dormant Xbox Bluetooth and USB XInput mode in the stock firmware of a single tested 8BitDo Ultimate 2C Bluetooth controller. It does not install a Windows virtual controller or require DS4Windows or Steam Input. It does **not** support Xbox One or Series consoles.

> **Important:** The working result was verified exclusively on the project author's own physical 80NC unit, with the exact original firmware listed below. It has NOT been tested on any other unit, hardware revision, firmware version, or model. Even another 80NC with the same product name is not guaranteed to work. Flash at your own risk; recovery is not guaranteed.

## What was actually verified

| Test | Result on that single unit |
| --- | --- |
| Product label | Ultimate 2C Bluetooth, model 80NC |
| Factory firmware | V1.01, 2025-07-24, type 108 |
| Bootloader USB / internal PID | `2DC8:3208` / `301A` |
| Original firmware reinstall | PASS |
| Patched flash + updater inspection | PASS |
| Bluetooth identity | `045E:02E0` |
| Windows `XInputGetState`, slot 0 | PASS, return code 0 |
| USB Xbox mode (`045E:028E`) | PASS, Windows native XInput, slot 0; Bluetooth disabled |
| USB input sampling | PASS: 55 changed samples; ABXY, D-pad, LB/RB, Menu/View, digital LT/RT, both sticks |
| Stick clicks, Guide and vibration | Not comprehensively tested |
| Xbox One S console via USB | FAIL: not recognized; controller LED illuminated |
| Other devices or firmware revisions | **Not tested** |

The physical X button is the one at the top of the Switch-layout face buttons. Hold it before pressing Home on a fully powered-off controller to request mode 3. Home without X preserves the original mode selector. For USB, hold X through cable connection. Full physical validation of all controls and vibration is still pending. The digital triggers cannot become analog through this patch.

## Build locally (no proprietary binaries in this repo)

You need Python 3 and your own official 8BitDo Firmware Updater 2.52 ZIP and original `.dat`. Obtain the updater from [8BitDo support](https://support.8bitdo.com/firmware-updater.html). The correct original was obtained by an official reinstall on the tested device, from `updateFile/b1e151e4-c14b-4ae4-80ce-f64d23457a0d.dat`. Do not use the Wireless, Wired or 2.4 GHz model's firmware.

Original firmware SHA-256:

```
b6badf8a7ecb4c2a63be78bae3b01000b9f7a43f148806c996b948533290691a
```

Generate the exact tested candidate without touching hardware:

```powershell
python build_patch.py original.dat patched.dat
```

Expected candidate SHA-256:

```
64de40596324ef55d66ed7bf46f36c3cd7f6d81a777ebd13b39ebc46d0e0cf51
```

The script refuses an unknown input, verifies the exact header and original selector, checks encrypt/decrypt roundtrip, and runs 75,536 selector cases. No firmware binary is redistributed here.

## Optional Windows test kit

**Read the warning first.** The local launcher only supports the exact verified updater binaries. It stops at a SHA-256 mismatch. The updater is not modified. Cache reuse is specific to this updater version; if the server changes its filename, the expected patched upload may not happen. Do not try a different model or force an unsupported firmware.

```powershell
python prepare_kit.py 8BitDo_Firmware_Updater_Win.zip original.dat test-kit
```

1. Close other controller software and disconnect other controllers.
2. Enter the 80NC bootloader (hold L+R while connecting USB on the tested unit).
3. Run `test-kit\TESTAR_XINPUT.bat`. The script queries the internal PID before staging the cache. Only proceed if it reports `301A` and you accept the risk.
4. Select the exact same firmware entry in the official updater: type 108, V1.01 dated 2025-07-24. Cancel if the display or model differs. Do not update the updater itself.
5. Wait for **Update complete** before disconnecting or closing. Close the updater to collect logs.
6. Power the controller off, hold the top physical X and press Home. Pair over Bluetooth and test Windows XInput with the script below. If necessary remove the previous pairing.

With DS4Windows, Steam and other controller tools closed, disconnect other controllers and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test-kit\TEST_XINPUT.ps1
```

The hardware-tested Bluetooth result was `045E:02E0` and `XINPUT NATIVO PASS - Controle 0`. A successful slot alone does not prove that every button or axis works.

To restore the original, use `test-kit\RESTAURAR_ORIGINAL.bat` if the bootloader remains accessible. The local cache is reset after the launcher's run; that alone does not restore the controller's flash.

## Design

The stock image contains mode-3 USB and Bluetooth routines. This patch changes 19 plaintext bytes in one 20-byte boot-mode selector span (`0x5760..0x5773`, flash address `0x0101D760`), preserving the remaining payload, header, version, size and PID. It reuses the existing mode-3 implementations rather than injecting a new protocol stack. The stock image base is `0x01018000`, section length `0x15000`.

The native XInput result on the one tested unit is reproducible from the verified source image. The project is experimental and independent of 8BitDo or Microsoft; product names identify compatibility only. No vendor firmware, application binaries, personal logs or device serial numbers are published.

## Credits

Encryption/decryption uses [8CryptDo v2.0](https://github.com/aeromodes/8cryptdo) by AeroModes, MIT, bundled unmodified with its license. Thanks to the upstream author. Project source is MIT; this does not confer rights to redistribute vendor software.

---

## Português (Brasil)

**A versão funcional foi testada exclusivamente no controle físico do autor (uma única unidade 80NC), firmware V1.01 de 24/07/2025, tipo 108 e PID interno 301A.** Nenhum outro exemplar, revisão ou modelo foi validado. O modo Xbox Bluetooth apareceu como `045E:02E0` e retornou sucesso na API XInput do Windows. Por USB, `045E:028E` também retornou sucesso no Windows, com Bluetooth desligado; o log registrou 55 mudanças de estado nos botões, gatilhos e analógicos. Cliques dos sticks, Home, vibração e jogos ainda precisam de testes completos. O Xbox One S **não reconheceu** o controle por USB. Não há garantia de compatibilidade nem de recuperação; a instalação é por conta e risco do usuário.
