import asyncio
from concurrent.futures import ThreadPoolExecutor
import uuid

from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
import torch
import soundfile as sf
import uvicorn
import os
import requests

# --- Thread Pool for CPU-bound work ---
# Created early so it's available for model loading
executor = ThreadPoolExecutor(max_workers=2)

# --- Global State (models loaded in background) ---
whisper_model = None
qwen_model = None
models_ready = False
TTS_AVAILABLE = False

# Check TTS availability at import time (fast)
try:
    from qwen_tts import Qwen3TTSModel
    TTS_AVAILABLE = True
except ImportError:
    print("⚠️ qwen_tts not installed - TTS endpoint disabled")

# --- Ollama Configuration ---
OLLAMA_URL = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "qwen3:1.7b"
OLLAMA_TIMEOUT = 10  # seconds

# --- Pydantic Models ---
class SanitizeRequest(BaseModel):
    text: str
    instructions: str

class SanitizeResponse(BaseModel):
    sanitized_text: str

# --- FastAPI App ---
app = FastAPI()

# --- Background Model Loading ---
def _load_models_sync():
    """Load models synchronously - called from thread pool."""
    global whisper_model, qwen_model, models_ready

    print("🔧 Loading Whisper model...")
    whisper_model = __import__('whisper').load_model("small", device="cpu")
    print("✅ Whisper model loaded")

    if TTS_AVAILABLE:
        print("🔧 Loading TTS model...")
        qwen_model = Qwen3TTSModel.from_pretrained(
            "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
            device_map="auto",
            attn_implementation="eager"
        )
        print("✅ TTS model loaded")

    models_ready = True
    print("✅ All models ready!")

@app.on_event("startup")
async def load_models_background():
    """Load models in background so server can start immediately."""
    print("🚀 Server starting - loading models in background...")
    loop = asyncio.get_running_loop()
    loop.run_in_executor(executor, _load_models_sync)

# --- Health Check ---
@app.get("/health")
async def health_check():
    """Health check endpoint - works even during model loading."""
    return {"status": "ok", "models_ready": models_ready}

# --- Transcription ---
def _sync_transcribe(audio_path: str) -> dict:
    """Synchronous transcription - runs in thread pool."""
    return whisper_model.transcribe(
        audio_path,
        fp16=False,
        language="en",
        task="transcribe"
    )

@app.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    """Transcribe audio using Whisper. Non-blocking."""
    if not models_ready:
        raise HTTPException(status_code=503, detail="Models still loading, please wait...")

    temp_audio_path = f"temp_{uuid.uuid4().hex}_{file.filename}"

    try:
        with open(temp_audio_path, "wb") as buffer:
            buffer.write(await file.read())

        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(executor, _sync_transcribe, temp_audio_path)

        transcribed_text = result["text"]
        segments = result.get("segments", [])
        speech_duration = None
        if segments:
            first_start = segments[0].get("start", 0)
            last_end = segments[-1].get("end", 0)
            speech_duration = last_end - first_start

        return {
            "transcription": transcribed_text,
            "speech_duration": speech_duration
        }

    except Exception as e:
        print(f"❌ Transcription error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

    finally:
        if os.path.exists(temp_audio_path):
            os.remove(temp_audio_path)

# --- Ollama (Non-blocking) ---
def _sync_ollama_call(payload: dict) -> dict:
    """Synchronous Ollama call - runs in thread pool."""
    response = requests.post(
        OLLAMA_URL,
        json=payload,
        timeout=OLLAMA_TIMEOUT
    )
    response.raise_for_status()
    return response.json()

async def call_ollama(text: str, instructions: str, max_retries: int = 1) -> str:
    """Call Ollama API - non-blocking via thread pool."""
    system_instruction = """You are a text transformation assistant. Follow the user's instructions exactly.

Rules:
- Apply the user's instructions to transform the text
- Do not add explanations, commentary, or meta-text
- Return ONLY the transformed text"""

    full_prompt = f"{system_instruction}\n\nInstructions: {instructions}\n\nText to transform:\n{text}\n\nReturn only the transformed text:"

    payload = {
        "model": OLLAMA_MODEL,
        "prompt": full_prompt,
        "stream": False,
        "options": {
            "temperature": 0.3,
            "top_p": 0.9
        }
    }

    loop = asyncio.get_running_loop()

    for attempt in range(max_retries + 1):
        try:
            result = await loop.run_in_executor(executor, _sync_ollama_call, payload)
            sanitized = result.get("response", "").strip()

            if not sanitized:
                raise ValueError("Empty response from Ollama")

            return sanitized

        except requests.exceptions.Timeout:
            if attempt == max_retries:
                raise HTTPException(
                    status_code=504,
                    detail="Ollama request timed out after 10 seconds"
                )
        except requests.exceptions.ConnectionError:
            if attempt == max_retries:
                raise HTTPException(
                    status_code=503,
                    detail="Cannot connect to Ollama. Is it running on localhost:11434?"
                )
        except Exception as e:
            if attempt == max_retries:
                raise HTTPException(
                    status_code=500,
                    detail=f"Sanitization failed: {str(e)}"
                )

@app.post("/sanitize", response_model=SanitizeResponse)
async def sanitize_text(request: SanitizeRequest):
    """Sanitize text using Ollama LLM."""
    try:
        if not request.text or not request.text.strip():
            raise HTTPException(status_code=400, detail="Text cannot be empty")

        if len(request.text) > 10000:
            raise HTTPException(status_code=400, detail="Text too long (max 10,000 characters)")

        if not request.instructions or not request.instructions.strip():
            raise HTTPException(status_code=400, detail="Instructions cannot be empty")

        sanitized = await call_ollama(request.text, request.instructions)
        return SanitizeResponse(sanitized_text=sanitized)

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Sanitization error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Sanitization failed: {str(e)}")

# --- TTS ---
@app.post("/synthesize")
async def synthesize_text(text: str):
    """Synthesize text to audio using Qwen3-TTS."""
    if not TTS_AVAILABLE or qwen_model is None:
        raise HTTPException(status_code=503, detail="TTS not available - qwen_tts not installed")

    if not models_ready:
        raise HTTPException(status_code=503, detail="Models still loading, please wait...")

    audio_data_list, sampling_rate = qwen_model.generate_custom_voice(
        text=text,
        speaker="serena",
        language="english"
    )

    audio_data = audio_data_list[0]
    temp_audio_path = f"temp_output_{uuid.uuid4().hex}.wav"

    try:
        sf.write(temp_audio_path, audio_data, sampling_rate)
        with open(temp_audio_path, "rb") as f:
            audio_bytes = f.read()
        return {"audio_data": audio_bytes.hex(), "sampling_rate": sampling_rate}
    finally:
        if os.path.exists(temp_audio_path):
            os.remove(temp_audio_path)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
