import os
import io
import wave
import torch
import numpy as np
import whisper
import time
from typing import Optional

class WhisperSTT:
    """
    Wrapper for OpenAI Whisper to provide local speech-to-text capability.
    Loads the 'base' model by default for a balance of speed and accuracy.
    """
    def __init__(self, model_size: str = "base", device: Optional[str] = None):
        self.model_size = model_size
        if device is None:
            self.device = "cuda" if torch.cuda.is_available() else "cpu"
        else:
            self.device = device
            
        print(f"[WHISPER] Initializing on {self.device} (size={model_size})...")
        
        # Determine cache directory (ensure it matches download_models.py)
        # Components dir is repo_root/components
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
        self.cache_dir = os.path.join(repo_root, "model_cache")
        os.makedirs(self.cache_dir, exist_ok=True)
        
        try:
            # Load model (base is ~72MB)
            self.model = whisper.load_model(model_size, device=self.device, download_root=self.cache_dir)
            print(f"[WHISPER] ✓ Model loaded successfully.")
        except Exception as e:
            print(f"[WHISPER] ✗ Failed to load model: {e}")
            self.model = None

    def transcribe(self, audio_data: np.ndarray, sample_rate: int = 16000) -> str:
        """
        Transcribe a chunk of audio data (numpy array).
        Whisper expects 16kHz float32 mono.
        """
        if self.model is None:
            return ""
            
        try:
            # Ensure audio is float32 and normalized between -1 and 1
            if audio_data.dtype != np.float32:
                audio_data = audio_data.astype(np.float32)
            
            # If mono [N, 1] or [N], flatten to [N]
            if audio_data.ndim > 1:
                audio_data = audio_data.flatten()
                
            # Perform transcription
            # fp16=False to avoid warnings on CPU
            result = self.model.transcribe(
                audio_data, 
                fp16=(self.device == "cuda"),
                language=None # Auto-detect language
            )
            
            text = result.get("text", "").strip()
            return text
        except Exception as e:
            print(f"[WHISPER] Transcription error: {e}")
            return ""

if __name__ == "__main__":
    # Quick test
    detector = WhisperSTT()
    # Dummy silent audio
    dummy_audio = np.zeros(16000 * 2, dtype=np.float32)
    print(f"Test transcription: '{detector.transcribe(dummy_audio)}'")
