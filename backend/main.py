"""
Mayari TTS Backend - Kokoro TTS Server
Based on MimikaStudio's implementation
"""
import warnings
warnings.filterwarnings("ignore", message="pkg_resources is deprecated")

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from pathlib import Path
from contextlib import asynccontextmanager
import os
import re
import io
import uuid
import soundfile as sf

from tts.kokoro_engine import get_kokoro_engine, BRITISH_VOICES, DEFAULT_VOICE
from tts.text_chunking import smart_chunk_text
from tts.audio_utils import merge_audio_chunks

# Request models
class KokoroRequest(BaseModel):
    text: str
    voice: str = DEFAULT_VOICE
    speed: float = 1.0
    smart_chunking: bool = True
    max_chars_per_chunk: int = 1500
    crossfade_ms: int = 40

class HealthResponse(BaseModel):
    status: str
    version: str
    engine: str


def _resolve_runtime_path(env_var: str, fallback: Path) -> Path:
    raw_value = os.environ.get(env_var, "").strip()
    if raw_value:
        return Path(raw_value).expanduser()
    return fallback


def _parse_allow_origins() -> list[str]:
    raw_value = os.environ.get("MAYARI_ALLOW_ORIGINS", "").strip()
    if raw_value:
        origins = [origin.strip() for origin in raw_value.split(",") if origin.strip()]
        if origins:
            return origins
    return ["http://127.0.0.1", "http://localhost", "null"]


backend_dir = Path(__file__).resolve().parent
project_root = backend_dir.parents[0]
runtime_home = _resolve_runtime_path("MAYARI_RUNTIME_HOME", backend_dir)
outputs_dir = _resolve_runtime_path("MAYARI_OUTPUT_DIR", runtime_home / "outputs")
pdf_dir = _resolve_runtime_path("MAYARI_PDF_DIR", project_root / "pdf")
log_dir = _resolve_runtime_path("MAYARI_LOG_DIR", runtime_home / "logs")

for runtime_dir in (runtime_home, outputs_dir, pdf_dir, log_dir):
    runtime_dir.mkdir(parents=True, exist_ok=True)


def _safe_audio_path(filename: str) -> Path:
    if Path(filename).name != filename:
        raise HTTPException(status_code=400, detail="Invalid filename")

    target = (outputs_dir / filename).resolve()
    outputs_root = outputs_dir.resolve()
    if target != outputs_root and outputs_root not in target.parents:
        raise HTTPException(status_code=400, detail="Invalid filename")
    return target


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
    allow_origins=_parse_allow_origins(),
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount runtime directories for serving audio files and bundled documents.
app.mount("/audio", StaticFiles(directory=str(outputs_dir)), name="audio")
app.mount("/pdf", StaticFiles(directory=str(pdf_dir)), name="pdf")


def _normalize_pdf_text_for_tts(text: str) -> str:
    """Normalize extracted PDF text for sentence parsing and read-aloud."""
    if not text:
        return ""
    normalized = re.sub(r"(?<!\n)\n(?!\n)", " ", text)
    normalized = normalized.replace("\u00a0", " ")
    normalized = re.sub(r"([.!?;:,])(?=[A-Za-z])", r"\1 ", normalized)
    normalized = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", normalized)
    normalized = re.sub(r"[ \t]+", " ", normalized)
    normalized = re.sub(r"\n{3,}", "\n\n", normalized)
    return normalized.strip()


def _generate_chunked_audio(
    text: str,
    max_chars_per_chunk: int,
    crossfade_ms: int,
    smart_chunking: bool,
    generate_fn,
):
    chunks = smart_chunk_text(text, max_chars=max_chars_per_chunk) if smart_chunking else [text]
    chunks = [chunk for chunk in chunks if chunk.strip()]
    if not chunks:
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    all_audio = []
    sample_rate = None

    for chunk in chunks:
        audio, sr = generate_fn(chunk)
        if audio is None or len(audio) == 0:
            continue
        if sample_rate is None:
            sample_rate = sr
        elif sr != sample_rate:
            raise HTTPException(
                status_code=500,
                detail=f"Mismatched sample rates across chunks ({sample_rate} vs {sr})",
            )
        all_audio.append(audio)

    if not all_audio or sample_rate is None:
        raise HTTPException(status_code=500, detail="No audio generated")

    merged = merge_audio_chunks(all_audio, sample_rate, crossfade_ms=crossfade_ms)
    return merged, sample_rate, len(chunks)


@app.get("/health")
async def health_check() -> HealthResponse:
    """Health check endpoint."""
    return HealthResponse(
        status="ok",
        version="1.0.0",
        engine="kokoro"
    )


