import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme.dart';
import '../models.dart';

const _labels = {'cronux': 'CronuxAI', 'cronux-coder': 'CronuxCoder', 'cronux-pro': 'CronuxPro'};

class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final String username;
  const MessageBubble({super.key, required this.msg, required this.username});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          if (!isUser) ...[
            ClipOval(child: Image.asset('assets/logo.png', width: 28, height: 28)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Name
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    isUser ? username : (_labels[msg.model] ?? 'CronuxAI'),
                    style: const TextStyle(color: CronuxTheme.t2, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                // Search badge
                if (msg.searchUsed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: CronuxTheme.a1.withOpacity(.1),
                      border: Border.all(color: CronuxTheme.a2.withOpacity(.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('🔍 Web search', style: TextStyle(color: CronuxTheme.a3, fontSize: 11)),
                  ),
                // Bubble
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                  padding: isUser ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10) : EdgeInsets.zero,
                  decoration: isUser ? BoxDecoration(
                    color: CronuxTheme.bgCard,
                    border: Border.all(color: CronuxTheme.border),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14), topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14),
                    ),
                  ) : null,
                  child: isUser
                    ? Text(msg.content, style: const TextStyle(color: CronuxTheme.t1, fontSize: 14, height: 1.6))
                    : MarkdownBody(
                        data: msg.content,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(color: CronuxTheme.t1, fontSize: 14, height: 1.7),
                          code: const TextStyle(color: CronuxTheme.a3, fontFamily: 'monospace', fontSize: 13),
                          codeblockDecoration: BoxDecoration(
                            color: const Color(0xFF09090D),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: CronuxTheme.border),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(left: BorderSide(color: CronuxTheme.a2, width: 3)),
                          ),
                          strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          em: const TextStyle(color: CronuxTheme.a4, fontStyle: FontStyle.italic),
                          h1: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          h2: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                          h3: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                ),
                // Actions (AI only)
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        _actBtn(Icons.copy_rounded, () {
                          Clipboard.setData(ClipboardData(text: msg.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 1), backgroundColor: CronuxTheme.bgCard),
                          );
                        }),
                        _actBtn(Icons.thumb_up_outlined, () {}),
                        _actBtn(Icons.thumb_down_outlined, () {}),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: CronuxTheme.gradPurple),
              alignment: Alignment.center,
              child: Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(5),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, size: 15, color: CronuxTheme.t3),
    ),
  );
}
