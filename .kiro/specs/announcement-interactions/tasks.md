# Implementation Plan: announcement-interactions

## Overview

Extend the Hope Academy announcement feed with emoji reactions and threaded comments. The implementation is additive — existing `AnnouncementModel`, `AnnouncementService`, and `AnnouncementsFeedWidget` are extended rather than replaced. New components (`InteractionService`, `CommentModel`, `ReactionPickerWidget`, `InteractionBarWidget`, `CommentThreadWidget`) are added incrementally and wired together in the final step.

All Firestore paths, field names, and widget interfaces follow the design document exactly. Optimistic UI is used for reactions; comment writes are non-optimistic with real-time stream updates.

---

## Tasks

- [x] 1. Extend `AnnouncementModel` with interaction fields
  - Add `reactionCounts` (`Map<String, int>`) and `commentCount` (`int`) fields to `AnnouncementModel` in `lib/models/announcement_model.dart`
  - Update the constructor with defaults: `reactionCounts = const {}`, `commentCount = 0`
  - Update `fromFirestore` to parse `reactionCounts` as `Map<String, int>.from(...)` with null-safe fallback to `{}`, and `commentCount` with fallback to `0`
  - Update `toFirestore` to **omit** both fields (they are managed exclusively by `InteractionService`)
  - Add a `copyWith` method to `AnnouncementModel` that supports updating `reactionCounts` and `commentCount`
  - _Requirements: 1.1, 5.3, 5.4_

- [x] 2. Create `CommentModel`
  - Create `lib/models/comment_model.dart` with the `CommentModel` class matching the design's full Dart definition
  - Implement `CommentModel.fromFirestore(DocumentSnapshot doc)` parsing `authorUid`, `authorName`, `authorRole`, `text`, and `createdAt`
  - Implement `toFirestore()` returning the map with `FieldValue.serverTimestamp()` for `createdAt`
  - Ensure all fields are `final` and the constructor uses `required` named parameters
  - _Requirements: 2.4, 5.2_

  - [ ]* 2.1 Write property test for `CommentModel` serialization round-trip
    - **Property 4: Comment text round-trip** — for any valid (non-empty, non-whitespace) string, `fromFirestore(toFirestore(comment)).text == original`
    - Use `fast_check` with a minimum of 100 iterations; tag: `// Feature: announcement-interactions, Property 4`
    - **Validates: Requirements 2.4, 5.2**

