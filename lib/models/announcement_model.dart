import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final String category; // 'general', 'urgent', 'event', 'academic'
  final String authorName;
  final String authorRole;
  final DateTime createdAt;
  final String targetRole; // 'all', 'teacher', 'student'
  final bool isPinned;
  final Map<String, int> reactionCounts;
  final int commentCount;
  final List<String> mediaUrls;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    this.targetRole = 'all',
    this.isPinned = false,
    this.reactionCounts = const {},
    this.commentCount = 0,
    this.mediaUrls = const [],
  });

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AnnouncementModel(
      id: doc.id,
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      category: d['category'] ?? 'general',
      authorName: d['authorName'] ?? 'Hope Academy Admin',
      authorRole: d['authorRole'] ?? 'Admin',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      targetRole: d['targetRole'] ?? 'all',
      isPinned: d['isPinned'] ?? false,
      reactionCounts: Map<String, int>.from(
        (d['reactionCounts'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      ),
      commentCount: (d['commentCount'] as num?)?.toInt() ?? 0,
      mediaUrls: List<String>.from(d['mediaUrls'] ?? const []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'content': content,
        'category': category,
        'authorName': authorName,
        'authorRole': authorRole,
        'createdAt': Timestamp.fromDate(createdAt),
        'targetRole': targetRole,
        'isPinned': isPinned,
        'mediaUrls': mediaUrls,
        // reactionCounts and commentCount are intentionally omitted —
        // they are managed exclusively by InteractionService
      };

  AnnouncementModel copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    String? authorName,
    String? authorRole,
    DateTime? createdAt,
    String? targetRole,
    bool? isPinned,
    Map<String, int>? reactionCounts,
    int? commentCount,
    List<String>? mediaUrls,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      createdAt: createdAt ?? this.createdAt,
      targetRole: targetRole ?? this.targetRole,
      isPinned: isPinned ?? this.isPinned,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      commentCount: commentCount ?? this.commentCount,
      mediaUrls: mediaUrls ?? this.mediaUrls,
    );
  }

  /// Audience values stored in [targetRole]:
  ///  all      → everyone
  ///  staff    → admins, sub-admins and teachers
  ///  teacher  → teachers (+ admins)
  ///  student  → parents & students (+ admins)
  bool isVisibleTo(UserModel? viewer) {
    if (viewer == null) return targetRole == 'all';
    if (viewer.fullName == authorName) return true; // author
    switch (viewer.role) {
      case UserRole.admin:
      case UserRole.subAdmin:
        return true;
      case UserRole.teacher:
        return targetRole == 'all' ||
            targetRole == 'staff' ||
            targetRole == 'teacher';
      case UserRole.student:
        return targetRole == 'all' || targetRole == 'student';
    }
  }
}
