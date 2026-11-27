import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/presentation/companion_live_preview.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AvatarSceneCatalog.instance.load();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live companion preview',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff78795e)),
        scaffoldBackgroundColor: const Color(0xffece9e2),
        useMaterial3: true,
      ),
      home: CompanionLivePreview(
        initialSpecies:
            AvatarSpecies.tryParse(Uri.base.queryParameters['species'] ?? '') ??
            AvatarSpecies.sheep,
      ),
    ),
  );
}
