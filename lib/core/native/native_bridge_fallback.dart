class NativeBridgeFallback {
  static void handleFailure(String method, dynamic error) {}

  static bool isAvailable(String method) {
    return true; // capability check
  }
}
