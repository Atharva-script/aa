"""
verify_audio_signals.py
=======================
Standalone diagnostic script to confirm that audio loopback capture is
working correctly BEFORE starting the full backend.

Usage:
  1. Play any video/music on this PC.
  2. Run:  python verify_audio_signals.py
  3. Watch the amplitude readings. They should be > 0.001 if audio is flowing.

If Loopback amplitude stays at 0.0000, open Windows Sound Settings and ensure
"Stereo Mix" is ENABLED under Recording Devices.
"""

import sys
import time
import numpy as np

SAMPLE_RATE = 16000
TEST_DURATION = 3.0   # seconds per round
ROUNDS = 3

def _color(val):
    """Returns a colored OK/SILENT tag."""
    if val > 0.01:   return f"\033[92m{val:.5f}  [SIGNAL OK]\033[0m"
    elif val > 0.001: return f"\033[93m{val:.5f}  [WEAK]\033[0m"
    else:             return f"\033[91m{val:.5f}  [SILENT]\033[0m"

# ------------------------------------------------------------------
# 1. List all sound devices (sounddevice)
# ------------------------------------------------------------------
print("\n" + "="*60)
print("  CYBER OWL - Audio Signal Verifier")
print("="*60)

try:
    import sounddevice as sd
    devices = sd.query_devices()
    print("\n[sounddevice] All INPUT-capable devices:")
    for i, d in enumerate(devices):
        if d['max_input_channels'] > 0:
            tag = ""
            name = d['name'].lower()
            if 'stereo mix' in name or 'what u hear' in name or 'wave' in name:
                tag = "  <-- STEREO MIX / LOOPBACK"
            elif 'microphone' in name or 'mic' in name:
                tag = "  <-- MICROPHONE"
            print(f"  [{i:2d}] {d['name']}{tag}")
except ImportError:
    print("[ERROR] sounddevice not installed. Run: pip install sounddevice")
    sys.exit(1)

print()

# ------------------------------------------------------------------
# 2. Try sounddevice loopback (Stereo Mix first)
# ------------------------------------------------------------------
loopback_idx = None
loopback_name = None

for i, d in enumerate(devices):
    name = d['name'].lower()
    if d['max_input_channels'] > 0 and \
       ('stereo mix' in name or 'what u hear' in name or 'wave out mix' in name):
        loopback_idx = i
        loopback_name = d['name']
        break

if loopback_idx is not None:
    print(f"[LOOPBACK] Testing Stereo Mix: [{loopback_idx}] {loopback_name}")
    print(f"  Recording {TEST_DURATION:.0f}s chunks for {ROUNDS} rounds...\n")
    for r in range(1, ROUNDS + 1):
        buf = []
        def _cb(indata, frames, t, status):
            buf.append(indata.copy())
        try:
            with sd.InputStream(device=loopback_idx, channels=1,
                                samplerate=SAMPLE_RATE,
                                blocksize=int(SAMPLE_RATE * 0.2),
                                callback=_cb):
                time.sleep(TEST_DURATION)
            if buf:
                arr = np.concatenate(buf, axis=0)
                amp = float(np.abs(arr).max())
            else:
                amp = 0.0
            print(f"  Round {r}: Loopback MAX amplitude = {_color(amp)}")
        except Exception as e:
            print(f"  Round {r}: [ERROR] {e}")
else:
    print("[LOOPBACK] No Stereo Mix device found via sounddevice.")
    print("  >>> Please enable 'Stereo Mix' in Windows Sound -> Recording tab <<<\n")

# ------------------------------------------------------------------
# 3. Try soundcard default speaker loopback as secondary check
# ------------------------------------------------------------------
print()
try:
    import soundcard as sc
    spk = sc.default_speaker()
    print(f"[SOUNDCARD] Testing default speaker loopback: {spk.name}")
    for r in range(1, ROUNDS + 1):
        try:
            lb = sc.get_microphone(id=spk.id, include_loopback=True)
            with lb.recorder(samplerate=SAMPLE_RATE) as rec:
                data = rec.record(numframes=int(SAMPLE_RATE * TEST_DURATION))
            amp = float(np.abs(data).max())
            print(f"  Round {r}: Soundcard MAX amplitude = {_color(amp)}")
        except Exception as e:
            print(f"  Round {r}: [ERROR] {e}")
except ImportError:
    print("[SOUNDCARD] soundcard not installed. Skipping.")
except Exception as e:
    print(f"[SOUNDCARD] Failed: {e}")

# ------------------------------------------------------------------
# 4. Summary
# ------------------------------------------------------------------
print()
print("="*60)
print("  SUMMARY")
print("="*60)
print("  If Loopback amplitude > 0.001 while audio plays: system READY")
print("  If amplitude = 0.0000 always: Stereo Mix is disabled or muted")
print("  Fix: Open Sound Settings -> Recording -> Enable 'Stereo Mix'")
print("       Right-click Stereo Mix -> Properties -> Levels -> raise volume")
print("="*60 + "\n")
