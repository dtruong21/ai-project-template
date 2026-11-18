import 'package:app/core/ui/ui_tokens.dart';
import 'package:flutter/material.dart';

enum AppButtonVariant {
  /// The one main action on a screen.
  primary,

  /// Alternative actions next to a primary one.
  secondary,

  /// Low-emphasis actions: "Cancel", "Skip", inline links.
  text,

  /// Irreversible actions: "Delete account". Always behind a `confirm()`.
  danger,
}

/// The app's button. Use this instead of Material buttons directly so every
/// action gets the loading state and the minimum touch target for free.
///
/// While [loading] the button is disabled, shows a spinner, and **keeps its
/// width** — the layout never jumps and a double tap can't submit twice.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
    super.key,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;

  /// Fill the available width (forms, sheets). Default hugs the label.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = UiTokens.of(context);
    // While loading the button keeps its colors (it is busy, not disabled);
    // taps are swallowed by the IgnorePointer below.
    final onTap = loading && onPressed != null ? () {} : onPressed;
    final spinnerColor = switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.danger => scheme.onError,
      AppButtonVariant.secondary || AppButtonVariant.text => scheme.primary,
    };

    // Spinner is stacked over the (invisible) label so the size is unchanged.
    final content = Stack(
      alignment: Alignment.center,
      children: [
        Visibility.maintain(
          visible: !loading,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: Gap.sm),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        if (loading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          ),
      ],
    );

    const minSize = Size(Gap.touchTarget, Gap.touchTarget);
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(minimumSize: minSize),
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: minSize),
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: minSize),
        child: content,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          backgroundColor: tokens.danger,
          foregroundColor: scheme.onError,
        ),
        child: content,
      ),
    };

    return Semantics(
      // Screen readers announce "busy" instead of a silent disabled button.
      label: loading ? '$label, loading' : null,
      child: IgnorePointer(
        ignoring: loading,
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
