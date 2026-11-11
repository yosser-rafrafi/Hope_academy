import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../models/activity_model.dart';
import '../../models/user_model.dart';
import '../../services/portfolio_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/kid_ui.dart';
import '../../widgets/media_widgets.dart';
import '../../widgets/user_avatar.dart';

/// Student CV / portfolio: pick the sections to include, preview them, then
/// export a beautiful PDF (print, save or share to any app).
class PortfolioScreen extends StatefulWidget {
  final UserModel student;
  final UserModel viewer;
  const PortfolioScreen({super.key, required this.student, required this.viewer});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _service = PortfolioService();
  late Future<PortfolioData> _future;
  Set<PortfolioSection> _sections = PortfolioSectionX.defaults;
  bool _busy = false;

  /// Parents/students never see internal teacher notes.
  bool get _viewerIsParent => widget.viewer.role == UserRole.student;

  List<PortfolioSection> get _available => PortfolioSection.values
      .where((s) => !(_viewerIsParent && s == PortfolioSection.teacherNotes))
      .toList();

  String get _prefKey => 'portfolio_sections_${widget.student.uid}';

  @override
  void initState() {
    super.initState();
    _future = _service.load(widget.student, viewerIsParent: _viewerIsParent);
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefKey);
      if (saved != null && mounted) {
        setState(() => _sections = PortfolioSection.values
            .where((s) => saved.contains(s.name) && _available.contains(s))
            .toSet());
      }
    } catch (_) {}
  }

  Future<void> _toggle(PortfolioSection s) async {
    setState(() {
      _sections = Set.of(_sections);
      if (!_sections.add(s)) _sections.remove(s);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, _sections.map((e) => e.name).toList());
    } catch (_) {}
  }

  Future<void> _export({required bool share}) async {
    setState(() => _busy = true);
    try {
      final data = await _future;
      final bytes = await _service.buildPdf(data, _sections);
      final name = 'portfolio_${widget.student.fullName.replaceAll(' ', '_')}';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not create the PDF: $e'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return Scaffold(
      backgroundColor: context.pageBg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: PlayfulHeader(
            gradient: AppColors.grapeGradient,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                UserAvatar(user: s, radius: 46),
                const SizedBox(height: 10),
                Text(s.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('✨ My Portfolio',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 26),
              ]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              FadeSlideIn(child: _chooser()),
              const SizedBox(height: 16),
              FutureBuilder<PortfolioData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return EmptyState(
                        emoji: '😕',
                        title: 'Could not load the portfolio',
                        subtitle: '${snap.error ?? ''}');
                  }
                  return _preview(snap.data!);
                },
              ),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: context.cardBg,
            border: Border(top: BorderSide(color: context.divider)),
          ),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _export(share: false),
                icon: const Icon(Icons.print_rounded),
                label: const Text('Preview'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _export(share: true),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Share / Save PDF'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Section chooser ──────────────────────────────────────────────────────

  Widget _chooser() {
    return PlayfulCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle(
            title: 'What should the PDF include?',
            icon: Icons.checklist_rounded,
            color: AppColors.grape),
        const SizedBox(height: 4),
        Text('Tap to switch sections on or off. 🔒 = sensitive information.',
            style: TextStyle(fontSize: 12, color: context.textSecondary)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final sec in _available)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _sections.contains(sec)
                    ? AppColors.grape.withValues(alpha: 0.2)
                    : context.softFill,
                border: Border.all(
                  color: _sections.contains(sec) ? AppColors.grape : context.divider,
                  width: _sections.contains(sec) ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _toggle(sec),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(sec.emoji, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(sec.label,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary)),
                    if (sec.sensitive) ...[
                      const SizedBox(width: 4),
                      const Text('🔒', style: TextStyle(fontSize: 11)),
                    ],
                    if (_sections.contains(sec)) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_circle, size: 16, color: AppColors.grape),
                    ],
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }

  // ─── Live preview ─────────────────────────────────────────────────────────

  Widget _preview(PortfolioData d) {
    final hours = d.totalMinutes / 60;
    final blocks = <Widget>[
      Row(children: [
        Expanded(child: StatBubble(icon: Icons.palette_rounded, value: d.activities.length, label: 'Activities', color: AppColors.grape)),
        const SizedBox(width: 8),
        Expanded(child: StatBubble(icon: Icons.timer_rounded, value: hours.round(), label: 'Hours', color: AppColors.sky)),
        const SizedBox(width: 8),
        Expanded(child: StatBubble(icon: Icons.star_rounded, value: d.skills.length, label: 'Skills', color: AppColors.sun)),
        const SizedBox(width: 8),
        Expanded(child: StatBubble(icon: Icons.flag_rounded, value: d.objectives.length, label: 'Goals', color: AppColors.mint)),
      ]),
      if (_sections.contains(PortfolioSection.skills) && d.skills.isNotEmpty)
        _card('Skills & strengths', Icons.star_rounded, AppColors.sun,
            Column(children: [for (final s in d.skills.take(8)) _skillRow(s)])),
      if (_sections.contains(PortfolioSection.objectives) && d.objectives.isNotEmpty)
        _card('Objectives achieved', Icons.flag_rounded, AppColors.mint,
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final o in d.objectives.take(24))
                Chip(
                  label: Text(o, style: TextStyle(fontSize: 12, color: context.textPrimary)),
                  backgroundColor: AppColors.mint.withValues(alpha: 0.15),
                  side: BorderSide(color: AppColors.mint.withValues(alpha: 0.4)),
                ),
            ])),
      if (_sections.contains(PortfolioSection.activities) && d.activities.isNotEmpty)
        _card('Activity history', Icons.palette_rounded, AppColors.grape,
            Column(children: [for (final a in d.activities.take(8)) _activityTile(a)])),
      if (_sections.contains(PortfolioSection.gallery) && d.photoUrls.isNotEmpty)
        _card('Photo gallery', Icons.photo_library_rounded, AppColors.sky,
            MediaGallery(urls: d.photoUrls.take(6).toList(), height: 120)),
      if (_sections.contains(PortfolioSection.attendance))
        _card('Attendance', Icons.event_available_rounded, AppColors.sky,
            Text(
              d.absences.isEmpty
                  ? 'No absences recorded — perfect attendance! 🎉'
                  : '${d.absences.length} absence(s) recorded.',
              style: TextStyle(color: context.textPrimary),
            )),
      if (_sections.contains(PortfolioSection.mood) && d.moods.isNotEmpty)
        _card('Mood & wellbeing', Icons.mood_rounded, AppColors.coral,
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in d.moods.entries)
                Chip(
                  label: Text('${e.key.emoji} ${e.key.label} × ${e.value}',
                      style: TextStyle(color: context.textPrimary)),
                  backgroundColor: AppColors.coral.withValues(alpha: 0.12),
                ),
            ])),
      if (d.activities.isEmpty)
        const EmptyState(
          emoji: '🌱',
          title: 'No completed activities yet',
          subtitle: 'The portfolio fills up as activities are completed.',
        ),
    ];
    return Column(children: [
      for (var i = 0; i < blocks.length; i++) ...[
        FadeSlideIn(delay: Duration(milliseconds: 80 * i), child: blocks[i]),
        const SizedBox(height: 12),
      ],
    ]);
  }

  Widget _card(String title, IconData icon, Color color, Widget child) {
    return PlayfulCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(title: title, icon: icon, color: color),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _skillRow(SkillStat s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(s.category.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.category.label,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: context.textPrimary)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: s.ratio),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: context.softFill,
                  valueColor: const AlwaysStoppedAnimation(AppColors.sky),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Row(children: [
          for (var i = 0; i < 5; i++)
            Icon(i < s.stars ? Icons.star_rounded : Icons.star_border_rounded,
                size: 16, color: AppColors.sun),
        ]),
      ]),
    );
  }

  Widget _activityTile(ActivityModel a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.grape.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(a.category.emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: context.textPrimary)),
            Text('${a.date.day}/${a.date.month}/${a.date.year} • ${a.category.label}',
                style: TextStyle(fontSize: 11, color: context.textSecondary)),
          ]),
        ),
        if (a.mood != null) Text(a.mood!.emoji, style: const TextStyle(fontSize: 20)),
        if (a.mediaUrls.any((u) => !StorageService.isVideoUrl(u)))
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.photo_rounded, size: 16, color: context.textSecondary),
          ),
      ]),
    );
  }
}
