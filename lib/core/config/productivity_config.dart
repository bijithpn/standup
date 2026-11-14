import 'package:breakmate/core/config/flavor_config.dart';

/// Feature flags for productivity tracking (monitoring, insights, analytics), chosen per build flavor.
class ProductivityConfig {
  const ProductivityConfig({
    required this.enabled,
    required this.backgroundMonitoringEnabled,
    required this.insightsEnabled,
    required this.weeklyAnalyticsEnabled,
    required this.verboseLogging,
  });

  final bool enabled;

  final bool backgroundMonitoringEnabled;

  final bool insightsEnabled;

  final bool weeklyAnalyticsEnabled;

  final bool verboseLogging;

  static const ProductivityConfig development = ProductivityConfig(
    enabled: true,
    backgroundMonitoringEnabled: true,
    insightsEnabled: true,
    weeklyAnalyticsEnabled: true,
    verboseLogging: true,
  );

  static const ProductivityConfig production = ProductivityConfig(
    enabled: true,
    backgroundMonitoringEnabled: true,
    insightsEnabled: true,
    weeklyAnalyticsEnabled: true,
    verboseLogging: false,
  );

  // FlavorConfig may be uninitialised (e.g. in tests); fall back to production.
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

/// How long activity history is kept; `days == 0` means keep forever.
enum ActivityRetention {
  week('7 days', 7),
  month('30 days', 30),
  quarter('90 days', 90),
  forever('Forever', 0);

  const ActivityRetention(this.label, this.days);

  final String label;

  final int days;

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
