import 'package:flutter/material.dart';
import '../core/widgets.dart';
import '../core/models.dart';
import 'auth_page.dart';

class PollsPage extends StatelessWidget {
  const PollsPage({super.key, this.admin = false});
  final bool admin;
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    return Scaffold(
      appBar: AppBar(
        title: const Text('استطلاع السكان'),
        actions: admin
            ? [
                IconButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreatePollPage()),
                    );
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PollsPage(admin: true),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  tooltip: 'إضافة استطلاع',
                ),
              ]
            : null,
      ),
      body: DataView<List<Map<String, dynamic>>>(
        load: () => repo.polls(admin: admin),
        builder: (context, polls, reload) => RefreshIndicator(
          onRefresh: () async {
            reload();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'صوت واحد لكل حساب. هذه استطلاعات رأي وليست تصويتاً رسمياً يتحقق من الإقامة.',
                ),
              ),
              if (polls.isEmpty)
                const EmptyState('لا توجد استطلاعات منشورة بعد.'),
              ...polls.map(
                (poll) => PollCard(
                  key: ValueKey(poll['id']),
                  poll: poll,
                  admin: admin,
                  onDeleted: reload,
                ),
              ),
              if (polls.length == 100) const Text('تُعرض أحدث 100 استطلاع.'),
            ],
          ),
        ),
      ),
    );
  }
}

class PollCard extends StatefulWidget {
  const PollCard({
    super.key,
    required this.poll,
    this.admin = false,
    required this.onDeleted,
  });
  final Map<String, dynamic> poll;
  final bool admin;
  final VoidCallback onDeleted;
  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  bool _busy = false;
  int _version = 0;
  Future<Map<String, dynamic>> _load() async {
    final repo = AppScope.of(context).repository;
    final results = await repo.pollResults(widget.poll['id'] as String);
    final vote = await repo.myVote(widget.poll['id'] as String);
    return {'results': results, 'vote': vote};
  }

  Future<void> _vote(int index) async {
    if (_busy || !await requireSignIn(context) || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(
        context,
      ).repository.vote(widget.poll['id'] as String, index);
      if (mounted) setState(() => _version++);
    } catch (error) {
      if (mounted) {
        showError(context, error);
        setState(() => _version++);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.poll;
    final options = List<String>.from(p['options'] as List);
    final open =
        DateTime.parse(p['closes_at'] as String).isAfter(DateTime.now()) &&
        p['published'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${p['question']}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            Text('ينتهي: ${dateLabel(p['closes_at'])}'),
            if (p['published'] != true) const Text('مسودة غير منشورة'),
            DataView<Map<String, dynamic>>(
              key: ValueKey(_version),
              load: _load,
              builder: (context, data, reload) {
                final counts = {
                  for (final r in data['results'] as List<Map<String, dynamic>>)
                    r['option_index'] as int: (r['votes'] as num).toInt(),
                };
                final total = counts.values.fold<int>(0, (a, b) => a + b);
                final voted = data['vote'] as int?;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < options.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(options[i]),
                        subtitle: Text(
                          '${counts[i] ?? 0} أصوات${voted == i ? ' • اختيارك' : ''}',
                        ),
                        trailing: open && voted == null
                            ? OutlinedButton(
                                onPressed: _busy ? null : () => _vote(i),
                                child: const Text('تصويت'),
                              )
                            : null,
                      ),
                    Text('المجموع: $total'),
                    TextButton(
                      onPressed: reload,
                      child: const Text('تحديث النتائج'),
                    ),
                  ],
                );
              },
            ),
            if (widget.admin)
              TextButton.icon(
                onPressed: () async {
                  if (!await confirm(context, 'حذف الاستطلاع وكل أصواته؟')) {
                    return;
                  }
                  if (!context.mounted) return;
                  try {
                    await AppScope.of(
                      context,
                    ).repository.deletePoll(p['id'] as String);
                    widget.onDeleted();
                  } catch (error) {
                    if (context.mounted) showError(context, error);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('حذف الاستطلاع'),
              ),
          ],
        ),
      ),
    );
  }
}

class CreatePollPage extends StatefulWidget {
  const CreatePollPage({super.key});
  @override
  State<CreatePollPage> createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<CreatePollPage> {
  final _form = GlobalKey<FormState>(),
      _question = TextEditingController(),
      _options = TextEditingController();
  DateTime? _close;
  bool _busy = false, _published = true;
  @override
  void dispose() {
    _question.dispose();
    _options.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_close == null || !_close!.isAfter(DateTime.now())) {
      message(context, 'اختر موعد انتهاء مستقبلياً.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).repository.createPoll({
        'question': _question.text.trim(),
        'options': _options.text
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'closes_at': _close!.toUtc().toIso8601String(),
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
    appBar: AppBar(title: const Text('استطلاع جديد')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _question,
              enabled: !_busy,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'السؤال'),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'أدخل السؤال.' : null,
            ),
            TextFormField(
              controller: _options,
              enabled: !_busy,
              minLines: 3,
              maxLines: 8,
              maxLength: 1600,
              decoration: const InputDecoration(
                labelText: 'خيار في كل سطر (2 إلى 8 خيارات)',
              ),
              validator: (v) {
                final a = (v ?? '')
                    .split('\n')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                return a.length >= 2 &&
                        a.length <= 8 &&
                        a.toSet().length == a.length
                    ? null
                    : 'أدخل 2 إلى 8 خيارات مختلفة.';
              },
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: now.add(const Duration(days: 7)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 730)),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 18, minute: 0),
                      );
                      if (time != null && mounted) {
                        setState(
                          () => _close = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      }
                    },
              child: Text(
                _close == null
                    ? 'موعد الانتهاء'
                    : dateLabel(_close!.toIso8601String()),
              ),
            ),
            SwitchListTile(
              value: _published,
              onChanged: _busy ? null : (v) => setState(() => _published = v),
              title: const Text('نشر الاستطلاع'),
            ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'جارٍ الحفظ…' : 'إنشاء الاستطلاع'),
            ),
          ],
        ),
      ),
    ),
  );
}
