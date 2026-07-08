import '../models/activity_log_model.dart';
import '../models/student_model.dart';

/// Generates structured parent-friendly reports from teacher notes.
/// Currently uses template-based generation.
/// Replace [_callLLM] with an actual API call (OpenAI, Gemini, etc.) when ready.
class AiReportService {
  // ─── Daily Report ─────────────────────────────────────────────────────────

  Future<String> generateDailyReport({
    required StudentModel student,
    required ActivityLogModel log,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800)); // simulate latency

    final date = _formatDate(log.date);
    final mood = log.mood.label;
    final moodEmoji = log.mood.emoji;
    final category = log.category.label;

    return '''📋 Daily Report — $date

Dear Parent of ${student.fullName},

We are delighted to share today's update about ${student.firstName}'s day at Hope Academy.

🌟 Overall Mood: $moodEmoji $mood

📚 Activity: ${log.title}
Category: $category

📝 Teacher's Observations:
${log.notes}

${log.objectivesAddressed.isNotEmpty ? '''🎯 Learning Objectives Addressed:
${log.objectivesAddressed.map((o) => '• $o').join('\n')}

''' : ''}${_generateEncouragement(log.mood, student.firstName)}

We look forward to seeing ${student.firstName} tomorrow!

Warm regards,
The Hope Academy Team''';
  }

  // ─── Weekly Summary ───────────────────────────────────────────────────────

  Future<String> generateWeeklySummary({
    required StudentModel student,
    required List<ActivityLogModel> logs,
    required DateTime weekStart,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (logs.isEmpty) {
      return 'No activity logs found for this week for ${student.fullName}.';
    }

    final weekEnd = weekStart.add(const Duration(days: 6));
    final daysPresent = logs.map((l) => l.date.day).toSet().length;

    // Category breakdown
    final categoryCount = <String, int>{};
    for (final log in logs) {
      final cat = log.category.label;
      categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
    }

    // Mood analysis
    final goodDays = logs
        .where((l) =>
            l.mood == MoodLevel.excellent || l.mood == MoodLevel.good)
        .length;
    final moodSummary = goodDays >= logs.length * 0.7
        ? 'had a wonderful week with many positive moments'
        : goodDays >= logs.length * 0.4
            ? 'had a mixed week with some great moments'
            : 'faced some challenges this week, and our team is here to support';

    // Objectives
    final allObjectives =
        logs.expand((l) => l.objectivesAddressed).toSet().toList();

    return '''📊 Weekly Progress Report
Week of ${_formatDate(weekStart)} – ${_formatDate(weekEnd)}

Dear Parents of ${student.fullName},

Here is a summary of ${student.firstName}'s progress this week at Hope Academy.

━━━━━━━━━━━━━━━━━━━━━━━━
📅 Attendance: $daysPresent day${daysPresent == 1 ? '' : 's'} of activities logged

😊 Mood Overview:
${student.firstName} $moodSummary.

📚 Activities This Week:
${categoryCount.entries.map((e) => '• ${e.key}: ${e.value} session${e.value == 1 ? '' : 's'}').join('\n')}

${allObjectives.isNotEmpty ? '''🎯 Objectives Worked On:
${allObjectives.map((o) => '• $o').join('\n')}

''' : ''}📝 Highlights:
${_buildWeeklyHighlights(logs, student.firstName)}

${_buildWeeklyEncouragement(goodDays, logs.length, student.firstName)}

Thank you for your continued partnership in ${student.firstName}'s journey.

With warmth,
The Hope Academy Team''';
  }

  // ─── Activity Suggestions ─────────────────────────────────────────────────

  Future<List<String>> suggestActivities({
    required StudentModel student,
    required List<ActivityLogModel> recentLogs,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final needs = student.supportNeeds.map((n) => n.label).toList();
    final recentCategories =
        recentLogs.take(5).map((l) => l.category.label).toSet();

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
    if (needs.contains('Motor Skills') ||
        needs.contains('Occupational Therapy')) {
      suggestions.addAll([
        'Fine motor: threading beads or lacing boards',
        'Gross motor: obstacle course with soft mats',
        'Playdough sculpting for hand strength',
      ]);
    }
    if (!recentCategories.contains('Art')) {
      suggestions.add('Creative art: finger painting or collage');
    }
    if (!recentCategories.contains('Music')) {
      suggestions.add('Music & movement: rhythm instruments session');
    }

    // Always include general suggestions
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

  String _generateEncouragement(MoodLevel mood, String name) {
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
    }
  }

  String _buildWeeklyHighlights(
      List<ActivityLogModel> logs, String firstName) {
    final highlights = logs
        .where((l) =>
            l.mood == MoodLevel.excellent || l.mood == MoodLevel.good)
        .take(3)
        .map((l) => '• ${l.title}: ${l.notes.length > 80 ? l.notes.substring(0, 80) + '…' : l.notes}')
        .toList();

    if (highlights.isEmpty) {
      return '• $firstName showed perseverance throughout the week.';
    }
    return highlights.join('\n');
  }

  String _buildWeeklyEncouragement(
      int goodDays, int total, String firstName) {
    if (goodDays >= total * 0.7) {
      return '🌈 What a great week! $firstName is making wonderful progress. Keep up the amazing work at home too!';
    } else if (goodDays >= total * 0.4) {
      return '💛 A week of growth and learning. $firstName is working hard, and we are proud of every effort.';
    } else {
      return '🤝 This week had its challenges, but every child progresses at their own pace. Our team is fully committed to supporting $firstName.';
    }
  }
}
