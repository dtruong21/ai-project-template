import 'package:flutter/material.dart';

/// Circle with the person's initials. Purely decorative for screen readers —
/// put the name in text next to it.
class AppAvatar extends StatelessWidget {
  const AppAvatar({required this.name, this.size = 40, super.key});

  final String name;
  final double size;

  /// Up to two initials; `?` when the name is blank.
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    final letters = words.length == 1
        ? [words.first.characters.first]
        : [words.first.characters.first, words.last.characters.first];
    return letters.join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(
          initialsOf(name),
          style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
