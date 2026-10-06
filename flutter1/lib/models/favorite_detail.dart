class FavoriteDetail {
  const FavoriteDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.nextAction,
    required this.sourceUrl,
    required this.category,
    required this.status,
  });

  final int id;
  final String title;
  final String description;
  final String nextAction;
  final String sourceUrl;
  final String category;
  final String status;

  factory FavoriteDetail.fromJson(Map<String, dynamic> json) {
    return FavoriteDetail(
      id: int.parse(json['id'].toString()),
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      nextAction: json['nextAction'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      category: json['category'] as String? ?? 'text',
      status: json['status'] as String? ?? 'inbox',
    );
  }
}
