/// One line in the game chat.
class ChatMessage {
  final String id;
  final String text;
  final bool isBot;
  final DateTime at;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isBot,
    required this.at,
  });
}
