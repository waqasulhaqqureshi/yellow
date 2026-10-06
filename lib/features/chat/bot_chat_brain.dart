import 'dart:math';

import 'package:flutter/foundation.dart';

import '../bot/domain/bot_profile.dart';
import '../bot/domain/bot_personality.dart';
import 'chat_matrix.dart';
import 'chat_message.dart';
import 'heuristic_reply_engine.dart';
import 'persona/abuse_guard.dart';
import 'persona/chat_persona.dart';
import 'persona/group_corpus.dart';
import 'persona/persona_corpus.dart';
import 'persona/rich_corpus.dart';
import 'persona/typo_engine.dart';

/// Orchestrates everything the bot says during a game.
///
/// Layer 0: Persona — a per-bot social voice (style, city, typos, response
///          rate) that drives intros, origin/city chat and whether the bot
///          replies at all.
/// Layer 1: Game events → personality-flavored scripted matrix (rate-limited).
/// Layer 2: Human free text → HeuristicReplyEngine (pattern + fuzzy + context).
/// Layer 3: Fallback → confused/intent matrix replies.
///
/// Features:
///   • Persona-driven intro ("where are you from?", city talk, salty opens).
///   • Human-like typos / slang / emoji via [TypoEngine].
///   • Silent bots that sometimes leave you on read.
///   • Human-like response policy (skip chance, typing delay, mood).
///   • Chat lock after game ends — no new messages accepted.
///   • Rate limiting per personality (cooldown + max lines per game).
///   • Anti-repetition (engine tracks last reply).
class BotChatBrain extends ChangeNotifier {
  BotChatBrain({
    required this.bot,
    required this.humanName,
    Random? random,
  })  : _random = random ?? Random(),
        persona = ChatPersona.fromBot(bot, random: random) {
    _heuristicEngine = HeuristicReplyEngine(
      botName: bot.name,
      humanName: humanName,
      personality: bot.personality,
      random: _random,
    );
  }

  final BotProfile bot;
  final String humanName;
  final Random _random;

  /// This bot's social voice.
  final ChatPersona persona;

  late final HeuristicReplyEngine _heuristicEngine;

  final List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _botTyping = false;

  bool get botTyping => _botTyping;

  DateTime? _lastBotLineAt;
  int _botLinesThisGame = 0;
  static const int _maxLinesPerGame = 40;
  bool _disposed = false;
  bool _locked = false;
  bool _introDone = false;

  /// Whether the chat sheet is currently on screen. Bot messages that
  /// arrive while it is closed count as unread (red badge on the chat icon).
  bool chatOpen = false;
  int _unread = 0;
  int get unread => _unread;
  void markRead() {
    _unread = 0;
    if (!_disposed) notifyListeners();
  }

  /// City/country the human told us, remembered for follow-ups.
  String? userCity;

  /// Name the human asked us to use ("call me Ali"). Overrides the generated
  /// "Player1234" handle so the bot never addresses a placeholder.
  String? _preferredName;
  String? _fallbackTerm;

  /// When true, the chat is locked (game over). No new user messages are
  /// accepted and the bot will not generate new replies.
  bool get isLocked => _locked;

  /// Lock the chat — called when the game ends.
  void lock() {
    _locked = true;
  }

  /// True when the profile name is a real, human-chosen name (not the
  /// generated "Player1234" placeholder).
  bool get _humanHasRealName {
    final n = humanName.trim();
    return n.isNotEmpty &&
        !RegExp(r'^player\s*\d*$', caseSensitive: false).hasMatch(n);
  }

  /// What the bot calls the human: their chosen name if known, else a warm
  /// generic term — never "Player1234".
  String _addressName() {
    if (_preferredName != null) return _preferredName!;
    if (_humanHasRealName) return humanName;
    _fallbackTerm ??=
        const ['friend', 'mate', 'champ', 'amigo'][_random.nextInt(4)];
    return _fallbackTerm!;
  }

  String _fill(String template) {
    return template
        .replaceAll('{name}', _addressName())
        .replaceAll('{bot}', bot.name);
  }

  String _fillPersona(String template) {
    return _fill(template)
        .replaceAll('{city}', persona.city)
        .replaceAll('{country}', persona.country)
        .replaceAll('{userCity}', userCity ?? 'there');
  }

  void _pushBot(String text) {
    if (text.trim().isEmpty) return;
    _messages.add(
      ChatMessage(
        id: 'b-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(9999)}',
        text: text,
        isBot: true,
        at: DateTime.now(),
      ),
    );
    _lastBotLineAt = DateTime.now();
    _botLinesThisGame++;
    if (!chatOpen) _unread++;
    if (!_disposed) notifyListeners();
  }

  void _pushHuman(String text) {
    _messages.add(
      ChatMessage(
        id: 'h-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(9999)}',
        text: text,
        isBot: false,
        at: DateTime.now(),
      ),
    );
    if (!_disposed) notifyListeners();
  }

  bool _cooldownOk() {
    if (_botLinesThisGame >= _maxLinesPerGame) return false;
    final last = _lastBotLineAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= bot.personality.chatCooldown;
  }

