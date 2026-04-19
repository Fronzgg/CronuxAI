import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';

class SidebarWidget extends StatelessWidget {
  final List<Chat> chats;
  final String? activeId;
  final User user;
  final VoidCallback onNewChat, onAccount, onClose;
  final void Function(String) onSwitchChat, onDeleteChat;

  const SidebarWidget({super.key, required this.chats, required this.activeId, required this.user,
    required this.onNewChat, required this.onSwitchChat, required this.onDeleteChat,
    required this.onAccount, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final today = chats.where((c) => now - int.parse(c.id.replaceAll('-','').substring(0,13).padRight(13,'0')) < 86400000).toList();
    final week  = chats.where((c) { final age = now - int.parse(c.id.replaceAll('-','').substring(0,13).padRight(13,'0')); return age >= 86400000 && age < 604800000; }).toList();
    final older = chats.where((c) => now - int.parse(c.id.replaceAll('-','').substring(0,13).padRight(13,'0')) >= 604800000).toList();

    return Container(
      decoration: BoxDecoration(
        color: CronuxTheme.bgSide,
        border: Border(right: BorderSide(color: CronuxTheme.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Image.asset('assets/logo.png', width: 26, height: 26),
                  const SizedBox(width: 8),
                  const Text('CronuxAI', style: TextStyle(color: CronuxTheme.t1, fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(onTap: onClose, child: const Icon(Icons.close_rounded, color: CronuxTheme.t2, size: 20)),
                ],
              ),
            ),
            // New chat
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: onNewChat,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: CronuxTheme.gradPurple,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: CronuxTheme.a1.withOpacity(.3), blurRadius: 10)],
                  ),
                  child: const Row(
                    children: [Icon(Icons.add_rounded, color: Colors.white, size: 18), SizedBox(width: 8),
                      Text('Новый чат', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: CronuxTheme.border, height: 1),
            // Chat list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                children: [
                  if (today.isNotEmpty) ...[_groupLabel('Сегодня'), ...today.map(_chatRow)],
                  if (week.isNotEmpty)  ...[_groupLabel('7 дней'),  ...week.map(_chatRow)],
                  if (older.isNotEmpty) ...[_groupLabel('Ранее'),    ...older.map(_chatRow)],
                  if (chats.isEmpty) Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Нет чатов', style: TextStyle(color: CronuxTheme.t3, fontSize: 12), textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
            Divider(color: CronuxTheme.border, height: 1),
            // User row
            GestureDetector(
              onTap: onAccount,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: CronuxTheme.gradPurple),
                      alignment: Alignment.center,
                      child: Text(user.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.username, style: const TextStyle(color: CronuxTheme.t1, fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(user.isPro ? 'Pro' : 'Free', style: TextStyle(color: user.isPro ? CronuxTheme.a3 : CronuxTheme.t3, fontSize: 11)),
                      ],
                    )),
                    const Icon(Icons.more_horiz_rounded, color: CronuxTheme.t3, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 3),
    child: Text(label, style: const TextStyle(color: CronuxTheme.t3, fontSize: 11)),
  );

  Widget _chatRow(Chat c) => Builder(builder: (context) => Dismissible(
    key: Key(c.id),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(color: const Color(0xFFf87171).withOpacity(.15), borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFf87171), size: 18),
    ),
    onDismissed: (_) => onDeleteChat(c.id),
    child: GestureDetector(
      onTap: () => onSwitchChat(c.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: c.id == activeId ? CronuxTheme.bgHov : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.id == activeId ? CronuxTheme.t1 : CronuxTheme.t2, fontSize: 13)),
      ),
    ),
  ));
}
