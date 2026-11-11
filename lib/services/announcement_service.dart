import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement_model.dart';
import '../models/user_model.dart';

class AnnouncementService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('announcements');

  /// Pass [viewer] so audience restrictions (staff only, parents only…) apply.
  Stream<List<AnnouncementModel>> streamAnnouncements({UserModel? viewer}) {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) {
        return _getMockAnnouncements();
      }
      return snap.docs
          .map(AnnouncementModel.fromFirestore)
          .where((a) => a.isVisibleTo(viewer))
          .toList();
    }).handleError((_) => _getMockAnnouncements());
  }

  Future<void> create(AnnouncementModel announcement) async {
    await _col.add(announcement.toFirestore());
  }

  Future<void> update(String id,
      {required String title,
      required String content,
      required String category,
      required bool isPinned,
      String? targetRole,
      List<String>? mediaUrls}) async {
    await _col.doc(id).update({
      'title': title,
      'content': content,
      'category': category,
      'isPinned': isPinned,
      if (targetRole != null) 'targetRole': targetRole,
      if (mediaUrls != null) 'mediaUrls': mediaUrls,
    });
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  List<AnnouncementModel> _getMockAnnouncements() {
    final now = DateTime.now();
    return [
      AnnouncementModel(
        id: 'mock-1',
        title: 'Welcome to the New School Term at Hope Academy! 🎓',
        content:
            'We are excited to welcome all our parents, teachers, and students to a new term full of growth, learning, and progress. Please ensure student medical profiles are kept up to date.',
        category: 'general',
        authorName: 'Hope Academy Administration',
        authorRole: 'Admin',
        createdAt: now.subtract(const Duration(hours: 2)),
        isPinned: true,
      ),
      AnnouncementModel(
        id: 'mock-2',
        title: 'Parent-Teacher Consultations Scheduled 🗓️',
        content:
            'Individual consultation meetings for student progress and therapeutic objectives will be held this Thursday. Please check your assigned slot in the parent portal.',
        category: 'event',
        authorName: 'Academic Coordination',
        authorRole: 'Sub-Admin',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      AnnouncementModel(
        id: 'mock-3',
        title: 'Specialized Activity Day & Sensory Workshop 🎨',
        content:
            'Join us this Friday for a hands-on sensory integration workshop designed to boost motor skills and emotional expression.',
        category: 'academic',
        authorName: 'Therapy & Support Team',
        authorRole: 'Teacher',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }
}