- [ ] 3. Implement `InteractionService`
  - Create `lib/services/interaction_service.dart` with the `InteractionService` class
  - [ ] 3.1 Implement reaction streams
    - Implement `streamReactionCounts(String announcementId)` returning `Stream<Map<String, int>>` from `announcements/{id}` document field `reactionCounts`
    - Implement `streamUserReaction(String announcementId, String userId)` returning `Stream<String?>` from `announcements/{id}/reactions/{userId}` document's `emoji` field; emit `null` when document does not exist
    - _Requirements: 1.9, 5.4_

  - [ ] 3.2 Implement comment stream
    - Implement `streamComments(String announcementId)` returning `Stream<List<CommentModel>>` from `announcements/{id}/comments` ordered by `createdAt` ascending
    - Map each `QuerySnapshot` document to `CommentModel.fromFirestore`
    - _Requirements: 2.6, 5.5_

  - [ ]* 3.3 Write property test for comment ordering invariant
    - **Property 6: Comment ordering** — for any sequence of `CommentModel` instances with random `createdAt` values, the stream (tested via the sort helper / comparator logic) always emits them in non-decreasing `createdAt` order
    - Use `fast_check` with a minimum of 100 iterations; tag: `// Feature: announcement-interactions, Property 6`
    - **Validates: Requirements 2.2**

  - [ ] 3.4 Implement `setReaction`
    - Implement `setReaction({required String announcementId, required String userId, required String? emoji, required String? previousEmoji})` using a single `WriteBatch`
    - Batch step 1: set or delete `announcements/{id}/reactions/{userId}` document
    - Batch step 2: `FieldValue.increment(-1)` on `reactionCounts[previousEmoji]` if `previousEmoji != null`
    - Batch step 3: `FieldValue.increment(+1)` on `reactionCounts[emoji]` if `emoji != null`
    - Commit the batch; propagate any thrown `FirebaseException`
    - _Requirements: 1.3, 1.4, 1.5, 4.5, 5.1, 5.3_

  - [ ]* 3.5 Write property tests for reaction count arithmetic
    - **Property 1: Reaction count consistency after set** — after `setReaction` with no prior reaction, count for that emoji increments by 1, others unchanged
    - **Property 2: Reaction toggle** — calling `setReaction` with the same emoji the user already holds results in user reaction = null and count decremented by 1
    - **Property 3: Reaction replace** — calling `setReaction` with a different emoji decrements E1 by 1 and increments E2 by 1, others unchanged
    - Test the arithmetic logic in isolation (pure function over a `Map<String, int>`) using `fast_check` with 100 iterations each; tag each with property number
    - **Validates: Requirements 1.3, 1.4, 1.5, 5.3**

  - [ ] 3.6 Implement `addComment` and `deleteComment`
    - Implement `addComment({required String announcementId, required String authorUid, required String authorName, required String authorRole, required String text})` adding a document to the `comments` sub-collection
    - Implement `deleteComment({required String announcementId, required String commentId})` deleting the comment document; propagate thrown exceptions
    - _Requirements: 2.4, 3.3, 4.1, 4.2, 4.3_

- [ ] 4. Checkpoint — Core data layer complete
  - Ensure unit tests for `AnnouncementModel`, `CommentModel`, and `InteractionService` logic all pass
  - Verify `dart analyze` reports no issues on the three new/modified files
  - Ask the user if questions arise before proceeding to UI.

- [ ] 5. Create `ReactionPickerWidget`
  - Create `lib/widgets/reaction_picker_widget.dart`
  - Render a horizontal row of exactly five `TextButton` emoji buttons: `['👍', '❤️', '😮', '😢', '😡']`
  - Accept a callback `onEmojiSelected(String emoji)` and a `onDismiss` callback
  - The widget is intended to be inserted as an `OverlayEntry`; it renders itself in a `Material` card with rounded corners using `AppColors` tokens
  - Apply a combined `ScaleTransition` + `FadeTransition` driven by an `AnimationController` passed in (or owned internally with `vsync`)
  - _Requirements: 1.2, 6.5_

  - [ ]* 5.1 Write property test for reaction picker emoji completeness
    - **Property (supporting P9): Reaction picker renders exactly the five expected emojis** — build the widget under test and assert the widget tree contains all five emoji strings and nothing outside the allowed set
    - Use `fast_check` or a parameterised widget test; tag: `// Feature: announcement-interactions, Property 9 (picker)`
    - **Validates: Requirements 1.2**

