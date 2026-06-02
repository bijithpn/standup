import 'package:objectbox/objectbox.dart';

@Entity()
class SessionState {
  @Id(assignable: true)
  int id = 1; // Singleton

  String lastSessionDate; // Format: "YYYY-MM-DD" (today's date)
  int workElapsedSeconds; // Duration of work since last break
  int totalWorkTodaySeconds; // Total work time for today
  int postureElapsedSeconds; // Health reminder counters
  int eyeBlinkElapsedSeconds;
  bool isPreBreak; // Was user in pre-break warning?
  String timerState; // Enum name: 'idle', 'running', 'paused', etc.
  @Property(type: PropertyType.date)
  DateTime? longBreakWindowStartedAt; // Timestamp for long break tracking

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