@app.get("/api/health")
async def health_check_api() -> HealthResponse:
    """Health check endpoint (API namespace)."""
    return await health_check()


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

    if len(request.text) > 100000:
        raise HTTPException(status_code=400, detail="Text too long (max 100000 chars)")
    if request.max_chars_per_chunk <= 0:
        raise HTTPException(status_code=400, detail="max_chars_per_chunk must be > 0")

    try:
        engine = get_kokoro_engine()
        audio, sample_rate, chunk_count = _generate_chunked_audio(
            text=request.text,
            max_chars_per_chunk=request.max_chars_per_chunk,
            crossfade_ms=request.crossfade_ms,
            smart_chunking=request.smart_chunking,
            generate_fn=lambda chunk: engine.generate_audio(
                text=chunk,
                voice=request.voice,
                speed=request.speed,
            ),
        )
        output_path = outputs_dir / f"kokoro-{request.voice}-{uuid.uuid4().hex[:8]}.wav"
        sf.write(str(output_path), audio, sample_rate)

        # Get audio duration
        audio_info = sf.info(str(output_path))
        duration = audio_info.duration

        return {
            "audio_url": f"/audio/{output_path.name}",
            "filename": output_path.name,
            "voice": request.voice,
            "duration_seconds": duration,
            "chunk_count": chunk_count,
        }
    except ImportError as e:
        raise HTTPException(status_code=500, detail=f"Kokoro not installed: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation failed: {e}")


@app.get("/api/kokoro/audio/list")
async def list_audio_files():
    """List all generated audio files."""
    audio_files: list[dict] = []
    for file in outputs_dir.glob("kokoro-*.wav"):
        try:
            audio_info = sf.info(str(file))
            # Extract voice from filename: kokoro-{voice}-{uuid}.wav
            parts = file.stem.split("-")
            voice = parts[1] if len(parts) >= 2 else "unknown"
            modified_epoch = file.stat().st_mtime

            audio_files.append({
                "id": file.stem,
                "filename": file.name,
                "voice": voice,
                "audio_url": f"/audio/{file.name}",
                "duration_seconds": audio_info.duration,
                "size_bytes": file.stat().st_size,
                "_modified_epoch": modified_epoch,
            })
        except Exception:
            continue

    # Sort by modification time (newest first)
    audio_files.sort(key=lambda x: x["_modified_epoch"], reverse=True)
    for item in audio_files:
        item.pop("_modified_epoch", None)
    return {"audio_files": audio_files}


@app.delete("/api/kokoro/audio/{filename}")
async def delete_audio(filename: str):
    """Delete a generated audio file."""
    file_path = _safe_audio_path(filename)
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")

    try:
        file_path.unlink()
        return {"status": "deleted", "filename": filename}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete: {e}")


@app.get("/api/pdf/list")
async def list_pdfs():
    """List available PDF/TXT/MD documents from the bundled document folder."""
    docs = []
    for ext in ("*.pdf", "*.txt", "*.md"):
        for file in pdf_dir.glob(ext):
            docs.append({
                "name": file.name,
                "url": f"/pdf/{file.name}",
                "size_bytes": file.stat().st_size,
            })
    docs.sort(key=lambda item: item["name"])
    return {"documents": docs}


@app.post("/api/pdf/extract-text")
async def extract_pdf_text(file: UploadFile = File(...)):
    """Extract normalized text from uploaded PDF bytes for read-aloud."""
    filename = (file.filename or "").lower()
    if filename and not filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")

    payload = await file.read()
    if not payload:
        raise HTTPException(status_code=400, detail="Uploaded PDF is empty")

    try:
        text = ""
        extraction_errors = []

        # Preferred path if pypdf is installed.
        try:
            from pypdf import PdfReader  # type: ignore

            reader = PdfReader(io.BytesIO(payload))
            extracted_pages = [(page.extract_text() or "") for page in reader.pages]
            text = "\n\n".join(extracted_pages)
        except Exception as exc:
            extraction_errors.append(f"pypdf: {exc}")

        # Fallback to PyMuPDF (fitz), commonly available in local environments.
        if not text.strip():
            try:
                import fitz  # type: ignore

                with fitz.open(stream=payload, filetype="pdf") as document:
                    extracted_pages = [
                        (page.get_text("text") or "") for page in document
                    ]
                text = "\n\n".join(extracted_pages)
            except Exception as exc:
                extraction_errors.append(f"fitz: {exc}")

        # Final fallback to legacy PyPDF2 if present.
        if not text.strip():
            try:
                from PyPDF2 import PdfReader as LegacyPdfReader  # type: ignore

                reader = LegacyPdfReader(io.BytesIO(payload))
                extracted_pages = [(page.extract_text() or "") for page in reader.pages]
                text = "\n\n".join(extracted_pages)
            except Exception as exc:
                extraction_errors.append(f"PyPDF2: {exc}")

        if not text.strip():
            detail = "PDF extraction backend unavailable."
            if extraction_errors:
                detail = f"{detail} Attempts: {' | '.join(extraction_errors)}"
            raise HTTPException(status_code=503, detail=detail)

        normalized = _normalize_pdf_text_for_tts(text)
        return {
            "text": normalized,
            "chars": len(normalized),
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to extract PDF text: {exc}",
        ) from exc


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("MAYARI_BACKEND_PORT", os.environ.get("PORT", 8787)))
    host = os.environ.get("MAYARI_BACKEND_HOST", "127.0.0.1")
    uvicorn.run(app, host=host, port=port)
