import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/widgets.dart';
import '../core/models.dart';
import '../supabase_config.dart';
import '../staff_dashboard_page.dart';

Future<bool> requireSignIn(BuildContext context) async {
  if (AppScope.of(context).repository.userId != null) return true;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SignInPage()),
  );
  return context.mounted && AppScope.of(context).repository.userId != null;
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _contact = TextEditingController(), _code = TextEditingController();
  bool _phone = false, _sent = false, _busy = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _destination;
  @override
  void dispose() {
    _contact.dispose();
    _code.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _send({bool resend = false}) async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = AppScope.of(context).repository.client.auth;
      if (!_sent || resend) {
        final contact = _contact.text.trim();
        await auth.signInWithOtp(
          email: _phone ? null : contact,
          phone: _phone ? contact : null,
        );
        if (!mounted) return;
        setState(() {
          _sent = true;
          _destination = contact;
          _cooldown = 60;
          _code.clear();
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted || _cooldown <= 1) {
            timer.cancel();
            if (mounted) setState(() => _cooldown = 0);
          } else {
            setState(() => _cooldown--);
          }
        });
        message(context, 'تم إرسال رمز التحقق.');
      } else {
        final result = await auth.verifyOTP(
          email: _phone ? null : _destination,
          phone: _phone ? _destination : null,
          token: _code.text.trim(),
          type: _phone ? OtpType.sms : OtpType.email,
        );
        if (mounted && result.session != null) Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تسجيل الدخول')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'أهلاً بك في بلدية السويسة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'سجّل الدخول لتقديم الطلبات ومتابعتها.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (smsEnabled)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('البريد الإلكتروني'),
                      ),
                      ButtonSegment(value: true, label: Text('SMS')),
                    ],
                    selected: {_phone},
                    onSelectionChanged: _busy || _sent
                        ? null
                        : (v) => setState(() => _phone = v.first),
                  ),
                TextFormField(
                  controller: _contact,
                  enabled: !_busy && !_sent,
                  textDirection: TextDirection.ltr,
                  keyboardType: _phone
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: _phone
                        ? 'الهاتف مع رمز البلد'
                        : 'البريد الإلكتروني',
                    hintText: _phone ? '+961…' : 'name@example.com',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (_phone) {
                      return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(v)
                          ? null
                          : 'استخدم الصيغة الدولية دون مسافات.';
                    }
                    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
                        ? null
                        : 'أدخل بريداً إلكترونياً صحيحاً.';
                  },
                ),
                if (_sent) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _code,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 10,
                    decoration: const InputDecoration(labelText: 'رمز التحقق'),
                    validator: (v) =>
                        RegExp(r'^\d{6,10}$').hasMatch(v?.trim() ?? '')
                        ? null
                        : 'أدخل الرمز الموجود في الرسالة.',
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : () => _send(),
                  child: Text(
                    _busy
                        ? 'يرجى الانتظار…'
                        : _sent
                        ? 'تأكيد الرمز'
                        : 'إرسال رمز التحقق',
                  ),
                ),
                if (_sent)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _sent = false;
                                  _code.clear();
                                }),
                          child: const Text('تغيير بيانات الدخول'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _busy || _cooldown > 0
                              ? null
                              : () => _send(resend: true),
                          child: Text(
                            _cooldown > 0
                                ? 'إعادة الإرسال بعد $_cooldown ث'
                                : 'إعادة إرسال الرمز',
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPage()),
                  ),
                  child: const Text('الخصوصية واستخدام البيانات'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    if (repo.userId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyState('سجّل الدخول لمتابعة طلباتك وخدماتك.'),
            FilledButton(
              onPressed: () async {
                await requireSignIn(context);
                if (mounted) setState(() {});
              },
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );
    }
    return DataView<Membership>(
      key: ValueKey(repo.userId),
      load: repo.membership,
      builder: (context, member, reload) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(member.label, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          SelectableText(
            repo.client.auth.currentUser?.email ??
                repo.client.auth.currentUser?.phone ??
                '',
          ),
          const SizedBox(height: 12),
          const Text(
            'رقم الحساب — شاركه مع الإدارة عند الحاجة لإسناد دور أو فاتورة:',
          ),
          SelectableText(repo.userId!, textDirection: TextDirection.ltr),
          if (member.isStaff)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('لوحة فريق البلدية'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('الخصوصية واستخدام البيانات'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('تحديث صلاحيات الحساب'),
            onTap: reload,
          ),
          OutlinedButton(
            onPressed: () async {
              try {
                await repo.client.auth.signOut();
                if (mounted) setState(() {});
              } catch (error) {
                if (context.mounted) showError(context, error);
              }
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الخصوصية واستخدام البيانات')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        Text(
          'بيانات طلباتك',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Text(
          'نستخدم بيانات الدخول ونص الطلب ووسيلة التواصل والصورة والموقع الذي تختاره لمعالجة الطلبات. الموقع اختياري ولا يجري تتبعه في الخلفية. يمكن لفريق القسم المعني وإدارة البلدية الاطلاع على الطلب وصورته.',
        ),
        SizedBox(height: 20),
        Text(
          'المسودات على جهازك',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Text(
          'يمكن حفظ مسودة الطلب والصورة محلياً في التطبيق أو المتصفح. تبقى المسودة بعد تسجيل الخروج ولا تُرسل إلى البلدية تلقائياً. احذفها من نموذج الطلب إذا كنت تستخدم جهازاً مشتركاً.',
        ),
        SizedBox(height: 20),
        Text(
          'الخرائط والاستطلاعات',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Text(
          'تُحمّل الخرائط من مزوّد خارجي قد يتلقى عنوان اتصالك ومنطقة الخريطة. لا تُعرض بلاغات السكان للعامة. الاستطلاعات تسمح بصوت واحد لكل حساب وتعرض نتائج مجمّعة؛ لا تتحقق تلقائياً من الإقامة الفعلية.',
        ),
        SizedBox(height: 20),
        Text(
          'الاحتفاظ والحذف',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Text(
          'لطلب تصحيح بياناتك أو حذفها، تواصل مع البلدية من صفحة التواصل واذكر رقم حسابك. يجب أن تنشر البلدية بيانات التواصل المعتمدة ومدة الاحتفاظ بالبيانات قبل الإطلاق العام.',
        ),
      ],
    ),
  );
}
