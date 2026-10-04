import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/models.dart';
import '../core/widgets.dart';
import 'auth_page.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key, this.staff = false});
  final bool staff;
  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    if (repo.userId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyState('سجّل الدخول لعرض طلباتك.'),
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
    return PagedList(
      key: ValueKey('${repo.userId}/${widget.staff}'),
      load: (offset) => repo.requests(staff: widget.staff, offset: offset),
      empty: 'لا توجد طلبات بعد.',
      item: (row, refresh) => Card(
        child: ListTile(
          leading: Icon(
            row['request_type'] == 'service_request'
                ? Icons.description_outlined
                : Icons.report_outlined,
          ),
          title: Text('${row['category']} • ${shortId(row['id'])}'),
          subtitle: Text(
            '${statusLabels[row['status']] ?? row['status']}\n${dateLabel(row['created_at'])}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_left),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RequestDetailsPage(id: row['id'] as String),
              ),
            );
            refresh();
          },
        ),
      ),
    );
  }
}

class RequestDetailsPage extends StatelessWidget {
  const RequestDetailsPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    return Scaffold(
      appBar: AppBar(title: Text('الطلب ${shortId(id)}')),
      body: DataView<Map<String, dynamic>>(
        load: () => repo.request(id),
        builder: (context, row, reload) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${row['category']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                Chip(
                  label: Text(
                    statusLabels[row['status']] ?? '${row['status']}',
                  ),
                ),
                TextButton.icon(
                  onPressed: reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث الحالة'),
                ),
              ],
            ),
            SelectableText('${row['description']}'),
            const SizedBox(height: 16),
            if (row['location_text'] != null)
              Text('الموقع: ${row['location_text']}'),
            if (row['contact_phone'] != null)
              SelectableText('التواصل: ${row['contact_phone']}'),
            if (row['latitude'] != null && row['longitude'] != null)
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.https('www.openstreetmap.org', '/', {
                    'mlat': '${row['latitude']}',
                    'mlon': '${row['longitude']}',
                  });
                  try {
                    if (!await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        ) &&
                        context.mounted) {
                      message(context, 'تعذر فتح الخريطة.');
                    }
                  } catch (error) {
                    if (context.mounted) showError(context, error);
                  }
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('فتح الموقع على الخريطة'),
              ),
            if (row['photo_path'] != null)
              DataView<String>(
                key: ValueKey(row['photo_path']),
                load: () => repo.photoUrl(row['photo_path'] as String),
                builder: (context, url, refresh) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Image.network(
                    url,
                    height: 280,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) =>
                        ErrorState(error: error, retry: refresh),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'سجل المتابعة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            DataView<List<Map<String, dynamic>>>(
              key: ValueKey(row['updated_at']),
              load: () => repo.history(id),
              builder: (context, history, refresh) => Column(
                children: [
                  if (history.isEmpty)
                    const EmptyState(
                      'لا يوجد سجل متابعة لهذا الطلب القديم بعد.',
                    ),
                  ...history.map(
                    (entry) => ListTile(
                      leading: const Icon(Icons.timeline),
                      title: Text(
                        statusLabels[entry['status']] ?? '${entry['status']}',
                      ),
                      subtitle: Text(
                        '${dateLabel(entry['created_at'])}${entry['note'] == null ? '' : '\n${entry['note']}'}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DataView<Membership>(
              load: repo.membership,
              builder: (context, member, refresh) => member.isStaff
                  ? FilledButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UpdateRequestPage(row: row, member: member),
                          ),
                        );
                        reload();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تحديث الطلب'),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class UpdateRequestPage extends StatefulWidget {
  const UpdateRequestPage({super.key, required this.row, required this.member});
  final Map<String, dynamic> row;
  final Membership member;
  @override
  State<UpdateRequestPage> createState() => _UpdateRequestPageState();
}

class _UpdateRequestPageState extends State<UpdateRequestPage> {
  late String _status;
  String? _department;
  late TextEditingController _note;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _status = widget.row['status'] as String;
    _department = widget.row['department_id'] as String?;
    _note = TextEditingController(text: widget.row['staff_note'] as String?);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).repository.updateRequest(
        widget.row['id'] as String,
        _status,
        _note.text,
        widget.member.isAdmin ? _department : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تحديث الطلب')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'الحالة'),
          items: statusLabels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: _busy ? null : (v) => setState(() => _status = v!),
        ),
        const SizedBox(height: 16),
        if (widget.member.isAdmin)
          DataView<List<Map<String, dynamic>>>(
            load: AppScope.of(context).repository.departments,
            builder: (context, departments, refresh) =>
                DropdownButtonFormField<String>(
                  initialValue: _department,
                  decoration: const InputDecoration(labelText: 'القسم المسؤول'),
                  items: departments
                      .map(
                        (d) => DropdownMenuItem(
                          value: d['id'] as String,
                          child: Text('${d['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _department = v),
                ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          enabled: !_busy,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(labelText: 'ملاحظة تظهر للمقيم'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ التحديث'),
        ),
      ],
    ),
  );
}
