class TemplateModel {
  final String id;
  final String name;
  final String description;
  final bool requiresFocus;

  const TemplateModel({
    required this.id,
    required this.name,
    required this.description,
    this.requiresFocus = false,
  });
}
