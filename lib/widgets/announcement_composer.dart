import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';
import '../models/announcement_model.dart';
import '../models/user_model.dart';
import '../services/announcement_service.dart';
import '../services/storage_service.dart';
import 'kid_ui.dart';
import 'media_widgets.dart';

/// Create (or edit, when [existing] is given) a publication:
/// text, category, audience (who can see it), photos & videos, pin.
class AnnouncementComposer extends StatefulWidget {
  final UserModel author;
  final AnnouncementModel? existing;
  const AnnouncementComposer({super.key, required this.author, this.existing});

  static Future<void> show(BuildContext context,
      {required UserModel author, AnnouncementModel? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnnouncementComposer(author: author, existing: existing),
    );
  }

  @override
  State<AnnouncementComposer> createState() => _AnnouncementComposerState();
}

class _AnnouncementComposerState extends State<AnnouncementComposer> {
  final _service = AnnouncementService();
  final _storage = StorageService();
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _content =
      TextEditingController(text: widget.existing?.content ?? '');
  late String _category = widget.existing?.category ?? 'general';
  late String _audience = widget.existing?.targetRole ?? 'all';
  late bool _pinned = widget.existing?.isPinned ?? false;
  late List<String> _oldMedia = List.of(widget.existing?.mediaUrls ?? const []);
  List<XFile> _newMedia = [];
  bool _saving = false;
  double _progress = 0;

  static const _cats = [
    ('general', '📣', 'General', AppColors.sky),
    ('event', '🎉', 'Event', AppColors.grape),
    ('academic', '📚', 'Academic', AppColors.mint),
    ('urgent', '🚨', 'Urgent', AppColors.coral),
  ];
  static const _audiences = [
    ('all', Icons.public_rounded, 'Everyone'),
    ('student', Icons.family_restroom_rounded, 'Parents & students'),
    ('staff', Icons.badge_rounded, 'Staff only'),
    ('teacher', Icons.school_rounded, 'Teachers'),
  ];

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a title and a message')));
      return;
    }
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uploaded = _newMedia.isEmpty
          ? <String>[]
          : await _storage.uploadAll(
              folder: 'announcement_media/${widget.author.uid}',
              files: _newMedia,
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
            );
      final media = [..._oldMedia, ...uploaded];
      if (widget.existing == null) {
        await _service.create(AnnouncementModel(
          id: '',
          title: _title.text.trim(),
          content: _content.text.trim(),
          category: _category,
          authorName: widget.author.fullName,
          authorRole: widget.author.role.label,
          createdAt: DateTime.now(),
          targetRole: _audience,
          isPinned: _pinned,
          mediaUrls: media,
        ));
      } else {
        await _service.update(
          widget.existing!.id,
          title: _title.text.trim(),
          content: _content.text.trim(),
          category: _category,
          isPinned: _pinned,
          targetRole: _audience,
          mediaUrls: media,
        );
      }
      nav.pop();
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
          content: Text('Could not publish: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: context.divider, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(children: [
              Expanded(
                child: Text(editing ? 'Edit post' : 'New post ✨',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: context.textPrimary)),
              ),
              IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: context.textSecondary)),
            ]),
          ),
          if (_saving)
            LinearProgressIndicator(value: _newMedia.isEmpty ? null : _progress),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
              children: [
                TextField(
                  controller: _title,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Title', hintText: 'e.g. Sports day on Friday!'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _content,
                  enabled: !_saving,
                  minLines: 4,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Message', alignLabelWithHint: true),
                ),
                const SizedBox(height: 18),
                const SectionTitle(
                    title: 'Category', icon: Icons.category_rounded, color: AppColors.grape),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _cats.map((c) {
                    final sel = _category == c.$1;
                    return ChoiceChip(
                      label: Text('${c.$2} ${c.$3}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : context.textPrimary)),
                      selected: sel,
                      showCheckmark: false,
                      selectedColor: c.$4,
                      onSelected: _saving ? null : (_) => setState(() => _category = c.$1),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const SectionTitle(
                    title: 'Who can see it?',
                    icon: Icons.visibility_rounded,
                    color: AppColors.sky),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _audiences.map((a) {
                    final sel = _audience == a.$1;
                    return ChoiceChip(
                      avatar: Icon(a.$2,
                          size: 16, color: sel ? Colors.white : context.textSecondary),
                      label: Text(a.$3,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : context.textPrimary)),
                      selected: sel,
                      showCheckmark: false,
                      selectedColor: AppAudienceColors.of(a.$1),
                      onSelected: _saving ? null : (_) => setState(() => _audience = a.$1),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const SectionTitle(
                    title: 'Photos & videos',
                    icon: Icons.perm_media_rounded,
                    color: AppColors.mint),
                const SizedBox(height: 10),
                if (_oldMedia.isNotEmpty) ...[
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _oldMedia.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(clipBehavior: Clip.none, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 70,
                            height: 70,
                            child: StorageService.isVideoUrl(_oldMedia[i])
                                ? Container(
                                    color: AppColors.grape.withValues(alpha: 0.25),
                                    child: const Icon(Icons.videocam, color: AppColors.grape))
                                : Image.network(_oldMedia[i], fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => setState(() => _oldMedia.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: AppColors.coral, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                MediaPickerField(
                  files: _newMedia,
                  enabled: !_saving,
                  onChanged: (f) => setState(() => _newMedia = f),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('📌 Pin to top',
                      style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
                  value: _pinned,
                  onChanged: _saving ? null : (v) => setState(() => _pinned = v),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(editing ? 'Save changes' : 'Publish'),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class AppAudienceColors {
  static Color of(String a) {
    switch (a) {
      case 'staff':
        return AppColors.grape;
      case 'teacher':
        return const Color(0xFF2FAE85);
      case 'student':
        return const Color(0xFFE69A1B);
      default:
        return const Color(0xFF2E9BD6);
    }
  }
}
