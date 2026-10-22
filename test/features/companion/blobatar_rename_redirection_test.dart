import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/companion/controllers/companion_overlay_controller.dart';
import 'package:breakmate/features/companion/services/pet_registry_service.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class _FakeStorageService implements StorageService {
  @override
  bool get isReady => true;

  @override
  bool get hasFailed => false;

  @override
  String getString(String key, {String defaultValue = ''}) => defaultValue;

  @override
  bool getBool(String key, {bool defaultValue = false}) => defaultValue;

  @override
  int getInt(String key, {int defaultValue = 0}) => defaultValue;

  @override
  double getDouble(String key, {double defaultValue = 0.0}) => defaultValue;

  @override
  Future<bool> setString(String key, String value) async => true;

  @override
  Future<bool> setBool(String key, bool value) async => true;

  @override
  Future<bool> setInt(String key, int value) async => true;

  @override
  Future<bool> setDouble(String key, double value) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubSettingsRepository extends SettingsRepository {
  _StubSettingsRepository(this._model) : super(storage: _FakeStorageService());

  final SettingsModel _model;

  @override
  SettingsModel get currentSettings => _model;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EventBus eventBus;
  late CompanionOverlayController controller;
  late SettingsRepository settingsRepo;

  setUp(() {
    sl.reset();
    eventBus = EventBus.instance;
    sl.registerSingleton<EventBus>(eventBus);
    sl.registerSingleton<PetRegistryService>(PetRegistryService());

    settingsRepo = _StubSettingsRepository(
      const SettingsModel(
        companionEnabled: true,
        companionPetName: 'Blobby',
        companionPetTheme: 'blobatar',
      ),
    );
    sl.registerSingleton<SettingsRepository>(settingsRepo);

    controller = CompanionOverlayController(settingsRepo: settingsRepo);
  });

  tearDown(() {
    controller.dispose();
    sl.reset();
  });

  group('Blobatar Rename Redirection', () {
    test(
      'requestOpenBlobatarNameDialog sets pending flag and increments notifier',
      () {
        int count = 0;
        controller.openBlobatarNameDialogNotifier.addListener(() {
          count++;
        });

        expect(controller.consumePendingBlobatarNameDialogRequest(), isFalse);

        controller.requestOpenBlobatarNameDialog();

        expect(count, equals(1));
        expect(controller.consumePendingBlobatarNameDialogRequest(), isTrue);
        // Second call returns false since it was already consumed
        expect(controller.consumePendingBlobatarNameDialogRequest(), isFalse);
      },
    );

    test(
      'receiving openBlobatarEditor CompanionInteractionEvent requests dialog open',
      () async {
        int count = 0;
        controller.openBlobatarNameDialogNotifier.addListener(() {
          count++;
        });

        eventBus.emit(
          CompanionInteractionEvent(
            interactionType: 'openBlobatarEditor',
            metadata: {'petName': 'Blobby'},
          ),
        );

        // Wait a microtask for stream event processing
        await Future.delayed(Duration.zero);

        expect(count, equals(1));
        expect(controller.consumePendingBlobatarNameDialogRequest(), isTrue);
        expect(controller.consumePendingBlobatarNameDialogRequest(), isFalse);
      },
    );
  });
}
