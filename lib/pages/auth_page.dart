import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/customer_provider.dart';
import '../theme/app_theme.dart';

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

String _normalizeDigits(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final output = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    final arabicIndex = arabic.indexOf(character);
    final persianIndex = persian.indexOf(character);
    if (arabicIndex >= 0) {
      output.write(arabicIndex);
    } else if (persianIndex >= 0) {
      output.write(persianIndex);
    } else if (RegExp(r'[0-9+]').hasMatch(character)) {
      output.write(character);
    }
  }
  return output.toString();
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
  );
}

InputDecoration _fieldDecoration(String label, String hint, IconData icon) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
    );

/// Customer sign-in. Returns true (popped) when the customer ends up
/// signed in — either directly, or after the OTP page that follows when
/// the server asks for phone verification.
class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});
  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final provider = context.read<CustomerProvider>();
      final outcome = await provider.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      if (provider.verificationPending) {
        final verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const OtpVerifyPage()),
        );
        if (!mounted) return;
        if (verified == true) Navigator.pop(context, true);
        return;
      }
      if (outcome.message.isNotEmpty) _showMessage(context, outcome.message);
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(context, _cleanError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('تسجيل الدخول')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
              children: [
                const Text(
                  'أهلاً بعودتك إلى زخم',
                  style: TextStyle(
                    color: cream,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'سجّل الدخول بحسابك لإتمام الطلب ومتابعة طلباتك.',
                  style: TextStyle(color: muted, height: 1.6),
                ),
                const SizedBox(height: 26),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    'البريد الإلكتروني',
                    'example@mail.com',
                    Icons.email_outlined,
                  ),
                  validator: (value) => (value ?? '').contains('@')
                      ? null
                      : 'أدخل بريداً إلكترونياً صحيحاً',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _fieldDecoration(
                    'كلمة المرور',
                    'كلمة مرور حسابك',
                    Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) => (value ?? '').length < 6
                      ? 'كلمة المرور 6 أحرف على الأقل'
                      : null,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(
                      _submitting ? 'جارٍ تسجيل الدخول...' : 'تسجيل الدخول',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          final created = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomerRegisterPage(),
                            ),
                          );
                          if (!mounted) return;
                          if (created == true) Navigator.pop(context, true);
                        },
                  child: const Text('ليس لديك حساب؟ أنشئ حساباً جديداً'),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Customer sign-up: name, email, phone and password — the same fields
/// the web storefront asks for. Egyptian numbers get an SMS code; the
/// server may also accept international numbers directly.
class CustomerRegisterPage extends StatefulWidget {
  const CustomerRegisterPage({super.key});
  @override
  State<CustomerRegisterPage> createState() => _CustomerRegisterPageState();
}

class _CustomerRegisterPageState extends State<CustomerRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final provider = context.read<CustomerProvider>();
      final outcome = await provider.register(
        displayName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: _normalizeDigits(_phone.text),
      );
      if (!mounted) return;
      if (provider.verificationPending) {
        final verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const OtpVerifyPage()),
        );
        if (!mounted) return;
        if (verified == true) Navigator.pop(context, true);
        return;
      }
      if (outcome.message.isNotEmpty) _showMessage(context, outcome.message);
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showMessage(context, _cleanError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('إنشاء حساب')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
              children: [
                const Text(
                  'انضم إلى دار زخم',
                  style: TextStyle(
                    color: cream,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'حساب واحد لطلباتك كلها — والأرقام المصرية تُوثَّق برمز SMS، والأرقام الدولية تُسجَّل مباشرة.',
                  style: TextStyle(color: muted, height: 1.6),
                ),
                const SizedBox(height: 26),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration(
                    'الاسم الكامل',
                    'كما تحب أن نناديك',
                    Icons.person_outline,
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'اكتب الاسم الكامل'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    'البريد الإلكتروني',
                    'example@mail.com',
                    Icons.email_outlined,
                  ),
                  validator: (value) => (value ?? '').contains('@')
                      ? null
                      : 'أدخل بريداً إلكترونياً صحيحاً',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    'رقم الهاتف',
                    'مثال: 01xxxxxxxxx',
                    Icons.phone_outlined,
                  ),
                  validator: (value) {
                    final digits = _normalizeDigits(value ?? '');
                    if (digits.length < 10 || digits.length > 14) {
                      return 'أدخل رقم هاتف صحيحاً مع رمز الدولة عند الحاجة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _fieldDecoration(
                    'كلمة المرور',
                    '6 أحرف على الأقل',
                    Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) => (value ?? '').length < 6
                      ? 'كلمة المرور 6 أحرف على الأقل'
                      : null,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(
                      _submitting ? 'جارٍ إنشاء الحساب...' : 'إنشاء الحساب',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// 6-digit SMS code confirmation. The server resolves the account from
/// the pending session cookie issued by register/login, so this page
/// only needs the code itself.
class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({super.key});
  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  final _code = TextEditingController();
  bool _submitting = false;
  bool _resending = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (_submitting || code.length != 6) {
      if (code.length != 6) {
        _showMessage(context, 'أدخل الرمز المكوّن من 6 أرقام.');
      }
      return;
    }
    setState(() => _submitting = true);
    try {
      final verified =
          await context.read<CustomerProvider>().verifyPhone(code);
      if (!mounted) return;
      if (verified) {
        _showMessage(context, 'تم تأكيد رقم هاتفك بنجاح.');
        Navigator.pop(context, true);
      } else {
        _showMessage(context, 'تعذّر تأكيد الرمز. تحقق منه وحاول مجدداً.');
      }
    } catch (error) {
      if (mounted) _showMessage(context, _cleanError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      final result = await context.read<CustomerProvider>().resendPhone();
      if (!mounted) return;
      _showMessage(
        context,
        '${result['message'] ?? 'أُرسل رمز جديد إلى هاتفك.'}',
      );
    } catch (error) {
      if (mounted) _showMessage(context, _cleanError(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final mask = provider.pendingPhoneMask;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تأكيد رقم الهاتف')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
          children: [
            const Icon(Icons.sms_outlined, color: gold, size: 46),
            const SizedBox(height: 18),
            const Text(
              'أدخل رمز التأكيد',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cream,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mask.isNotEmpty
                  ? 'أرسلنا رمزاً من 6 أرقام إلى $mask.'
                  : 'أرسلنا رمزاً من 6 أرقام إلى هاتفك.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, height: 1.6),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 26,
                letterSpacing: 10,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: '••••••',
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'جارٍ التأكيد...' : 'تأكيد الرقم'),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _resending ? null : _resend,
              child: Text(
                _resending ? 'جارٍ إرسال رمز جديد...' : 'إعادة إرسال الرمز',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
