import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/models.dart';
import '../core/widgets.dart';

class ContentPage extends StatelessWidget {
  const ContentPage({super.key, required this.kind, this.admin = false});
  final String kind;
  final bool admin;
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    return Scaffold(
      appBar: AppBar(
        title: Text(contentLabels[kind]!),
        actions: admin
            ? [
                IconButton(
                  tooltip: 'إضافة',
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContentEditorPage(kind: kind),
                      ),
                    );
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ContentPage(kind: kind, admin: true),
                        ),
                      );
                    }
                  },
                ),
              ]
            : null,
      ),
      body: PagedList(
        load: (offset) => repo.content(kind, admin: admin, offset: offset),
        empty: 'لم تنشر البلدية معلومات هنا بعد.',
        item: (row, refresh) => Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row['title']}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText('${row['body']}'),
                if (row['location_text'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('الموقع / المنطقة: ${row['location_text']}'),
                  ),
                if (row['starts_at'] != null)
                  Text('الموعد: ${dateLabel(row['starts_at'])}'),
                if (row['progress'] != null) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (row['progress'] as num) / 100,
                  ),
                  Text('التقدم: ${row['progress']}%'),
                ],
                if (row['budget'] != null)
                  Text('الميزانية: ${row['budget']} ${row['currency']}'),
                if (row['phone'] != null)
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        if (!await launchUrl(
                              Uri(scheme: 'tel', path: row['phone'] as String),
                            ) &&
                            context.mounted) {
                          message(
                            context,
                            'تعذر فتح الاتصال. الرقم: ${row['phone']}',
                          );
                        }
                      } catch (error) {
                        if (context.mounted) showError(context, error);
                      }
                    },
                    icon: const Icon(Icons.phone_outlined),
                    label: Text('${row['phone']}'),
                  ),
                const SizedBox(height: 8),
                Text(
                  'نُشر: ${dateLabel(row['created_at'])}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (admin) ...[
                  Chip(
                    label: Text(row['published'] == true ? 'منشور' : 'مسودة'),
                  ),
                  Wrap(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ContentEditorPage(kind: kind, row: row),
                            ),
                          );
                          refresh();
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('تعديل'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          if (!await confirm(context, 'حذف هذا المحتوى؟')) {
                            return;
                          }
                          try {
                            await repo.deleteContent(row['id'] as String);
                            refresh();
                          } catch (error) {
                            if (context.mounted) showError(context, error);
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('حذف'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContentEditorPage extends StatefulWidget {
  const ContentEditorPage({super.key, required this.kind, this.row});
  final String kind;
  final Map<String, dynamic>? row;
  @override
  State<ContentEditorPage> createState() => _ContentEditorPageState();
}

class _ContentEditorPageState extends State<ContentEditorPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title,
      _body,
      _location,
      _phone,
      _progress,
      _budget;
  DateTime? _date;
  bool _published = false, _busy = false;
  String _currency = 'USD';
  @override
  void initState() {
    super.initState();
    final r = widget.row ?? {};
    _title = TextEditingController(text: r['title'] as String?);
    _body = TextEditingController(text: r['body'] as String?);
    _location = TextEditingController(text: r['location_text'] as String?);
    _phone = TextEditingController(text: r['phone'] as String?);
    _progress = TextEditingController(text: r['progress']?.toString());
    _budget = TextEditingController(text: r['budget']?.toString());
    _date = DateTime.tryParse('${r['starts_at']}')?.toLocal();
    _published = r['published'] == true;
    _currency = r['currency'] as String? ?? 'USD';
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _location, _phone, _progress, _budget]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date ?? now),
    );
    if (time != null && mounted) {
      setState(
        () => _date = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (widget.kind == 'event' && _date == null) {
      message(context, 'اختر موعد الفعالية.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).repository.saveContent({
        if (widget.row != null) 'id': widget.row!['id'],
        'kind': widget.kind,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'location_text': _location.text.trim().isEmpty
            ? null
            : _location.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'starts_at': _date?.toUtc().toIso8601String(),
        'progress': int.tryParse(_progress.text),
        'budget': num.tryParse(_budget.text),
        'currency': _currency,
        'published': _published,
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
    appBar: AppBar(title: Text('إدارة ${contentLabels[widget.kind]}')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _title,
              enabled: !_busy,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'العنوان'),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'أدخل العنوان.' : null,
            ),
            TextFormField(
              controller: _body,
              enabled: !_busy,
              minLines: 4,
              maxLines: 10,
              maxLength: 10000,
              decoration: InputDecoration(
                labelText: widget.kind == 'waste_schedule'
                    ? 'الأيام والأوقات وتعليمات الجمع'
                    : 'التفاصيل',
              ),
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? 'أدخل التفاصيل المعتمدة.'
                  : null,
            ),
            TextFormField(
              controller: _location,
              enabled: !_busy,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'الموقع / المنطقة'),
            ),
            if (widget.kind == 'contact')
              TextFormField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                maxLength: 16,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتف معتمد (اختياري)',
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ||
                        RegExp(r'^\+?[0-9]{6,15}$').hasMatch(v!.trim())
                    ? null
                    : 'أدخل رقماً صحيحاً دون مسافات.',
              ),
            if (widget.kind == 'event')
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _date == null
                      ? 'اختيار الموعد'
                      : dateLabel(_date!.toIso8601String()),
                ),
              ),
            if (widget.kind == 'project') ...[
              TextFormField(
                controller: _progress,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'نسبة التقدم من 0 إلى 100',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n != null && n >= 0 && n <= 100
                      ? null
                      : 'أدخل نسبة صحيحة.';
                },
              ),
              TextFormField(
                controller: _budget,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'الميزانية (اختياري)',
                ),
                validator: (v) =>
                    v == null || v.isEmpty || ((num.tryParse(v) ?? -1) >= 0)
                    ? null
                    : 'أدخل مبلغاً صحيحاً.',
              ),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                items: ['USD', 'LBP', 'EUR']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _currency = v!),
              ),
            ],
            SwitchListTile(
              value: _published,
              onChanged: _busy ? null : (v) => setState(() => _published = v),
              title: const Text('نشر للجميع'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ'),
            ),
          ],
        ),
      ),
    ),
  );
}
