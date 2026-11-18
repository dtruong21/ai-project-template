import 'package:app/core/api/api_client.dart';
import 'package:app/src/rust/api/feedback.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_feedback_provider.g.dart';

class MyFeedbackState {
  const MyFeedbackState({
    required this.items,
    required this.nextCursor,
    this.loadingMore = false,
  });

  final List<FeedbackItem> items;

  /// `null` when every page has been loaded.
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;
}

/// The signed-in user's own feedback, newest first, loaded a page at a time.
@riverpod
class MyFeedback extends _$MyFeedback {
  static const _path = '/v1/feedback';

  @override
  Future<MyFeedbackState> build() async {
    final page = await _fetch(null);
    return MyFeedbackState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<FeedbackPage> _fetch(String? cursor) async {
    final query = cursor == null
        ? ''
        : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    final body = await ref.read(apiClientProvider).getJson('$_path$query');
    return parseFeedbackPage(json: body);
  }

  /// Appends the next page. A failure keeps what is already on screen and
  /// rethrows so the caller can show a message.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(
      MyFeedbackState(
        items: current.items,
        nextCursor: current.nextCursor,
        loadingMore: true,
      ),
    );
    try {
      final page = await _fetch(current.nextCursor);
      state = AsyncData(
        MyFeedbackState(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object {
      state = AsyncData(current);
      rethrow;
    }
  }

  /// Deletes on the server first, then removes the row locally — the list
  /// never shows something as gone that is not.
  Future<void> remove(String id) async {
    await ref.read(apiClientProvider).delete('$_path/$id');
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      MyFeedbackState(
        items: [
          for (final item in current.items)
            if (item.id != id) item,
        ],
        nextCursor: current.nextCursor,
      ),
    );
  }
}
