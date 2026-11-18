//! Files module — rules shared by the app and the Worker.
//!
//! The server never trusts the client's claimed content type. It looks at
//! the first bytes of the file ([`sniff_content_type`]) and only accepts
//! formats on a short allowlist. That is what stops an uploaded HTML or SVG
//! file being served back as a page that runs script.

use std::fmt;

use serde::{Deserialize, Serialize};

pub const MAX_FILE_BYTES: usize = 10 * 1024 * 1024;
pub const MAX_FILES_PER_USER: u32 = 100;
pub const NAME_MAX_CHARS: usize = 120;

/// Error `code`s this module adds to the API's error envelope.
pub const TOO_LARGE: &str = "too_large";
pub const QUOTA_EXCEEDED: &str = "quota_exceeded";

/// Bytes needed to recognise every allowed format.
pub const SNIFF_BYTES: usize = 16;

/// One stored file, as returned by `GET /v1/files` and `POST /v1/files`.
/// No `uid`: a caller only ever sees their own files.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FileMeta {
    pub id: String,
    pub name: String,
    pub content_type: String,
    pub size: i64,
    pub created_at: i64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FileError {
    Empty,
    TooLarge,
    TypeNotAllowed,
}

impl fmt::Display for FileError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Empty => write!(f, "That file is empty."),
            Self::TooLarge => write!(
                f,
                "That file is too large (max {} MB).",
                MAX_FILE_BYTES / (1024 * 1024)
            ),
            Self::TypeNotAllowed => {
                write!(f, "Only PNG, JPEG, GIF, WebP and PDF files are allowed.")
            }
        }
    }
}

impl std::error::Error for FileError {}

/// The canonical content type of `head` (the start of a file), or `None`
/// when it is not an allowed format.
pub fn sniff_content_type(head: &[u8]) -> Option<&'static str> {
    if head.starts_with(&[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]) {
        Some("image/png")
    } else if head.starts_with(&[0xFF, 0xD8, 0xFF]) {
        Some("image/jpeg")
    } else if head.starts_with(b"GIF87a") || head.starts_with(b"GIF89a") {
        Some("image/gif")
    } else if head.len() >= 12 && &head[0..4] == b"RIFF" && &head[8..12] == b"WEBP" {
        Some("image/webp")
    } else if head.starts_with(b"%PDF-") {
        Some("application/pdf")
    } else {
        None
    }
}

/// Checks an upload given only its first bytes and total size — the app uses
/// this so it need not hand 10 MB across the bridge; the Worker calls it
/// with the real bytes. Returns the content type to store.
pub fn validate_parts(head: &[u8], size: usize) -> Result<&'static str, FileError> {
    if size == 0 {
        return Err(FileError::Empty);
    }
    if size > MAX_FILE_BYTES {
        return Err(FileError::TooLarge);
    }
    sniff_content_type(head).ok_or(FileError::TypeNotAllowed)
}

pub fn validate_upload(bytes: &[u8]) -> Result<&'static str, FileError> {
    validate_parts(&bytes[..bytes.len().min(SNIFF_BYTES)], bytes.len())
}

/// A display name that is safe to show in a list and to put inside a
/// `Content-Disposition` header: letters, digits, space and `. - _ ( )`
/// only, trimmed, at most [`NAME_MAX_CHARS`]. Anything else becomes `_`.
pub fn clean_name(raw: &str) -> String {
    let cleaned: String = raw
        .trim()
        .chars()
        .take(NAME_MAX_CHARS)
        .map(|c| {
            if c.is_alphanumeric() || matches!(c, ' ' | '.' | '-' | '_' | '(' | ')') {
                c
            } else {
                '_'
            }
        })
        .collect();
    let cleaned = cleaned.trim().to_string();
    if cleaned.is_empty() || cleaned.chars().all(|c| c == '.') {
        "file".to_string()
    } else {
        cleaned
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const PNG: &[u8] = &[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];

    #[test]
    fn recognises_each_allowed_format() {
        assert_eq!(sniff_content_type(PNG), Some("image/png"));
        assert_eq!(
            sniff_content_type(&[0xFF, 0xD8, 0xFF, 0xE0]),
            Some("image/jpeg")
        );
        assert_eq!(sniff_content_type(b"GIF89a...."), Some("image/gif"));
        assert_eq!(sniff_content_type(b"GIF87a...."), Some("image/gif"));
        assert_eq!(
            sniff_content_type(b"RIFF\x01\x02\x03\x04WEBPVP8 "),
            Some("image/webp")
        );
        assert_eq!(sniff_content_type(b"%PDF-1.7\n"), Some("application/pdf"));
    }

    #[test]
    fn rejects_everything_else_whatever_the_client_claims() {
        for bad in [
            &b"<html><script>alert(1)</script></html>"[..],
            b"<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>",
            b"#!/bin/sh\nrm -rf /",
            b"MZ\x90\x00",
            b"RIFF\x01\x02\x03\x04WAVEfmt ", // RIFF but not WebP
            b"",
            b"\x89PNG", // truncated signature
        ] {
            assert_eq!(sniff_content_type(bad), None, "accepted {bad:?}");
        }
    }

    #[test]
    fn validate_checks_size_and_type() {
        assert_eq!(validate_upload(PNG), Ok("image/png"));
        assert_eq!(validate_upload(&[]), Err(FileError::Empty));
        assert_eq!(
            validate_upload(b"plain text"),
            Err(FileError::TypeNotAllowed)
        );

        let mut big = PNG.to_vec();
        big.resize(MAX_FILE_BYTES, 0);
        assert_eq!(validate_upload(&big), Ok("image/png"));
        big.push(0);
        assert_eq!(validate_upload(&big), Err(FileError::TooLarge));
    }

    #[test]
    fn size_is_checked_before_type() {
        // The app sends only the head plus the real size.
        assert_eq!(
            validate_parts(PNG, MAX_FILE_BYTES + 1),
            Err(FileError::TooLarge)
        );
        assert_eq!(validate_parts(PNG, 0), Err(FileError::Empty));
    }

    #[test]
    fn clean_name_is_safe_for_headers_and_lists() {
        assert_eq!(clean_name("holiday photo (1).png"), "holiday photo (1).png");
        assert_eq!(
            clean_name("evil\"\r\nSet-Cookie: x=1.png"),
            "evil___Set-Cookie_ x_1.png"
        );
        assert_eq!(clean_name("../../etc/passwd"), ".._.._etc_passwd");
        assert_eq!(clean_name("   "), "file");
        assert_eq!(clean_name("..."), "file");
        assert_eq!(clean_name(&"x".repeat(500)).chars().count(), NAME_MAX_CHARS);
        assert_eq!(clean_name("Đạt.png"), "Đạt.png");
    }

    #[test]
    fn meta_round_trips() {
        let meta = FileMeta {
            id: "ab12".into(),
            name: "a.png".into(),
            content_type: "image/png".into(),
            size: 12,
            created_at: 1_700_000_000,
        };
        let json = serde_json::to_string(&meta).unwrap();
        assert_eq!(serde_json::from_str::<FileMeta>(&json).unwrap(), meta);
    }
}
