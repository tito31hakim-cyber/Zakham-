import 'package:flutter/material.dart';

import '../services/admin_api.dart';
import '../services/advisor_chat_api.dart';
import '../theme/app_theme.dart';
import '../utils/chat_text_sanitize.dart';

/// صفحة محادثة المستشار — حوار حر عن العطور والتركيبات والميكسات
/// وأسماء العطور، داخل مركز الذكاء.
///
/// الوسيط على الخادم فقط؛ بلا مفتاح إطلاقاً — تعمل فوراً. الردود
/// مسودات للمراجعة فقط: لا اعتماد تركيبات ولا تغيير أسعار ولا أي
/// إجراء من المحادثة.

class AdvisorChatPage extends StatefulWidget {
  const AdvisorChatPage({super.key, required this.api});

  final AdminApi api;

  @override
  State<AdvisorChatPage> createState() => _AdvisorChatPageState();
}

class _AdvisorChatPageState extends State<AdvisorChatPage> {
  final _messages = <AdvisorChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;

  static const _suggestions = <String>[
    'اقترح اسماً لعطر شتوي فاخر',
    'ما الفرق بين رويال وإعصار؟',
    'ما ميكسات الدار الحالية؟',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? text]) async {
    final question = (text ?? _input.text).trim();
    if (question.isEmpty || _sending) return;
    final history = <AdvisorChatMessage>[
      ..._messages,
      AdvisorChatMessage(role: 'user', content: question),
    ];
    setState(() {
      _messages.add(AdvisorChatMessage(role: 'user', content: question));
      _input.clear();
      _sending = true;
      _error = null;
    });
    _scrollToBottom();
    try {
      final reply = await widget.api.advisorChatApi.send(history);
      if (!mounted) return;
      setState(() {
        _messages
            .add(AdvisorChatMessage(role: 'assistant', content: reply));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _cleanError(Object e) {
    final text = e.toString();
    for (final prefix in ['Exception: ', 'FormatException: ']) {
      if (text.startsWith(prefix)) return text.substring(prefix.length);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('ناقش المستشار'),
          ),
          body: Column(
            children: [
              _disclaimer(context),
              Expanded(
                child: _messages.isEmpty
                    ? _emptyState(context)
                    : _messageList(context),
              ),
              if (_error != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              _composer(context),
            ],
          ),
        ),
      );

  Widget _disclaimer(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'الردود مسودات للمراجعة فقط — لا اعتماد تركيبات ولا تغيير في المتجر ولا أسعار من المحادثة.',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: context.ink, fontSize: 12, height: 1.6),
              ),
            ),
          ],
        ),
      );

  Widget _emptyState(BuildContext context) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 50),
          Icon(Icons.forum_outlined, color: context.goldText, size: 56),
          const SizedBox(height: 18),
          Text(
            'اسأل المستشار',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: context.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'حوار حر عن العطور والتركيبات والميكسات وأسماء العطور — من بيانات دار زخم فقط.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.subdued, height: 1.6),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _suggestions
                .map((s) => ActionChip(
                      label: Text(s),
                      onPressed: _sending ? null : () => _send(s),
                    ))
                .toList(),
          ),
        ],
      );

  Widget _messageList(BuildContext context) => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: _messages.length + (_sending ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _messages.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final message = _messages[index];
          final isUser = message.role == 'user';
          return Align(
            alignment:
                isUser ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .82,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? context.goldText.withOpacity(.16)
                    : context.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUser
                      ? context.goldText.withOpacity(.4)
                      : context.hairline,
                ),
              ),
              child: Text(
                // ردود المستشار تمر بدالة التنظيف قبل عرضها، فلا تصل
                // رموز Markdown الخام إلى المستخدم أبداً حتى لو ورد
                // نص خام من أي مصدر؛ رسائل المستخدم تُعرض كما كتبها.
                isUser ? message.content : sanitizeChatText(message.content),
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: context.ink, fontSize: 14, height: 1.6),
              ),
            ),
          );
        },
      );

  Widget _composer(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          border: Border(top: BorderSide(color: context.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                textAlign: TextAlign.right,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'اكتب سؤالك للمستشار…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _sending ? null : () => _send(),
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(13),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      );
}
