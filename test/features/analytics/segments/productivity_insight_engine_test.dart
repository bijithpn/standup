import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/segments/productivity_aggregator.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight_engine.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';

ActivitySegment seg(
  DateTime day, {
  required int fromMinute,
  required int toMinute,
  String app = 'code',
  String category = 'coding',
  ActivityKind kind = ActivityKind.active,
}) {
  final active = kind == ActivityKind.active;
  return ActivitySegment(
    appKey: active ? app : '',
    appName: active ? app : '',
    categoryName: active ? category : '',
    date:
        '${day.year}-${day.month.toString().padLeft(2, '0')}'
        '-${day.day.toString().padLeft(2, '0')}',
    startedAtMs: day.add(Duration(minutes: fromMinute)).millisecondsSinceEpoch,
    endedAtMs: day.add(Duration(minutes: toMinute)).millisecondsSinceEpoch,
    kind: kind.storedValue,
  );
}

/// A day that works hard in the morning window, with [switchesAfternoon]
/// application switches after lunch.
DailyProductivitySummary workday(
  DateTime day, {
  int switchesAfternoon = 0,
  int breakMinutes = 0,
  int blockMinutes = 15,
}) {
  final segments = <ActivitySegment>[
    // 09:00–12:00 in one app: three solid hours.
    seg(day, fromMinute: 540, toMinute: 720),
  ];

  // 14:00 onward, alternating apps to create switches.
  var cursor = 840;
  for (var i = 0; i < switchesAfternoon + 1; i++) {
    segments.add(
      seg(
        day,
        fromMinute: cursor,
        toMinute: cursor + blockMinutes,
        app: i.isEven ? 'chrome' : 'slack',
      ),
    );
    cursor += blockMinutes;
  }

  if (breakMinutes > 0) {
    segments.add(
      seg(
        day,
        fromMinute: 720,
        toMinute: 720 + breakMinutes,
        kind: ActivityKind.onBreak,
      ),
    );
  }

  return aggregateDay(
    '${day.year}-${day.month.toString().padLeft(2, '0')}'
    '-${day.day.toString().padLeft(2, '0')}',
    segments,
  );
}

/// A day with [morningBlocks] and [afternoonBlocks] alternating app blocks of
/// [blockMinutes] each, so the switching rate on each side of lunch is
/// deliberate rather than incidental.
DailyProductivitySummary splitDay(
  DateTime day, {
  required int morningBlocks,
  required int afternoonBlocks,
  int blockMinutes = 10,
}) {
  final segments = <ActivitySegment>[];

  var cursor = 540; // 09:00
  for (var i = 0; i < morningBlocks; i++) {
    segments.add(
      seg(
        day,
        fromMinute: cursor,
        toMinute: cursor + blockMinutes,
        app: i.isEven ? 'code' : 'chrome',
      ),
    );
    cursor += blockMinutes;
  }

  cursor = 840; // 14:00
  for (var i = 0; i < afternoonBlocks; i++) {
    segments.add(
      seg(
        day,
        fromMinute: cursor,
        toMinute: cursor + blockMinutes,
        app: i.isEven ? 'code' : 'chrome',
      ),
    );
    cursor += blockMinutes;
  }

  return aggregateDay(
    '${day.year}-${day.month.toString().padLeft(2, '0')}'
    '-${day.day.toString().padLeft(2, '0')}',
    segments,
  );
}

RangeProductivitySummary splitRange(
  int dayCount, {
  required int morningBlocks,
  required int afternoonBlocks,
  int blockMinutes = 10,
}) {
  return aggregateRange(<DailyProductivitySummary>[
    for (var i = 0; i < dayCount; i++)
      splitDay(
        DateTime(2026, 9, 1 + i),
        morningBlocks: morningBlocks,
        afternoonBlocks: afternoonBlocks,
        blockMinutes: blockMinutes,
      ),
  ]);
}

RangeProductivitySummary rangeOf(
  int dayCount, {
  int switchesAfternoon = 0,
  int breakMinutes = 0,
}) {
  return aggregateRange(<DailyProductivitySummary>[
    for (var i = 0; i < dayCount; i++)
      workday(
        DateTime(2026, 9, 1 + i),
        switchesAfternoon: switchesAfternoon,
        breakMinutes: breakMinutes,
      ),
  ]);
}

