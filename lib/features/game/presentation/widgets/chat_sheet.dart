import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/arena_theme.dart';
import '../../../chat/bot_chat_brain.dart';

/// Compact in-game chat overlay. It deliberately sits near the top so the
/// board remains visible, just like the reference, and it moves safely above
/// the software keyboard on short devices.
class ChatSheet extends StatefulWidget {
  final BotChatBrain chat;

  const ChatSheet({super.key, required this.chat});

  static Future<void> show(BuildContext context, BotChatBrain chat) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (dialogContext) => ChatSheet(chat: chat),
    );
  }

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    // Do not allow sending messages after the game ends.
    if (widget.chat.isLocked) return;
    _input.clear();
    widget.chat.onUserMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = media.size.height - media.viewInsets.bottom - media.padding.top - 24;
    final panelHeight = min(360.0, max(230.0, available));
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Material(
            color: const Color(0xFFF7F8FA),
            elevation: 18,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: ArenaTheme.line),
            ),
            child: SizedBox(
              width: min(media.size.width - 16, 520.0),
              height: panelHeight,
              child: Column(
                children: [
                  _header(),
                  Expanded(child: _messages()),
                  _composer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: const Color(0xFF173A50),
      padding: const EdgeInsets.fromLTRB(12, 9, 5, 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Chat with ${widget.chat.bot.displayName}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: widget.chat,
            builder: (context, child) => widget.chat.botTyping
                ? const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('typing…', style: TextStyle(color: ArenaTheme.emerald, fontSize: 11)),
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _messages() {
    return AnimatedBuilder(
      animation: widget.chat,
      builder: (context, child) {
        final messages = widget.chat.messages;
        if (messages.length != _lastCount) {
          _lastCount = messages.length;
          WidgetsBinding.instance.addPostFrameCallback((duration) {
            if (_scroll.hasClients) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
        }
        if (messages.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined, size: 30, color: ArenaTheme.chessBlue),
                  SizedBox(height: 9),
                  Text(
                    'Game chat',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF253746)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Messages from you and your opponent appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF637381), fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
          itemCount: messages.length + (widget.chat.botTyping ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= messages.length) return const _TypingBubble();
            final message = messages[index];
            return _bubble(message.text, message.isBot);
          },
        );
      },
    );
  }

  Widget _bubble(String text, bool isBot) {
    final speaker = isBot ? widget.chat.bot.name : 'You';
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isBot ? const Color(0xFFF0F3F4) : const Color(0xFFDDF2E4),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFD5DEE2)),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$speaker: ',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              TextSpan(text: text),
            ],
          ),
          style: const TextStyle(color: Color(0xFF172329), fontSize: 13),
        ),
      ),
    );
  }

  Widget _composer() {
    if (widget.chat.isLocked) {
      return Container(
        color: ArenaTheme.cardDeep,
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        child: const Text(
          'Game over — chat closed',
          style: TextStyle(color: Color(0xFF8A969C), fontSize: 13),
        ),
      );
    }
    return Container(
      color: ArenaTheme.cardDeep,
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 39,
              child: TextField(
                controller: _input,
                style: const TextStyle(color: Color(0xFF172329), fontSize: 13),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Message',
                  hintStyle: const TextStyle(color: Color(0xFF8A969C)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (text) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            height: 39,
            child: FilledButton(
              onPressed: _send,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
              child: const Text('Send', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3F4),
          borderRadius: BorderRadius.circular(7),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final count = (_controller.value * 3).floor() % 3 + 1;
            return Text(
              '.' * count,
              style: const TextStyle(
                color: Color(0xFF50616A),
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            );
          },
        ),
      ),
    );
  }
}
