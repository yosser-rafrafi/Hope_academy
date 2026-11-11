import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Fade + slide-up entrance animation. Use `delay` to stagger lists:
/// `FadeSlideIn(delay: Duration(milliseconds: 60 * index), child: ...)`.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offset = const Offset(0, 24),
  });

  @override
  Widget build(BuildContext context) {
    final total = delay + duration;
    final start = total.inMilliseconds == 0
        ? 0.0
        : delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(offset.dx * (1 - t), offset.dy * (1 - t)),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

/// Playful "press" feedback: shrinks slightly while pressed.
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const BouncyTap({super.key, required this.child, this.onTap, this.onLongPress});

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Gradient header with softly floating bubbles/stars. Drop-in for profile
/// and hero sections.
class PlayfulHeader extends StatefulWidget {
  final Gradient gradient;
  final Widget child;
  final double? height;
  final BorderRadius borderRadius;
  const PlayfulHeader({
    super.key,
    required this.child,
    this.gradient = AppColors.skyGradient,
    this.height,
    this.borderRadius = const BorderRadius.vertical(bottom: Radius.circular(32)),
  });

  @override
  State<PlayfulHeader> createState() => _PlayfulHeaderState();
}

class _PlayfulHeaderState extends State<PlayfulHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(gradient: widget.gradient),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) =>
                      CustomPaint(painter: _BubblesPainter(_c.value)),
                ),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _BubblesPainter extends CustomPainter {
  final double t;
  _BubblesPainter(this.t);

  static const _seeds = [
    [0.1, 0.25, 34.0, 0.0],
    [0.85, 0.2, 48.0, 0.3],
    [0.65, 0.8, 26.0, 0.6],
    [0.25, 0.85, 40.0, 0.15],
    [0.95, 0.65, 22.0, 0.45],
    [0.45, 0.12, 18.0, 0.75],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.13);
    for (final s in _seeds) {
      final phase = (t + s[3]) * 2 * math.pi;
      final dx = size.width * s[0] + math.sin(phase) * 8;
      final dy = size.height * s[1] + math.cos(phase) * 10;
      canvas.drawCircle(Offset(dx, dy), s[2], paint);
    }
    // little stars
    final star = Paint()..color = Colors.white.withValues(alpha: 0.28);
    for (var i = 0; i < 4; i++) {
      final phase = (t * 2 + i * 0.25) * 2 * math.pi;
      final c = Offset(size.width * (0.2 + i * 0.22),
          size.height * (0.15 + 0.12 * math.sin(phase + i)));
      _drawStar(canvas, c, 5 + 2 * math.sin(phase).abs(), star);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rad = i.isEven ? r : r * 0.4;
      final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), p);
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter old) => old.t != t;
}

/// Rounded card that adapts to light/dark.
class PlayfulCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final VoidCallback? onTap;
  const PlayfulCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: accent?.withValues(alpha: 0.35) ?? context.divider),
        boxShadow: context.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            if (accent != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 5, color: accent),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
    return onTap == null ? card : BouncyTap(onTap: onTap, child: card);
  }
}

/// Section title with a coloured emoji/icon bubble.
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  const SectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.color = AppColors.sky,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: context.textPrimary)),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

/// Small coloured stat tile (icon + number + label) with count-up animation.
class StatBubble extends StatelessWidget {
  final IconData icon;
  final num value;
  final String label;
  final Color color;
  final String suffix;
  const StatBubble({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.sky,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            '${v.round()}$suffix',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.textPrimary),
          ),
        ),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.textSecondary)),
      ]),
    );
  }
}

/// Friendly empty state with a bouncing emoji.
class EmptyState extends StatefulWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  const EmptyState({super.key, this.emoji = '🌈', required this.title, this.subtitle});

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, -10 * Curves.easeInOut.transform(_c.value)),
              child: Text(widget.emoji, style: const TextStyle(fontSize: 56)),
            ),
          ),
          const SizedBox(height: 12),
          Text(widget.title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: context.textPrimary)),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(widget.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary)),
          ],
        ]),
      ),
    );
  }
}

/// Pill showing who can see a piece of content.
class AudienceBadge extends StatelessWidget {
  final String audience; // all | staff | teacher | student
  final bool dense;
  const AudienceBadge({super.key, required this.audience, this.dense = false});

  static (String, IconData, Color) info(String a) {
    switch (a) {
      case 'staff':
        return ('Staff only', Icons.lock_rounded, AppColors.grape);
      case 'teacher':
        return ('Teachers', Icons.school_rounded, AppColors.mint);
      case 'student':
        return ('Parents & students', Icons.family_restroom_rounded, AppColors.sun);
      default:
        return ('Everyone', Icons.public_rounded, AppColors.sky);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = info(audience);
    final fg = context.isDark ? color : HSLColor.fromColor(color).withLightness(0.32).toColor();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: dense ? 11 : 13, color: fg),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: dense ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: fg)),
      ]),
    );
  }
}
