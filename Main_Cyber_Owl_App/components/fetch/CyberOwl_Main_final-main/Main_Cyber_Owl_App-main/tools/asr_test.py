import re
import os
import sys
import tempfile
import wave
import json
import time
import numpy as np

root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
main_path = os.path.join(root, 'mainapp.py')
test8_path = os.path.join(root, 'components', 'test8.py')

def extract_constant(path, name):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            txt = f.read()
        m = re.search(rf"^{name}\s*=\s*(.+)$", txt, flags=re.MULTILINE)
        if m:
            return m.group(1).strip().strip('"\'\'')
    except Exception as e:
        return None

print('Workspace root:', root)
cs = extract_constant(test8_path, 'CHUNK_SECONDS')
acs = extract_constant(main_path, 'AUDIO_CHUNK_SECONDS')
print('CHUNK_SECONDS (components/test8.py):', cs)
print('AUDIO_CHUNK_SECONDS (mainapp.py):', acs)

# build a 1s 16kHz sine wave
sr = 16000
dur = 1.0
t = np.linspace(0, dur, int(sr*dur), endpoint=False)
# low amplitude speech-like tone
x = 0.1 * np.sin(2*np.pi*220*t)
pcm = (x * 32767).astype(np.int16)
fd, tmpwav = tempfile.mkstemp(suffix='.wav')
os.close(fd)
with wave.open(tmpwav, 'wb') as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(sr)
    wf.writeframes(pcm.tobytes())
print('WAV written to', tmpwav)

# VOSK removed: skip local VOSK recognition test
vosk_ok = False
print('VOSK support disabled; skipping recognition test')

# cleanup
try:
    os.remove(tmpwav)
except:
    pass

print('Test complete')
