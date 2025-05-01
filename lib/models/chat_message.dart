class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, this.isUser = false});
  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      ChatMessage(text: json['text'], isUser: json['isUser']);
  Map<String, dynamic> toJson() => {'text': text, 'isUser': isUser};
}