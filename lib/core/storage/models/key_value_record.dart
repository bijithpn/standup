import 'package:objectbox/objectbox.dart';

/// Generic string key/value row; [type] records how [value] was encoded so it can be parsed back.
@Entity()
class KeyValueRecord {
  @Id()
  int id;

  @Unique()
  String key;

  String value;
  String type;

  KeyValueRecord({
    this.id = 0,
    required this.key,
    required this.value,
    required this.type,
  });
}
