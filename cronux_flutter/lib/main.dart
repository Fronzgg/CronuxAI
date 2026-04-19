import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'storage.dart';
import 'theme.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: CronuxTheme.bg,
  ));
  runApp(const CronuxApp());
}

class CronuxApp extends StatelessWidget {
  const CronuxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CronuxAI',
      debugShowCheckedModeBanner: false,
      theme: CronuxTheme.dark,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = Storage.getUser();
    // Автологин Fronz
    if (_user == null) {
      final users = Storage.getUsers();
      if (users.containsKey('fronz')) {
        _user = User.fromJson(Map<String, dynamic>.from(users['fronz']));
        Storage.saveUser(_user!);
      }
    }
  }

  void _onLogin(User user) => setState(() => _user = user);
  void _onLogout() { Storage.clearUser(); setState(() => _user = null); }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return AuthScreen(onLogin: _onLogin);
    return ChatScreen(user: _user!, onLogout: _onLogout);
  }
}
