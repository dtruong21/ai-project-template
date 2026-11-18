import 'dart:math' as math;
import 'dart:typed_data';

import 'package:app/core/api/api_client.dart';
import 'package:app/src/rust/api/files.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'files_provider.g.dart';

/// A file chosen by the user, fully read into memory (the API caps files at
/// 10 MB, so this is bounded).
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Asks the user for a file; `null` when they cancel. A provider so tests
/// can replace it — the real picker needs a device.
// ponytail: gallery images only (no permission strings needed on iOS or
// Android). For PDFs and arbitrary files add `file_picker` and return its
// result here; nothing else changes.
final filePickerProvider = Provider<Future<PickedFile?> Function()>(
  (ref) => () async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return PickedFile(name: picked.name, bytes: await picked.readAsBytes());
  },
);

class FilesState {
  const FilesState({
    required this.items,
    required this.nextCursor,
    this.loadingMore = false,
  });

  final List<FileItem> items;

  /// `null` when every page has been loaded.
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;
}

/// The signed-in user's files, newest first, a page at a time.
@riverpod
class MyFiles extends _$MyFiles {
  static const _path = '/v1/files';

  @override
  Future<FilesState> build() async {
    final page = await _fetch(null);
    return FilesState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<FilePage> _fetch(String? cursor) async {
    final query = cursor == null
        ? ''
        : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    final body = await ref.read(apiClientProvider).getJson('$_path$query');
    return parseFilePage(json: body);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(
      FilesState(
        items: current.items,
        nextCursor: current.nextCursor,
        loadingMore: true,
      ),
    );
    try {
      final page = await _fetch(current.nextCursor);
      state = AsyncData(
        FilesState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object {
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Checks the file with the Rust rules (same ones the Worker enforces),
  /// uploads it, and puts it at the top of the list. Throws on failure and
  /// leaves the list as it was: a rejected file never appears.
  Future<void> upload(PickedFile file) async {
    final head = file.bytes.sublist(
      0,
      math.min(file.bytes.length, sniffBytes()),
    );
    final contentType = checkUpload(
      head: head,
      size: BigInt.from(file.bytes.length),
    );
    final name = Uri.encodeQueryComponent(cleanFileName(raw: file.name));
    final body = await ref
        .read(apiClientProvider)
        .postBytes('$_path?name=$name', file.bytes, contentType: contentType);

    final created = parseFile(json: body);
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        FilesState(
          items: [created, ...current.items],
          nextCursor: current.nextCursor,
        ),
      );
    }
  }

  /// Deletes on the server first, then removes the row locally.
  Future<void> remove(String id) async {
    await ref.read(apiClientProvider).delete('$_path/$id');
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      FilesState(
        items: [
          for (final item in current.items)
            if (item.id != id) item,
        ],
        nextCursor: current.nextCursor,
      ),
    );
  }
}

/// The bytes of one file, fetched with the auth header (so it cannot be an
/// `Image.network` URL). Disposed — and so re-fetched — when no longer shown.
@riverpod
Future<Uint8List> fileBytes(Ref ref, String id) =>
    ref.watch(apiClientProvider).getBytes('/v1/files/$id');

/// "12 B", "3.4 KB", "1.2 MB".
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
