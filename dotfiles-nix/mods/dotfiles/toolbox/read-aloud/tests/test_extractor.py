from __future__ import annotations

from unittest.mock import patch


def test_extract_from_url_returns_title_and_body():
    from read_aloud.extractor import extract_from_url

    fake_html = "<html><body><h1>My Title</h1><p>Article body text.</p></body></html>"
    with patch("read_aloud.extractor.trafilatura.fetch_url", return_value=fake_html) as mock_fetch:
        with patch("read_aloud.extractor.trafilatura.extract", return_value="My Title\n\nArticle body text.") as mock_extract:
            result = extract_from_url("https://example.com/article")

    mock_fetch.assert_called_once_with("https://example.com/article")
    mock_extract.assert_called_once_with(fake_html, include_comments=False, no_fallback=False)
    assert result == "My Title\n\nArticle body text."


def test_extract_from_url_raises_on_fetch_failure():
    from read_aloud.extractor import ExtractionError, extract_from_url

    with patch("read_aloud.extractor.trafilatura.fetch_url", return_value=None):
        try:
            extract_from_url("https://example.com/bad")
            assert False, "Should have raised"
        except ExtractionError as e:
            assert "fetch" in str(e).lower()


def test_extract_from_url_raises_on_empty_content():
    from read_aloud.extractor import ExtractionError, extract_from_url

    fake_html = "<html><body></body></html>"
    with patch("read_aloud.extractor.trafilatura.fetch_url", return_value=fake_html):
        with patch("read_aloud.extractor.trafilatura.extract", return_value=None):
            try:
                extract_from_url("https://example.com/empty")
                assert False, "Should have raised"
            except ExtractionError as e:
                assert "content" in str(e).lower()
