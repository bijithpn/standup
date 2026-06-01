enum FlavorType { dev, prod }

class FlavorConfig {
  final String appName;
  final String bundleId;
  final FlavorType flavorType;
  final String sentryDsn;

  static FlavorConfig? _instance;

  FlavorConfig._internal({
    required this.appName,
    required this.bundleId,
    required this.flavorType,
    required this.sentryDsn,
  });

  factory FlavorConfig({
    required String appName,
    required String bundleId,
    required FlavorType flavorType,
    required String sentryDsn,
  }) {
    _instance ??= FlavorConfig._internal(
      appName: appName,
      bundleId: bundleId,
      flavorType: flavorType,
      sentryDsn: sentryDsn,
    );
    return _instance!;
  }

  static FlavorConfig get instance {
    if (_instance == null) {
      throw StateError("FlavorConfig is not initialized. Call FlavorConfig(...) first.");
    }
    return _instance!;
  }

  /// Convenience getter for current flavor type
  static FlavorType get current => instance.flavorType;

  /// Convenience check for dev flavor
  static bool get isDevelopment => instance.isDev;

  bool get isDev => flavorType == FlavorType.dev;
  bool get isProd => flavorType == FlavorType.prod;
}
