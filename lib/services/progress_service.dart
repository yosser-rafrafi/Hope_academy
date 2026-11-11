import '../models/activity_model.dart';

/// Developmental domains shown in the "Progress Garden".
///
/// Each [ActivityCategory] feeds exactly one domain, so the garden is
/// computed purely from data the teachers already log — no new Firestore
/// collection is required.
enum ProgressDomain { communication, autonomy, motor, social, creativity, cognitive }

extension ProgressDomainExt on ProgressDomain {
  String get label {
    switch (this) {
      case ProgressDomain.communication:
        return 'Communication';
      case ProgressDomain.autonomy:
        return 'Independence';
      case ProgressDomain.motor:
        return 'Movement & Senses';
      case ProgressDomain.social:
        return 'Friendship';
      case ProgressDomain.creativity:
        return 'Creativity';
      case ProgressDomain.cognitive:
        return 'Discovery';
    }
  }

  String get emoji {
    switch (this) {
      case ProgressDomain.communication:
        return '💬';
      case ProgressDomain.autonomy:
        return '🌱';
      case ProgressDomain.motor:
        return '🤸';
      case ProgressDomain.social:
        return '🤝';
      case ProgressDomain.creativity:
        return '🎨';
      case ProgressDomain.cognitive:
        return '🔍';
    }
  }

  static ProgressDomain fromCategory(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.speechTherapy:
      case ActivityCategory.languages:
        return ProgressDomain.communication;
      case ActivityCategory.cookingAndLifeSkills:
      case ActivityCategory.skillsDevelopment:
      case ActivityCategory.workshop:
        return ProgressDomain.autonomy;
      case ActivityCategory.physicalEducation:
      case ActivityCategory.physicalTherapy:
      case ActivityCategory.sensoryIntegration:
        return ProgressDomain.motor;
      case ActivityCategory.socialSkills:
        return ProgressDomain.social;
      case ActivityCategory.artAndCreativity:
      case ActivityCategory.music:
        return ProgressDomain.creativity;
      case ActivityCategory.computerSkills:
        return ProgressDomain.cognitive;
    }
  }
}

/// How far a plant has grown. Growth is cumulative and never shrinks:
/// the garden only celebrates effort, it never compares a child to a norm.
enum GrowthStage { seed, sprout, bud, bloom, flourish }

extension GrowthStageExt on GrowthStage {
  String get label {
    switch (this) {
      case GrowthStage.seed:
        return 'Seed';
      case GrowthStage.sprout:
        return 'Sprouting';
      case GrowthStage.bud:
        return 'Budding';
      case GrowthStage.bloom:
        return 'Blooming';
      case GrowthStage.flourish:
        return 'Flourishing';
    }
  }
}

class DomainProgress {
  final ProgressDomain domain;
  final int sessions;
  final double points;
  final GrowthStage stage;

  /// 0.0 – 1.0 progress inside the current stage (for smooth animation).
  final double stageProgress;

  /// True when the last 30 days were more active than the 30 days before.
  /// Used only to show a positive "growing fast" sparkle — a decline is
  /// never surfaced.
  final bool growingFast;

  const DomainProgress({
    required this.domain,
    required this.sessions,
    required this.points,
    required this.stage,
    required this.stageProgress,
    required this.growingFast,
  });

  /// 0.0 – 1.0 overall growth, handy for drawing.
  double get growth => (stage.index + stageProgress) / (GrowthStage.values.length);
}

class PrideMoment {
  final String activityId;
  final String title;
  final DateTime date;
  final ActivityCategory category;
  final List<String> mediaUrls;

  const PrideMoment({
    required this.activityId,
    required this.title,
    required this.date,
    required this.category,
    this.mediaUrls = const [],
  });
}

class ProgressSummary {
  final List<DomainProgress> domains;
  final int totalSessions;
  final int currentStreakDays;
  final List<PrideMoment> prideMoments;

  const ProgressSummary({
    required this.domains,
    required this.totalSessions,
    required this.currentStreakDays,
    required this.prideMoments,
  });

  bool get isEmpty => totalSessions == 0;

  /// The domain currently growing the most, for a positive headline.
  DomainProgress? get star {
    final fast = domains.where((d) => d.growingFast).toList();
    if (fast.isEmpty) return null;
    fast.sort((a, b) => b.points.compareTo(a.points));
    return fast.first;
  }
}

