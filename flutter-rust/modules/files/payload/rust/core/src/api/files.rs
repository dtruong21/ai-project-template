//! Files module, app side: check an upload before sending it, parse lists.

use shared::files::{self as rules, FileMeta};
use shared::Page;

/// Checks a file before upload with the same rules the Worker enforces.
/// Pass only the first [`rules::SNIFF_BYTES`] bytes plus the real size, so
/// megabytes never cross the bridge. Returns the content type to send; the
/// `Err` string is user-facing.
#[flutter_rust_bridge::frb(sync)]
pub fn check_upload(head: Vec<u8>, size: u64) -> Result<String, String> {
    let size = usize::try_from(size).unwrap_or(usize::MAX);
    rules::validate_parts(&head, size)
        .map(str::to_string)
        .map_err(|e| e.to_string())
}

/// A name that is safe to show and to send as `?name=`.
#[flutter_rust_bridge::frb(sync)]
pub fn clean_file_name(raw: String) -> String {
    rules::clean_name(&raw)
}

/// How many first bytes `check_upload` needs.
#[flutter_rust_bridge::frb(sync)]
pub fn sniff_bytes() -> u32 {
    rules::SNIFF_BYTES as u32
}

pub struct FileItem {
    pub id: String,
    pub name: String,
    pub content_type: String,
    pub size: i64,
    /// Seconds since epoch, UTC.
    pub created_at: i64,
}

pub struct FilePage {
    pub items: Vec<FileItem>,
    /// Pass back as `?cursor=` for the next page; `None` on the last page.
    pub next_cursor: Option<String>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn parse_file_page(json: String) -> Result<FilePage, String> {
    let page: Page<FileMeta> =
        serde_json::from_str(&json).map_err(|_| "Unexpected response from the server.")?;
    Ok(FilePage {
        items: page
            .items
            .into_iter()
            .map(|f| FileItem {
                id: f.id,
                name: f.name,
                content_type: f.content_type,
                size: f.size,
                created_at: f.created_at,
            })
            .collect(),
        next_cursor: page.next_cursor,
    })
}

/// Parses the body of `POST /v1/files`.
#[flutter_rust_bridge::frb(sync)]
pub fn parse_file(json: String) -> Result<FileItem, String> {
    let f: FileMeta =
        serde_json::from_str(&json).map_err(|_| "Unexpected response from the server.")?;
    Ok(FileItem {
        id: f.id,
        name: f.name,
        content_type: f.content_type,
        size: f.size,
        created_at: f.created_at,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const PNG_HEAD: [u8; 8] = [0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A];

    #[test]
    fn accepts_an_image_and_says_its_type() {
        assert_eq!(check_upload(PNG_HEAD.to_vec(), 1234).unwrap(), "image/png");
    }

    #[test]
    fn rejects_empty_oversized_and_unknown_files_with_a_readable_message() {
        assert!(check_upload(PNG_HEAD.to_vec(), 0)
            .unwrap_err()
            .contains("empty"));
        assert!(check_upload(PNG_HEAD.to_vec(), 50 * 1024 * 1024)
            .unwrap_err()
            .contains("too large"));
        assert!(check_upload(b"<html>".to_vec(), 10)
            .unwrap_err()
            .contains("Only"));
    }

    #[test]
    fn parses_pages_and_single_files() {
        let item = r#"{"id":"ab","name":"a.png","content_type":"image/png","size":5,"created_at":1700000000}"#;
        let page =
            parse_file_page(format!(r#"{{"items":[{item}],"next_cursor":"1_ab"}}"#)).unwrap();
        assert_eq!(page.items[0].name, "a.png");
        assert_eq!(page.next_cursor.as_deref(), Some("1_ab"));
        assert_eq!(parse_file(item.to_string()).unwrap().size, 5);
        assert!(parse_file_page("{}".to_string()).is_err());
        assert!(parse_file("".to_string()).is_err());
    }
}
