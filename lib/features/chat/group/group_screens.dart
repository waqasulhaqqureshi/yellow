import 'package:flutter/material.dart';

import '../../../core/widgets/flag_avatar.dart';
import 'group_chat_controller.dart';
import 'group_models.dart';

/// Entry point from the home pill: a bottom sheet with your joined rooms
/// plus Join / Create options (CoC-style group entry).
void showGroupSheet(BuildContext context) {
  final controller = GroupChatController.shared;
  controller.init();
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupSheet(controller: controller),
  );
}

class _GroupSheet extends StatelessWidget {
  final GroupChatController controller;

  const _GroupSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final joined = GroupCatalog.groups
        .where((g) => controller.joinedIds.contains(g.id))
        .toList();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBFDFF), Color(0xFFF2F7FF)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD0DDE8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.groups, color: Color(0xFF0B63CE), size: 22),
              SizedBox(width: 8),
              Text(
                'Group Chat',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (joined.isNotEmpty) ...[
            ...joined.map((g) => _joinedRow(context, g)),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupExploreScreen(controller: controller),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B63CE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Explore groups',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _createSoon(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0B63CE),
                side: const BorderSide(color: Color(0xFF0B63CE)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Create a group',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _joinedRow(BuildContext context, ChatGroup g) {
    final msgs = controller.messagesFor(g.id);
    final preview = msgs.isEmpty ? g.tagline : msgs.last.text;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0DDE8)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).pop();
            _openRoom(context, g);
          },
          child: Row(
            children: [
              _emblem(g),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF98A2B3), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _createSoon(BuildContext context) {
    Navigator.of(context).pop();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Create a group',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Group creation is coming soon. For now, explore the rooms already live!',
          style: TextStyle(color: Color(0xFF667085)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

void _openRoom(BuildContext context, ChatGroup g) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GroupRoomScreen(
        controller: GroupChatController.shared,
        group: g,
        userName: 'You',
      ),
    ),
  );
}

/// White/blue group emblem — shared by the sheet and the explore screen.
IconData _iconFor(String topic) => switch (topic) {
      'chessTalk' => Icons.bolt,
      'openingsTalk' => Icons.account_balance,
      'endgameTalk' => Icons.flag,
      'banter' => Icons.emoji_emotions_outlined,
      'questions' => Icons.school_outlined,
      'lifeTalk' => Icons.nightlight_outlined,
      'foodTalk' => Icons.restaurant,
      'sportTalk' => Icons.sports_cricket,
      'hype' => Icons.trending_up,
      _ => Icons.groups,
    };

Widget _emblem(ChatGroup g) {
  return Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: const Color(0xFFDCEBFF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF0B63CE), width: 1.5),
    ),
    child: Icon(_iconFor(g.topic), color: const Color(0xFF0B63CE), size: 24),
  );
}

/// CoC-style group browser (white/blue house style): search bar, emblem cards, member
/// counts, tags and a Join button per group.
class GroupExploreScreen extends StatefulWidget {
  final GroupChatController controller;

  const GroupExploreScreen({super.key, required this.controller});

  @override
  State<GroupExploreScreen> createState() => _GroupExploreScreenState();
}

class _GroupExploreScreenState extends State<GroupExploreScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final groups = GroupCatalog.groups
        .where((g) =>
            q.isEmpty ||
            g.name.toLowerCase().contains(q) ||
            g.tagline.toLowerCase().contains(q))
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Explore groups',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search groups',
                  hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF98A2B3), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                children: groups.map((g) => _groupCard(g)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(ChatGroup g) {
    final joined = widget.controller.joinedIds.contains(g.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0DDE8)),
      ),
      child: Row(
        children: [
          _emblem(g),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        g.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '#${g.id}',
                      style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  g.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.people, size: 13, color: Color(0xFF98A2B3)),
                    const SizedBox(width: 3),
                    Text(
                      '${g.members.length}/${g.memberCount}',
                      style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    Icon(_iconFor(g.topic), size: 13, color: const Color(0xFF98A2B3)),
                    const SizedBox(width: 3),
                    Text(
                      g.topic,
                      style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          joined
              ? IconButton(
                  onPressed: () => _openRoom(context, g),
                  icon: const Icon(Icons.chat_bubble, color: Color(0xFF0B63CE)),
                )
              : FilledButton(
                  onPressed: () => widget.controller.join(g.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B63CE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Join'),
                ),
        ],
      ),
    );
  }
}

/// Live room view.
class GroupRoomScreen extends StatefulWidget {
  final GroupChatController controller;
  final ChatGroup group;
  final String userName;

  const GroupRoomScreen({
    super.key,
    required this.controller,
    required this.group,
    required this.userName,
  });

  @override
  State<GroupRoomScreen> createState() => _GroupRoomScreenState();
}

class _GroupRoomScreenState extends State<GroupRoomScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.openRoom(widget.group.id);
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.controller.closeRoom();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.controller.messagesFor(widget.group.id);
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.name,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${widget.group.memberCount} members',
              style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              itemCount: msgs.length,
              itemBuilder: (context, i) => _bubble(msgs[i]),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Message ${widget.group.name}',
                        hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF2F6FC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _send(_input.text),
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF0B63CE)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _input.clear();
    widget.controller.send(widget.group.id, t);
  }

  Widget _bubble(GroupMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A9EE8), Color(0xFF0076DA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 32),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDE6F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.senderSeed != null) BotAvatar(seed: msg.senderSeed!, size: 30),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.senderName,
                        style: const TextStyle(
                          color: Color(0xFF0B63CE),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (msg.isoCode != null) ...[
                        const SizedBox(width: 5),
                        CountryFlag(isoCode: msg.isoCode!, width: 16, height: 11),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg.text,
                    style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
