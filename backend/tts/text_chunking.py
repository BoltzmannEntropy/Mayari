"""Text chunking helpers for TTS generation."""

import re


def split_into_sentences(text: str) -> list[str]:
    """Split text into sentences using a regex fallback."""
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return []
    parts = re.split(r"(?<=[.!?])\s+", text)
    return [part.strip() for part in parts if part.strip()]


def smart_chunk_text(text: str, max_chars: int = 1500) -> list[str]:
    """Split text into chunks that respect sentence boundaries when possible."""
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return []

    sentences = split_into_sentences(text)
    chunks: list[str] = []
    current_chunk: list[str] = []
    current_len = 0

    for sentence in sentences:
        if len(sentence) > max_chars:
            if current_chunk:
                chunks.append(" ".join(current_chunk))
                current_chunk = []
                current_len = 0

            words = sentence.split()
            temp_words: list[str] = []
            temp_len = 0
            for word in words:
                word_len = len(word) + (1 if temp_words else 0)
                if temp_words and (temp_len + word_len > max_chars):
                    chunks.append(" ".join(temp_words))
                    temp_words = [word]
                    temp_len = len(word)
                else:
                    temp_words.append(word)
                    temp_len += word_len
            if temp_words:
                chunks.append(" ".join(temp_words))
            continue

        sentence_len = len(sentence) + (1 if current_chunk else 0)
        if current_chunk and (current_len + sentence_len > max_chars):
            chunks.append(" ".join(current_chunk))
            current_chunk = [sentence]
            current_len = len(sentence)
        else:
            current_chunk.append(sentence)
            current_len += sentence_len

    if current_chunk:
        chunks.append(" ".join(current_chunk))

    return chunks

