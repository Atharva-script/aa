import sounddevice as sd
import soundcard as sc

print("--- SOUNDDEVICE DEVICES ---")
devices = sd.query_devices()
for i, d in enumerate(devices):
    print(f"[{i}] {d['name']} (Inputs: {d['max_input_channels']}, Outputs: {d['max_output_channels']})")

print("\n--- SOUNDCARD SPEAKERS ---")
speakers = sc.all_speakers()
for i, s in enumerate(speakers):
    print(f"[{i}] {s.name}")

print("\n--- SOUNDCARD MICROPHONES ---")
mics = sc.all_microphones()
for i, m in enumerate(mics):
    print(f"[{i}] {m.name}")