- [ ] 6. Create `InteractionBarWidget`
  - Create `lib/widgets/interaction_bar_widget.dart` as a `StatefulWidget`
  - Accept props: `announcementId`, `initialReactionCounts`, `initialCommentCount`, `currentUser`, `onCommentToggle`
  - On `initState`, subscribe to `InteractionService.streamUserReaction` and `streamReactionCounts`; cancel subscriptions in `dispose`
  - Maintain `_optimisticCounts` (copy of counts for instant UI) and `_optimisticUserEmoji` (current user's emoji) as local state
  - [ ] 6.1 Implement reaction summary display
    - Filter `_optimisticCounts` to only emoji with count > 0
    - Sort filtered entries in descending count order
    - Render each as a `Chip`/pill; highlight the user's active emoji with `AppColors.primary` background
    - When no reactions exist, display a muted "React" prompt label
    - _Requirements: 1.8, 6.1, 6.2, 6.3_

  - [ ]* 6.2 Write property test for reaction summary display ordering
    - **Property 11: Reaction summary shows only non-zero emoji in descending order** — for any arbitrary `reactionCounts` map, the display logic (extracted pure function) returns only emoji with count > 0, sorted non-increasing
    - Use `fast_check` with 100 iterations; tag: `// Feature: announcement-interactions, Property 11`
    - **Validates: Requirements 6.3**

  - [ ] 6.3 Implement reaction button and optimistic write
    - Render a "react" `IconButton` that opens `ReactionPickerWidget` as an `OverlayEntry` anchored above the button
    - On emoji selection: apply optimistic update to `_optimisticCounts` and `_optimisticUserEmoji`, dismiss picker, call `InteractionService.setReaction`
    - On `Future` failure: revert `_optimisticCounts` and `_optimisticUserEmoji` to pre-tap values, show error `SnackBar` using `AppColors.error`
    - Disable all interaction controls (grey out) when `announcementId.startsWith('mock-')`
    - _Requirements: 1.3, 1.4, 1.5, 1.6, 1.7_

  - [ ]* 6.4 Write property test for active reaction highlighting
    - **Property 9: Active reaction highlighting** — for any emoji E in the valid set, when `_optimisticUserEmoji == E`, only the chip for E has a primary-color background; all others do not
    - Widget test driven by `fast_check` picking a random valid emoji; tag: `// Feature: announcement-interactions, Property 9`
    - **Validates: Requirements 1.8**

  - [ ] 6.5 Implement comment count button
    - Render a comment `IconButton` with count label on the right side of the bar
    - On tap: call `onCommentToggle`
    - Update displayed count from `InteractionService` stream in real time
    - _Requirements: 1.1, 2.1, 2.9, 6.1_

- [ ] 7. Checkpoint — Widgets `ReactionPickerWidget` and `InteractionBarWidget` complete
  - Run `flutter test` on widget tests for `ReactionPickerWidget` and `InteractionBarWidget`
  - Verify overlay appears and dismisses, optimistic state updates, and error revert path
  - Ask the user if questions arise before proceeding.

- [ ] 8. Create `CommentThreadWidget`
  - Create `lib/widgets/comment_thread_widget.dart`
  - Accept props: `announcementId`, `currentUser`
  - On `initState`, subscribe to `InteractionService.streamComments(announcementId)`; cancel in `dispose`
  - [ ] 8.1 Implement comment list with `AnimatedSize`
    - Wrap the entire thread in `AnimatedSize(duration: 300ms, curve: Curves.easeInOut)`
    - Render a `Divider` then a `ListView` (shrinkWrap, NeverScrollableScrollPhysics) of `CommentTileWidget` items
    - Display comments in the order emitted by the stream (ascending `createdAt`)
    - _Requirements: 2.1, 2.2, 6.4_

  - [ ] 8.2 Implement `CommentTileWidget` (inline private widget)
    - Show author avatar initial in a `CircleAvatar`, display name, role badge, relative timestamp, and comment text
    - Show delete `IconButton` if `currentUser.role` is `admin` or `subAdmin`, or if `currentUser.uid == comment.authorUid`
    - On delete tap: call `InteractionService.deleteComment`; on failure show error `SnackBar` and keep comment visible
    - _Requirements: 2.7, 3.1, 3.2, 3.3, 3.5_

  - [ ]* 8.3 Write property test for delete icon visibility
    - **Property 10: Delete icon visibility for moderators and comment authors** — for any `CommentModel` and any user: delete icon is present iff the user is admin, sub-admin, or the comment's `authorUid` matches the user's uid; absent for all other combinations
    - Use `fast_check` to generate random user roles and UIDs; tag: `// Feature: announcement-interactions, Property 10`
    - **Validates: Requirements 3.1, 3.2**

  - [ ]* 8.4 Write property test for comment display field completeness
    - **Property 7: Comment display fields completeness** — for any `CommentModel`, the rendered `CommentTileWidget` tree contains the author's display name, role label, comment text, and a non-empty relative timestamp string
    - Use `fast_check` to generate random `CommentModel` instances; tag: `// Feature: announcement-interactions, Property 7`
    - **Validates: Requirements 2.7**

  - [ ] 8.5 Implement `CommentComposeBar`
    - Render a `TextField` with hint "Write a comment…" and a send `IconButton`
    - On send tap: if `text.trim().isEmpty`, keep field focused and do not call service
    - If non-empty: call `InteractionService.addComment`; on success clear the field; on failure show error `SnackBar` and preserve text
    - _Requirements: 2.3, 2.4, 2.5, 2.8_

  - [ ]* 8.6 Write property test for whitespace comment rejection
    - **Property 5: Empty/whitespace comment rejection** — for any string composed entirely of whitespace characters (space, tab, newline, etc.) or the empty string, the validation function returns `false` and `addComment` is never invoked
    - Use `fast_check` with 100 iterations; tag: `// Feature: announcement-interactions, Property 5`
    - **Validates: Requirements 2.5**

  - [ ]* 8.7 Write property test for delete removes from stream
    - **Property 8: Delete removes from stream** — given any list of `CommentModel` items, after removing an item at a random index, the resulting list does not contain that comment's `id`
    - Test the list-filtering logic; tag: `// Feature: announcement-interactions, Property 8`
    - **Validates: Requirements 3.3, 3.4**

- [ ] 9. Checkpoint — `CommentThreadWidget` complete
  - Run `flutter test` on `CommentThreadWidget` widget tests
  - Verify empty-state rendering, real-time additions, delete flow, and whitespace rejection
  - Ask the user if questions arise before proceeding to integration.

- [ ] 10. Integrate all widgets into `AnnouncementsFeedWidget`
  - In `lib/widgets/announcements_feed_widget.dart`, add `String? _expandedCommentAnnouncementId` state variable to `_AnnouncementsFeedWidgetState`
  - In `_buildAnnouncementCard`, append to the card's `Column`:
    - `InteractionBarWidget(announcementId: item.id, initialReactionCounts: item.reactionCounts, initialCommentCount: item.commentCount, currentUser: user!, onCommentToggle: () => setState(() { ... toggle _expandedCommentAnnouncementId ... }))`
    - `if (_expandedCommentAnnouncementId == item.id) CommentThreadWidget(announcementId: item.id, currentUser: user!)`
  - Guard `InteractionBarWidget` and `CommentThreadWidget` from being rendered when `user == null`
  - Ensure that mock announcement cards (`id.startsWith('mock-')`) render `InteractionBarWidget` in a disabled/muted state without crashing
  - Import `interaction_service.dart`, `comment_model.dart`, `interaction_bar_widget.dart`, `comment_thread_widget.dart`
  - _Requirements: 1.1, 2.1, 6.1, 6.4_

- [ ] 11. Final checkpoint — Full integration
  - Run `flutter analyze` across the project; resolve all warnings and errors
  - Run `flutter test` to execute all unit, property, and widget tests; ensure all pass
  - Verify dark-mode rendering: confirm no hard-coded light colours in new widgets by reviewing `AppColors` usage
  - Ask the user if questions arise.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Property tests require adding `fast_check` to `dev_dependencies` in `pubspec.yaml`
- Each property test is tagged with its property number and the requirements clause it validates
- Mock announcements (IDs starting with `'mock-'`) must never trigger Firestore calls; all new widgets must handle this gracefully
- `reactionCounts` and `commentCount` on `AnnouncementModel` are read-only from the Flutter side — `InteractionService` is the sole writer via `WriteBatch`
- The `CommentThreadWidget` is rendered inline (not `showModalBottomSheet`) to preserve scroll context per requirement 6.4
