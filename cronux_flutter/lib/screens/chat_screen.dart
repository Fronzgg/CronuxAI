import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../models.dart';
import '../storage.dart';
import '../api_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/sidebar.dart';
import 'account_sheet.dart';

const _uuid = Uuid();
const _modelLabels = {'cronux': 'CronuxAI', 'cronux-coder': 'CronuxCoder', 'cronux-pro': 'CronuxPro'};

class ChatScreen extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;
  const ChatScreen({super.key, required this.user, required this.onLogout});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late List<Chat> _chats;
  String? _activeId;
  String _model = 'cronux';
  bool _search = false;
  bool _loading = false;
  bool _drawerOpen = false;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late AnimationController _sendAnim;

  Chat? get _active => _chats.firstWhere((c) => c.id == _activeId, orElse: () => _chats.isEmpty ? Chat(id:'', title:'', messages:[], model:'cronux') : _chats.first);

  @override
  void initState() {
    super.initState();
    _chats = Storage.getChats(widget.user.username);
    if (_chats.isNotEmpty) { _activeId = _chats.first.id; _model = _chats.first.model; }
    _sendAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
  }

  @override
  void dispose() { _inputCtrl.dispose(); _scrollCtrl.dispose(); _sendAnim.dispose(); super.dispose(); }

  void _newChat() {
    final chat = Chat(id: _uuid.v4(), title: 'Новый чат', messages: [], model: _model);
    setState(() { _chats.insert(0, chat); _activeId = chat.id; _drawerOpen = false; });
    Storage.saveChats(widget.user.username, _chats);
  }

  void _switchChat(String id) {
    final c = _chats.firstWhere((c) => c.id == id);
    setState(() { _activeId = id; _model = c.model; _drawerOpen = false; });
  }

  void _deleteChat(String id) {
    setState(() {
      _chats.removeWhere((c) => c.id == id);
      if (_activeId == id) _activeId = _chats.isNotEmpty ? _chats.first.id : null;
    });
    Storage.saveChats(widget.user.username, _chats);
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    // Проверка лимита
    final msgsToday = Storage.getMsgsToday(widget.user.username);
    if (!widget.user.unlimited && msgsToday >= widget.user.dailyLimit) {
      _showLimitDialog(); return;
    }

    if (_activeId == null) _newChat();
    final chat = _active!;
    if (chat.messages.isEmpty) { chat.title = text.length > 40 ? text.substring(0, 40) : text; }

    final userMsg = ChatMessage(role: 'user', content: text, model: _model);
    setState(() { chat.messages.add(userMsg); _loading = true; });
    _inputCtrl.clear();
    Storage.incMsgsToday(widget.user.username);
    Storage.saveChats(widget.user.username, _chats);
    _scrollToBottom();

    try {
      String message = text;
      // Добавить память
      final mem = Storage.getMemory(widget.user.username);
      if (mem.isNotEmpty) message += '\n\n[Память]:\n${mem.map((m) => '- $m').join('\n')}';
      // Поиск
      if (_search) {
        final results = await ApiService.search(text);
        if (results.isNotEmpty) message = 'Вопрос: $text\n\nРезультаты поиска:\n$results\n\nОтветь на основе этих данных.';
      }

      final history = chat.messages.where((m) => m != userMsg)
        .map((m) => {'role': m.role, 'content': m.content}).toList();
      final response = await ApiService.chat(message: message, model: _model, history: history);

      final aiMsg = ChatMessage(role: 'assistant', content: response, model: _model, searchUsed: _search);
      setState(() { chat.messages.add(aiMsg); });
      Storage.saveChats(widget.user.username, _chats);
      _scrollToBottom();
    } catch (e) {
      final errMsg = ChatMessage(role: 'assistant', content: 'Ошибка: $e', model: _model);
      setState(() { chat.messages.add(errMsg); });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showLimitDialog() {
    showModalBottomSheet(context: context, backgroundColor: CronuxTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✦ Лимит исчерпан', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CronuxTheme.t1)),
          const SizedBox(height: 8),
          Text('Бесплатно: 3 запроса в день\nPro: 100 запросов в день', textAlign: TextAlign.center, style: TextStyle(color: CronuxTheme.t2, fontSize: 14)),
          const SizedBox(height: 24),
          _gradBtn('Получить Pro — 300 ₽/мес', () { Navigator.pop(context); _openAccount(); }),
          const SizedBox(height: 12),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Позже', style: TextStyle(color: CronuxTheme.t2))),
        ]),
      ),
    );
  }

  void _openAccount() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AccountSheet(user: widget.user, chats: _chats, onLogout: widget.onLogout),
    );
  }

  Widget _gradBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFf59e0b), Color(0xFFf97316)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFFf59e0b).withOpacity(.3), blurRadius: 16)],
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final chat = _activeId != null ? _active : null;
    final hasMessages = chat != null && chat.messages.isNotEmpty;

    return Scaffold(
      backgroundColor: CronuxTheme.bg,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(bottom: 0, left: 0, right: 0, height: 300,
            child: Container(decoration: const BoxDecoration(
              gradient: RadialGradient(center: Alignment(0, 1.5), radius: 1,
                colors: [Color(0x15A855F7), Colors.transparent]),
            )),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Topbar
                _buildTopbar(hasMessages),
                // Messages
                Expanded(child: hasMessages ? _buildMessages(chat!) : _buildWelcome()),
                // Input
                _buildInput(),
              ],
            ),
          ),

          // Drawer overlay
          if (_drawerOpen) ...[
            GestureDetector(
              onTap: () => setState(() => _drawerOpen = false),
              child: Container(color: Colors.black54),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: 0, top: 0, bottom: 0,
              width: 280,
              child: SidebarWidget(
                chats: _chats, activeId: _activeId, user: widget.user,
                onNewChat: _newChat, onSwitchChat: _switchChat, onDeleteChat: _deleteChat,
                onAccount: _openAccount, onClose: () => setState(() => _drawerOpen = false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopbar(bool hasMessages) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: CronuxTheme.bgSide.withOpacity(.9),
      border: Border(bottom: BorderSide(color: CronuxTheme.border)),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _drawerOpen = true),
          child: const Icon(Icons.menu_rounded, color: CronuxTheme.t2, size: 22),
        ),
        const SizedBox(width: 12),
        Image.asset('assets/logo.png', width: 24, height: 24),
        const SizedBox(width: 8),
        Text(hasMessages ? _modelLabels[_model]! : 'CronuxAI',
          style: const TextStyle(color: CronuxTheme.t1, fontSize: 15, fontWeight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: _openAccount,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: CronuxTheme.gradPurple,
            ),
            alignment: Alignment.center,
            child: Text(widget.user.username[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ),
  );

  Widget _buildWelcome() => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: CronuxTheme.a1.withOpacity(.4), blurRadius: 24)],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/logo.png')),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (b) => CronuxTheme.gradPurple.createShader(b),
            child: const Text('CronuxAI', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          Text('Быстрые ответы, память и поиск', style: TextStyle(color: CronuxTheme.t2, fontSize: 14)),
          const SizedBox(height: 28),
          // Model tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _modelTab('cronux', '✦ Instant'),
              const SizedBox(width: 8),
              _modelTab('cronux-coder', '⚙ Coder'),
              const SizedBox(width: 8),
              _modelTab('cronux-pro', '◈ Pro'),
            ],
          ),
          const SizedBox(height: 32),
          // Quick chips
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
            children: ['Напиши код на Python', 'Объясни квантовую физику', 'Реши интеграл', 'Что нового в AI?']
              .map((s) => GestureDetector(
                onTap: () { _inputCtrl.text = s; _send(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: CronuxTheme.bgCard, border: Border.all(color: CronuxTheme.border),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s, style: const TextStyle(color: CronuxTheme.t2, fontSize: 13)),
                ),
              )).toList(),
          ),
        ],
      ),
    ),
  );

  Widget _modelTab(String model, String label) {
    final active = _model == model;
    return GestureDetector(
      onTap: () { setState(() => _model = model); final c = _active; if (c != null && c.id.isNotEmpty) { c.model = model; Storage.saveChats(widget.user.username, _chats); } },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? CronuxTheme.gradPurple : null,
          color: active ? null : CronuxTheme.bgCard,
          border: Border.all(color: active ? Colors.transparent : CronuxTheme.border),
          borderRadius: BorderRadius.circular(20),
          boxShadow: active ? [BoxShadow(color: CronuxTheme.a1.withOpacity(.35), blurRadius: 12)] : null,
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : CronuxTheme.t2, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildMessages(Chat chat) => ListView.builder(
    controller: _scrollCtrl,
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: chat.messages.length + (_loading ? 1 : 0),
    itemBuilder: (_, i) {
      if (i == chat.messages.length) return const _TypingIndicator();
      return MessageBubble(msg: chat.messages[i], username: widget.user.username);
    },
  );

  Widget _buildInput() => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    decoration: BoxDecoration(
      color: CronuxTheme.bgSide.withOpacity(.95),
      border: Border(top: BorderSide(color: CronuxTheme.border)),
    ),
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: CronuxTheme.bgInput,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CronuxTheme.border),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded, color: CronuxTheme.t2, size: 20),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      maxLines: 5, minLines: 1,
                      style: const TextStyle(color: CronuxTheme.t1, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Спросите CronuxAI...',
                        hintStyle: TextStyle(color: CronuxTheme.t3),
                        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: GestureDetector(
                      onTap: _loading ? null : _send,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _loading ? null : CronuxTheme.gradPurple,
                          color: _loading ? CronuxTheme.bgHov : null,
                          boxShadow: _loading ? null : [BoxShadow(color: CronuxTheme.a1.withOpacity(.45), blurRadius: 14)],
                        ),
                        child: ClipOval(
                          child: _loading
                            ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: CronuxTheme.a2)))
                            : Image.asset('assets/logo.png', fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Pills
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    _pill('🔍 Поиск', _search, () => setState(() => _search = !_search)),
                    const SizedBox(width: 8),
                    _pill('◈ DeepThink', false, () {}),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _pill(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active ? CronuxTheme.a1.withOpacity(.15) : Colors.transparent,
        border: Border.all(color: active ? CronuxTheme.a2 : CronuxTheme.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: active ? CronuxTheme.a3 : CronuxTheme.t2, fontSize: 12.5)),
    ),
  );

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    if (_inputCtrl.text.isEmpty) _inputCtrl.text = 'Распознай текст на изображении';
    _send();
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        ClipOval(child: Image.asset('assets/logo.png', width: 28, height: 28)),
        const SizedBox(width: 10),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Row(
            children: List.generate(3, (i) {
              final t = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
              final y = -6.0 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: CronuxTheme.a2),
                ),
              );
            }),
          ),
        ),
      ],
    ),
  );
}
