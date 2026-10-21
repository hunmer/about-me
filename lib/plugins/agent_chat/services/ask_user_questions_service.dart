import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class UserQuestion {
  const UserQuestion({
    required this.id,
    required this.question,
    this.header = '',
    this.options = const [],
    this.multiSelect = false,
  });

  final String id;
  final String question;
  final String header;
  final List<Map<String, String>> options;
  final bool multiSelect;

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'header': header,
    'options': options,
    'multiSelect': multiSelect,
  };

  static List<UserQuestion> parse(Map<String, dynamic> args) {
    final raw = args['questions'];
    if (raw is! List || raw.isEmpty || raw.length > 4) {
      throw const FormatException('questions 必须包含 1 至 4 个问题');
    }
    final ids = <String>{};
    return raw.map((item) {
      if (item is! Map) throw const FormatException('问题必须是对象');
      final id = item['id'];
      final question = item['question'];
      if (id is! String || id.trim().isEmpty || !ids.add(id)) {
        throw const FormatException('每个问题的 id 必须非空且唯一');
      }
      if (question is! String || question.trim().isEmpty) {
        throw const FormatException('question 必须是非空字符串');
      }
      if ((item['header'] != null && item['header'] is! String) ||
          (item['multiSelect'] != null && item['multiSelect'] is! bool)) {
        throw const FormatException('header 必须是字符串，multiSelect 必须是布尔值');
      }
      final rawOptions = item['options'] ?? const [];
      if (rawOptions is! List) {
        throw const FormatException('options 必须是数组');
      }
      final labels = <String>{};
      final options = rawOptions.map((option) {
        if (option is! Map ||
            option['label'] is! String ||
            (option['label'] as String).trim().isEmpty ||
            !labels.add(option['label'] as String) ||
            (option['description'] != null &&
                option['description'] is! String)) {
          throw const FormatException('选项需要非空且唯一的 label，可选 description 为字符串');
        }
        return {
          'label': option['label'] as String,
          'description': option['description'] as String? ?? '',
        };
      }).toList();
      return UserQuestion(
        id: id,
        question: question,
        header: item['header'] as String? ?? '',
        options: options,
        multiSelect: item['multiSelect'] as bool? ?? false,
      );
    }).toList();
  }
}

/// 一次提问独立等待，使用 requestId 防止并发会话串答。
class UserQuestionsRequest extends ChangeNotifier {
  UserQuestionsRequest._(this.questions) : id = const Uuid().v4();

  final String id;
  final List<UserQuestion> questions;
  final _completer = Completer<Map<String, dynamic>>();
  Map<String, dynamic>? result;
  bool get isPending => !_completer.isCompleted;
  Future<Map<String, dynamic>> get future => _completer.future;

  Map<String, dynamic> toJson() => {
    'requestId': id,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  bool answer(List<Map<String, dynamic>> answers) {
    if (!isPending || answers.length != questions.length) return false;
    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final answer = answers[i];
      final selected = answer['selected'];
      final text = answer['text'];
      if (answer['id'] != question.id ||
          selected is! List<String> ||
          text is! String ||
          (selected.isEmpty && text.trim().isEmpty) ||
          (!question.multiSelect && selected.length > 1) ||
          selected.toSet().length != selected.length ||
          selected.any(
            (label) => !question.options.any((o) => o['label'] == label),
          )) {
        return false;
      }
    }
    _complete({'status': 'answered', 'answers': answers});
    return true;
  }

  void cancel([String reason = '用户取消回答']) {
    _complete({'status': 'cancelled', 'reason': reason, 'answers': <Object>[]});
  }

  void _complete(Map<String, dynamic> value) {
    if (!isPending) return;
    result = value;
    _completer.complete(value);
    notifyListeners();
  }
}

class AskUserQuestionsService {
  AskUserQuestionsService._();
  static final instance = AskUserQuestionsService._();

  final _requests = <String, UserQuestionsRequest>{};

  UserQuestionsRequest? find(String id) => _requests[id];

  UserQuestionsRequest create(
    List<UserQuestion> questions, {
    bool Function()? isCancelling,
  }) {
    final request = UserQuestionsRequest._(questions);
    _requests[request.id] = request;
    Timer? timer;
    if (isCancelling != null) {
      if (isCancelling()) {
        request.cancel('已取消发送');
      } else {
        timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
          if (isCancelling()) request.cancel('已取消发送');
        });
      }
    }
    unawaited(
      request.future.then((_) {
        timer?.cancel();
        _requests.remove(request.id);
      }),
    );
    return request;
  }
}
