import 'package:flutter/material.dart';

import '../services/customer_chat_api.dart';
import '../theme/app_theme.dart';
import '../utils/chat_text_sanitize.dart';

/// محادثة العملاء المصغرة — «مساعد دار زخم» للعملاء والزوار فقط.
///
/// تُفتح من زر المساعد الذكي العائم في شاشات المتجر. نطاقها البحث عن
/// العطور من كتالوج المتجر فقط: ترشيح عطر، وإعطاء النوتات، واكتشاف
/// العطور الموجودة — ولا شيء آخر؛ لا ميكسات ولا مواد ولا تركيبات
/// ولا أي بيانات داخلية. الوسيط على الخادم فقط (نقطة عامة بلا
/// مصادقة)، وبلا أي بيانات عملاء في السياق.

class CustomerChatPage extends StatefulWidget {
  const CustomerChatPage({super.key, this.api});

  /// عميل المحادثة — يُمرَّر في الاختبارات فقط؛ في الإنتاج يُبنى
  /// عميل افتراضي على النقطة العامة.
  final CustomerChatApi? api;

  @override
  State<CustomerChatPage> createState() => _CustomerChatPageState();
}

class _CustomerChatPageState extends State<CustomerChatPage> {
  late final CustomerChatApi _api = widget.api ?? CustomerChatApi();
  final _messages = <CustomerChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;
  bool _limitReached = false;

  static const _suggestions = <String>[
    'رشّح لي عطراً للسهرة',
    'أي عطر فيه ورد وعنبر؟',
    'ما العطور المتوفرة حالياً؟',
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
    if (question.isEmpty || _sending || _limitReached) return;
    if (_api.sessionLimitReached) {
      setState(() => _limitReached = true);
      return;
    }
    final history = <CustomerChatMessage>[
      ..._messages,
      CustomerChatMessage(role: 'user', content: question),
    ];
    setState(() {
      _messages.add(CustomerChatMessage(role: 'user', content: question));
      _input.clear();
      _sending = true;
      _error = null;
    });
    _scrollToBottom();
    try {
      final reply = await _api.send(history);
      if (!mounted) return;
      setState(() {
        _messages.add(
          CustomerChatMessage(role: 'assistant', content: reply),
        );
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _restartChat() {
    _api.resetSession();
    setState(() {
      _messages.clear();
      _error = null;
      _limitReached = false;
    });
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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مساعد دار زخم'),
                Text(
                  'مساعد ذكي',
                  style: TextStyle(
                    color: context.goldText,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              _scopeNote(context),
              Expanded(
                child: _messages.isEmpty
                    ? _emptyState(context)
                    : _messageList(context),
              ),
              if (_limitReached)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    children: [
                      Text(
                        'وصلت لحد رسائل هذه الجلسة — ابدأ محادثة جديدة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: context.subdued, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _restartChat,
                        child: const Text('ابدأ محادثة جديدة'),
                      ),
                    ],
                  ),
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

  Widget _scopeNote(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.goldText.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.goldText.withOpacity(.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, color: context.goldText, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'أساعدك في اختيار عطر من تشكيلة دار زخم فقط — الترشيحات والنوتات من الكتالوج المعروض في المتجر.',
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
          Icon(Icons.auto_awesome, color: context.goldText, size: 56),
          const SizedBox(height: 18),
          Text(
            'أي عطر يشبهك؟',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: context.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'اسألني عن عطر لمناسبة أو نوتة تحبها، وسأرشّح لك من عطور دار زخم الموجودة في المتجر.',
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
                      onPressed: _sending || _limitReached
                          ? null
                          : () => _send(s),
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
                maxLength: CustomerChatApi.maxMessageChars,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'اسأل عن عطر…',
                  counterText: '',
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
              onPressed:
                  (_sending || _limitReached) ? null : () => _send(),
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
