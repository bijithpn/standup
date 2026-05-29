class NativePermissionStatus {
  final bool isMeetingDetectionAvailable;
  final bool isFocusModeAvailable;
  final bool isNotificationsAllowed;
  final bool isLaunchAtStartupEnabled;

  const NativePermissionStatus({
    this.isMeetingDetectionAvailable = false,
    this.isFocusModeAvailable = false,
    this.isNotificationsAllowed = false,
    this.isLaunchAtStartupEnabled = false,
  });

  NativePermissionStatus copyWith({
    bool? isMeetingDetectionAvailable,
    bool? isFocusModeAvailable,
    bool? isNotificationsAllowed,
    bool? isLaunchAtStartupEnabled,
  }) {
    return NativePermissionStatus(
      isMeetingDetectionAvailable:
          isMeetingDetectionAvailable ?? this.isMeetingDetectionAvailable,
      isFocusModeAvailable: isFocusModeAvailable ?? this.isFocusModeAvailable,
      isNotificationsAllowed:
          isNotificationsAllowed ?? this.isNotificationsAllowed,
      isLaunchAtStartupEnabled:
          isLaunchAtStartupEnabled ?? this.isLaunchAtStartupEnabled,
    );
  }
}