  /// Persona-driven opener, called once when the game starts. Replaces the
  /// generic matrix gameStart line with a voice that matches the bot.
  Future<void> startIntro() async {
    if (_introDone || _disposed) return;
    _introDone = true;
    // The bot does NOT always text first: roughly half of eager personas
    // and a small share of quiet ones open the conversation.
    if (_random.nextDouble() > persona.introEagerness * 0.5) return;

    final openers = PersonaCorpus.opener(persona.style)
        .where((l) => l.isNotEmpty)
        .toList();
    if (openers.isNotEmpty) {
      final line = _humanize(_fillPersona(openers[_random.nextInt(openers.length)]));
      await _typeAndSend(line);
    }
    // Curious bots follow up by asking where you're from.
    if (!_disposed && persona.asksQuestions && _random.nextDouble() < 0.6) {
      final asks = PersonaCorpus.askOrigin(persona.style);
      final line = _humanize(_fillPersona(asks[_random.nextInt(asks.length)]));
      await _typeAndSend(line);
    }
    // If the human is still a "Player1234", curious bots ask what to call them.
    if (!_disposed && !_humanHasRealName && persona.asksQuestions &&
        _random.nextDouble() < 0.5) {
      final line = _humanize(_fillPersona(
        persona.style == ChatStyle.formal
            ? 'What should I call you, if I may ask?'
            : 'what should i call you? just tell me your name',
      ));
      await _typeAndSend(line);
    }
  }

  String _humanize(String text) =>
      AbuseGuard.censor(TypoEngine.humanize(text, persona, _random));

  /// Occasional mid-game banter reflecting whether the bot feels winning.
  /// Rate-limited so it never spams.
  Future<void> emitBanter({required bool winning}) async {
    if (_locked || _disposed) return;
    if (!_cooldownOk()) return;
    if (_random.nextDouble() > bot.personality.chatFrequency) return;
    final pool = RichCorpus.banter(persona.style, winning);
    final line = _humanize(_fillPersona(pool[_random.nextInt(pool.length)]));
    await _typeAndSend(line);
  }

  /// Game-event line (blunders, captures, results...). Fire-and-forget with
  /// typing simulation. [force] bypasses rate limits, [instant] skips the
  /// typing delay (used for game results).
  Future<void> onEvent(
    BotChatEvent event, {
    bool force = false,
    bool instant = false,
  }) async {
    if (_disposed) return;
    if (!force) {
      if (!_cooldownOk()) return;
      if (_random.nextDouble() > bot.personality.chatFrequency) return;
    }
    var line = _fill(ChatMatrix.pickEvent(event, bot.personality, _random));
    line = _humanize(line);
    if (instant) {
      _pushBot(line);
      _heuristicEngine.recordBotEvent(line);
      return;
    }
    await _typeAndSend(line);
    _heuristicEngine.recordBotEvent(line);
  }

  /// Player sent a free-text message. Returns immediately; the reply arrives
  /// asynchronously with a typing indicator.
  Future<void> onUserMessage(String raw) async {
    if (_locked) return;
    final text = raw.trim();
    if (text.isEmpty || _disposed) return;
    _pushHuman(text);

    // ── Persona layer: social / origin conversation ────────────────────
    final social = _handleSocial(text);
    if (social != null) {
      await _typeAndSend(social);
      return;
    }

    // Silent / low-response bots sometimes just don't reply.
    if (_random.nextDouble() > persona.responseRate) {
      return;
    }

    final reply = _heuristicEngine.generateReply(
      userInput: text,
      context: GameContext(
        isGameOver: _locked,
        moveCount: _botLinesThisGame * 2,
      ),
    );

    if (_disposed) return;
    if (reply.text == null || reply.text!.isEmpty) return;

    await _typeAndSend(_humanize(reply.text!), customDelayMs: reply.typingDelayMs);
  }

