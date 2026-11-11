import 'package:flutter_test/flutter_test.dart';
import 'package:hope_academy/models/activity_model.dart';
import 'package:hope_academy/services/progress_service.dart';

// NOTE: replace `hope_academy` with the `name:` found in your pubspec.yaml.

final _now = DateTime(2026, 10, 10);

ActivityModel _act({
  String id = 'a',
  ActivityCategory cat = ActivityCategory.speechTherapy,
  DateTime? date,
  double focus = 0,
  MoodLevel? mood,
  List<String> media = const [],
}) {
  final d = date ?? _now;
  return ActivityModel(
    id: id,
    title: 'Activity $id',
    description: 'desc',
    category: cat,
    date: d,
    studentId: 's1',
    teacherId: 't1',
    concentrationRate: focus,
    mood: mood,
    mediaUrls: media,
    createdAt: d,
    updatedAt: d,
  );
}

DomainProgress _domain(ProgressSummary s, ProgressDomain d) =>
    s.domains.firstWhere((x) => x.domain == d);

void main() {
  const service = ProgressService();

  test('empty input gives an empty garden of seeds', () {
    final s = service.compute(const [], now: _now);
    expect(s.isEmpty, isTrue);
    expect(s.currentStreakDays, 0);
    expect(s.domains.every((d) => d.stage == GrowthStage.seed), isTrue);
    expect(s.star, isNull);
  });

  test('one session plants a sprout only in its own domain', () {
    final s = service.compute([_act()], now: _now);
    expect(_domain(s, ProgressDomain.communication).stage, GrowthStage.sprout);
    expect(_domain(s, ProgressDomain.motor).stage, GrowthStage.seed);
  });

  test('every category maps to a domain', () {
    for (final c in ActivityCategory.values) {
      expect(() => ProgressDomainExt.fromCategory(c), returnsNormally);
    }
  });

  test('growth never decreases when more sessions are added', () {
    var acts = <ActivityModel>[];
    var last = -1.0;
    for (var i = 0; i < 12; i++) {
      acts = [...acts, _act(id: '$i', focus: 70, mood: MoodLevel.good)];
      final g = _domain(service.compute(acts, now: _now),
              ProgressDomain.communication)
          .growth;
      expect(g, greaterThanOrEqualTo(last));
      last = g;
    }
  });

  test('focused, happy sessions reach bloom faster', () {
    final acts = List.generate(
        5, (i) => _act(id: '$i', focus: 100, mood: MoodLevel.excellent));
    expect(_domain(service.compute(acts, now: _now),
            ProgressDomain.communication)
        .stage, GrowthStage.bloom);
  });

  test('streak tolerates a weekend gap but stops after a long one', () {
    final acts = [
      _act(id: '1', date: DateTime(2026, 10, 9)),
      _act(id: '2', date: DateTime(2026, 10, 8)),
      _act(id: '3', date: DateTime(2026, 10, 5)), // gap of 3 → still counts
      _act(id: '4', date: DateTime(2026, 10, 1)), // gap of 4 → breaks
    ];
    expect(service.compute(acts, now: _now).currentStreakDays, 3);
  });

  test('growingFast needs more recent than previous activity', () {
    final acts = [
      _act(id: '1', date: DateTime(2026, 10, 1)),
      _act(id: '2', date: DateTime(2026, 10, 3)),
      _act(id: '3', date: DateTime(2026, 10, 5)),
      _act(id: '4', date: DateTime(2026, 8, 25)),
    ];
    final s = service.compute(acts, now: _now);
    expect(_domain(s, ProgressDomain.communication).growingFast, isTrue);
    expect(s.star?.domain, ProgressDomain.communication);
  });

  test('pride moments: max 3, photos first', () {
    final acts = [
      for (var i = 0; i < 5; i++)
        _act(
          id: '$i',
          date: DateTime(2026, 10, 1 + i),
          mood: MoodLevel.excellent,
          media: i == 0 ? const ['https://x/y.jpg'] : const [],
        ),
    ];
    final s = service.compute(acts, now: _now);
    expect(s.prideMoments.length, 3);
    expect(s.prideMoments.first.activityId, '0');
  });
}
