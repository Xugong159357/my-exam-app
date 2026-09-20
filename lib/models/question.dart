class Question {
  final int id;
  final String content;
  final String correctAnswer;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  bool isFavorite;
  bool isWrong;

  Question({
    required this.id,
    required this.content,
    required this.correctAnswer,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    this.isFavorite = false,
    this.isWrong = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'correct_answer': correctAnswer,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'is_favorite': isFavorite ? 1 : 0,
      'is_wrong': isWrong ? 1 : 0,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'],
      content: map['content'] ?? '',
      correctAnswer: (map['correct_answer'] ?? '').toString().trim().toUpperCase(),
      optionA: map['option_a'] ?? '',
      optionB: map['option_b'] ?? '',
      optionC: map['option_c'] ?? '',
      optionD: map['option_d'] ?? '',
      isFavorite: map['is_favorite'] == 1,
      isWrong: map['is_wrong'] == 1,
    );
  }
}