from __future__ import annotations

import trafilatura


class ExtractionError(Exception):
    pass


def extract_from_url(url: str) -> str:
    """Fetch a URL and extract article text (with title prepended).

    Returns the full text as a single string.
    Raises ExtractionError on fetch failure or empty content.
    """
    html = trafilatura.fetch_url(url)
    if html is None:
        raise ExtractionError(f"Failed to fetch URL: {url}")

    text = trafilatura.extract(html, include_comments=False, no_fallback=False)
    if not text:
        raise ExtractionError(f"No content could be extracted from: {url}")

    return text