void main() {
  group('evidence gate', () {
    test('no history produces no insights at all', () {
      final insights = generateInsights(
        range: RangeProductivitySummary.empty(),
      );

      expect(insights, isEmpty);
      expect(
        hasEnoughDataForInsights(RangeProductivitySummary.empty()),
        isFalse,
      );
    });

    test('one day is not enough to claim a pattern', () {
      final range = rangeOf(1);

      expect(hasEnoughDataForInsights(range), isFalse);
      final patterns = generateInsights(
        range: range,
      ).where((i) => i.type == InsightType.focusWindow);
      expect(patterns, isEmpty);
    });

    test('two days earns a hedged finding, not a confident one', () {
      final insights = generateInsights(range: rangeOf(2));
      final window = insights.firstWhere(
        (i) => i.type == InsightType.focusWindow,
      );

      expect(window.confidence, InsightConfidence.low);
      expect(window.evidenceDayCount, 2);
      expect(window.needsEvidenceNote, isTrue);
      expect(
        window.description.toLowerCase(),
        contains('lean'),
        reason: 'a low-confidence finding must be phrased as a possibility',
      );
    });

    test('a working week earns a confident finding', () {
      final insights = generateInsights(range: rangeOf(7));
      final window = insights.firstWhere(
        (i) => i.type == InsightType.focusWindow,
      );

      expect(window.confidence, InsightConfidence.high);
      expect(window.needsEvidenceNote, isFalse);
      expect(window.description, contains('Most of your active time'));
    });

    test('confidence grades on days of evidence', () {
      expect(InsightEvidence.forDays(1), InsightConfidence.low);
      expect(InsightEvidence.forDays(4), InsightConfidence.medium);
      expect(InsightEvidence.forDays(7), InsightConfidence.high);
      expect(InsightEvidence.isSufficient(1), isFalse);
      expect(InsightEvidence.isSufficient(2), isTrue);
    });
  });

  group('focus window', () {
    test('finds the hours the work actually happens in', () {
      final insights = generateInsights(range: rangeOf(7));
      final window = insights.firstWhere(
        (i) => i.type == InsightType.focusWindow,
      );

      expect(window.supportingData['startHour'], 9);
      expect(window.supportingData['endHour'], 12);
    });

    test('a confident window becomes something actionable', () {
      final insights = generateInsights(range: rangeOf(7));
      final opportunity = insights.where(
        (i) => i.type == InsightType.focusOpportunity,
      );

      expect(opportunity, hasLength(1));
      expect(opportunity.single.description, contains('9am'));
    });

    test('a shaky window is not turned into advice', () {
      final insights = generateInsights(range: rangeOf(2));

      expect(
        insights.where((i) => i.type == InsightType.focusOpportunity),
        isEmpty,
        reason: 'do not tell someone to plan around two days of data',
      );
    });

    test('scattered minutes produce no window', () {
      final scattered = aggregateRange(<DailyProductivitySummary>[
        for (var i = 0; i < 5; i++)
          aggregateDay('2026-09-0${i + 1}', <ActivitySegment>[
            seg(DateTime(2026, 9, 1 + i), fromMinute: 540, toMinute: 545),
          ]),
      ]);

      final insights = generateInsights(range: scattered);
      expect(insights.where((i) => i.type == InsightType.focusWindow), isEmpty);
    });
  });

  group('afternoon context switching', () {
    test('reports a real rise after lunch', () {
      // Long morning blocks, short afternoon ones: the same work, switched
      // between far more often after lunch.
      final range = aggregateRange(<DailyProductivitySummary>[
        for (var i = 0; i < 7; i++)
          aggregateDay('2026-09-0${i + 1}', <ActivitySegment>[
            for (var block = 0; block < 4; block++)
              seg(
                DateTime(2026, 9, 1 + i),
                fromMinute: 540 + block * 30,
                toMinute: 570 + block * 30,
                app: block.isEven ? 'code' : 'chrome',
              ),
            for (var block = 0; block < 24; block++)
              seg(
                DateTime(2026, 9, 1 + i),
                fromMinute: 840 + block * 5,
                toMinute: 845 + block * 5,
                app: block.isEven ? 'code' : 'chrome',
              ),
          ]),
      ]);

      final shift = generateInsights(
        range: range,
      ).firstWhere((i) => i.id == 'afternoon-switching');

      final change = shift.supportingData['change']! as double;
      expect(change, greaterThan(0));
      expect(shift.description, contains('higher'));
      expect(shift.confidence, InsightConfidence.high);
    });

    test('calls out an undisturbed morning against a busy afternoon', () {
      // No morning switching at all: there is nothing to take a percentage of,
      // and the finding still has to be expressible.
      final range = aggregateRange(<DailyProductivitySummary>[
        for (var i = 0; i < 7; i++)
          aggregateDay('2026-09-0${i + 1}', <ActivitySegment>[
            seg(DateTime(2026, 9, 1 + i), fromMinute: 540, toMinute: 720),
            for (var block = 0; block < 24; block++)
              seg(
                DateTime(2026, 9, 1 + i),
                fromMinute: 840 + block * 5,
                toMinute: 845 + block * 5,
                app: block.isEven ? 'chrome' : 'slack',
              ),
          ]),
      ]);

      final shift = generateInsights(
        range: range,
      ).firstWhere((i) => i.id == 'afternoon-switching');

      expect(shift.supportingData['morningPerHour'], 0);
      expect(shift.description, contains('without switching'));
    });

    test('says nothing when the two halves are alike', () {
      // The same rhythm on both sides of lunch is not a finding.
      final insights = generateInsights(
        range: splitRange(7, morningBlocks: 12, afternoonBlocks: 12),
      );

      expect(
        insights.where((i) => i.id == 'afternoon-switching'),
        isEmpty,
        reason: 'a non-difference is not a finding',
      );
    });

    test('needs both halves of the day before comparing', () {
      // Mornings only — nothing to compare the afternoon against.
      final morningsOnly = aggregateRange(<DailyProductivitySummary>[
        for (var i = 0; i < 7; i++)
          aggregateDay('2026-09-0${i + 1}', <ActivitySegment>[
            seg(DateTime(2026, 9, 1 + i), fromMinute: 540, toMinute: 720),
          ]),
      ]);

      final insights = generateInsights(range: morningsOnly);
      expect(insights.where((i) => i.id == 'afternoon-switching'), isEmpty);
    });
  });

  group("today's observations", () {
    test('a day stands on its own evidence', () {
      final today = workday(DateTime(2026, 9, 20));
      final insights = generateInsights(
        range: RangeProductivitySummary.empty(),
        today: today,
      );

      final busiest = insights.firstWhere(
        (i) => i.type == InsightType.applicationPattern,
      );
      expect(busiest.confidence, InsightConfidence.high);
      expect(busiest.evidenceDayCount, 1);
      expect(busiest.title, 'code');
      expect(busiest.description, contains('3h'));
    });

    test('reports idle time when a real share of the day went nowhere', () {
      final day = aggregateDay('2026-09-20', <ActivitySegment>[
        seg(DateTime(2026, 9, 20), fromMinute: 540, toMinute: 660),
        seg(
          DateTime(2026, 9, 20),
          fromMinute: 660,
          toMinute: 780,
          kind: ActivityKind.idle,
        ),
      ]);

      final insights = generateInsights(
        range: RangeProductivitySummary.empty(),
        today: day,
      );

      final idle = insights.firstWhere((i) => i.type == InsightType.idleTime);
      expect(idle.supportingData['idleSeconds'], 120 * 60);
      expect(idle.description, contains('2h'));
    });

    test('stays quiet about a little idle time', () {
      final day = aggregateDay('2026-09-20', <ActivitySegment>[
        seg(DateTime(2026, 9, 20), fromMinute: 540, toMinute: 720),
        seg(
          DateTime(2026, 9, 20),
          fromMinute: 720,
          toMinute: 730,
          kind: ActivityKind.idle,
        ),
      ]);

      final insights = generateInsights(
        range: RangeProductivitySummary.empty(),
        today: day,
      );

      expect(insights.where((i) => i.type == InsightType.idleTime), isEmpty);
    });

    test('flags a heavily fragmented day', () {
      // Two hours of two-minute blocks: a switch every couple of minutes,
      // which is what fragmentation actually looks like.
      final day = splitDay(
        DateTime(2026, 9, 20),
        morningBlocks: 60,
        afternoonBlocks: 0,
        blockMinutes: 2,
      );
      final insights = generateInsights(
        range: RangeProductivitySummary.empty(),
        today: day,
      );

      final switching = insights.firstWhere((i) => i.id == 'today-switching');
      expect(switching.supportingData['switches'], greaterThan(10));
    });

    test('an empty day produces nothing', () {
      final insights = generateInsights(
        range: RangeProductivitySummary.empty(),
        today: DailyProductivitySummary.empty('2026-09-20'),
      );

      expect(insights, isEmpty);
    });
  });

  group('break rhythm', () {
    test('reports the balance of breaks against work', () {
      final insights = generateInsights(range: rangeOf(7, breakMinutes: 15));
      final breaks = insights.firstWhere(
        (i) => i.type == InsightType.breakPattern,
      );

      expect(breaks.supportingData['averageBreakSeconds'], 15 * 60);
      expect(breaks.supportingData['daysWithBreaks'], 7);
    });

    test('says nothing when no breaks were taken', () {
      final insights = generateInsights(range: rangeOf(7));

      expect(
        insights.where((i) => i.type == InsightType.breakPattern),
        isEmpty,
      );
    });
  });

  group('ordering', () {
    test('confident findings come before hedged ones', () {
      final insights = generateInsights(
        range: rangeOf(2, switchesAfternoon: 8, breakMinutes: 15),
        today: splitDay(
          DateTime(2026, 9, 20),
          morningBlocks: 60,
          afternoonBlocks: 0,
          blockMinutes: 2,
        ),
      );

      expect(insights.length, greaterThan(1));
      for (var i = 1; i < insights.length; i++) {
        expect(
          insights[i].confidence.index,
          greaterThanOrEqualTo(insights[i - 1].confidence.index),
          reason: 'a possibility must never outrank a measurement',
        );
      }
    });

    test('every finding carries the evidence behind it', () {
      final insights = generateInsights(
        range: rangeOf(7, switchesAfternoon: 8),
      );

      for (final insight in insights) {
        expect(insight.evidenceDayCount, greaterThan(0));
        expect(insight.supportingData, isNotEmpty);
        expect(insight.description, isNotEmpty);
      }
    });
  });
}
