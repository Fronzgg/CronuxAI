import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../storage.dart';

class AuthScreen extends StatefulWidget {
  final void Function(User) onLogin;
  const AuthScreen({super.key, required this.onLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _error = '';

  void _login() {
    final name = _userCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text;
    final users = Storage.getUsers();
    final u = users[name];
    if (u == null || u['password'] != pass) {
      setState(() => _error = 'Неверные данные'); return;
    }
    final user = User.fromJson(Map<String, dynamic>.from(u));
    Storage.saveUser(user);
    widget.onLogin(user);
  }

  void _register() {
    final name = _userCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text;
    if (name.isEmpty || pass.isEmpty) { setState(() => _error = 'Заполните поля'); return; }
    final users = Storage.getUsers();
    if (users.containsKey(name)) { setState(() => _error = 'Пользователь существует'); return; }
    users[name] = {'username': name[0].toUpperCase() + name.substring(1), 'password': pass, 'unlimited': false, 'plan': 'free'};
    Storage.saveUsers(users);
    final user = User.fromJson(Map<String, dynamic>.from(users[name]));
    Storage.saveUser(user);
    widget.onLogin(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CronuxTheme.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, 1.2), radius: 1.2,
            colors: [Color(0x22A855F7), CronuxTheme.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: CronuxTheme.gradPurple,
                      boxShadow: [BoxShadow(color: CronuxTheme.a1.withOpacity(.4), blurRadius: 24, spreadRadius: 2)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShaderMask(
                    shaderCallback: (b) => CronuxTheme.gradPurple.createShader(b),
                    child: const Text('CronuxAI', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(height: 32),

                  // Tabs
                  Container(
                    decoration: BoxDecoration(color: CronuxTheme.bgHov, borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(4),
                    child: Row(children: [
                      _tab('Войти', _isLogin, () => setState(() { _isLogin = true; _error = ''; })),
                      _tab('Регистрация', !_isLogin, () => setState(() { _isLogin = false; _error = ''; })),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  _input(_userCtrl, 'Имя пользователя', false),
                  if (!_isLogin) ...[const SizedBox(height: 10), _input(_emailCtrl, 'Email', false)],
                  const SizedBox(height: 10),
                  _input(_passCtrl, 'Пароль', true),
                  const SizedBox(height: 16),

                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error, style: const TextStyle(color: Color(0xFFf87171), fontSize: 13)),
                    ),

                  // Button
                  GestureDetector(
                    onTap: _isLogin ? _login : _register,
                    child: Container(
                      width: double.infinity, height: 50,
                      decoration: BoxDecoration(
                        gradient: CronuxTheme.gradPurple,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: CronuxTheme.a1.withOpacity(.35), blurRadius: 16)],
                      ),
                      alignment: Alignment.center,
                      child: Text(_isLogin ? 'Войти' : 'Создать аккаунт',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Тест: Fronz / fronz123', style: TextStyle(color: CronuxTheme.t3, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? CronuxTheme.a1 : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: active ? Colors.white : CronuxTheme.t2, fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    ),
  );

  Widget _input(TextEditingController ctrl, String hint, bool obscure) => TextField(
    controller: ctrl, obscureText: obscure,
    style: const TextStyle(color: CronuxTheme.t1, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: CronuxTheme.t3),
      filled: true, fillColor: CronuxTheme.bgHov,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CronuxTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CronuxTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CronuxTheme.a2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
