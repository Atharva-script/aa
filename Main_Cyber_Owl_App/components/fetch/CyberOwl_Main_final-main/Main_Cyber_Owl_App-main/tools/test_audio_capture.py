#!/usr/bin/env python3
"""
Test script to verify mainapp-style audio transcription and bullying detection.

Usage:
  python tools/test_audio_capture.py path/to/sample_with_bully_words.wav

The script:
- Loads the provided audio file with pydub
- Converts it to a 16 kHz mono WAV in-memory
- Uses SpeechRecognition (`recognize_google`) to transcribe
- Runs `components.test8.predict_toxicity` on the transcript (if available)

This replicates the transcription + detection pipeline used in `mainapp.py`.
"""

import sys
import io
import os

from pydub import AudioSegment
import speech_recognition as sr

try:
    from components.test8 import predict_toxicity as test8_predict
    TEST8_AVAILABLE = True
except Exception:
    TEST8_AVAILABLE = False


SAMPLE_RATE = 16000


def transcribe_file(path, sample_rate=SAMPLE_RATE):
    # Load via pydub (supports many formats)
    audio = AudioSegment.from_file(path)
    # Ensure correct sample rate / channels / width to match mainapp expectations
    audio = audio.set_frame_rate(sample_rate).set_channels(1).set_sample_width(2)

    # Export WAV into BytesIO
    buf = io.BytesIO()
    audio.export(buf, format='wav')
    buf.seek(0)

    r = sr.Recognizer()
    with sr.AudioFile(buf) as source:
        audio_data = r.record(source)

    try:
        transcript = r.recognize_google(audio_data)
    except Exception as e:
        transcript = f"[ASR Error: {e}]"
    return transcript


def main():
    if len(sys.argv) < 2:
        print("Usage: python tools/test_audio_capture.py <audio-file>")
        sys.exit(1)

    audio_path = sys.argv[1]
    if not os.path.exists(audio_path):
        print(f"Audio file not found: {audio_path}")
        sys.exit(1)

    print(f"Transcribing: {audio_path}")
    transcript = transcribe_file(audio_path)
    print("\n--- Transcript ---")
    print(transcript)
    print("--- End Transcript ---\n")

    if TEST8_AVAILABLE:
        try:
            res = test8_predict(transcript)
            print("components.test8.predict_toxicity returned:")
            print(res)
        except Exception as e:
            print("components.test8.predict_toxicity raised:", e)
    else:
        print("components.test8 not available in this environment.")


if __name__ == '__main__':
    main()
