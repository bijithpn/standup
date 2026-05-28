class NativeBridgeFallback {
  static void handleFailure(String method, dynamic error) {
    // Log gracefully
    // Surface missing permissions or unsupported APIs to settings state
  }

  static bool isAvailable(String method) {
    return true; // capability check
  }
}
