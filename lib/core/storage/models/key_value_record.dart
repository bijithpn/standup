import 'package:objectbox/objectbox.dart';

@Entity()
class KeyValueRecord {
  @Id()
  int id;

  @Unique()
  String key;

  String value;
  String type; // 'int', 'bool', 'string', 'double'

  KeyValueRecord({
    this.id = 0,
    required this.key,
    required this.value,
    required this.type,
  });
}
