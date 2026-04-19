import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Storage {
  static late SharedPreferences _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  // Session
  static User? getUser() {
    final s = _p.getString('cx_session');
    if (s == null) return null;
    try { return User.fromJson(jsonDecode(s)); } catch (_) { return null; }
  }
  static Future<void> saveUser(User u) => _p.setString('cx_session', jsonEncode(u.toJson()));
  static Future<void> clearUser() => _p.remove('cx_session');

  // Users DB
  static Map<String, dynamic> getUsers() {
    final s = _p.getString('cx_users') ?? '{}';
    final m = Map<String, dynamic>.from(jsonDecode(s));
    if (!m.containsKey('fronz')) {
      m['fronz'] = {'username':'Fronz','password':'fronz123','unlimited':true,'plan':'pro'};
      _p.setString('cx_users', jsonEncode(m));
    }
    return m;
  }
  static Future<void> saveUsers(Map<String, dynamic> u) => _p.setString('cx_users', jsonEncode(u));

  // Chats
  static List<Chat> getChats(String username) {
    final s = _p.getString('cx_chats_${username.toLowerCase()}') ?? '[]';
    try { return (jsonDecode(s) as List).map((c) => Chat.fromJson(c)).toList(); }
    catch (_) { return []; }
  }
  static Future<void> saveChats(String username, List<Chat> chats) =>
    _p.setString('cx_chats_${username.toLowerCase()}', jsonEncode(chats.map((c) => c.toJson()).toList()));

  // Credits / msgs today
  static String _today() => DateTime.now().toIso8601String().substring(0, 10);
  static int getMsgsToday(String username) {
    final k = 'cx_msgs_${username.toLowerCase()}_${_today()}';
    return _p.getInt(k) ?? 0;
  }
  static Future<void> incMsgsToday(String username) {
    final k = 'cx_msgs_${username.toLowerCase()}_${_today()}';
    return _p.setInt(k, getMsgsToday(username) + 1);
  }

  // Memory
  static List<String> getMemory(String username) {
    final s = _p.getString('cx_mem_${username.toLowerCase()}') ?? '[]';
    return List<String>.from(jsonDecode(s));
  }
  static Future<void> saveMemory(String username, List<String> mem) =>
    _p.setString('cx_mem_${username.toLowerCase()}', jsonEncode(mem));
}
