/// Transient feedback: confirmations and snackbars.
library;

import 'package:app/core/ui/app_button.dart';
import 'package:app/core/ui/ui_tokens.dart';
import 'package:flutter/material.dart';

/// Asks before doing something. Returns `true` only on an explicit confirm —
/// dismissing (back, tap outside) is `false`.
///
/// For irreversible actions pass `destructive: true`: the confirm button
/// turns into the danger style and its label must name the action
/// ("Delete account"), never "OK".
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: confirmLabel,
          variant: destructive
              ? AppButtonVariant.danger
              : AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Brief confirmation that something happened ("Saved"). Replaces any
/// snackbar already showing, so rapid actions don't queue up.
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// A failure the user should know about but that doesn't replace the screen
/// (a save that failed while the form stays open).
void showError(BuildContext context, String text) {
  final tokens = UiTokens.of(context);
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: tokens.danger,
        content: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onError, size: 20),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(text, style: TextStyle(color: scheme.onError)),
            ),
          ],
        ),
      ),
    );
}
