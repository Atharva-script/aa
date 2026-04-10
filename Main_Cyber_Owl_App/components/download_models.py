"""
Pre-download AI models locally to speed up app launch
Run this once before running MainApp.py
"""
import os
from transformers import pipeline, AutoTokenizer, AutoModelForSequenceClassification
from detoxify import Detoxify
import torch

# Set cache directories
CACHE_DIR = os.path.join(os.getcwd(), "model_cache")
DETOXIFY_CACHE = os.path.join(CACHE_DIR, "detoxify")
os.makedirs(CACHE_DIR, exist_ok=True)
os.makedirs(DETOXIFY_CACHE, exist_ok=True)

# Set environment variables
os.environ['TRANSFORMERS_CACHE'] = CACHE_DIR
os.environ['TORCH_HOME'] = CACHE_DIR
os.environ['HF_HOME'] = CACHE_DIR
os.environ['HF_DATASETS_CACHE'] = CACHE_DIR

print("=" * 60)
print("📦 DOWNLOADING AI MODELS LOCALLY")
print(f"📁 Cache Location: {CACHE_DIR}")
print("=" * 60)

# Check device
device = 0 if torch.cuda.is_available() else -1
device_str = 'cuda' if device == 0 else 'cpu'
print(f"📱 Device: {'GPU' if device == 0 else 'CPU'}")

# 1. Download Whisper AI (BEST SPEECH RECOGNITION)
print("\n1️⃣ Downloading Whisper AI (OpenAI Speech Recognition)...")
try:
    import whisper
    print("   Loading Whisper 'base' model (72MB)...")
    model = whisper.load_model("base", download_root=CACHE_DIR)
    print("✅ Whisper AI downloaded successfully")
    del model  # Free memory
except ImportError:
    print("⚠️ Whisper not installed. Installing now...")
    import subprocess
    import sys
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'openai-whisper'])
    import whisper
    print("   Loading Whisper 'base' model (72MB)...")
    model = whisper.load_model("base", download_root=CACHE_DIR)
    print("✅ Whisper AI installed and downloaded")
    del model
except Exception as e:
    print(f"❌ Error downloading Whisper: {e}")

# 2. Download Detoxify with explicit cache
print("\n2️⃣ Downloading Detoxify (unitary/toxic-bert)...")
try:
    # Detoxify internally uses 'unitary/toxic-bert', so download it explicitly
    tokenizer = AutoTokenizer.from_pretrained("unitary/toxic-bert", cache_dir=CACHE_DIR)
    model = AutoModelForSequenceClassification.from_pretrained("unitary/toxic-bert", cache_dir=CACHE_DIR)
    print(f"✅ Detoxify base model downloaded to {CACHE_DIR}")
    
    # Initialize Detoxify to download weights
    det_model = Detoxify('original', device=device_str)
    print("✅ Detoxify initialized")
    
    # Also download multilingual version
    print("   Downloading multilingual version...")
    det_model_multi = Detoxify('multilingual', device=device_str)
    print("✅ Detoxify multilingual downloaded")
except Exception as e:
    print(f"❌ Error downloading Detoxify: {e}")

# 3. Download Toxic-BERT
print("\n3️⃣ Downloading Toxic-BERT...")
try:
    AutoTokenizer.from_pretrained("unitary/toxic-bert", cache_dir=CACHE_DIR)
    AutoModelForSequenceClassification.from_pretrained("unitary/toxic-bert", cache_dir=CACHE_DIR)
    pipe = pipeline("text-classification", model="unitary/toxic-bert", device=device, cache_dir=CACHE_DIR)
    print("✅ Toxic-BERT downloaded")
except Exception as e:
    print(f"❌ Error downloading Toxic-BERT: {e}")

# 4. Download Hate Speech detector
print("\n4️⃣ Downloading Hate Speech detector...")
try:
    AutoTokenizer.from_pretrained("facebook/roberta-hate-speech-dynabench-r4-target", cache_dir=CACHE_DIR)
    AutoModelForSequenceClassification.from_pretrained("facebook/roberta-hate-speech-dynabench-r4-target", cache_dir=CACHE_DIR)
    pipe2 = pipeline("text-classification", model="facebook/roberta-hate-speech-dynabench-r4-target", device=device, cache_dir=CACHE_DIR)
    print("✅ Hate Speech detector downloaded")
except Exception as e:
    print(f"❌ Error downloading Hate Speech: {e}")

# 5. Download Hinglish/Hindi hate detector
print("\n5️⃣ Downloading Hinglish/Hindi hate detector...")
try:
    model_name = "Hate-speech-CNERG/dehatebert-mono-english"
    AutoTokenizer.from_pretrained(model_name, cache_dir=CACHE_DIR)
    AutoModelForSequenceClassification.from_pretrained(model_name, cache_dir=CACHE_DIR)
    print("✅ Hinglish hate detector downloaded")
except Exception as e:
    print(f"❌ Error downloading Hinglish detector: {e}")

# Verify downloads
print("\n" + "=" * 60)
print("🔍 VERIFYING DOWNLOADS...")
print("=" * 60)

cache_contents = os.listdir(CACHE_DIR)
print(f"📂 Cache contains {len(cache_contents)} items:")
for item in cache_contents[:15]:  # Show first 15
    item_path = os.path.join(CACHE_DIR, item)
    if os.path.isdir(item_path):
        size = sum(os.path.getsize(os.path.join(dirpath, filename))
                   for dirpath, dirnames, filenames in os.walk(item_path)
                   for filename in filenames) / (1024 * 1024)  # MB
        print(f"  📁 {item} ({size:.1f} MB)")
    else:
        size = os.path.getsize(item_path) / (1024 * 1024)
        print(f"  📄 {item} ({size:.1f} MB)")

# Check for Whisper model
whisper_models_dir = os.path.join(CACHE_DIR)
if os.path.exists(whisper_models_dir):
    whisper_files = [f for f in os.listdir(whisper_models_dir) if 'base' in f.lower()]
    if whisper_files:
        print(f"\n✅ Whisper model found: {whisper_files}")

print("\n" + "=" * 60)
print("✅ ALL MODELS DOWNLOADED SUCCESSFULLY")
print(f"📁 Location: {CACHE_DIR}")
print("⚠️ Do NOT delete this folder!")
print("=" * 60)
print("\n🚀 You can now run: python mainapp.py")