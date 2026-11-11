import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../models/pei_model.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String peiFmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// 0 → coral … 4 → green.
Color peiLevelColor(int level) {
  switch (level.clamp(kPeiMinLevel, kPeiMaxLevel)) {
    case 0:  return AppColors.coral;
    case 1:  return AppColors.warning;
    case 2:  return AppColors.sun;
    case 3:  return AppColors.sky;
    default: return AppColors.success;
  }
}

Color peiStatusColor(PeiStatus s) {
  switch (s) {
    case PeiStatus.draft:     return AppColors.warning;
    case PeiStatus.active:    return AppColors.success;
    case PeiStatus.completed: return AppColors.info;
    case PeiStatus.archived:  return AppColors.textSecondary;
  }
}

Color peiGoalStatusColor(GoalStatus s) {
  switch (s) {
    case GoalStatus.notStarted: return AppColors.textSecondary;
    case GoalStatus.inProgress: return AppColors.sky;
    case GoalStatus.achieved:   return AppColors.success;
    case GoalStatus.onHold:     return AppColors.warning;
  }
}

// ─── Small pill ───────────────────────────────────────────────────────────────

class PeiPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const PeiPill({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}

// ─── Progress bar ─────────────────────────────────────────────────────────────

class PeiProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;
  const PeiProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.success,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: color,
        backgroundColor: color.withAlpha(30),
      ),
    );
  }
}

// ─── Level picker (0..4) ──────────────────────────────────────────────────────

/// Five numbered bubbles + the label of the selected level underneath.
/// [min]/[max] restrict the selectable range (e.g. target ≥ baseline).
class PeiLevelPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  const PeiLevelPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = kPeiMinLevel,
    this.max = kPeiMaxLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        children: [
          for (var i = kPeiMinLevel; i <= kPeiMaxLevel; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _bubble(context, i),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Text(context.tr('pei.level.$value'),
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: peiLevelColor(value))),
    ]);
  }

  Widget _bubble(BuildContext context, int i) {
    final enabled = i >= min && i <= max;
    final selected = i == value;
    final c = peiLevelColor(i);
    return GestureDetector(
      onTap: enabled ? () => onChanged(i) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 42,
        decoration: BoxDecoration(
          color: selected ? c : c.withAlpha(enabled ? 24 : 8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? c : c.withAlpha(enabled ? 80 : 30), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text('$i',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : (enabled ? c : context.textSecondary.withAlpha(110)))),
      ),
    );
  }
}

// ─── Level chip (read-only) ───────────────────────────────────────────────────

class PeiLevelChip extends StatelessWidget {
  final int level;
  final String? prefix;
  const PeiLevelChip({super.key, required this.level, this.prefix});

  @override
  Widget build(BuildContext context) {
    final c = peiLevelColor(level);
    return PeiPill(
      label: '${prefix ?? ''}$level · ${context.tr('pei.level.$level')}',
      color: c,
    );
  }
}

// ─── Evolution chart (no external package) ────────────────────────────────────

/// Line chart of observed levels over time (oldest → newest, evenly spaced).
class PeiLevelChart extends StatelessWidget {
  /// Entries of ONE goal, any order.
  final List<PeiProgressEntry> entries;
  final int targetLevel;
  final double height;
  const PeiLevelChart({
    super.key,
    required this.entries,
    required this.targetLevel,
    this.height = 130,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.createdAt.compareTo(b.createdAt);
      });
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          levels: sorted.map((e) => e.level).toList(),
          target: targetLevel,
          line: AppColors.sky,
          grid: context.divider,
          targetColor: AppColors.success,
          textColor: context.textSecondary,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<int> levels;
  final int target;
  final Color line, grid, targetColor, textColor;
  final bool rtl;
  _ChartPainter({
    required this.levels,
    required this.target,
    required this.line,
    required this.grid,
    required this.targetColor,
    required this.textColor,
    required this.rtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 22.0, topPad = 8.0, botPad = 8.0, rightPad = 8.0;
    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - botPad;
    if (w <= 0 || h <= 0) return;

    double yOf(int lvl) =>
        topPad + h - (lvl - kPeiMinLevel) / (kPeiMaxLevel - kPeiMinLevel) * h;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var l = kPeiMinLevel; l <= kPeiMaxLevel; l++) {
      final y = yOf(l);
      final x0 = rtl ? rightPad : leftPad;
      final x1 = rtl ? size.width - leftPad : size.width - rightPad;
      canvas.drawLine(Offset(x0, y), Offset(x1, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
            text: '$l', style: TextStyle(fontSize: 10, color: textColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      final tx = rtl ? size.width - leftPad + 8 : 4.0;
      tp.paint(canvas, Offset(tx, y - tp.height / 2));
    }

    // Target line (dashed)
    final ty = yOf(target);
    final dash = Paint()
      ..color = targetColor.withAlpha(180)
      ..strokeWidth = 1.5;
    final xs = rtl ? rightPad : leftPad;
    final xe = rtl ? size.width - leftPad : size.width - rightPad;
    for (double x = xs; x < xe; x += 10) {
      canvas.drawLine(Offset(x, ty), Offset((x + 5).clamp(xs, xe), ty), dash);
    }

    if (levels.isEmpty) return;

    Offset pt(int i) {
      final t = levels.length == 1 ? 0.5 : i / (levels.length - 1);
      final fx = rtl ? 1 - t : t;
      return Offset((rtl ? rightPad : leftPad) + fx * w, yOf(levels[i]));
    }

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < levels.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < levels.length; i++) {
      final p = pt(i);
      canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()..color = peiLevelColor(levels[i]));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.levels != levels || old.target != target || old.rtl != rtl;
}
