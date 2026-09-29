class Item {
  const Item({
    required this.id,
    required this.title,
    required this.nextAction,
    required this.sourceUrl,
    required this.category,
    required this.status,
  });

  final int id;
  final String title;
  final String nextAction;
  final String sourceUrl;
  final String category;
  final String status;

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: int.parse(json['id'].toString()),
      title: json['title'] as String,
      nextAction: json['nextAction'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      category: json['category'] as String? ?? 'text',
      status: json['status'] as String? ?? 'inbox',
    );
  }
}
