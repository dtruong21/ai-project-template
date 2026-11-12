/// Event registry — the typed source of truth in code.
///
/// Every event the app can fire is declared here as a subclass of the sealed
/// `AppEvent` class. If an event isn't in the hierarchy, it can't be passed
/// to `track()` — the compiler rejects it. This is intentional: it keeps the
/// analytics surface bounded.
///
/// Mirror in human-readable form: docs/TRACKING-PLAN.md
/// Add new events via `/track <event_name>` — it updates both files.
///
/// Discipline:
/// - Names: `noun_verb` past-tense, snake_case.
/// - Properties: scalars only. No nested objects.
/// - No PII as property values — reference by user_id only.
library;

// ─── Base ────────────────────────────────────────────────────────────────────

/// The closed family of analytics events. `sealed` forces every event to live
/// in this file (or be `part of` it), which keeps the registry auditable.
sealed class AppEvent {
  const AppEvent();

  /// The event name fired to the analytics provider. snake_case past-tense.
  String get name;

  /// Scalar-only property map. No nested maps, no PII.
  Map<String, Object?> get props;
}

// ─── Universal events ────────────────────────────────────────────────────────

final class AppOpened extends AppEvent {
  const AppOpened({required this.isColdStart});
  final bool isColdStart;

  @override
  String get name => 'app_opened';

  @override
  Map<String, Object?> get props => {'is_cold_start': isColdStart};
}

/// Auth methods. Keep in sync with `SigninMethod` if you split the two.
enum SignupMethod { email, google, apple, anonymous }

final class SignupCompleted extends AppEvent {
  const SignupCompleted({required this.method});
  final SignupMethod method;

  @override
  String get name => 'signup_completed';

  @override
  Map<String, Object?> get props => {'method': method.name};
}

enum SigninMethod { email, google, apple }

final class SigninCompleted extends AppEvent {
  const SigninCompleted({required this.method});
  final SigninMethod method;

  @override
  String get name => 'signin_completed';

  @override
  Map<String, Object?> get props => {'method': method.name};
}

final class SignoutCompleted extends AppEvent {
  const SignoutCompleted();

  @override
  String get name => 'signout_completed';

  @override
  Map<String, Object?> get props => const {};
}

final class FeedbackSubmitted extends AppEvent {
  const FeedbackSubmitted({required this.category, required this.lengthChars});

  /// One of 'bug' | 'idea' | 'praise' | 'other'. Kept as a String here so
  /// feature code doesn't have to import the feature enum; the feature owns
  /// validation at its call site.
  final String category;
  final int lengthChars;

  @override
  String get name => 'feedback_submitted';

  @override
  Map<String, Object?> get props => {
        'category': category,
        'length_chars': lengthChars,
      };
}

// ─── Project-specific events (extend below — keep this section growing) ──────
//
// Example: uncomment and adapt.
//
// final class HabitCreated extends AppEvent {
//   const HabitCreated({required this.schedule, required this.hasReminder});
//   final String schedule;     // 'daily' | 'weekdays' | 'custom'
//   final bool hasReminder;
//
//   @override
//   String get name => 'habit_created';
//
//   @override
//   Map<String, Object?> get props => {
//         'schedule': schedule,
//         'has_reminder': hasReminder,
//       };
// }

// ─── User properties registry ────────────────────────────────────────────────

/// Sparse by design. Add a property only when it drives segmentation or is
/// needed for cross-event analysis. Set via `identify()` in `client.dart`.
///
/// All fields nullable — `identify()` merges; pass only what you're updating.
class UserProperties {
  const UserProperties({
    this.signupDate,
    this.signupMethod,
    this.appVersion,
    this.platform,
  });

  final String? signupDate; // ISO date
  final SignupMethod? signupMethod;
  final String? appVersion; // semver
  final String? platform; // 'ios' | 'android' | 'web'

  Map<String, Object?> toMap() => {
        if (signupDate != null) 'signup_date': signupDate,
        if (signupMethod != null) 'signup_method': signupMethod!.name,
        if (appVersion != null) 'app_version': appVersion,
        if (platform != null) 'platform': platform,
      };
}
