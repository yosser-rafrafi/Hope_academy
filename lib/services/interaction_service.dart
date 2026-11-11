import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';

class InteractionService {
  final _db = FirebaseFirestore.instance;

  CollectionReference _announcementsCol() => _db.collection('announcements');

  // ── Reaction Streams ──────────────────────────────────────────────────────

  /// Streams the reaction counts map from the announcement document.
  Stream<Map<String, int>> streamReactionCounts(String announcementId) {
    return _announcementsCol()
        .doc(announcementId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <String, int>{};
      final d = doc.data() as Map<String, dynamic>;
      final rawReactions = d['reactionCounts'];
      if (rawReactions == null) return <String, int>{};
      final raw = rawReactions as Map<String, dynamic>;
      return Map<String, int>.from(
        raw.map((k, v) => MapEntry(k, (v as num).toInt())),
      );
    });
  }

  /// Streams the current user's active reaction emoji for an announcement.
  /// Emits null when the user has no reaction.
  Stream<String?> streamUserReaction(
      String announcementId, String userId) {
    return _announcementsCol()
        .doc(announcementId)
        .collection('reactions')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      return data?['emoji']?.toString();
    });
  }

  // ── Comment Stream ────────────────────────────────────────────────────────

  /// Streams the live comment count from the announcement document.
  Stream<int> streamCommentCount(String announcementId) {
    return _announcementsCol()
        .doc(announcementId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 0;
      final d = doc.data() as Map<String, dynamic>;
      return (d['commentCount'] as num?)?.toInt() ?? 0;
    });
  }

  /// Streams the list of comments for an announcement, ordered by createdAt ascending.
  /// Staff-only comments are hidden from parents/students (except their own).
  Stream<List<CommentModel>> streamComments(String announcementId,
      {UserModel? viewer}) {
    return _announcementsCol()
        .doc(announcementId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map(CommentModel.fromFirestore)
            .where((c) =>
                c.visibility != 'staff' ||
                viewer == null ||
                viewer.role != UserRole.student ||
                c.authorUid == viewer.uid)
            .toList());
  }

  // ── Reaction Write ────────────────────────────────────────────────────────

  /// Sets or removes a user's reaction using a single atomic WriteBatch.
  ///
  /// - [emoji] null means remove reaction.
  /// - [previousEmoji] is the emoji the user previously had (to decrement).
  Future<void> setReaction({
    required String announcementId,
    required String userId,
    required String? emoji,
    required String? previousEmoji,
  }) async {
    final batch = _db.batch();
    final reactionDoc = _announcementsCol()
        .doc(announcementId)
        .collection('reactions')
        .doc(userId);
    final announcementDoc =
        _announcementsCol().doc(announcementId);

    // Step 1: set or delete the user's reaction document
    if (emoji != null) {
      batch.set(reactionDoc, {
        'emoji': emoji,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.delete(reactionDoc);
    }

    // Step 2: decrement previous emoji count
    if (previousEmoji != null) {
      batch.update(announcementDoc, {
        'reactionCounts.$previousEmoji': FieldValue.increment(-1),
      });
    }

    // Step 3: increment new emoji count
    if (emoji != null) {
      batch.update(announcementDoc, {
        'reactionCounts.$emoji': FieldValue.increment(1),
      });
    }

    await batch.commit();
  }

  // ── Comment Writes ────────────────────────────────────────────────────────

  /// Adds a new comment to the announcement's comments sub-collection
  /// and atomically increments commentCount on the announcement document.
  Future<void> addComment({
    required String announcementId,
    required String authorUid,
    required String authorName,
    required String authorRole,
    required String text,
    String visibility = 'everyone',
  }) async {
    final comment = CommentModel(
      id: '',
      authorUid: authorUid,
      authorName: authorName,
      authorRole: authorRole,
      text: text,
      createdAt: DateTime.now(),
      visibility: visibility,
    );

    final batch = _db.batch();

    // Add the comment document
    final commentRef = _announcementsCol()
        .doc(announcementId)
        .collection('comments')
        .doc();
    batch.set(commentRef, comment.toFirestore());

    // Increment commentCount on the parent announcement
    batch.update(_announcementsCol().doc(announcementId), {
      'commentCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Deletes a comment from the announcement's comments sub-collection
  /// and atomically decrements commentCount on the announcement document.
  Future<void> deleteComment({
    required String announcementId,
    required String commentId,
  }) async {
    final batch = _db.batch();

    // Delete the comment document
    batch.delete(_announcementsCol()
        .doc(announcementId)
        .collection('comments')
        .doc(commentId));

    // Decrement commentCount on the parent announcement (floor at 0)
    // We use a transaction to avoid going below zero
    await batch.commit();

    // Decrement separately to avoid going below 0
    await _db.runTransaction((txn) async {
      final announcementRef = _announcementsCol().doc(announcementId);
      final snap = await txn.get(announcementRef);
      if (!snap.exists) return;
      final current = ((snap.data() as Map<String, dynamic>)['commentCount'] as num?)?.toInt() ?? 0;
      txn.update(announcementRef, {
        'commentCount': current > 0 ? FieldValue.increment(-1) : 0,
      });
    });
  }

  /// Updates the text of an existing comment.
  Future<void> updateComment({
    required String announcementId,
    required String commentId,
    required String newText,
  }) async {
    await _announcementsCol()
        .doc(announcementId)
        .collection('comments')
        .doc(commentId)
        .update({'text': newText});
  }
}