/// Pure, side-effect-free computation of the Progress Garden.
/// Kept free of Firestore so it can be unit-tested.
class ProgressService {
  const ProgressService();

  /// Points needed to reach each stage (index = stage.index).
  static const List<double> _thresholds = [0, 1, 4, 9, 16];

  ProgressSummary compute(List<ActivityModel> activities, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final recentStart = today.subtract(const Duration(days: 30));
    final previousStart = today.subtract(const Duration(days: 60));

    final points = {for (final d in ProgressDomain.values) d: 0.0};
    final sessions = {for (final d in ProgressDomain.values) d: 0};
    final recent = {for (final d in ProgressDomain.values) d: 0};
    final previous = {for (final d in ProgressDomain.values) d: 0};

    for (final a in activities) {
      final d = ProgressDomainExt.fromCategory(a.category);
      sessions[d] = sessions[d]! + 1;
      points[d] = points[d]! + _pointsFor(a);

      final day = _day(a.date);
      if (!day.isBefore(recentStart)) {
        recent[d] = recent[d]! + 1;
      } else if (!day.isBefore(previousStart)) {
        previous[d] = previous[d]! + 1;
      }
    }

    final domains = ProgressDomain.values.map((d) {
      final p = points[d]!;
      final stageIndex = _stageIndexFor(p);
      final stage = GrowthStage.values[stageIndex];
      return DomainProgress(
        domain: d,
        sessions: sessions[d]!,
        points: p,
        stage: stage,
        stageProgress: _stageProgress(p, stageIndex),
        growingFast: recent[d]! >= 2 && recent[d]! > previous[d]!,
      );
    }).toList();

    return ProgressSummary(
      domains: domains,
      totalSessions: activities.length,
      currentStreakDays: _streak(activities, today),
      prideMoments: _prideMoments(activities),
    );
  }

  // ─── Internals ────────────────────────────────────────────────────────────

  /// Every session counts (showing up is progress). Focus and a positive
  /// mood add a little extra.
  double _pointsFor(ActivityModel a) {
    var p = 1.0;
    p += (a.concentrationRate.clamp(0, 100)) / 100 * 0.6;
    if (a.mood == MoodLevel.excellent) {
      p += 0.5;
    } else if (a.mood == MoodLevel.good) {
      p += 0.25;
    }
    return p;
  }

  int _stageIndexFor(double points) {
    var idx = 0;
    for (var i = 0; i < _thresholds.length; i++) {
      if (points >= _thresholds[i]) idx = i;
    }
    return idx;
  }

  double _stageProgress(double points, int stageIndex) {
    if (stageIndex >= _thresholds.length - 1) return 1.0;
    final lo = _thresholds[stageIndex];
    final hi = _thresholds[stageIndex + 1];
    return ((points - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();
  }

  /// Consecutive days with at least one activity, counting back from the
  /// most recent logged day (not necessarily today, so a weekend does not
  /// feel like a "failure").
  int _streak(List<ActivityModel> activities, DateTime today) {
    if (activities.isEmpty) return 0;
    final days = activities
        .map((a) => _day(a.date))
        .where((d) => !d.isAfter(today))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;

    var streak = 1;
    for (var i = 1; i < days.length; i++) {
      final gap = days[i - 1].difference(days[i]).inDays;
      // Weekends (Fri/Sat in Egypt, Sat/Sun elsewhere) must not break it:
      // allow a gap of up to 3 days.
      if (gap <= 3) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  List<PrideMoment> _prideMoments(List<ActivityModel> activities) {
    final good = activities
        .where((a) =>
            a.mood == MoodLevel.excellent || a.concentrationRate >= 85)
        .toList()
      ..sort((a, b) {
        // Moments with photos first, then newest.
        final m = (b.mediaUrls.isNotEmpty ? 1 : 0)
            .compareTo(a.mediaUrls.isNotEmpty ? 1 : 0);
        return m != 0 ? m : b.date.compareTo(a.date);
      });
    return good
        .take(3)
        .map((a) => PrideMoment(
              activityId: a.id,
              title: a.title,
              date: a.date,
              category: a.category,
              mediaUrls: a.mediaUrls,
            ))
        .toList();
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
