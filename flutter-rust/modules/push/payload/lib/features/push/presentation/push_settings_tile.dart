import 'package:app/core/api/api_exception.dart';
import 'package:app/core/ui/ui.dart';
import 'package:app/features/push/application/push_provider.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "Notifications" switch for the settings screen.
class PushSettingsTile extends ConsumerStatefulWidget {
  const PushSettingsTile({super.key});

  @override
  ConsumerState<PushSettingsTile> createState() => _PushSettingsTileState();
}

class _PushSettingsTileState extends ConsumerState<PushSettingsTile> {
  bool _busy = false;

  Future<void> _toggle({required bool on}) async {
    setState(() => _busy = true);
    try {
      final controller = ref.read(pushControllerProvider.notifier);
      if (on) {
        await controller.enable();
      } else {
        await controller.disable();
      }
    } on Object catch (e) {
      if (mounted) showError(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Words a user can act on — never a raw exception.
  String _message(Object error) => switch (error) {
    ApiUnauthenticatedException() => 'Sign in to turn on notifications.',
    ApiNetworkException() =>
      "Can't reach the server. Notifications were not changed.",
    FirebaseException(code: 'apns-token-not-set') =>
      "This device can't receive notifications (the iOS Simulator can't).",
    ApiResponseException(isValidation: true, :final message) => message,
    _ => "Couldn't change notifications. Try again.",
  };

  @override
  Widget build(BuildContext context) {
    final push = ref.watch(pushControllerProvider);
    final state = push.value;
    final subtitle = switch (push) {
      AsyncValue(hasError: true) => "Couldn't check notification status",
      AsyncValue(value: PushState(available: false)) =>
        'Available once Firebase is set up',
      AsyncValue(value: PushState(denied: true)) =>
        'Turned off in system settings',
      _ => 'Get notified about activity',
    };
    final usable = state != null && state.available && !state.denied && !_busy;

    return SwitchListTile(
      secondary: _busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.notifications_outlined),
      title: const Text('Notifications'),
      subtitle: Text(subtitle),
      value: state?.enabled ?? false,
      onChanged: usable ? (on) => _toggle(on: on) : null,
    );
  }
}
