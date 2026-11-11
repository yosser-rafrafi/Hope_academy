import '../models/activity_model.dart';
import '../models/student_model.dart';

/// Generates structured parent-friendly reports from teacher notes.
///
/// This used to read from `ActivityLogModel`, a model that had no service
/// and no screen to create it — every call site actually passed `logs: []`
/// (see MERGE_NOTES.md). It now reads directly from `ActivityModel`, which
/// is the model teachers actually write to via `ActivityService` /
/// `CreateActivityScreen`, so a report reflects real logged activities.
///
/// Currently uses template-based generation. Replace [_callLLM] with an
/// actual API call (OpenAI, Gemini, etc.) when ready.
class AiReportService {
  // ─── Daily Report ─────────────────────────────────────────────────────────

  Future<String> generateDailyReport({
    required StudentModel student,
    required ActivityModel activity,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800)); // simulate latency

    final date = _formatDate(activity.date);
    final mood = activity.mood;
    final category = activity.category.label;

    return '''📋 Daily Report — $date

Dear Parent of ${student.fullName},

We are delighted to share today's update about ${student.firstName}'s day at Hope Academy.

${mood != null ? '🌟 Overall Mood: ${mood.emoji} ${mood.label}\n\n' : ''}📚 Activity: ${activity.title}
Category: $category

📝 Teacher's Observations:
${activity.description}

${activity.objectives.isNotEmpty ? '''🎯 Learning Objectives Addressed:
${activity.objectives.map((o) => '• $o').join('\n')}

''' : ''}${_generateEncouragement(mood, student.firstName)}

We look forward to seeing ${student.firstName} tomorrow!

Warm regards,
The Hope Academy Team''';
  }

  // ─── Weekly Summary ───────────────────────────────────────────────────────

  Future<String> generateWeeklySummary({
    required StudentModel student,
    required List<ActivityModel> activities,
    required DateTime weekStart,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (activities.isEmpty) {
      return 'No activities logged for ${student.fullName} this week yet — check back once the teacher records a few daily entries.';
    }

    final weekEnd = weekStart.add(const Duration(days: 6));
    final daysLogged = activities.map((a) => a.date.day).toSet().length;

    // Category breakdown
    final categoryCount = <String, int>{};
    for (final a in activities) {
      final cat = a.category.label;
      categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
    }

    // Mood analysis — only over activities that actually recorded a mood.
    final moodsLogged = activities.where((a) => a.mood != null).toList();
    final goodDays = moodsLogged
        .where((a) => a.mood == MoodLevel.excellent || a.mood == MoodLevel.good)
        .length;
    final moodSummary = moodsLogged.isEmpty
        ? 'kept busy with a full schedule of activities'
        : goodDays >= moodsLogged.length * 0.7
            ? 'had a wonderful week with many positive moments'
            : goodDays >= moodsLogged.length * 0.4
                ? 'had a mixed week with some great moments'
                : 'faced some challenges this week, and our team is here to support';

    final allObjectives = activities.expand((a) => a.objectives).toSet().toList();

    return '''📊 Weekly Progress Report
Week of ${_formatDate(weekStart)} – ${_formatDate(weekEnd)}

Dear Parents of ${student.fullName},

Here is a summary of ${student.firstName}'s progress this week at Hope Academy.

━━━━━━━━━━━━━━━━━━━━━━━━
📅 Activity: $daysLogged day${daysLogged == 1 ? '' : 's'} logged this week

😊 Mood Overview:
${student.firstName} $moodSummary.

📚 Activities This Week:
${categoryCount.entries.map((e) => '• ${e.key}: ${e.value} session${e.value == 1 ? '' : 's'}').join('\n')}

${allObjectives.isNotEmpty ? '''🎯 Objectives Worked On:
${allObjectives.map((o) => '• $o').join('\n')}

''' : ''}📝 Highlights:
${_buildWeeklyHighlights(activities, student.firstName)}

${_buildWeeklyEncouragement(goodDays, moodsLogged.length, student.firstName)}

Thank you for your continued partnership in ${student.firstName}'s journey.

With warmth,
The Hope Academy Team''';
  }

  // ─── Activity Suggestions ─────────────────────────────────────────────────

  Future<List<String>> suggestActivities({
    required StudentModel student,
    required List<ActivityModel> recentActivities,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final needs = student.supportNeeds.map((n) => n.label).toList();
    final recentCategories =
        recentActivities.take(5).map((a) => a.category.label).toSet();

    final suggestions = <String>[];

    if (needs.contains('Autism Spectrum')) {
      suggestions.addAll([
        'Sensory bin exploration with sand or rice',
        'Visual schedule review and reinforcement',
        'Turn-taking games with 2–3 peers',
      ]);
    }
    if (needs.contains('Speech & Language')) {
      suggestions.addAll([
        'Picture-word matching cards (10 minutes)',
        'Articulation practice with mirror',
        'Story sequencing using 3–4 picture cards',
      ]);
    }
    if (needs.contains('Occupational Therapy') ||
        needs.contains('Physical Disability')) {
      suggestions.addAll([
        'Fine motor: threading beads or lacing boards',
        'Gross motor: obstacle course with soft mats',
        'Playdough sculpting for hand strength',
      ]);
    }
    if (!recentCategories.contains('Art & Creativity')) {
      suggestions.add('Creative art: finger painting or collage');
    }
    if (!recentCategories.contains('Music')) {
      suggestions.add('Music & movement: rhythm instruments session');
    }

    suggestions.addAll([
      'Emotion recognition flashcards',
      'Cooperative building blocks activity',
      'Mindfulness breathing exercise (3 minutes)',
    ]);

    return suggestions.take(6).toList();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _generateEncouragement(MoodLevel? mood, String name) {
    switch (mood) {
      case MoodLevel.excellent:
        return '🌟 $name had an outstanding day — full of energy and enthusiasm!';
      case MoodLevel.good:
        return '👍 $name had a positive and productive day.';
      case MoodLevel.neutral:
        return '💛 $name had a steady day. Every day is a step forward!';
      case MoodLevel.difficult:
        return '💪 $name faced some challenges today. Our team is here to support and we will keep working together.';
      case MoodLevel.veryDifficult:
        return '🤝 Today was tough for $name. We are monitoring closely and will share more details if needed. Thank you for your trust.';
      case null:
        return '📌 $name took part in today\'s activity — see the notes above for details.';
    }
  }

  String _buildWeeklyHighlights(List<ActivityModel> activities, String firstName) {
    final highlights = activities
        .where((a) => a.mood == MoodLevel.excellent || a.mood == MoodLevel.good)
        .take(3)
        .map((a) =>
            '• ${a.title}: ${a.description.length > 80 ? "${a.description.substring(0, 80)}…" : a.description}')
        .toList();

    if (highlights.isEmpty) {
      return '• $firstName showed perseverance throughout the week.';
    }
    return highlights.join('\n');
  }

  String _buildWeeklyEncouragement(int goodDays, int total, String firstName) {
    if (total == 0) {
      return '🤝 Ask the teacher to log a mood alongside daily activities to unlock a fuller weekly picture.';
    }
    if (goodDays >= total * 0.7) {
      return '🌈 What a great week! $firstName is making wonderful progress. Keep up the amazing work at home too!';
    } else if (goodDays >= total * 0.4) {
      return '💛 A week of growth and learning. $firstName is working hard, and we are proud of every effort.';
    } else {
      return '🤝 This week had its challenges, but every child progresses at their own pace. Our team is fully committed to supporting $firstName.';
    }
  }
}
