import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../persona/abuse_guard.dart';
import '../persona/chat_persona.dart';
import '../persona/group_corpus.dart';
import '../persona/typo_engine.dart';
import 'group_models.dart';

/// Simulates a living group-chat room: members converse with each other on
/// a bursty human schedule, react to the user through a lightweight intent
/// router, and never repeat a line already shown this session.
///
/// Pure on-device logic — no dependencies, no network.
class GroupChatController extends ChangeNotifier {
  GroupChatController({Random? random}) : _random = random ?? Random();

  /// App-wide instance so the sheet, explore and rooms share one state.
  static final GroupChatController shared = GroupChatController();

  final Random _random;
  bool _initialized = false;

  Box<dynamic>? _box;
  final Set<String> _joined = <String>{};
  final Map<String, List<GroupMessage>> _rooms = {};
  final Map<String, Set<String>> _shown = {};
  Timer? _ambientTimer;
  Timer? _burstTimer;
  String? _activeRoom;
  bool _lastWasQuestion = false;

  static const String _boxName = 'arena_groups';

  Set<String> get joinedIds => Set.unmodifiable(_joined);
  bool get hasJoined => _joined.isNotEmpty;
  List<GroupMessage> messagesFor(String groupId) =>
      List.unmodifiable(_rooms[groupId] ?? const []);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _box = await Hive.openBox<dynamic>(_boxName);
    final stored = _box!.get('joined');
    if (stored is List) {
      _joined.addAll(stored.whereType<String>());
    }
    notifyListeners();
  }

  Future<void> join(String groupId) async {
    _joined.add(groupId);
    await _box?.put('joined', _joined.toList());
    notifyListeners();
  }

  // ── Persona voice per style ──────────────────────────────────────────

  static ChatPersona _personaFor(GroupMember m) {
    switch (m.style) {
      case ChatStyle.salty:
        return const ChatPersona(
          style: ChatStyle.salty,
          city: 'Karachi',
          country: 'Pakistan',
          responseRate: 0.8,
          typoRate: 0.16,
          slangRate: 0.5,
          emojiRate: 0.08,
          asksQuestions: false,
          introEagerness: 0.3,
        );
      case ChatStyle.cheerful:
        return const ChatPersona(
          style: ChatStyle.cheerful,
          city: 'Lahore',
          country: 'Pakistan',
          responseRate: 0.95,
          typoRate: 0.06,
          slangRate: 0.3,
          emojiRate: 0.5,
          asksQuestions: true,
          introEagerness: 0.8,
        );
      case ChatStyle.formal:
        return const ChatPersona(
          style: ChatStyle.formal,
          city: 'Islamabad',
          country: 'Pakistan',
          responseRate: 0.7,
          typoRate: 0,
          slangRate: 0,
          emojiRate: 0,
          asksQuestions: true,
          introEagerness: 0.4,
        );
      case ChatStyle.silent:
        return const ChatPersona(
          style: ChatStyle.silent,
          city: 'Quetta',
          country: 'Pakistan',
          responseRate: 0.25,
          typoRate: 0.1,
          slangRate: 0.2,
          emojiRate: 0,
          asksQuestions: false,
          introEagerness: 0.1,
        );
      case ChatStyle.rash:
        return const ChatPersona(
          style: ChatStyle.rash,
          city: 'Multan',
          country: 'Pakistan',
          responseRate: 0.85,
          typoRate: 0.22,
          slangRate: 0.55,
          emojiRate: 0.15,
          asksQuestions: false,
          introEagerness: 0.5,
        );
      default:
        return const ChatPersona(
          style: ChatStyle.normal,
          city: 'Hyderabad',
          country: 'Pakistan',
          responseRate: 0.8,
          typoRate: 0.12,
          slangRate: 0.35,
          emojiRate: 0.2,
          asksQuestions: true,
          introEagerness: 0.5,
        );
    }
  }

  String _voice(GroupMember m, String line) =>
      TypoEngine.humanize(line, _personaFor(m), _random);

  // ── Line selection (no repeats, thread-aware) ────────────────────────

  String _pick(String topic, {bool question = false, bool answer = false}) {
    final pool = question
        ? GroupCorpus.questions
        : answer
            ? GroupCorpus.answers
            : (GroupCorpus.byTopic[topic] ?? GroupCorpus.chessTalk);
    for (var attempt = 0; attempt < 24; attempt++) {
      final line = pool[_random.nextInt(pool.length)];
      final seen = _shown.putIfAbsent(_activeRoom ?? 'global', () => {});
      if (!seen.contains(line)) {
        seen.add(line);
        return line;
      }
    }
    return pool[_random.nextInt(pool.length)];
  }

  GroupMember _speaker(ChatGroup g, [GroupMember? exclude]) {
    for (var i = 0; i < 8; i++) {
      final m = g.members[_random.nextInt(g.members.length)];
      if (exclude == null || m.name != exclude.name) return m;
    }
    return g.members[_random.nextInt(g.members.length)];
  }

  // ── Room lifecycle ───────────────────────────────────────────────────

  /// Seeds a backlog and starts the ambient conversation for a room.
  void openRoom(String groupId) {
    _activeRoom = groupId;
    final g = GroupCatalog.byId(groupId);
    final room = _rooms.putIfAbsent(groupId, () => <GroupMessage>[]);
    if (room.isEmpty) {
      final backlog = 8 + _random.nextInt(6);
      for (var i = 0; i < backlog; i++) {
        final m = _speaker(g);
        final line = _ambientLine(g, null);
        room.add(GroupMessage(
          senderName: m.name,
          senderSeed: m.avatarSeed,
          isoCode: m.isoCode,
          text: _voice(m, line),
        ));
      }
    }
    _scheduleAmbient(g);
    notifyListeners();
  }

  void closeRoom() {
    _activeRoom = null;
    _ambientTimer?.cancel();
    _burstTimer?.cancel();
  }

  void _scheduleAmbient(ChatGroup g) {
    _ambientTimer?.cancel();
    final gap = g.minGapSec + _random.nextInt(g.maxGapSec - g.minGapSec + 1);
    _ambientTimer = Timer(Duration(seconds: gap), () {
      if (_activeRoom != g.id) return;
      final room = _rooms[g.id]!;
      final m = _speaker(g);
      final line = _ambientLine(g, room.isEmpty ? null : room.last);
      room.add(GroupMessage(
        senderName: m.name,
        senderSeed: m.avatarSeed,
        isoCode: m.isoCode,
        text: _voice(m, line),
      ));
      notifyListeners();
      // 20% chance another member quick-chains a reaction (burst).
      if (_random.nextDouble() < 0.2) {
        _burstTimer = Timer(
          Duration(milliseconds: 1200 + _random.nextInt(2200)),
          () {
            if (_activeRoom != g.id) return;
            final r = _speaker(g, m);
            room.add(GroupMessage(
              senderName: r.name,
              senderSeed: r.avatarSeed,
              isoCode: r.isoCode,
              text: _voice(r, _pick('reactions')),
            ));
            notifyListeners();
          },
        );
      }
      _scheduleAmbient(g);
    });
  }

  /// Thread-aware ambient line: answers questions, asks some, riffs on the
  /// group's dominant topic, sprinkles off-topic life chatter.
  String _ambientLine(ChatGroup g, GroupMessage? last) {
    if (last != null && _lastWasQuestion) {
      _lastWasQuestion = false;
      return _pick(g.topic, answer: true);
    }
    final roll = _random.nextDouble();
    if (roll < 0.15) {
      _lastWasQuestion = true;
      return _pick(g.topic, question: true);
    }
    if (roll < 0.30) return _pick('reactions');
    if (roll < 0.42) return _pick(_offTopic(g));
    _lastWasQuestion = false;
    return _pick(g.topic);
  }

  String _offTopic(ChatGroup g) {
    const options = [
      'lifeTalk',
      'foodTalk',
      'weatherTalk',
      'sportTalk',
      'musicMovies',
      'techTalk',
      'studyWork',
      // Urdu-flavoured life chatter (the 20k expansion pools).
      'romanUrdu',
      'festivals',
      'familyLife',
      'moviesMusicUrdu',
      'cricketUrdu',
      'foodUrdu',
    ];
    return options[_random.nextInt(options.length)];
  }

  // ── User posting ─────────────────────────────────────────────────────

  void send(String groupId, String text) {
    final g = GroupCatalog.byId(groupId);
    final room = _rooms.putIfAbsent(groupId, () => <GroupMessage>[]);
    room.add(GroupMessage(senderName: 'You', text: text, isUser: true));
    notifyListeners();

    // 1–2 members react after a human typing delay.
    final responders = 1 + (_random.nextDouble() < 0.4 ? 1 : 0);
    GroupMember? last;
    for (var i = 0; i < responders; i++) {
      final m = _speaker(g, last);
      last = m;
      final delay = Duration(milliseconds: 1800 + i * 2500 + _random.nextInt(2500));
      Timer(delay, () {
        if (_activeRoom != g.id) {
          // Room closed: still keep the reply in history for next open.
          _rooms[groupId]!.add(GroupMessage(
            senderName: m.name,
            senderSeed: m.avatarSeed,
            isoCode: m.isoCode,
            text: _voice(m, _reactToUser(m, text)),
          ));
          return;
        }
        _rooms[groupId]!.add(GroupMessage(
          senderName: m.name,
          senderSeed: m.avatarSeed,
          isoCode: m.isoCode,
          text: _voice(m, _reactToUser(m, text)),
        ));
        notifyListeners();
      });
    }
  }

  /// Lightweight intent router for user posts.
  String _reactToUser(GroupMember m, String text) {
    final t = text.toLowerCase();
    // Abuse → this member scolds instead of chatting on.
    if (AbuseGuard.containsAbuse(text)) {
      return AbuseGuard.reprimand(m.style, _random);
    }
    // Roman Urdu / Hindi in → Roman Urdu out.
    if (RomanUrdu.detect(t)) {
      if (t.contains('?') ||
          RegExp(r'\b(kya|kahan|kaun|kab|kyun|kyu|kaisa|kaisi)\b').hasMatch(t)) {
        return _pick('urduAnswers');
      }
      return _random.nextDouble() < 0.65
          ? _pick('romanUrdu')
          : _pick('urduAnswers');
    }
    if (RegExp(r'\b(hi|hello|hey|salaam|assalam|yo)\b').hasMatch(t)) {
      return _pick('greetings');
    }
    if (RegExp(r'\b(bye|good ?night|gtg|gotta go)\b').hasMatch(t)) {
      return _pick('farewells');
    }
    if (RegExp(r'\b(thanks|thank you|thx)\b').hasMatch(t)) {
      return _pick('reactions');
    }
    if (t.contains('?')) {
      return _random.nextDouble() < 0.75
          ? _pick('answers', answer: true)
          : _pick('reactions');
    }
    if (RegExp(r'\b(win|won|lost|loss|losses|blunder|rating|elo)\b').hasMatch(t)) {
      return _random.nextDouble() < 0.5 ? _pick('hype') : _pick('reactions');
    }
    final roll = _random.nextDouble();
    if (roll < 0.4) return _pick('reactions');
    if (roll < 0.6) return _pick('chessTalk');
    if (roll < 0.8) {
      _lastWasQuestion = true;
      return _pick('questions', question: true);
    }
    return _pick('lifeTalk');
  }

  @override
  void dispose() {
    closeRoom();
    super.dispose();
  }
}
