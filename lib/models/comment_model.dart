import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String authorUid;
  final String authorName;
  final String authorRole;
  final String text;
  final DateTime createdAt;
  final String visibility; // 'everyone' | 'staff'

  const CommentModel({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.createdAt,
    this.visibility = 'everyone',
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      authorUid: d['authorUid'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      authorRole: d['authorRole'] ?? '',
      text: d['text'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      visibility: d['visibility'] ?? 'everyone',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'authorRole': authorRole,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'visibility': visibility,
      };
}
