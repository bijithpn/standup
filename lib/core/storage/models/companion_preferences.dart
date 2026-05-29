import 'package:objectbox/objectbox.dart';

@Entity()
class CompanionPreferences {
  @Id()
  int id;

  bool companionEnabled;
  String companionPetTheme;
  String companionPetName;
  double companionScale;
  bool companionClickThrough;
  bool companionFollowMouse;

  CompanionPreferences({
    this.id = 0,
    this.companionEnabled = false,
    this.companionPetTheme = 'grey_cat',
    this.companionPetName = 'Mochi',
    this.companionScale = 1.5,
    this.companionClickThrough = false,
    this.companionFollowMouse = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companionEnabled': companionEnabled,
      'companionPetTheme': companionPetTheme,
      'companionPetName': companionPetName,
      'companionScale': companionScale,
      'companionClickThrough': companionClickThrough,
      'companionFollowMouse': companionFollowMouse,
    };
  }
}
