/// Feedback bottom sheet — category chips + free text.
///
/// Renders every state of the submission: idle, loading (button disabled,
/// spinner), error (message + input kept so nothing is lost), success
/// (sheet closes, snackbar confirms).
library;

import 'package:app/core/api/api_exception.dart';
import 'package:app/features/feedback/feedback_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showFeedbackSheet(BuildContext context, {required String route}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // lets the sheet rise above the keyboard
    showDragHandle: true,
    builder: (_) => _FeedbackSheet(route: route),
  );
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  const _FeedbackSheet({required this.route});

  final String route;

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  final _body = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.idea;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref
        .read(feedbackSubmissionProvider.notifier)
        .submit(
          SubmitFeedbackInput(
            category: _category,
            body: _body.text,
            route: widget.route,
            appVersion: const String.fromEnvironment(
              'APP_VERSION',
              defaultValue: 'dev',
            ),
          ),
        );
    if (!mounted || ref.read(feedbackSubmissionProvider).hasError) return;
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Thanks — every message gets read.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedbackSubmissionProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Send feedback', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final category in FeedbackCategory.values)
                ChoiceChip(
                  label: Text(_label(category)),
                  selected: _category == category,
                  onSelected: state.isLoading
                      ? null
                      : (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            enabled: !state.isLoading,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Your message',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (state.hasError) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage(state.error!),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.isLoading ? null : _submit,
            child: state.isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
    );
  }
}

String _label(FeedbackCategory category) => switch (category) {
  FeedbackCategory.bug => 'Bug',
  FeedbackCategory.idea => 'Idea',
  FeedbackCategory.praise => 'Praise',
  FeedbackCategory.other => 'Other',
};

/// Maps failures to words a user can act on. Never shows a raw exception.
String _errorMessage(Object error) => switch (error) {
  ApiUnauthenticatedException() => 'Sign in is required to send feedback.',
  ApiNetworkException() =>
    "Can't reach the server. Check your connection and try again.",
  // 422 body is the user-facing validation message from the shared rules.
  ApiResponseException(statusCode: 422, :final body) => body,
  ApiResponseException() => 'Something went wrong on our side. Try again.',
  // Thrown by the Rust validation before any request is made; its message
  // is user-facing by contract (see rust/shared).
  _ => _rustMessage(error),
};

String _rustMessage(Object error) {
  final text = error.toString();
  return text.isEmpty ? 'Something went wrong. Try again.' : text;
}
