class Folder {
  const Folder({required this.id, required this.name, required this.itemCount});

  final int id;
  final String name;
  final int itemCount;

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    id: int.parse(json['id'].toString()),
    name: json['name'] as String,
    itemCount: int.tryParse(json['itemCount'].toString()) ?? 0,
  );
}
