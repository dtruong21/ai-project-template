import 'package:app/core/api/api_exception.dart';
import 'package:app/core/ui/ui.dart';
import 'package:app/features/files/application/files_provider.dart';
import 'package:app/src/rust/api/files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  bool _uploading = false;

  Future<void> _add() async {
    final file = await ref.read(filePickerProvider)();
    if (file == null || !mounted) return; // cancelled

    setState(() => _uploading = true);
    try {
      await ref.read(myFilesProvider.notifier).upload(file);
      if (mounted) showMessage(context, 'Uploaded');
    } on Object catch (e) {
      if (mounted) showError(context, _message(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Words a user can act on — never a raw exception.
  String _message(Object error) => switch (error) {
    ApiUnauthenticatedException() => 'Sign in to upload files.',
    ApiNetworkException() => "Can't reach the server. Nothing was uploaded.",
    // too_large, quota_exceeded and validation messages are written for users.
    ApiResponseException(
      code: 'too_large' || 'quota_exceeded' || 'validation_failed',
      :final message,
    ) =>
      message,
    ApiResponseException() => "Couldn't upload. Try again.",
    // Thrown by the Rust check before any request; user-facing by contract.
    _ => error.toString(),
  };

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(myFilesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My files'),
        bottom: _uploading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _add,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add image'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myFilesProvider.future),
        child: AsyncValueView(
          value: files,
          onRetry: () => ref.invalidate(myFilesProvider),
          isEmpty: (state) => state.items.isEmpty,
          empty: EmptyState(
            icon: Icons.folder_open_outlined,
            title: 'No files yet',
            message: 'Images you add show up here.',
            actionLabel: 'Add image',
            onAction: _uploading ? null : _add,
          ),
          data: (state) => ListView.separated(
            // Room so the last row is not hidden behind the button.
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == state.items.length) {
                return _LoadMore(loading: state.loadingMore);
              }
              return _FileRow(item: state.items[index]);
            },
          ),
        ),
      ),
    );
  }
}

class _FileRow extends ConsumerWidget {
  const _FileRow({required this.item});

  final FileItem item;

  bool get _isImage => item.contentType.startsWith('image/');

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirm(
      context,
      title: 'Delete this file?',
      message: item.name,
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(myFilesProvider.notifier).remove(item.id);
      if (context.mounted) showMessage(context, 'Deleted');
    } on ApiNetworkException {
      if (context.mounted) {
        showError(context, "Can't reach the server. Nothing was deleted.");
      }
    } on Exception {
      if (context.mounted) showError(context, "Couldn't delete. Try again.");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = UiTokens.of(context).muted;
    final date = MaterialLocalizations.of(context).formatMediumDate(
      DateTime.fromMillisecondsSinceEpoch(item.createdAt.toInt() * 1000),
    );
    return ListTile(
      leading: Icon(_isImage ? Icons.image_outlined : Icons.picture_as_pdf),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${formatFileSize(item.size.toInt())} · $date',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
      ),
      onTap: _isImage
          ? () => showDialog<void>(
              context: context,
              builder: (_) => _ImagePreview(item: item),
            )
          : null,
      trailing: IconButton(
        tooltip: 'Delete',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _delete(context, ref),
      ),
    );
  }
}

class _ImagePreview extends ConsumerWidget {
  const _ImagePreview({required this.item});

  final FileItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(fileBytesProvider(item.id));
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: AsyncValueView(
          value: bytes,
          onRetry: () => ref.invalidate(fileBytesProvider(item.id)),
          data: (data) => InteractiveViewer(
            child: Image.memory(
              data,
              fit: BoxFit.contain,
              semanticLabel: item.name,
              errorBuilder: (_, _, _) => const StateView(
                icon: Icons.broken_image_outlined,
                title: "Can't show this image",
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadMore extends ConsumerWidget {
  const _LoadMore({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Center(
        child: AppButton(
          label: 'Load more',
          variant: AppButtonVariant.secondary,
          loading: loading,
          onPressed: () async {
            try {
              await ref.read(myFilesProvider.notifier).loadMore();
            } on Exception {
              if (context.mounted) {
                showError(context, "Couldn't load more. Try again.");
              }
            }
          },
        ),
      ),
    );
  }
}
