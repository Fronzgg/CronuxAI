class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final String model;
  final bool searchUsed;
  final DateTime ts;

  ChatMessage({
    required this.role,
    required this.content,
    required this.model,
    this.searchUsed = false,
    DateTime? ts,
  }) : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'role': role, 'content': content, 'model': model,
    'searchUsed': searchUsed, 'ts': ts.millisecondsSinceEpoch,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    role: j['role'], content: j['content'], model: j['model'] ?? 'cronux',
    searchUsed: j['searchUsed'] ?? false,
    ts: DateTime.fromMillisecondsSinceEpoch(j['ts'] ?? 0),
  );
}

class Chat {
  final String id;
  String title;
  List<ChatMessage> messages;
  String model;

  Chat({required this.id, required this.title, required this.messages, required this.model});

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'model': model,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
    id: j['id'], title: j['title'], model: j['model'] ?? 'cronux',
    messages: (j['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList(),
  );
}

class User {
  final String username;
  final bool unlimited;
  final String plan; // 'free' | 'pro'

  User({required this.username, required this.unlimited, required this.plan});

  Map<String, dynamic> toJson() => {'username': username, 'unlimited': unlimited, 'plan': plan};
  factory User.fromJson(Map<String, dynamic> j) => User(
    username: j['username'], unlimited: j['unlimited'] ?? false, plan: j['plan'] ?? 'free',
  );

  bool get isPro => unlimited || plan == 'pro';
  int get dailyLimit => unlimited ? 999999 : (isPro ? 100 : 3);
}
