import 'package:app/core/api/api_exception.dart';
import 'package:app/core/ui/ui.dart';
import 'package:app/features/feedback/application/my_feedback_provider.dart';
import 'package:app/features/feedback/presentation/feedback_sheet.dart';
import 'package:app/src/rust/api/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyFeedbackScreen extends ConsumerWidget {
  const MyFeedbackScreen({super.key});

  static const _route = '/settings/feedback';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(myFeedbackProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My feedback')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myFeedbackProvider.future),
        child: AsyncValueView(
          value: feedback,
          onRetry: () => ref.invalidate(myFeedbackProvider),
          isEmpty: (state) => state.items.isEmpty,
          empty: EmptyState(
            title: 'No feedback yet',
            message: 'What you send will show up here.',
            actionLabel: 'Send feedback',
            onAction: () async {
              await showFeedbackSheet(context, route: _route);
              ref.invalidate(myFeedbackProvider);
            },
          ),
          data: (state) => ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == state.items.length) {
                return _LoadMore(loading: state.loadingMore);
              }
              return _FeedbackRow(item: state.items[index]);
            },
          ),
        ),
      ),
    );
  }
}

class _FeedbackRow extends ConsumerWidget {
  const _FeedbackRow({required this.item});

  final FeedbackItem item;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirm(
      context,
      title: 'Delete this feedback?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(myFeedbackProvider.notifier).remove(item.id);
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
    final theme = Theme.of(context);
    final sent = DateTime.fromMillisecondsSinceEpoch(
      item.createdAt.toInt() * 1000,
    );
    return ListTile(
      title: Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Gap.xs),
        child: Text(
          '${_categoryLabel(item.category)} · ${_dateLabel(context, sent)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: UiTokens.of(context).muted,
          ),
        ),
      ),
      trailing: IconButton(
        tooltip: 'Delete',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _delete(context, ref),
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
              await ref.read(myFeedbackProvider.notifier).loadMore();
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

String _categoryLabel(String category) => switch (category) {
  'bug' => 'Bug',
  'idea' => 'Idea',
  'praise' => 'Praise',
  _ => 'Other',
};

/// Locale-aware date without adding the `intl` package.
String _dateLabel(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatMediumDate(date);
