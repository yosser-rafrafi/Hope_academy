import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/announcement_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/announcement_service.dart';
import 'announcement_composer.dart';
import 'announcement_share_sheet.dart';
import 'comment_thread_widget.dart';
import 'interaction_bar_widget.dart';
import 'kid_ui.dart';
import 'media_widgets.dart';

class AnnouncementsFeedWidget extends StatefulWidget {
  final bool compact;
  const AnnouncementsFeedWidget({super.key, this.compact = false});

  @override
  State<AnnouncementsFeedWidget> createState() =>
      _AnnouncementsFeedWidgetState();
}

class _AnnouncementsFeedWidgetState extends State<AnnouncementsFeedWidget> {
  final AnnouncementService _service = AnnouncementService();
  String? _expandedCommentAnnouncementId;
  Stream<List<AnnouncementModel>>? _stream;
  String? _streamUid;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final canCreate = user != null && user.role != UserRole.student;

    // keep one stream per user (avoid re-subscribing on every rebuild)
    if (_stream == null || _streamUid != user?.uid) {
      _streamUid = user?.uid;
      _stream = _service.streamAnnouncements(viewer: user);
    }

    return StreamBuilder<List<AnnouncementModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator.adaptive(),
            ),
          );
        }

        final items = List<AnnouncementModel>.of(snapshot.data ?? [])
          ..sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            return b.createdAt.compareTo(a.createdAt);
          });

        final header = Row(children: [
          Expanded(
            child: SectionTitle(
              title: 'Announcements & News',
              icon: Icons.campaign_rounded,
              color: AppColors.coral,
            ),
          ),
          if (canCreate && !widget.compact)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New post'),
              onPressed: () => AnnouncementComposer.show(context, author: user!),
            ),
        ]);

        if (items.isEmpty) {
          return Column(children: [
            header,
            const EmptyState(
              emoji: '📭',
              title: 'No announcements yet',
              subtitle: 'News from the school will appear here.',
            ),
          ]);
        }

        final display = widget.compact ? items.take(2).toList() : items;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: display.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) => FadeSlideIn(
                key: ValueKey(display[i].id),
                delay: Duration(milliseconds: 70 * i.clamp(0, 6)),
                child: _buildCard(context, display[i], canCreate, user),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, AnnouncementModel item,
      bool isStaff, UserModel? user) {
    final (color, label, icon) = _categoryStyle(item.category);
    final isMock = item.id.startsWith('mock');
    final dark = context.isDark;
    final fg = dark ? color : HSLColor.fromColor(color).withLightness(0.32).toColor();

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: item.isPinned ? AppColors.sun : context.divider,
          width: item.isPinned ? 1.6 : 1,
        ),
        boxShadow: context.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // coloured category strip
          Container(height: 5, color: color),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Text(
                      item.authorName.isNotEmpty ? item.authorName[0].toUpperCase() : '?',
                      style: TextStyle(fontWeight: FontWeight.w800, color: fg),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: context.textPrimary)),
                        Text('${item.authorRole} • ${_timeAgo(item.createdAt)}',
                            style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
                      ],
                    ),
                  ),
                  if (item.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Text('📌', style: TextStyle(fontSize: 16)),
                    ),
                  if (!isMock)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, color: context.textSecondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onSelected: (v) {
                        if (v == 'share') AnnouncementShareSheet.show(context, item);
                        if (v == 'edit' && user != null) {
                          AnnouncementComposer.show(context, author: user, existing: item);
                        }
                        if (v == 'delete') _confirmDelete(context, item);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'share',
                            child: ListTile(
                                dense: true,
                                leading: Icon(Icons.ios_share_rounded),
                                title: Text('Share'))),
                        if (_canEdit(user, item))
                          const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Edit'))),
                        if (_canEdit(user, item))
                          const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.delete_outline, color: AppColors.error),
                                  title: Text('Delete'))),
                      ],
                    ),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 12, color: fg),
                      const SizedBox(width: 4),
                      Text(label,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
                    ]),
                  ),
                  if (isStaff || item.targetRole != 'all')
                    AudienceBadge(audience: item.targetRole),
                ]),
                const SizedBox(height: 10),
                Text(item.title,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary)),
                const SizedBox(height: 6),
                Text(item.content,
                    style: TextStyle(fontSize: 14, height: 1.45, color: context.textSecondary)),
                if (item.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  MediaGallery(urls: item.mediaUrls, height: 170),
                ],
              ],
            ),
          ),
          if (user != null) ...[
            Divider(height: 1, color: context.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(children: [
                Expanded(
                  child: InteractionBarWidget(
                    announcementId: item.id,
                    initialReactionCounts: item.reactionCounts,
                    initialCommentCount: item.commentCount,
                    currentUser: user,
                    onCommentToggle: () => setState(() {
                      _expandedCommentAnnouncementId =
                          _expandedCommentAnnouncementId == item.id ? null : item.id;
                    }),
                  ),
                ),
                IconButton(
                  tooltip: 'Share',
                  icon: Icon(Icons.ios_share_rounded, size: 20, color: context.brand),
                  onPressed: () => AnnouncementShareSheet.show(context, item),
                ),
              ]),
            ),
          ],
          if (user != null && _expandedCommentAnnouncementId == item.id)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: CommentThreadWidget(announcementId: item.id, currentUser: user),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AnnouncementModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete this post?'),
        content: const Text('This also removes its comments and reactions from the feed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _service.delete(item.id);
  }

  (Color, String, IconData) _categoryStyle(String cat) {
    switch (cat) {
      case 'urgent':
        return (AppColors.coral, 'Urgent', Icons.warning_rounded);
      case 'event':
        return (AppColors.grape, 'Event', Icons.celebration_rounded);
      case 'academic':
        return (AppColors.mint, 'Academic', Icons.school_rounded);
      default:
        return (AppColors.sky, 'General', Icons.campaign_rounded);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  bool _canEdit(UserModel? user, AnnouncementModel item) {
    if (user == null || item.id.startsWith('mock')) return false;
    return user.role == UserRole.admin ||
        user.role == UserRole.subAdmin ||
        user.fullName == item.authorName;
  }
}
