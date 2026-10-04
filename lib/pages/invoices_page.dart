import 'package:flutter/material.dart';
import '../core/widgets.dart';
import '../core/models.dart';
import 'auth_page.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key, this.admin = false});
  final bool admin;
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  int _version = 0;
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير والمدفوعات'),
        actions: widget.admin
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'إصدار فاتورة',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateInvoicePage(),
                      ),
                    );
                    if (mounted) setState(() => _version++);
                  },
                ),
              ]
            : null,
      ),
      body: repo.userId == null
          ? Center(
              child: FilledButton(
                onPressed: () async {
                  await requireSignIn(context);
                  if (mounted) setState(() => _version++);
                },
                child: const Text('تسجيل الدخول لعرض الفواتير'),
              ),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'الدفع الإلكتروني غير مفعّل. تواصل مع البلدية لتسديد الفواتير. لا تُعتبر الفاتورة مدفوعة إلا بعد التحقق من الإيصال.',
                  ),
                ),
                Expanded(
                  child: PagedList(
                    key: ValueKey(_version),
                    load: (offset) =>
                        repo.invoices(admin: widget.admin, offset: offset),
                    empty: 'لا توجد فواتير مسجلة لحسابك.',
                    item: (row, refresh) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['title']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text('${row['amount']} ${row['currency']}'),
                            Text('المرجع: ${shortId(row['id'])}'),
                            Chip(
                              label: Text(
                                row['status'] == 'paid'
                                    ? 'مدفوعة ومتحقق منها'
                                    : 'غير مدفوعة',
                              ),
                            ),
                            if (row['paid_at'] != null)
                              Text(
                                'تاريخ التحقق: ${dateLabel(row['paid_at'])}',
                              ),
                            if (row['payment_reference'] != null)
                              SelectableText(
                                'الإيصال: ${row['payment_reference']}',
                              ),
                            if (widget.admin) ...[
                              SelectableText(
                                'حساب المقيم: ${row['resident_id']}',
                              ),
                              if (row['status'] == 'unpaid')
                                TextButton(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RecordPaymentPage(
                                          id: row['id'] as String,
                                        ),
                                      ),
                                    );
                                    refresh();
                                  },
                                  child: const Text('تسجيل إيصال متحقق منه'),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class CreateInvoicePage extends StatefulWidget {
  const CreateInvoicePage({super.key});
  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _form = GlobalKey<FormState>();
  final _owner = TextEditingController(),
      _title = TextEditingController(),
      _amount = TextEditingController();
  String _currency = 'USD';
  bool _busy = false;
  @override
  void dispose() {
    _owner.dispose();
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).repository.createInvoice({
        'resident_id': _owner.text.trim(),
        'title': _title.text.trim(),
        'amount': _amount.text.trim(),
        'currency': _currency,
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إصدار فاتورة')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _owner,
              enabled: !_busy,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم حساب المقيم UUID',
              ),
              validator: (v) => validUuid(v) ? null : 'أدخل رقم حساب صحيحاً.',
            ),
            TextFormField(
              controller: _title,
              enabled: !_busy,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'وصف الفاتورة'),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'أدخل الوصف.' : null,
            ),
            TextFormField(
              controller: _amount,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'المبلغ'),
              validator: (v) =>
                  RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(v?.trim() ?? '') &&
                      (num.tryParse(v!.trim()) ?? 0) > 0
                  ? null
                  : 'أدخل مبلغاً موجباً حتى منزلتين عشريتين.',
            ),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              items: [
                'USD',
                'LBP',
                'EUR',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: _busy ? null : (v) => setState(() => _currency = v!),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'جارٍ الحفظ…' : 'إصدار الفاتورة'),
            ),
          ],
        ),
      ),
    ),
  );
}

bool validUuid(String? value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value?.trim() ?? '');

class RecordPaymentPage extends StatefulWidget {
  const RecordPaymentPage({super.key, required this.id});
  final String id;
  @override
  State<RecordPaymentPage> createState() => _RecordPaymentPageState();
}

class _RecordPaymentPageState extends State<RecordPaymentPage> {
  final _receipt = TextEditingController();
  bool _verified = false, _busy = false;
  @override
  void dispose() {
    _receipt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تسجيل دفع متحقق منه')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _receipt,
          enabled: !_busy,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'مرجع الإيصال المعتمد'),
        ),
        CheckboxListTile(
          value: _verified,
          onChanged: _busy
              ? null
              : (v) => setState(() => _verified = v ?? false),
          title: const Text('تحققت من استلام المبلغ ومن صحة الإيصال.'),
        ),
        FilledButton(
          onPressed: _busy || !_verified
              ? null
              : () async {
                  if (_receipt.text.trim().length < 3) {
                    message(context, 'أدخل مرجع الإيصال.');
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    await AppScope.of(
                      context,
                    ).repository.recordPayment(widget.id, _receipt.text.trim());
                    if (context.mounted) Navigator.pop(context);
                  } catch (error) {
                    if (context.mounted) showError(context, error);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'جارٍ التسجيل…' : 'تأكيد تسجيل الدفع'),
        ),
      ],
    ),
  );
}
