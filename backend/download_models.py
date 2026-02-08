
import whisper
from qwen_tts import Qwen3TTSModel
import torch
import os

def download_models():
    print("----------------------------------------------------------------")
    print("⬇️  Downloading/Loading Whisper 'base' model...")
    # This will download the model to ~/.cache/whisper if not present
    whisper.load_model("base")
    print("✅ Whisper model ready.")

    print("----------------------------------------------------------------")
    print("⬇️  Downloading/Loading Qwen3-TTS model...")
    # This will download the model to ~/.cache/huggingface if not present
    Qwen3TTSModel.from_pretrained(
        "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
        device_map="auto",
        attn_implementation="eager"
    )
    print("✅ Qwen3-TTS model ready.")
    print("----------------------------------------------------------------")

if __name__ == "__main__":
    download_models()
