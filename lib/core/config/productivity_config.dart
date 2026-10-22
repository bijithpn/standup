import 'package:breakmate/core/config/flavor_config.dart';

/// What the productivity module is allowed to do in this build.
///
/// One configuration resolved from the flavour, not two implementations: the
/// development build differs only in what it exposes for diagnosis, never in
/// how it records or what it records. A production build that behaved
/// differently from the one being tested would defeat the point of testing it.
class ProductivityConfig {
  const ProductivityConfig({
    required this.enabled,
    required this.backgroundMonitoringEnabled,
    required this.insightsEnabled,
    required this.weeklyAnalyticsEnabled,
    required this.verboseLogging,
  });

  /// The module as a whole. Off means the Productivity screens are hidden and
  /// nothing new is recorded — without deleting any code or existing history.
  final bool enabled;

  /// Whether the tracker's poll loop may run. Still subject to the user's own
  /// `appUsageTrackingEnabled` consent, which this never overrides.
  final bool backgroundMonitoringEnabled;

  /// Whether derived findings are generated and shown.
  final bool insightsEnabled;

  /// Whether the multi-day views are offered.
  final bool weeklyAnalyticsEnabled;

  /// Event-level logging. Off in production, where the useful signal is an
  /// error, not a line per application switch.
  final bool verboseLogging;

  /// Everything on, with verbose logging — the development build.
  static const ProductivityConfig development = ProductivityConfig(
    enabled: true,
    backgroundMonitoringEnabled: true,
    insightsEnabled: true,
    weeklyAnalyticsEnabled: true,
    verboseLogging: true,
  );

  /// Everything on, quiet logging — the released build.
  static const ProductivityConfig production = ProductivityConfig(
    enabled: true,
    backgroundMonitoringEnabled: true,
    insightsEnabled: true,
    weeklyAnalyticsEnabled: true,
    verboseLogging: false,
  );

  /// The configuration for the running flavour.
  ///
  /// Falls back to production when the flavour has not been initialised, which
  /// happens in tests: the safer default is the one that exposes least.
  static ProductivityConfig get current {
    try {
      return FlavorConfig.instance.isDev ? development : production;
    } catch (_) {
      return production;
    }
  }

  ProductivityConfig copyWith({
    bool? enabled,
    bool? backgroundMonitoringEnabled,
    bool? insightsEnabled,
    bool? weeklyAnalyticsEnabled,
    bool? verboseLogging,
  }) {
    return ProductivityConfig(
      enabled: enabled ?? this.enabled,
      backgroundMonitoringEnabled:
          backgroundMonitoringEnabled ?? this.backgroundMonitoringEnabled,
      insightsEnabled: insightsEnabled ?? this.insightsEnabled,
      weeklyAnalyticsEnabled:
          weeklyAnalyticsEnabled ?? this.weeklyAnalyticsEnabled,
      verboseLogging: verboseLogging ?? this.verboseLogging,
    );
  }
}

/// How long recorded activity is kept.
///
/// Offered as a small set rather than a free number so the choice is a
/// judgement about privacy rather than an arithmetic exercise.
enum ActivityRetention {
  week('7 days', 7),
  month('30 days', 30),
  quarter('90 days', 90),
  forever('Forever', 0);

  const ActivityRetention(this.label, this.days);

  final String label;

  /// Days to keep, or 0 for no limit.
  final int days;

  /// The default: enough history for the weekly and monthly views to mean
  /// something, and no more. Matches what app usage has always pruned to.
  static const ActivityRetention defaultChoice = ActivityRetention.month;

  static ActivityRetention fromDays(int days) {
    for (final option in ActivityRetention.values) {
      if (option.days == days) return option;
    }
    return defaultChoice;
  }

  static ActivityRetention fromLabel(String label) {
    for (final option in ActivityRetention.values) {
      if (option.label == label) return option;
    }
    return defaultChoice;
  }
}
