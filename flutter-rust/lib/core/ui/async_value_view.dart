import 'package:app/core/ui/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders an [AsyncValue] with all four states handled — the standing rule
/// "empty / loading / error / offline ship with every feature", enforced by
/// construction instead of by review.
///
/// ```dart
/// AsyncValueView(
///   value: ref.watch(thingsProvider),
///   onRetry: () => ref.invalidate(thingsProvider),
///   isEmpty: (things) => things.isEmpty,
///   empty: const EmptyState(title: 'No things yet'),
///   data: (things) => ThingsList(things),
/// )
/// ```
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  /// When this returns true for loaded data, [empty] is shown instead.
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    // On refresh keep showing the previous data instead of flashing a spinner.
    if (value.hasValue && !value.hasError) {
      final loaded = value.requireValue;
      if (empty != null && (isEmpty?.call(loaded) ?? false)) return empty!;
      return data(loaded);
    }
    if (value.hasError) {
      return ErrorState(error: value.error!, onRetry: onRetry);
    }
    return const LoadingState();
  }
}
