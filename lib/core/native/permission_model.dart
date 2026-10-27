class NativePermissionStatus {
  final bool isMeetingDetectionAvailable;
  final bool isNotificationsAllowed;
  final bool isLaunchAtStartupEnabled;

  const NativePermissionStatus({
    this.isMeetingDetectionAvailable = false,
    this.isNotificationsAllowed = false,
    this.isLaunchAtStartupEnabled = false,
  });

  NativePermissionStatus copyWith({
    bool? isMeetingDetectionAvailable,
    bool? isNotificationsAllowed,
    bool? isLaunchAtStartupEnabled,
  }) {
    return NativePermissionStatus(
      isMeetingDetectionAvailable:
          isMeetingDetectionAvailable ?? this.isMeetingDetectionAvailable,
      isNotificationsAllowed:
          isNotificationsAllowed ?? this.isNotificationsAllowed,
      isLaunchAtStartupEnabled:
          isLaunchAtStartupEnabled ?? this.isLaunchAtStartupEnabled,
    );
  }
}
