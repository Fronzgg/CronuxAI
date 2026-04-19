import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../storage.dart';

class AccountSheet extends StatefulWidget {
  final User user;
  final List<Chat> chats;
  final VoidCallback onLogout;
  const AccountSheet({super.key, required this.user, required this.chats, required this.onLogout});

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  late List<String> _memory;

  @override
  void initState() { super.initState(); _memory = Storage.getMemory(widget.user.username); }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final msgsToday = Storage.getMsgsToday(widget.user.username);
    final limit = widget.user.dailyLimit;
    final isPro = widget.user.isPro;

    return DraggableScrollableSheet(
      initialChildSize: .85, maxChildSize: .95, minChildSize: .5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: CronuxTheme.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            // Handle
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: CronuxTheme.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // User header
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: CronuxTheme.gradPurple),
                  alignment: Alignment.center,
                  child: Text(widget.user.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.user.username, style: const TextStyle(color: CronuxTheme.t1, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(isPro ? (widget.user.unlimited ? 'Pro · Безлимит ∞' : 'Pro · 100/день') : 'Free · 3/день',
                    style: TextStyle(color: isPro ? CronuxTheme.a3 : CronuxTheme.t3, fontSize: 12)),
                ]),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Content Usage'),
            const SizedBox(height: 10),
            // Usage grid
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
              children: [
                _usageCard('Сообщений сегодня', widget.user.unlimited ? '$msgsToday' : '$msgsToday/$limit',
                  widget.user.unlimited ? msgsToday / 100 : msgsToday / limit, CronuxTheme.a2),
                _usageCard('Кредиты', widget.user.unlimited ? '∞' : '${limit - msgsToday}',
                  widget.user.unlimited ? 1.0 : (limit - msgsToday) / limit, const Color(0xFF34d399)),
                _usageCard('Чатов всего', '${widget.chats.length}',
                  (widget.chats.length / 20).clamp(0, 1), CronuxTheme.a3),
                _usageCard('Память', '${_memory.length} заметок',
                  (_memory.length / 10).clamp(0, 1), const Color(0xFF60a5fa)),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Память'),
            const SizedBox(height: 8),
            ..._memory.asMap().entries.map((e) => _memItem(e.key, e.value)),
            if (_memory.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Память пуста', style: TextStyle(color: CronuxTheme.t3, fontSize: 13), textAlign: TextAlign.center)),
            const SizedBox(height: 8),
            _outlineBtn('+ Добавить заметку', _addMemory),
            if (!isPro) ...[
              const SizedBox(height: 16),
              _gradBtn('✦ Получить Pro — 300 ₽/мес', const LinearGradient(colors: [Color(0xFFf59e0b), Color(0xFFf97316)]), _activatePro),
            ],
            const SizedBox(height: 16),
            Divider(color: CronuxTheme.border),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () { Navigator.pop(context); widget.onLogout(); },
              child: Row(children: [
                const Icon(Icons.logout_rounded, color: Color(0xFFf87171), size: 18),
                const SizedBox(width: 8),
                const Text('Выйти из аккаунта', style: TextStyle(color: Color(0xFFf87171), fontSize: 14)),
              ]),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(color: CronuxTheme.t3, fontSize: 11, letterSpacing: .08, fontWeight: FontWeight.w500));

  Widget _usageCard(String label, String value, double progress, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: CronuxTheme.bgHov, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: CronuxTheme.t2, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: CronuxTheme.t1, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0), minHeight: 3,
        backgroundColor: CronuxTheme.border, valueColor: AlwaysStoppedAnimation(color),
      )),
    ]),
  );

  Widget _memItem(int i, String text) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: CronuxTheme.bgHov, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Expanded(child: Text(text, style: const TextStyle(color: CronuxTheme.t2, fontSize: 13))),
      GestureDetector(
        onTap: () { setState(() { _memory.removeAt(i); Storage.saveMemory(widget.user.username, _memory); }); },
        child: const Icon(Icons.close_rounded, color: CronuxTheme.t3, size: 16),
      ),
    ]),
  );

  void _addMemory() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: CronuxTheme.bgCard,
      title: const Text('Добавить в память', style: TextStyle(color: CronuxTheme.t1, fontSize: 16)),
      content: TextField(controller: ctrl, maxLines: 3,
        style: const TextStyle(color: CronuxTheme.t1),
        decoration: InputDecoration(hintText: 'Например: Я разработчик...', hintStyle: TextStyle(color: CronuxTheme.t3),
          filled: true, fillColor: CronuxTheme.bgHov,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CronuxTheme.border)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Отмена', style: TextStyle(color: CronuxTheme.t2))),
        TextButton(onPressed: () {
          if (ctrl.text.trim().isNotEmpty) {
            setState(() { _memory.add(ctrl.text.trim()); Storage.saveMemory(widget.user.username, _memory); });
          }
          Navigator.pop(context);
        }, child: const Text('Сохранить', style: TextStyle(color: CronuxTheme.a3))),
      ],
    ));
  }

  void _activatePro() {
    final users = Storage.getUsers();
    final key = widget.user.username.toLowerCase();
    if (users.containsKey(key)) { users[key]['plan'] = 'pro'; Storage.saveUsers(users); }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✦ Pro активирован!'), backgroundColor: CronuxTheme.a1));
  }

  Widget _outlineBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: Border.all(color: CronuxTheme.border, style: BorderStyle.solid), borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: CronuxTheme.t2, fontSize: 13)),
    ),
  );

  Widget _gradBtn(String label, LinearGradient grad, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 48,
      decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFFf59e0b).withOpacity(.3), blurRadius: 14)]),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
    ),
  );
}
