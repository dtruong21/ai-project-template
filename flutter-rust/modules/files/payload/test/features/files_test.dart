import 'dart:typed_data';

import 'package:app/core/api/api_exception.dart';
import 'package:app/core/ui/ui.dart';
import 'package:app/features/files/application/files_provider.dart';
import 'package:app/features/files/presentation/files_screen.dart';
import 'package:app/src/rust/api/files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFiles extends MyFiles {
  _FakeFiles(this._initial, {this.failUploadWith});

  final FilesState _initial;
  final Exception? failUploadWith;
  final uploaded = <String>[];
  final removed = <String>[];

  @override
  Future<FilesState> build() async => _initial;

  @override
  Future<void> upload(PickedFile file) async {
    if (failUploadWith != null) throw failUploadWith!;
    uploaded.add(file.name);
    state = AsyncData(
      FilesState(
        items: [_item('new', file.name), ...?state.value?.items],
        nextCursor: null,
      ),
    );
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    state = AsyncData(
      FilesState(
        items: _initial.items.where((i) => i.id != id).toList(),
        nextCursor: null,
      ),
    );
  }
}

FileItem _item(String id, String name, {String type = 'image/png'}) => FileItem(
  id: id,
  name: name,
  contentType: type,
  size: 2048,
  createdAt: 1700000000,
);

Future<_FakeFiles> _pump(
  WidgetTester tester,
  FilesState state, {
  PickedFile? picks,
  Exception? failUploadWith,
}) async {
  final fake = _FakeFiles(state, failUploadWith: failUploadWith);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myFilesProvider.overrideWith(() => fake),
        filePickerProvider.overrideWithValue(() async => picks),
      ],
      child: const MaterialApp(home: FilesScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  test('formatFileSize', () {
    expect(formatFileSize(12), '12 B');
    expect(formatFileSize(2048), '2.0 KB');
    expect(formatFileSize(1572864), '1.5 MB');
  });

  testWidgets('empty state offers to add an image', (tester) async {
    await _pump(tester, const FilesState(items: [], nextCursor: null));
    expect(find.text('No files yet'), findsOneWidget);
    expect(find.text('Add image'), findsWidgets);
  });

  testWidgets('lists files with size', (tester) async {
    await _pump(
      tester,
      FilesState(
        items: [
          _item('a', 'cat.png'),
          _item('b', 'doc.pdf', type: 'application/pdf'),
        ],
        nextCursor: null,
      ),
    );
    expect(find.text('cat.png'), findsOneWidget);
    expect(find.text('doc.pdf'), findsOneWidget);
    expect(find.textContaining('2.0 KB'), findsNWidgets(2));
  });

  testWidgets('picking a file uploads it and it appears', (tester) async {
    final fake = await _pump(
      tester,
      const FilesState(items: [], nextCursor: null),
      picks: PickedFile(name: 'dog.png', bytes: Uint8List.fromList([1, 2, 3])),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(fake.uploaded, ['dog.png']);
    expect(find.text('dog.png'), findsOneWidget);
    expect(find.text('Uploaded'), findsOneWidget);
  });

  testWidgets('cancelling the picker uploads nothing', (tester) async {
    final fake = await _pump(
      tester,
      const FilesState(items: [], nextCursor: null),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(fake.uploaded, isEmpty);
  });

  testWidgets('a rejected upload explains why and adds nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      const FilesState(items: [], nextCursor: null),
      picks: PickedFile(name: 'big.png', bytes: Uint8List(3)),
      failUploadWith: const ApiResponseException(
        '/v1/files',
        413,
        code: 'too_large',
        message: 'That file is too large (max 10 MB).',
      ),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('That file is too large (max 10 MB).'), findsOneWidget);
    expect(find.text('big.png'), findsNothing);
  });

  testWidgets('delete asks first; confirm removes the file', (tester) async {
    final fake = await _pump(
      tester,
      FilesState(items: [_item('a', 'cat.png')], nextCursor: null),
    );
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(fake.removed, isEmpty);
    await tester.tap(find.widgetWithText(AppButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(fake.removed, ['a']);
    expect(find.text('cat.png'), findsNothing);
  });
}
