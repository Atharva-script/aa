import warnings
import webrtcvad
import soundcard as sc
import numpy as np
import whisper
import wave
import tempfile
import time
from soundcard import SoundcardRuntimeWarning

# ===============================
# SUPPRESS SOUND WARNINGS
# ===============================
warnings.filterwarnings("ignore", category=SoundcardRuntimeWarning)

# ===============================
# CONFIG
# ===============================
SAMPLE_RATE = 16000
FRAME_MS = 20
FRAME_SAMPLES = int(SAMPLE_RATE * FRAME_MS / 1000)
FRAME_BYTES = FRAME_SAMPLES * 2
MAX_SILENCE_FRAMES = 20
VAD_MODE = 2

# ===============================
# LOAD WHISPER
# ===============================
print("⏳ Loading Whisper...")
whisper_model = whisper.load_model("small", device="cpu")
print("✅ Whisper loaded")

vad = webrtcvad.Vad(VAD_MODE)

# ===============================
# HELPERS
# ===============================
def float_to_pcm16(audio):
    audio = np.clip(audio, -1.0, 1.0)
    return (audio * 32767).astype(np.int16).tobytes()

def save_wav(pcm_bytes):
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    with wave.open(tmp.name, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm_bytes)
    return tmp.name

# ===============================
# MAIN
# ===============================
def main():
    speaker = sc.default_speaker()
    mic = sc.get_microphone(id=speaker.id, include_loopback=True)

    speech_frames = []
    silence_count = 0
    speaking = False

    print("\n🎧 REAL-TIME VOICE ACTIVITY + TRANSLATION STARTED")
    print("🟢 SPEECH | ⚪ SILENCE")
    print("🌍 Auto-translate to English")
    print("🛑 Ctrl+C to stop\n")

    try:
        with mic.recorder(samplerate=SAMPLE_RATE, channels=1) as recorder:
            while True:
                audio = recorder.record(FRAME_SAMPLES)

                if audio.ndim > 1:
                    audio = audio[:, 0]

                if len(audio) != FRAME_SAMPLES:
                    continue

                pcm = float_to_pcm16(audio)
                if len(pcm) != FRAME_BYTES:
                    continue

                is_speech = vad.is_speech(pcm, SAMPLE_RATE)

                if is_speech:
                    if not speaking:
                        print("🟢 SPEECH START")
                        speaking = True
                        speech_frames = []

                    speech_frames.append(pcm)
                    silence_count = 0

                else:
                    if speaking:
                        silence_count += 1
                        if silence_count >= MAX_SILENCE_FRAMES:
                            print("⚪ SPEECH END → Processing")
                            speaking = False
                            silence_count = 0

                            audio_bytes = b"".join(speech_frames)
                            wav_path = save_wav(audio_bytes)

                            # ===============================
                            # WHISPER TRANSCRIBE + TRANSLATE
                            # ===============================
                            result = whisper_model.transcribe(
                                wav_path,
                                task="translate",   # 🔥 TRANSLATION ENABLED
                                language=None,
                                fp16=False
                            )

                            translated_text = result.get("text", "").strip()

                            if translated_text:
                                print("\n🗣️ Translated Text (English):")
                                print(translated_text)
                                print()

                time.sleep(0.002)

    except KeyboardInterrupt:
        print("\n👋 VAD stopped")

# ===============================
if __name__ == "__main__":
    main()