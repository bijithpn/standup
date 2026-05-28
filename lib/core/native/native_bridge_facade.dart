abstract class NativeBridgeFacade {
  Future<void> requestPermissions();
  Future<void> showOverlay(Map<String, dynamic> data);
  Future<void> hideOverlay();
  Future<void> setTrayTitle(String title);
  Future<void> setTrayTooltip(String tooltip);
  Future<bool> checkCapabilities();
}
