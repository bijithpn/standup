import 'package:objectbox/objectbox.dart';

/// Single-row (id 1) snapshot of timer progress, used to resume the session after a restart.
@Entity()
class SessionState {
  @Id(assignable: true)
  int id = 1;

  String lastSessionDate;
  int workElapsedSeconds;
  int totalWorkTodaySeconds;
  int postureElapsedSeconds;
  int eyeBlinkElapsedSeconds;
  bool isPreBreak;
  String timerState;
  @Property(type: PropertyType.date)
  DateTime? longBreakWindowStartedAt;

  SessionState({
    this.id = 1,
    required this.lastSessionDate,
    this.workElapsedSeconds = 0,
    this.totalWorkTodaySeconds = 0,
    this.postureElapsedSeconds = 0,
    this.eyeBlinkElapsedSeconds = 0,
    this.isPreBreak = false,
    required this.timerState,
    this.longBreakWindowStartedAt,
  });
}