  /// Handles origin/city/small-talk conversation that the persona owns.
  /// Returns a humanized reply, or null to fall through to the engine.
  String? _handleSocial(String text) {
    final t = text.toLowerCase();

    // Abuse: known, star-censored and answered with a scold — never
    // ignored, never repeated.
    if (AbuseGuard.containsAbuse(text)) {
      return _humanize(AbuseGuard.reprimand(persona.style, _random));
    }

    // Roman Urdu / Hindi in → Roman Urdu out.
    if (RomanUrdu.detect(t)) {
      final pool = t.contains('?') ||
              RegExp(r'\b(kya|kahan|kaun|kab|kyun|kyu|kaisa|kaisi)\b').hasMatch(t)
          ? GroupCorpus.urduAnswers
          : (_random.nextInt(100) < 65
              ? GroupCorpus.romanUrdu
              : GroupCorpus.urduAnswers);
      return _humanize(pool[_random.nextInt(pool.length)]);
    }

    // User tells us their name ("call me Ali", "my name is Sara", "I'm Sara").
    var nameMatch = RegExp(
      r'(?:call me|my name is|name is)\s+([A-Za-z][A-Za-z0-9_]{2,15})\b',
    ).firstMatch(text);
    nameMatch ??= RegExp(r"\bI'?m\s+([A-Z][a-z0-9_]{2,15})\b").firstMatch(text);
    final candidate = nameMatch?.group(1);
    final isFiller = candidate == null ||
        const ['from', 'in', 'a', 'an', 'the', 'ok', 'good', 'here', 'not', 'so', 'very', 'just', 'really', 'tired', 'bored', 'winning', 'losing']
            .contains(candidate.toLowerCase());
    if (nameMatch != null && !isFiller) {
      _preferredName = candidate[0].toUpperCase() + candidate.substring(1);
      return _humanize(_fillPersona(
        persona.style == ChatStyle.salty
            ? '$_preferredName, huh. alright. lets go'
            : 'nice to meet you, $_preferredName!',
      ));
    }

    // User says bye / gg.
    if (RegExp(r'\b(bye|good ?bye|see you|gg)\b').hasMatch(t)) {
      final pool = RichCorpus.reactBye(persona.style);
      return _humanize(_fillPersona(pool[_random.nextInt(pool.length)]));
    }

    // User thanks the bot.
    if (RegExp(r'\b(thanks|thank you|thx|ty)\b').hasMatch(t)) {
      final pool = RichCorpus.reactThanks(persona.style);
      return _humanize(_fillPersona(pool[_random.nextInt(pool.length)]));
    }

    // User praises the bot.
    if (RegExp(r'\b(nice|well played|good move|great|awesome|wp|good game)\b')
        .hasMatch(t)) {
      final pool = RichCorpus.reactPraise(persona.style);
      return _humanize(_fillPersona(pool[_random.nextInt(pool.length)]));
    }

    // User taunts the bot.
    if (RegExp(r'\b(losing|lose|easy|bad bot|noob|weak|slow|i win|gonna win)\b')
        .hasMatch(t)) {
      final pool = RichCorpus.reactTaunt(persona.style);
      return _humanize(_fillPersona(pool[_random.nextInt(pool.length)]));
    }

    // User tells us their city/country: "im from Lahore", "i live in X".
    final userOrigin = _extractUserOrigin(t);
    if (userOrigin != null) {
      userCity = userOrigin;
      final pool = PersonaCorpus.reactUserCity(persona.style);
      return _humanize(_fillPersona(pool[_random.nextInt(pool.length)]));
    }

    // User asks which city (bot).
    if (RegExp(r'(which|what) (city|town)').hasMatch(t) ||
        (t.contains('city') && t.contains('you'))) {
      final pool = PersonaCorpus.answerCity(persona.style);
      return _humanize(_fillPersona(pool[_random.nextInt(pool.length)]));
    }

    // User asks where the bot is from / lives.
    if ((t.contains('where') && (t.contains('from') || t.contains('live') || t.contains('stay'))) ||
        t.contains('which country') ||
        RegExp(r'(ur|your) (country|city|place)').hasMatch(t) ||
        RegExp(r'where (do you|are you|you) (live|from|stay|located)').hasMatch(t) ||
        t.contains('where are you from')) {
      final pool = PersonaCorpus.answerOrigin(persona.style);
      return _humanize(_fillPersona(pool[_random.nextInt(pool.length)]));
    }

    // User asks the bot's name (again) or age / how it's doing.
    if (RegExp(r'\b(how are you|how r u|hows it going|how are u|kaise ho|sup|wassup|what.?s up)\b')
        .hasMatch(t)) {
      final pool = RichCorpus.reactGreeting(persona.style);
      return _humanize(_fillPersona(pool[_random.nextInt(pool.length)]));
    }

    return null;
  }

  /// Pulls the place name out of "im from X", "i live in X", "from X".
  String? _extractUserOrigin(String t) {
    final patterns = [
      RegExp(r"i\s*('?m| am)?\s*from\s+([a-z][a-z\s]{1,20})"),
      RegExp(r'i live in\s+([a-z][a-z\s]{1,20})'),
      RegExp(r'^from\s+([a-z][a-z\s]{1,20})'),
      RegExp(r'my city is\s+([a-z][a-z\s]{1,20})'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(t);
      if (m != null) {
        final raw = m.group(m.groupCount)!;
        final cleaned = raw.trim().split(RegExp(r'\s+')).take(2).join(' ');
        if (cleaned.length >= 3) {
          return cleaned[0].toUpperCase() + cleaned.substring(1);
        }
      }
    }
    return null;
  }

  Future<void> _typeAndSend(String text, {int? customDelayMs}) async {
    if (_disposed) return;
    if (text.trim().isEmpty) return;
    _botTyping = true;
    if (!_disposed) notifyListeners();

    final ms = customDelayMs ??
        (700 +
                _random.nextInt(1100) +
                text.length * 40 +
                (_random.nextDouble() < 0.2
                    ? 1500 + _random.nextInt(1500)
                    : 0))
            .clamp(1200, 8000);
    await Future.delayed(Duration(milliseconds: ms));
    if (_disposed) return;
    _botTyping = false;
    _pushBot(text);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
