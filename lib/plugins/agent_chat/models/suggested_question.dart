/// 保留分组信息和列表顺序，避免不同分组的同名问题互相影响。
class SuggestedQuestion {
  const SuggestedQuestion({
    required this.category,
    required this.categoryName,
    required this.question,
  });

  final String category;
  final String categoryName;
  final String question;

  Map<String, dynamic> toJson() => {
    'category': category,
    'categoryName': categoryName,
    'question': question,
  };
}
