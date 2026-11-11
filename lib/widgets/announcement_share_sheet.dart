import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../models/announcement_model.dart';
import '../services/share_service.dart';

/// Bottom sheet: previews a branded picture card of a post and shares it as an
/// image (Instagram / Facebook / WhatsApp stories…) or as text.
class AnnouncementShareSheet extends StatefulWidget {
  final AnnouncementModel post;
  const AnnouncementShareSheet({super.key, required this.post});

  static Future<void> show(BuildContext context, AnnouncementModel post) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnnouncementShareSheet(post: post),
    );
  }

  @override
  State<AnnouncementShareSheet> createState() => _AnnouncementShareSheetState();
}

class _AnnouncementShareSheetState extends State<AnnouncementShareSheet> {
  final _key = GlobalKey();
  bool _busy = false;

  String get _text {
    final p = widget.post;
    return '${p.title}\n\n${p.content}\n\n— Hope Academy Egypt ${ShareService.hashtag}';
  }

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final png = await ShareService.capture(_key);
      await ShareService.sharePng(png, name: 'hope_academy_post', text: _text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grad = _gradient(widget.post.category);
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
                color: context.divider, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 16),
          Text('Share this post',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: context.textPrimary)),
          const SizedBox(height: 14),
          RepaintBoundary(
            key: _key,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(gradient: grad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Text('🎓', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 10),
                      const Text('Hope Academy Egypt',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ]),
                    const Spacer(),
                    Text(widget.post.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            height: 1.15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Text(widget.post.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, height: 1.35)),
                    const Spacer(),
                    Text(ShareService.hashtag,
                        style: const TextStyle(
                            color: Colors.white70, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _shareImage,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.ios_share_rounded),
              label: const Text('Share as picture (Instagram, Facebook…)'),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ShareService.shareText(_text, subject: widget.post.title),
                icon: const Icon(Icons.text_snippet_outlined),
                label: const Text('Text'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _text));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')));
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  LinearGradient _gradient(String cat) {
    switch (cat) {
      case 'urgent':
        return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF7A7A), Color(0xFFE74C3C)]);
      case 'event':
        return AppColors.grapeGradient;
      case 'academic':
        return AppColors.mintGradient;
      default:
        return AppColors.skyGradient;
    }
  }
}
