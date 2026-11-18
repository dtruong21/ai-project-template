import 'package:app/core/api/api_exception.dart';
import 'package:app/core/ui/ui.dart';
import 'package:app/features/settings/application/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showProfileEditSheet(BuildContext context, {String? current}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // lets the sheet rise above the keyboard
    showDragHandle: true,
    builder: (_) => _ProfileEditSheet(current: current),
  );
}

class _ProfileEditSheet extends ConsumerStatefulWidget {
  const _ProfileEditSheet({required this.current});

  final String? current;

  @override
  ConsumerState<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<_ProfileEditSheet> {
  late final _name = TextEditingController(text: widget.current);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).save(_name.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(context, 'Saved');
    } on Object catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Words a user can act on — never a raw exception.
  String _message(Object error) => switch (error) {
    ApiUnauthenticatedException() => 'Sign in to save your name.',
    ApiNetworkException() => "Can't reach the server. Try again.",
    ApiResponseException(isValidation: true, :final message) => message,
    ApiResponseException() => "Couldn't save. Try again.",
    // Rust validation, thrown before any request; user-facing by contract.
    _ => error.toString(),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        Gap.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your name', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _name,
            enabled: !_saving,
            autofocus: true,
            maxLength: 50,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Display name',
              errorText: _error,
            ),
          ),
          const SizedBox(height: Gap.lg),
          AppButton(
            label: 'Save',
            expand: true,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
