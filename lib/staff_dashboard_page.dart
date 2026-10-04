import 'package:flutter/material.dart';
import 'core/models.dart';
import 'core/widgets.dart';
import 'pages/content_page.dart';
import 'pages/requests_page.dart';
import 'pages/polls_page.dart';
import 'pages/invoices_page.dart';

class StaffDashboardPage extends StatelessWidget {
  const StaffDashboardPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('لوحة فريق البلدية')),
    body: DataView<Membership>(
      load: AppScope.of(context).repository.membership,
      builder: (context, member, reload) {
        if (!member.isStaff) {
          return const EmptyState(
            'هذا الحساب لا يملك صلاحية دخول فريق البلدية.',
            icon: Icons.lock_outline,
          );
        }
        return DefaultTabController(
          length: member.isAdmin ? 3 : 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  const Tab(text: 'الطلبات'),
                  const Tab(text: 'الإحصاءات'),
                  if (member.isAdmin) const Tab(text: 'الإدارة'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    const RequestsPage(staff: true),
                    const StaffAnalyticsPage(),
                    if (member.isAdmin)
                      ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          for (final kind in contentLabels.keys)
                            Card(
                              child: ListTile(
                                title: Text(contentLabels[kind]!),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ContentPage(kind: kind, admin: true),
                                  ),
                                ),
                              ),
                            ),
                          Card(
                            child: ListTile(
                              title: const Text('إدارة الاستطلاعات'),
                              leading: const Icon(Icons.how_to_vote_outlined),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PollsPage(admin: true),
                                ),
                              ),
                            ),
                          ),
                          Card(
                            child: ListTile(
                              title: const Text('إدارة الفواتير'),
                              leading: const Icon(Icons.receipt_long_outlined),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const InvoicesPage(admin: true),
                                ),
                              ),
                            ),
                          ),
                          Card(
                            child: ListTile(
                              title: const Text('إدارة الفريق والصلاحيات'),
                              leading: const Icon(
                                Icons.manage_accounts_outlined,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MembersPage(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'تُظهر الطلبات البيانات التي يسمح حسابك بالوصول إليها. تحديث الحالة يسجل اسم حساب الموظف ووقت التغيير في قاعدة البيانات.',
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class StaffAnalyticsPage extends StatelessWidget {
  const StaffAnalyticsPage({super.key});
  @override
  Widget build(BuildContext context) => DataView<Map<String, dynamic>>(
    load: AppScope.of(context).repository.metrics,
    builder: (context, metrics, reload) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'إحصاءات الطلبات ضمن صلاحيات حسابك',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('إجمالي الطلبات'),
            trailing: Text('${metrics['total']}'),
          ),
        ),
        for (final status in statusLabels.entries)
          Card(
            child: ListTile(
              title: Text(status.value),
              trailing: Text('${metrics[status.key]}'),
            ),
          ),
        TextButton.icon(
          onPressed: reload,
          icon: const Icon(Icons.refresh),
          label: const Text('تحديث الإحصاءات'),
        ),
      ],
    ),
  );
}

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});
  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  int _version = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('الفريق والصلاحيات'),
      actions: [
        IconButton(
          tooltip: 'إضافة أو تعديل عضو',
          icon: const Icon(Icons.person_add_outlined),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MemberEditorPage()),
            );
            if (mounted) setState(() => _version++);
          },
        ),
      ],
    ),
    body: DataView<List<Map<String, dynamic>>>(
      key: ValueKey(_version),
      load: AppScope.of(context).repository.members,
      builder: (context, members, reload) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'يجب أن يسجّل الشخص الدخول أولاً، ثم يشارك رقم حسابه من صفحة حسابي. منح صلاحية الإدارة يسمح بالوصول إلى جميع طلبات السكان.',
          ),
          ...members.map(
            (m) => Card(
              child: ListTile(
                title: SelectableText('${m['user_id']}'),
                subtitle: Text(
                  m['role'] == 'admin' ? 'مدير البلدية' : 'موظف قسم',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemberEditorPage(member: m),
                    ),
                  );
                  reload();
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class MemberEditorPage extends StatefulWidget {
  const MemberEditorPage({super.key, this.member});
  final Map<String, dynamic>? member;
  @override
  State<MemberEditorPage> createState() => _MemberEditorPageState();
}

class _MemberEditorPageState extends State<MemberEditorPage> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _id;
  String _role = 'staff';
  String? _department;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _id = TextEditingController(text: widget.member?['user_id'] as String?);
    _role = widget.member?['role'] as String? ?? 'staff';
    _department = widget.member?['department_id'] as String?;
  }

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_role == 'staff' && _department == null) {
      message(context, 'اختر القسم المسؤول.');
      return;
    }
    if (!await confirm(
          context,
          'تعيين هذا الحساب ${_role == 'admin'
              ? 'مديراً يصل إلى جميع الطلبات'
              : _role == 'staff'
              ? 'موظفاً في القسم المحدد'
              : 'مقيماً دون صلاحيات موظف'}؟',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).repository.manageMember(
        _id.text.trim(),
        _role,
        _role == 'staff' ? _department : null,
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
    appBar: AppBar(title: const Text('تعيين الصلاحيات')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _id,
              enabled: !_busy && widget.member == null,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'رقم الحساب UUID'),
              validator: (v) => validUuid(v) ? null : 'أدخل رقم حساب صحيحاً.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _role,
              items: const [
                DropdownMenuItem(value: 'resident', child: Text('مقيم')),
                DropdownMenuItem(value: 'staff', child: Text('موظف قسم')),
                DropdownMenuItem(value: 'admin', child: Text('مدير البلدية')),
              ],
              onChanged: _busy ? null : (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 16),
            if (_role == 'staff')
              DataView<List<Map<String, dynamic>>>(
                load: AppScope.of(context).repository.departments,
                builder: (context, departments, reload) =>
                    DropdownButtonFormField<String>(
                      initialValue: _department,
                      decoration: const InputDecoration(labelText: 'القسم'),
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'جارٍ الحفظ…' : 'حفظ الصلاحيات'),
            ),
          ],
        ),
      ),
    ),
  );
}
