"""
Mayari TTS Backend - Kokoro TTS Server
Based on MimikaStudio's implementation
"""
import warnings
warnings.filterwarnings("ignore", message="pkg_resources is deprecated")

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from pathlib import Path
from contextlib import asynccontextmanager
from typing import Optional
import os
import soundfile as sf

from tts.kokoro_engine import get_kokoro_engine, BRITISH_VOICES, DEFAULT_VOICE

# Request models
class KokoroRequest(BaseModel):
    text: str
    voice: str = DEFAULT_VOICE
    speed: float = 1.0

class HealthResponse(BaseModel):
    status: str
    version: str
    engine: str

# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("Mayari TTS Backend starting...")
    print("Loading Kokoro engine...")
    try:
        engine = get_kokoro_engine()
        engine.load_model()
        print("Kokoro engine loaded successfully")
    except Exception as e:
        print(f"Warning: Could not preload Kokoro: {e}")
    yield
    # Shutdown
    print("Mayari TTS Backend shutting down...")

app = FastAPI(
    title="Mayari TTS API",
    description="Kokoro TTS for PDF reading",
    version="1.0.0",
    lifespan=lifespan
)

# CORS for Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount outputs directory for serving audio files
outputs_dir = Path(__file__).parent / "outputs"
outputs_dir.mkdir(parents=True, exist_ok=True)
app.mount("/audio", StaticFiles(directory=str(outputs_dir)), name="audio")


@app.get("/health")
async def health_check() -> HealthResponse:
    """Health check endpoint."""
    return HealthResponse(
        status="ok",
        version="1.0.0",
        engine="kokoro"
    )


@app.get("/api/kokoro/voices")
async def get_voices():
    """Get available Kokoro voices."""
    voices = []
    for code, info in BRITISH_VOICES.items():
        voices.append({
            "code": code,
            "name": info["name"],
            "gender": info["gender"],
            "grade": info["grade"],
            "is_default": code == DEFAULT_VOICE
        })
    return {
        "voices": voices,
        "default": DEFAULT_VOICE
    }


@app.post("/api/kokoro/generate")
async def generate_speech(request: KokoroRequest):
    """Generate speech from text using Kokoro."""
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="Text is required")

    if len(request.text) > 10000:
        raise HTTPException(status_code=400, detail="Text too long (max 10000 chars)")

    try:
        engine = get_kokoro_engine()
        output_path = engine.generate(
            text=request.text,
            voice=request.voice,
            speed=request.speed
        )

        # Get audio duration
        audio_info = sf.info(str(output_path))
        duration = audio_info.duration

        return {
            "audio_url": f"/audio/{output_path.name}",
            "filename": output_path.name,
            "voice": request.voice,
            "duration_seconds": duration
        }
    except ImportError as e:
        raise HTTPException(status_code=500, detail=f"Kokoro not installed: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation failed: {e}")


@app.get("/api/kokoro/audio/list")
async def list_audio_files():
    """List all generated audio files."""
    audio_files = []
    for file in outputs_dir.glob("kokoro-*.wav"):
        try:
            audio_info = sf.info(str(file))
            # Extract voice from filename: kokoro-{voice}-{uuid}.wav
            parts = file.stem.split("-")
            voice = parts[1] if len(parts) >= 2 else "unknown"

            audio_files.append({
                "id": file.stem,
                "filename": file.name,
                "voice": voice,
                "audio_url": f"/audio/{file.name}",
                "duration_seconds": audio_info.duration,
                "size_bytes": file.stat().st_size
            })
        except Exception:
            continue

    # Sort by modification time (newest first)
    audio_files.sort(key=lambda x: x["filename"], reverse=True)
    return {"audio_files": audio_files}


@app.delete("/api/kokoro/audio/{filename}")
async def delete_audio(filename: str):
    """Delete a generated audio file."""
    file_path = outputs_dir / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")

    try:
        file_path.unlink()
        return {"status": "deleted", "filename": filename}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete: {e}")


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8787))
    uvicorn.run(app, host="127.0.0.1", port=port)
