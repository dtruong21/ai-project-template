/// Full-area states. Every screen that loads data renders exactly one of:
/// loading, empty, error, offline, or its content (see `AsyncValueView`).
library;

import 'package:app/core/api/api_exception.dart';
import 'package:app/core/ui/app_button.dart';
import 'package:app/core/ui/ui_tokens.dart';
import 'package:flutter/material.dart';

/// Shared layout: icon, title, optional message, optional action. Scrolls
/// when squeezed (keyboard open, large text) instead of overflowing.
class StateView extends StatelessWidget {
  const StateView({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = UiTokens.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: iconColor ?? tokens.muted),
              const SizedBox(height: Gap.lg),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: Gap.sm),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Gap.xl),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: AppButtonVariant.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({this.label = 'Loading', super.key});

  /// Read by screen readers; not shown.
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: label,
      child: const CircularProgressIndicator(),
    ),
  );
}

/// Nothing here *yet*. Say what will appear and, when possible, offer the
/// action that creates the first item.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => StateView(
    icon: icon,
    title: title,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

class OfflineState extends StatelessWidget {
  const OfflineState({this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => StateView(
    icon: Icons.wifi_off_outlined,
    title: "Can't reach the server",
    message: 'Check your connection and try again.',
    actionLabel: 'Try again',
    onAction: onRetry,
  );
}

class SignInRequiredState extends StatelessWidget {
  const SignInRequiredState({this.onSignIn, super.key});

  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) => StateView(
    icon: Icons.lock_outline,
    title: 'Sign in required',
    message: 'Sign in to see this.',
    actionLabel: 'Sign in',
    onAction: onSignIn,
  );
}

/// Turns any error into the right state. Never shows a raw exception:
/// network → [OfflineState], no user → [SignInRequiredState], everything
/// else → a generic message with retry.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => switch (error) {
    ApiNetworkException() => OfflineState(onRetry: onRetry),
    ApiUnauthenticatedException() => const SignInRequiredState(),
    _ => StateView(
      icon: Icons.error_outline,
      iconColor: UiTokens.of(context).danger,
      title: 'Something went wrong',
      message: 'This is on our side. Try again in a moment.',
      actionLabel: 'Try again',
      onAction: onRetry,
    ),
  };
}
