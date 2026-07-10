import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'staff_dashboard_page.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const SweissaApp());
}

class SweissaApp extends StatelessWidget {
  const SweissaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0A6257);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'بلدية السويسة',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: const Color(0xFFD9A441),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      ),
      home: const MunicipalityHomePage(),
    );
  }
}

class MunicipalityHomePage extends StatefulWidget {
  const MunicipalityHomePage({super.key});

  @override
  State<MunicipalityHomePage> createState() => _MunicipalityHomePageState();
}

class _MunicipalityHomePageState extends State<MunicipalityHomePage> {
  int _selectedTab = 0;
  final List<IssueReport> _reports = [];

  Future<void> _saveReport(IssueReport report) async {
    setState(() => _reports.insert(0, report));

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('requests').insert({
        'resident_id': user.id,
        'request_type': report.isServiceRequest ? 'service_request' : 'issue_report',
        'category': report.category,
        'description': report.description,
        'location_text': report.location,
        'has_photo': report.hasPhoto,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الطلب في قاعدة بيانات البلدية.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الطلب على الجهاز فقط. تحقق من الاتصال وحسابك.')));
      }
    }
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title — قريباً')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(child: _emergencyAlert()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(child: _sectionTitle('خدمات سريعة')),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 170,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  delegate: SliverChildListDelegate([
                    _serviceCard(
                      Icons.add_location_alt_outlined,
                      'بلّغ عن مشكلة',
                      'طرق، إنارة، نفايات',
                      const Color(0xFFDDEFEA),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReportIssuePage(
                            onSubmitted: (report) {
                              _saveReport(report);
                            },
                          ),
                        ),
                      ),
                    ),
                    _serviceCard(
                      Icons.description_outlined,
                      'طلب خدمة',
                      'معاملات البلدية',
                      const Color(0xFFE8EEF9),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ServiceRequestPage(
                            onSubmitted: (request) {
                              _saveReport(request);
                            },
                          ),
                        ),
                      ),
                    ),
                    _serviceCard(
                      Icons.calendar_month_outlined,
                      'مواعيد النفايات',
                      'اعرف يوم الجمع',
                      const Color(0xFFFFF0D7),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WasteSchedulePage()),
                      ),
                    ),
                    _serviceCard(
                      Icons.campaign_outlined,
                      'الإعلانات',
                      'أخبار البلدية',
                      const Color(0xFFF5E6F6),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
                      ),
                    ),
                    _serviceCard(
                      Icons.how_to_vote_outlined,
                      'استطلاع السكان',
                      'شارك في القرار',
                      const Color(0xFFE8EEF9),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CommunityPollPage()),
                      ),
                    ),
                    _serviceCard(
                      Icons.event_outlined,
                      'فعاليات محلية',
                      'اجتماعات ومبادرات',
                      const Color(0xFFF5E6F6),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EventsPage()),
                      ),
                    ),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
                sliver: SliverToBoxAdapter(child: _sectionTitle('آخر الأخبار')),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(children: [
                    _newsCard(),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MunicipalProjectsPage()),
                      ),
                      icon: const Icon(Icons.account_tree_outlined),
                      label: const Text('المشاريع البلدية والشفافية'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0A6257),
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedTab,
          onDestinationSelected: (index) {
            if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RequestsPage(reports: _reports)),
              );
              return;
            }
            if (index == 2) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const IssuesMapPage()),
              );
              return;
            }
            if (index == 3) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignInPage()),
              );
              return;
            }
            setState(() => _selectedTab = index);
            if (index != 0) _showComingSoon(['الرئيسية', 'الطلبات', 'الخريطة', 'حسابي'][index]);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'طلباتي'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'الخريطة'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A6257),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x260A6257), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), shape: BoxShape.circle),
              child: const Icon(Icons.location_city, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أهلاً بك', style: TextStyle(color: Color(0xFFD5EAE5), fontSize: 15)),
                  SizedBox(height: 4),
                  Text('بلدية السويسة', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 3),
                  Text('عكّار، لبنان', style: TextStyle(color: Color(0xFFD5EAE5))),
                ],
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchServicesPage()),
                ),
                icon: const Icon(Icons.search, color: Colors.white),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
                icon: const Icon(Icons.notifications_none, color: Colors.white),
              ),
            ]),
          ],
        ),
      );

  Widget _emergencyAlert() => InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MunicipalityContactPage()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: const Color(0xFFFFE9D7), borderRadius: BorderRadius.circular(16)),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB54708)),
              SizedBox(width: 12),
              Expanded(child: Text('في حالة طوارئ، اتصل مباشرة بخط البلدية.', style: TextStyle(color: Color(0xFF7A2E0E), fontWeight: FontWeight.w600))),
              Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFFB54708)),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1D2B29)));

  Widget _serviceCard(IconData icon, String title, String subtitle, Color color, {VoidCallback? onTap}) => InkWell(
        onTap: onTap ?? () => _showComingSoon(title),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: const Color(0xFF0A6257)),
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF65716F))),
            ],
          ),
        ),
      );

  Widget _newsCard() => InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 23, backgroundColor: Color(0xFFDDEFEA), child: Icon(Icons.campaign_outlined, color: Color(0xFF0A6257))),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('أهلاً بكم في تطبيق بلدية السويسة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 7),
                Text('تابعوا الأخبار والخدمات، وأرسلوا ملاحظاتكم بسهولة.', style: TextStyle(color: Color(0xFF65716F), height: 1.45)),
                SizedBox(height: 10),
                Text('اليوم', style: TextStyle(color: Color(0xFF0A6257), fontWeight: FontWeight.w600)),
              ])),
            ],
          ),
        ),
      );
}

class ReportIssuePage extends StatefulWidget {
  const ReportIssuePage({super.key, required this.onSubmitted});

  final ValueChanged<IssueReport> onSubmitted;

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String _category = 'إنارة الشوارع';
  Uint8List? _photoBytes;

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmitted(
      IssueReport(
        category: _category,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        hasPhoto: _photoBytes != null,
        isServiceRequest: false,
      ),
    );
    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF0A6257), size: 42),
          title: const Text('تم استلام البلاغ'),
          content: const Text('شكراً لمساعدتنا في تحسين السويسة. ستتمكن قريباً من متابعة حالة البلاغ من تبويب طلباتي.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(this.context).pop();
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted) setState(() => _photoBytes = bytes);
  }

  void _chooseImageSource() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار صورة من الجهاز'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0A6257);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإبلاغ عن مشكلة', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFDDEFEA), borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      children: [
                        Icon(Icons.tips_and_updates_outlined, color: primary),
                        SizedBox(width: 12),
                        Expanded(child: Text('أرسل التفاصيل بوضوح لمساعدة الفريق على معالجة المشكلة بسرعة.')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('نوع المشكلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: _fieldDecoration('اختر نوع المشكلة'),
                    items: const ['إنارة الشوارع', 'حفرة أو ضرر في الطريق', 'نفايات', 'مياه أو صرف صحي', 'أخرى']
                        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                  const SizedBox(height: 20),
                  const Text('وصف المشكلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: _fieldDecoration('مثال: عمود الإنارة قرب المدرسة لا يعمل منذ يومين.'),
                    validator: (value) => value == null || value.trim().length < 10 ? 'اكتب وصفاً من 10 أحرف على الأقل.' : null,
                  ),
                  const SizedBox(height: 20),
                  const Text('الموقع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _locationController,
                    decoration: _fieldDecoration('الحي، الشارع، أو أقرب معلَم').copyWith(prefixIcon: const Icon(Icons.location_on_outlined)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'أدخل موقع المشكلة.' : null,
                  ),
                  const SizedBox(height: 20),
                  if (_photoBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(_photoBytes!, height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: _chooseImageSource,
                    icon: Icon(_photoBytes != null ? Icons.edit_outlined : Icons.add_a_photo_outlined),
                    label: Text(_photoBytes != null ? 'تغيير الصورة' : 'إضافة صورة للمشكلة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: primary),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('إرسال البلاغ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF7A8582)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0A6257), width: 2)),
      );
}

class IssueReport {
  IssueReport({
    required this.category,
    required this.description,
    required this.location,
    required this.hasPhoto,
    required this.isServiceRequest,
    this.status = 'received',
  });

  final String category;
  final String description;
  final String location;
  final bool hasPhoto;
  final bool isServiceRequest;
  final String status;
}

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({super.key, required this.onSubmitted});

  final ValueChanged<IssueReport> onSubmitted;

  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailsController = TextEditingController();
  String _service = 'إفادة سكن';
  String _appointmentDay = 'الاثنين 20 تموز';
  String _appointmentTime = '10:00 صباحاً';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmitted(IssueReport(
      category: 'طلب خدمة — $_service',
      description: _detailsController.text.trim().isEmpty
          ? 'طلب مقدم من ${_nameController.text.trim()}.${_service == 'موعد مع البلدية' ? ' الموعد المطلوب: $_appointmentDay، $_appointmentTime.' : ''}'
          : '${_detailsController.text.trim()}${_service == 'موعد مع البلدية' ? ' — الموعد المطلوب: $_appointmentDay، $_appointmentTime.' : ''}',
      location: 'رقم التواصل: ${_phoneController.text.trim()}',
      hasPhoto: false,
      isServiceRequest: true,
    ));
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF0A6257), size: 42),
          title: const Text('تم إرسال طلب الخدمة'),
          content: const Text('سيظهر طلبك في تبويب طلباتي ليتمكن فريق البلدية من مراجعته.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('طلب خدمة', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('نوع الخدمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _service,
                  decoration: _decoration('اختر الخدمة'),
                  items: const ['إفادة سكن', 'موعد مع البلدية', 'طلب صيانة', 'استفسار عن معاملة', 'خدمة أخرى']
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => setState(() => _service = value!),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFE8EEF9), borderRadius: BorderRadius.circular(14)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, color: Color(0xFF0A6257)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_requirements, style: const TextStyle(height: 1.4))),
                  ]),
                ),
                const SizedBox(height: 20),
                const Text('الاسم الكامل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(controller: _nameController, decoration: _decoration('اكتب اسمك الكامل'), validator: _required),
                const SizedBox(height: 20),
                const Text('رقم الهاتف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _decoration('مثال: 03 123 456'), validator: _required),
                if (_service == 'موعد مع البلدية') ...[
                  const SizedBox(height: 20),
                  const Text('اختر الموعد المناسب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _appointmentDay,
                    decoration: _decoration('اختر اليوم'),
                    items: const ['الاثنين 20 تموز', 'الأربعاء 22 تموز', 'الجمعة 24 تموز']
                        .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                        .toList(),
                    onChanged: (day) => setState(() => _appointmentDay = day!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _appointmentTime,
                    decoration: _decoration('اختر الوقت'),
                    items: const ['9:00 صباحاً', '10:00 صباحاً', '11:00 صباحاً', '12:00 ظهراً']
                        .map((time) => DropdownMenuItem(value: time, child: Text(time)))
                        .toList(),
                    onChanged: (time) => setState(() => _appointmentTime = time!),
                  ),
                ],
                const SizedBox(height: 20),
                const Text('تفاصيل إضافية (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(controller: _detailsController, minLines: 4, maxLines: 6, decoration: _decoration('اكتب أي تفاصيل تساعد البلدية على معالجة طلبك.')),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('إرسال الطلب'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0A6257), padding: const EdgeInsets.symmetric(vertical: 17)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب.' : null;

  String get _requirements {
    switch (_service) {
      case 'إفادة سكن':
        return 'المطلوب عادةً: هوية أو إخراج قيد، وإثبات عنوان السكن. ستراجع البلدية المستندات قبل إصدار الإفادة.';
      case 'موعد مع البلدية':
        return 'اختر موعداً مناسباً واكتب موضوع اللقاء بوضوح لتوجيهك إلى القسم المختص.';
      case 'طلب صيانة':
        return 'اذكر موقع المشكلة بالتفصيل، وأرفق صورة من خلال خدمة الإبلاغ عن مشكلة عند الحاجة.';
      case 'استفسار عن معاملة':
        return 'أدخل رقم المعاملة إن وجد، واكتب سؤالك باختصار.';
      default:
        return 'اشرح الخدمة المطلوبة، وسيقوم فريق البلدية بالتواصل معك لتحديد المستندات اللازمة.';
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0A6257), width: 2)),
      );
}

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key, required this.reports});

  final List<IssueReport> reports;

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  late List<IssueReport> _reports;
  bool _loadingCloud = false;

  @override
  void initState() {
    super.initState();
    _reports = List.of(widget.reports);
    _loadCloudReports();
  }

  Future<void> _loadCloudReports() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _loadingCloud = true);
    try {
      final rows = await Supabase.instance.client
          .from('requests')
          .select()
          .eq('resident_id', user.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _reports = rows
            .map((row) => IssueReport(
                  category: row['category'] as String,
                  description: row['description'] as String,
                  location: (row['location_text'] as String?) ?? 'غير محدد',
                  hasPhoto: (row['has_photo'] as bool?) ?? false,
                  isServiceRequest: row['request_type'] == 'service_request',
                  status: (row['status'] as String?) ?? 'received',
                ))
            .toList();
      });
    } catch (_) {
      // Keep locally-created reports visible when the connection is unavailable.
    } finally {
      if (mounted) setState(() => _loadingCloud = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('طلباتي', style: TextStyle(fontWeight: FontWeight.bold))),
        body: _loadingCloud && _reports.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _reports.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_outlined, size: 60, color: Color(0xFF7A8582)),
                    SizedBox(height: 16),
                    Text('لا توجد بلاغات بعد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('يمكنك إرسال بلاغ من الصفحة الرئيسية.'),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _reports.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _reportCard(_reports[index]),
              ),
      ),
    );
  }

  Widget _reportCard(IssueReport report) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(backgroundColor: Color(0xFFDDEFEA), child: Icon(Icons.assignment_outlined, color: Color(0xFF0A6257))),
                const SizedBox(width: 12),
                Expanded(child: Text(report.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFFFE9D7), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _statusLabel(report),
                    style: const TextStyle(color: Color(0xFF9A4A10), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF65716F)),
              const SizedBox(width: 5),
              Expanded(child: Text(report.location, style: const TextStyle(color: Color(0xFF65716F)))),
              if (report.hasPhoto) const Icon(Icons.photo_outlined, color: Color(0xFF0A6257)),
            ]),
          ],
        ),
      );

  String _statusLabel(IssueReport report) {
    switch (report.status) {
      case 'in_progress':
        return 'قيد المعالجة';
      case 'resolved':
        return 'تم الحل';
      case 'rejected':
        return 'مرفوض';
      default:
        return report.isServiceRequest ? 'قيد المراجعة' : 'تم الاستلام';
    }
  }
}

class PaymentHistoryPage extends StatelessWidget {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الفواتير والمدفوعات', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('سجل الرسوم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _paymentCard('رسوم خدمة النفايات 2026', 'NF-2026-00124', '500,000 ل.ل.', 'غير مدفوع', const Color(0xFFFFE9D7), Icons.pending_outlined),
            _paymentCard('رسوم خدمة النفايات 2025', 'NF-2025-00781', '400,000 ل.ل.', 'مدفوع', const Color(0xFFDDEFEA), Icons.check_circle_outline),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFE8EEF9), borderRadius: BorderRadius.circular(16)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: Color(0xFF0A6257)),
                SizedBox(width: 10),
                Expanded(child: Text('ستظهر إيصالات الدفع عبر Whish Money هنا بعد تفعيل الربط الرسمي والتحقق من العملية.', style: TextStyle(height: 1.4))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _paymentCard(String title, String reference, String amount, String status, Color color, IconData icon) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF0A6257))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(reference, style: const TextStyle(color: Color(0xFF65716F), fontSize: 13))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(status, style: TextStyle(color: color == const Color(0xFFDDEFEA) ? const Color(0xFF0A6257) : const Color(0xFF9A4A10), fontSize: 13, fontWeight: FontWeight.w600))]),
        ]),
      );
}

class MunicipalityContactPage extends StatelessWidget {
  const MunicipalityContactPage({super.key});

  static final Uri _phoneUri = Uri(scheme: 'tel', path: '+96176491566');

  Future<void> _callMunicipality(BuildContext context) async {
    if (!await launchUrl(_phoneUri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الاتصال. الرقم: +961 76 491 566')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('التواصل مع البلدية', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Container(
              padding: const EdgeInsets.all(21),
              decoration: BoxDecoration(color: const Color(0xFF0A6257), borderRadius: BorderRadius.circular(22)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.location_city, color: Colors.white, size: 32),
                SizedBox(height: 12),
                Text('بلدية السويسة', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text('السويسة، عكار، لبنان', style: TextStyle(color: Color(0xFFD5EAE5))),
              ]),
            ),
            const SizedBox(height: 22),
            const Text('للطوارئ أو المساعدة السريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _callMunicipality(context),
              icon: const Icon(Icons.phone_in_talk_outlined),
              label: const Text('اتصل بالبلدية: +961 76 491 566'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB54708), padding: const EdgeInsets.symmetric(vertical: 18)),
            ),
            const SizedBox(height: 25),
            const Text('معلومات المكتب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 11),
            _infoTile(Icons.location_on_outlined, 'الموقع', 'وسط البلدة'),
            _infoTile(Icons.access_time_outlined, 'ساعات الدوام', '8:00 صباحاً – 5:00 مساءً'),
            _infoTile(Icons.phone_outlined, 'الهاتف', '+961 76 491 566'),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: const Color(0xFFFFE9D7), borderRadius: BorderRadius.circular(16)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB54708)),
                SizedBox(width: 10),
                Expanded(child: Text('للحالات التي تهدد السلامة مباشرة، اتصل بالبلدية ولا تنتظر الرد عبر البلاغات داخل التطبيق.', style: TextStyle(color: Color(0xFF7A2E0E), height: 1.4))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF0A6257)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF65716F)))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}

class MunicipalProjectsPage extends StatelessWidget {
  const MunicipalProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const projects = [
      _MunicipalProject('تأهيل الطريق الرئيسي', 'تحسين الطريق من مدخل البلدة إلى الساحة العامة.', 68, 'قيد التنفيذ', '1,250,000,000 ل.ل.', Icons.add_road_outlined, Color(0xFFE8EEF9)),
      _MunicipalProject('توسعة شبكة الإنارة', 'تركيب أعمدة إنارة موفرة للطاقة في الأحياء.', 42, 'قيد التنفيذ', '420,000,000 ل.ل.', Icons.lightbulb_outline, Color(0xFFDDEFEA)),
      _MunicipalProject('تحسين إدارة النفايات', 'تجديد الحاويات وتحسين مواعيد الجمع.', 85, 'قريب من الإنجاز', '180,000,000 ل.ل.', Icons.delete_outline, Color(0xFFFFF0D7)),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('المشاريع والشفافية', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(color: const Color(0xFF0A6257), borderRadius: BorderRadius.circular(20)),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('معاً نبني السويسة', style: TextStyle(color: Color(0xFFD5EAE5))),
                  SizedBox(height: 7),
                  Text('تابع تقدم المشاريع البلدية بوضوح.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 21)),
                ]),
              ),
              const SizedBox(height: 22),
              ...projects.map(_projectCard),
              const SizedBox(height: 5),
              const Text('الأرقام والمشاريع المعروضة تجريبية. ستُنشر البيانات الرسمية بعد اعتمادها من البلدية.', style: TextStyle(color: Color(0xFF65716F), fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _projectCard(_MunicipalProject project) => Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: project.color, borderRadius: BorderRadius.circular(12)), child: Icon(project.icon, color: const Color(0xFF0A6257))),
            const SizedBox(width: 12),
            Expanded(child: Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
          ]),
          const SizedBox(height: 13),
          Text(project.description, style: const TextStyle(color: Color(0xFF65716F))),
          const SizedBox(height: 15),
          Row(children: [Text(project.status, style: const TextStyle(color: Color(0xFF0A6257), fontWeight: FontWeight.bold)), const Spacer(), Text('${project.progress}% مكتمل', style: const TextStyle(color: Color(0xFF65716F)))]),
          const SizedBox(height: 7),
          LinearProgressIndicator(value: project.progress / 100, minHeight: 8, borderRadius: BorderRadius.circular(8), color: const Color(0xFF0A6257), backgroundColor: const Color(0xFFE4EFEA)),
          const SizedBox(height: 14),
          Row(children: [const Icon(Icons.account_balance_wallet_outlined, size: 17, color: Color(0xFF65716F)), const SizedBox(width: 6), const Text('الميزانية:', style: TextStyle(color: Color(0xFF65716F))), const SizedBox(width: 5), Text(project.budget, style: const TextStyle(fontWeight: FontWeight.bold))]),
        ]),
      );
}

class _MunicipalProject {
  const _MunicipalProject(this.title, this.description, this.progress, this.status, this.budget, this.icon, this.color);

  final String title;
  final String description;
  final int progress;
  final String status;
  final String budget;
  final IconData icon;
  final Color color;
}

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final Set<int> _reminders = {};
  final List<_Event> _events = const [
    _Event('حملة تنظيف الحي', 'السبت 18 تموز', '9:00 صباحاً', 'ساحة البلدية', Icons.cleaning_services_outlined, Color(0xFFDDEFEA)),
    _Event('اجتماع أهالي السويسة', 'الأربعاء 22 تموز', '6:00 مساءً', 'قاعة البلدية', Icons.groups_outlined, Color(0xFFE8EEF9)),
    _Event('يوم التشجير المجتمعي', 'الأحد 2 آب', '8:30 صباحاً', 'المدخل الشرقي للبلدة', Icons.park_outlined, Color(0xFFFFF0D7)),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الفعاليات المحلية', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: _events.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xFF0A6257), borderRadius: BorderRadius.circular(20)),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('شارك في مجتمعك', style: TextStyle(color: Color(0xFFD5EAE5))),
                    SizedBox(height: 7),
                    Text('فعاليات ومبادرات بلدية السويسة', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                  ]),
                );
              }
              return _eventCard(index - 1, _events[index - 1]);
            },
          ),
        ),
      ),
    );
  }

  Widget _eventCard(int index, _Event event) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: event.color, borderRadius: BorderRadius.circular(12)), child: Icon(event.icon, color: const Color(0xFF0A6257))),
            const SizedBox(width: 12),
            Expanded(child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
          ]),
          const SizedBox(height: 15),
          _eventDetail(Icons.calendar_today_outlined, event.day),
          _eventDetail(Icons.access_time_outlined, event.time),
          _eventDetail(Icons.location_on_outlined, event.location),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() {
              if (_reminders.contains(index)) {
                _reminders.remove(index);
              } else {
                _reminders.add(index);
              }
            }),
            icon: Icon(_reminders.contains(index) ? Icons.notifications_active : Icons.notifications_none),
            label: Text(_reminders.contains(index) ? 'تم تفعيل التذكير' : 'ذكّرني بالفعالية'),
          ),
        ]),
      );

  Widget _eventDetail(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [Icon(icon, size: 17, color: const Color(0xFF65716F)), const SizedBox(width: 7), Text(text, style: const TextStyle(color: Color(0xFF65716F)))]),
      );
}

class _Event {
  const _Event(this.title, this.day, this.time, this.location, this.icon, this.color);

  final String title;
  final String day;
  final String time;
  final String location;
  final IconData icon;
  final Color color;
}

class SearchServicesPage extends StatefulWidget {
  const SearchServicesPage({super.key});

  @override
  State<SearchServicesPage> createState() => _SearchServicesPageState();
}

class _SearchServicesPageState extends State<SearchServicesPage> {
  String _query = '';

  final List<_SearchItem> _items = const [
    _SearchItem('بلّغ عن مشكلة', 'طرق، إنارة، نفايات، مياه', Icons.add_location_alt_outlined),
    _SearchItem('طلب خدمة', 'إفادة سكن، موعد، صيانة، استفسار', Icons.description_outlined),
    _SearchItem('مواعيد النفايات', 'الجدول الأسبوعي والتذكيرات', Icons.calendar_month_outlined),
    _SearchItem('رسوم خدمة النفايات', 'الفواتير والدفع عبر Whish Money', Icons.receipt_long_outlined),
    _SearchItem('الإعلانات', 'الأخبار والتنبيهات الرسمية', Icons.campaign_outlined),
    _SearchItem('الفعاليات المحلية', 'اجتماعات ومبادرات البلدة', Icons.event_outlined),
    _SearchItem('المشاريع والشفافية', 'تقدم المشاريع والميزانيات', Icons.account_tree_outlined),
    _SearchItem('التواصل مع البلدية', 'الهاتف، الموقع، وساعات الدوام', Icons.phone_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final results = _items.where((item) => item.title.contains(_query) || item.detail.contains(_query)).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البحث في الخدمات', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'ابحث عن خدمة أو معلومة',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('لا توجد نتائج مطابقة.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _resultCard(results[index]),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _resultCard(_SearchItem item) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFDDEFEA), borderRadius: BorderRadius.circular(12)), child: Icon(item.icon, color: const Color(0xFF0A6257))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(item.detail, style: const TextStyle(color: Color(0xFF65716F), fontSize: 13))])),
        ]),
      );
}

class _SearchItem {
  const _SearchItem(this.title, this.detail, this.icon);

  final String title;
  final String detail;
  final IconData icon;
}

class CommunityPollPage extends StatefulWidget {
  const CommunityPollPage({super.key});

  @override
  State<CommunityPollPage> createState() => _CommunityPollPageState();
}

class _CommunityPollPageState extends State<CommunityPollPage> {
  int? _choice;
  bool _submitted = false;
  final List<_PollOption> _options = [
    _PollOption('صيانة الطرق', Icons.add_road_outlined, 42),
    _PollOption('إنارة الشوارع', Icons.lightbulb_outline, 31),
    _PollOption('جمع النفايات', Icons.delete_outline, 18),
    _PollOption('المياه والصرف الصحي', Icons.water_drop_outlined, 9),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('استطلاع السكان', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFFDDEFEA), borderRadius: BorderRadius.circular(20)),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('رأيكم مهم', style: TextStyle(color: Color(0xFF0A6257), fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('ما هي الخدمة التي يجب أن تكون أولوية البلدية خلال الأشهر القادمة؟', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, height: 1.35)),
                  SizedBox(height: 8),
                  Text('نتائج الاستطلاع تساعد في تحديد أولويات المشاريع والخدمات.', style: TextStyle(color: Color(0xFF527266))),
                ]),
              ),
              const SizedBox(height: 22),
              ...List.generate(_options.length, (index) => _optionCard(index)),
              const Spacer(),
              if (!_submitted)
                FilledButton(
                  onPressed: _choice == null ? null : () => setState(() => _submitted = true),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0A6257), padding: const EdgeInsets.symmetric(vertical: 17)),
                  child: const Text('إرسال التصويت'),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFDDEFEA), borderRadius: BorderRadius.circular(16)),
                  child: const Row(children: [Icon(Icons.check_circle, color: Color(0xFF0A6257)), SizedBox(width: 10), Expanded(child: Text('شكراً لمشاركتك. تم تسجيل صوتك.', style: TextStyle(fontWeight: FontWeight.bold)))]),
                ),
              const SizedBox(height: 12),
              const Text('الاستطلاع تجريبي حالياً. سيُربط بحساب واحد لكل مقيم قبل النشر الرسمي.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF65716F), fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _optionCard(int index) {
    final option = _options[index];
    final selected = _choice == index;
    return InkWell(
      onTap: _submitted ? null : () => setState(() => _choice = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDDEFEA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFF0A6257) : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          Icon(option.icon, color: const Color(0xFF0A6257)),
          const SizedBox(width: 12),
          Expanded(child: Text(option.label, style: const TextStyle(fontWeight: FontWeight.bold))),
          if (_submitted) Text('${option.percent}%', style: const TextStyle(color: Color(0xFF0A6257), fontWeight: FontWeight.bold)) else Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: const Color(0xFF0A6257)),
        ]),
      ),
    );
  }
}

class _PollOption {
  _PollOption(this.label, this.icon, this.percent);

  final String label;
  final IconData icon;
  final int percent;
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<_Notice> _notices = [
    _Notice('تنبيه أعمال صيانة', 'سيجري تحويل السير قرب مبنى البلدية غداً من 8 صباحاً حتى 2 ظهراً.', 'منذ 15 دقيقة', Icons.warning_amber_rounded, const Color(0xFFFFE9D7), true),
    _Notice('تذكير جمع النفايات', 'سيصل فريق الجمع إلى منطقتك غداً الساعة 7:00 صباحاً.', 'منذ ساعتين', Icons.delete_outline, const Color(0xFFFFF0D7), true),
    _Notice('تحديث على طلبك BL-1042', 'تم استلام بلاغ الإنارة وإحالته إلى فريق الصيانة.', 'أمس', Icons.assignment_turned_in_outlined, const Color(0xFFE8EEF9), false),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = _notices.where((notice) => notice.unread).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإشعارات', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            if (unread > 0)
              TextButton(
                onPressed: () => setState(() {
                  for (final notice in _notices) {
                    notice.unread = false;
                  }
                }),
                child: const Text('قراءة الكل'),
              ),
          ],
        ),
        body: _notices.isEmpty
            ? const Center(child: Text('لا توجد إشعارات جديدة.'))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _notices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 11),
                itemBuilder: (_, index) => _noticeCard(_notices[index]),
              ),
      ),
    );
  }

  Widget _noticeCard(_Notice notice) => InkWell(
        onTap: () => setState(() => notice.unread = false),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: notice.unread ? Colors.white : const Color(0xFFF1F4F3), borderRadius: BorderRadius.circular(18)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: notice.color, borderRadius: BorderRadius.circular(12)), child: Icon(notice.icon, color: const Color(0xFF0A6257))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(notice.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                if (notice.unread) Container(height: 8, width: 8, decoration: const BoxDecoration(color: Color(0xFF0A6257), shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 5),
              Text(notice.body, style: const TextStyle(color: Color(0xFF65716F), height: 1.35)),
              const SizedBox(height: 8),
              Text(notice.time, style: const TextStyle(color: Color(0xFF65716F), fontSize: 12)),
            ])),
          ]),
        ),
      );
}

class _Notice {
  _Notice(this.title, this.body, this.time, this.icon, this.color, this.unread);

  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color color;
  bool unread;
}

class IssuesMapPage extends StatefulWidget {
  const IssuesMapPage({super.key});

  @override
  State<IssuesMapPage> createState() => _IssuesMapPageState();
}

class _IssuesMapPageState extends State<IssuesMapPage> {
  String _filter = 'الكل';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('خريطة البلاغات', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: Column(children: [
            SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                children: ['الكل', 'تم الاستلام', 'قيد المعالجة', 'تم الحل']
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(item),
                            selected: _filter == item,
                            selectedColor: const Color(0xFFDDEFEA),
                            onSelected: (_) => setState(() => _filter = item),
                          ),
                        ))
                    .toList(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Expanded(child: _mapCanvas()),
                  const SizedBox(height: 16),
                  _legend(),
                  const SizedBox(height: 16),
                  const Text('المواقع المعروضة تجريبية. ستظهر البلاغات الحقيقية بعد ربط GPS وقاعدة البيانات.', style: TextStyle(fontSize: 12, color: Color(0xFF65716F)), textAlign: TextAlign.center),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _mapCanvas() => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE4EFEA),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFBCD2C9)),
        ),
        child: Stack(children: [
          const Positioned(top: 50, left: 0, right: 0, child: Divider(color: Color(0xFFCAD8D2), thickness: 9)),
          const Positioned(top: 170, left: 0, right: 0, child: Divider(color: Color(0xFFCAD8D2), thickness: 9)),
          const Positioned(top: 0, bottom: 0, left: 90, child: VerticalDivider(color: Color(0xFFCAD8D2), thickness: 9)),
          const Positioned(top: 0, bottom: 0, right: 95, child: VerticalDivider(color: Color(0xFFCAD8D2), thickness: 9)),
          const Positioned(top: 20, right: 20, child: Text('السويسة', style: TextStyle(color: Color(0xFF527266), fontWeight: FontWeight.bold))),
          _pin(const Alignment(-.45, -.32), const Color(0xFFD35B49), Icons.lightbulb_outline, 'إنارة'),
          _pin(const Alignment(.28, -.05), const Color(0xFFD99E32), Icons.delete_outline, 'نفايات'),
          _pin(const Alignment(-.12, .42), const Color(0xFF1D8A75), Icons.construction_outlined, 'طريق'),
          _pin(const Alignment(.52, .58), const Color(0xFFD35B49), Icons.water_drop_outlined, 'مياه'),
          Positioned(
            bottom: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(10)),
              child: const Text('خريطة تجريبية', style: TextStyle(fontSize: 11, color: Color(0xFF65716F))),
            ),
          ),
        ]),
      );

  Widget _pin(Alignment alignment, Color color, IconData icon, String label) => Align(
        alignment: alignment,
        child: Tooltip(
          message: label,
          child: Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))]),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      );

  Widget _legend() => Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _legendItem(const Color(0xFFD35B49), 'تم الاستلام'),
        _legendItem(const Color(0xFFD99E32), 'قيد المعالجة'),
        _legendItem(const Color(0xFF1D8A75), 'تم الحل'),
      ]);

  Widget _legendItem(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 10, width: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);
}

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  String _filter = 'الكل';

  final List<_Announcement> _items = const [
    _Announcement('تنبيه: أعمال صيانة على الطريق الرئيسي', 'سيجري تحويل السير قرب مبنى البلدية يوم الثلاثاء من الساعة 8 صباحاً حتى 2 ظهراً.', 'تنبيه', 'اليوم', Icons.warning_amber_rounded, Color(0xFFFFE9D7)),
    _Announcement('تحديث مواعيد جمع النفايات', 'يرجى مراجعة جدول جمع النفايات الجديد حسب الحي في التطبيق.', 'خدمات', 'أمس', Icons.delete_outline, Color(0xFFFFF0D7)),
    _Announcement('فتح باب طلبات إفادة السكن', 'يمكن للمقيمين تقديم طلب إفادة السكن من خلال خدمة طلب خدمة.', 'إعلان', 'منذ يومين', Icons.description_outlined, Color(0xFFE8EEF9)),
    _Announcement('حملة تشجير في السويسة', 'ندعو الأهالي للمشاركة في حملة التشجير يوم السبت المقبل.', 'مجتمع', 'منذ 4 أيام', Icons.park_outlined, Color(0xFFDDEFEA)),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = _filter == 'الكل' ? _items : _items.where((item) => item.type == _filter).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعلانات والأخبار', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: Column(children: [
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: ['الكل', 'تنبيه', 'خدمات', 'إعلان', 'مجتمع']
                    .map((filter) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                            selectedColor: const Color(0xFFDDEFEA),
                            side: BorderSide.none,
                          ),
                        ))
                    .toList(),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _announcementCard(visible[index]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _announcementCard(_Announcement item) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(13)),
            child: Icon(item.icon, color: const Color(0xFF0A6257)),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(12)),
                child: Text(item.type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text(item.date, style: const TextStyle(fontSize: 12, color: Color(0xFF65716F))),
            ]),
            const SizedBox(height: 9),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 5),
            Text(item.body, style: const TextStyle(color: Color(0xFF65716F), height: 1.4)),
          ])),
        ]),
      );
}

class _Announcement {
  const _Announcement(this.title, this.body, this.type, this.date, this.icon, this.color);

  final String title;
  final String body;
  final String type;
  final String date;
  final IconData icon;
  final Color color;
}

class WasteSchedulePage extends StatefulWidget {
  const WasteSchedulePage({super.key});

  @override
  State<WasteSchedulePage> createState() => _WasteSchedulePageState();
}

class _WasteSchedulePageState extends State<WasteSchedulePage> {
  String _area = 'وسط السويسة';
  bool _reminderOn = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مواعيد جمع النفايات', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF0A6257), borderRadius: BorderRadius.circular(22)),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('موعد الجمع القادم', style: TextStyle(color: Color(0xFFD5EAE5))),
                  SizedBox(height: 8),
                  Text('غداً، الساعة 7:00 صباحاً', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('يرجى إخراج النفايات قبل الموعد بساعة.', style: TextStyle(color: Color(0xFFD5EAE5))),
                ]),
              ),
              const SizedBox(height: 24),
              const Text('اختر منطقتك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _area,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: const ['وسط السويسة', 'الحي الشرقي', 'الحي الغربي', 'المنطقة الزراعية']
                    .map((area) => DropdownMenuItem(value: area, child: Text(area)))
                    .toList(),
                onChanged: (area) => setState(() => _area = area!),
              ),
              const SizedBox(height: 24),
              const Text('الجدول الأسبوعي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              _dayRow('الأحد', 'جمع النفايات المنزلية', true),
              _dayRow('الثلاثاء', 'جمع النفايات المنزلية', true),
              _dayRow('الخميس', 'جمع النفايات المنزلية', true),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _reminderOn,
                onChanged: (value) => setState(() => _reminderOn = value),
                title: const Text('تذكير قبل موعد الجمع', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('إشعار قبل الموعد بساعة'),
                activeThumbColor: const Color(0xFF0A6257),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WasteFeePage()),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('رسوم خدمة النفايات'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0A6257),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 18),
              const Text('هذه مواعيد تجريبية. ستقوم البلدية بتحديث المواعيد الرسمية حسب كل حي.', style: TextStyle(color: Color(0xFF65716F), fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayRow(String day, String detail, bool active) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            height: 38,
            width: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFFFF0D7), shape: BoxShape.circle),
            child: const Icon(Icons.delete_outline, color: Color(0xFF9A4A10)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(day, style: const TextStyle(fontWeight: FontWeight.bold)), Text(detail, style: const TextStyle(color: Color(0xFF65716F), fontSize: 13))])),
          const Icon(Icons.check_circle, color: Color(0xFF0A6257)),
        ]),
      );
}

class WasteFeePage extends StatefulWidget {
  const WasteFeePage({super.key});

  @override
  State<WasteFeePage> createState() => _WasteFeePageState();
}

class _WasteFeePageState extends State<WasteFeePage> {
  bool _paymentRequested = false;
  bool _whishSelected = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('رسوم خدمة النفايات', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: const Color(0xFF0A6257), borderRadius: BorderRadius.circular(22)),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('المبلغ المستحق', style: TextStyle(color: Color(0xFFD5EAE5))),
                  SizedBox(height: 10),
                  Text('500,000 ل.ل.', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('رسوم خدمة النفايات — سنة 2026', style: TextStyle(color: Color(0xFFD5EAE5))),
                ]),
              ),
              const SizedBox(height: 24),
              _infoRow(Icons.receipt_outlined, 'رقم الإيصال', 'NF-2026-00124'),
              _infoRow(Icons.calendar_today_outlined, 'تاريخ الاستحقاق', '31 كانون الأول 2026'),
              _infoRow(Icons.info_outline, 'الحالة', _paymentRequested ? 'طلب الدفع قيد المراجعة' : 'غير مدفوع'),
              const SizedBox(height: 24),
              const Text('طرق الدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Row(children: [
                  CircleAvatar(backgroundColor: Color(0xFFDDEFEA), child: Icon(Icons.account_balance_outlined, color: Color(0xFF0A6257))),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الدفع في مقر البلدية', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 3), Text('احضر رقم الإيصال عند الدفع.', style: TextStyle(color: Color(0xFF65716F), fontSize: 13))])),
                ]),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _whishSelected = !_whishSelected),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _whishSelected ? const Color(0xFFE8EEF9) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _whishSelected ? const Color(0xFF0A6257) : Colors.transparent, width: 2),
                  ),
                  child: Row(children: [
                    Container(
                      height: 42,
                      width: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFF163B74), borderRadius: BorderRadius.circular(11)),
                      child: const Text('W', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Whish Money', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 3), Text('الدفع من محفظة Whish Money', style: TextStyle(color: Color(0xFF65716F), fontSize: 13))])),
                    Icon(_whishSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: const Color(0xFF0A6257)),
                  ]),
                ),
              ),
              if (_whishSelected) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _paymentRequested ? null : () => _startWhishPayment(),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(_paymentRequested ? 'طلب Whish قيد التجهيز' : 'المتابعة عبر Whish Money'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF163B74), padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ],
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaymentHistoryPage()),
                ),
                icon: const Icon(Icons.history_outlined),
                label: const Text('سجل الفواتير والمدفوعات'),
              ),
              const SizedBox(height: 18),
              const Text('يمكن الدفع عبر Whish Money بعد ربط حساب البلدية التجاري. لا يتم تحصيل أي أموال أو اعتبار الفاتورة مدفوعة قبل التحقق الرسمي من عملية الدفع.', style: TextStyle(color: Color(0xFF65716F), fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF0A6257)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF65716F)))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );

  void _startWhishPayment() {
    setState(() => _paymentRequested = true);
    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF163B74), size: 40),
          title: const Text('الدفع عبر Whish Money'),
          content: const Text('سيُفتح رابط الدفع أو رمز QR من Whish Money هنا بعد تفعيل حساب البلدية التجاري وربط التحقق الآمن من الدفع.'),
          actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('حسناً'))],
        ),
      ),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _contactController = TextEditingController();
  final _codeController = TextEditingController();
  bool _usePhone = false;
  bool _codeSent = false;
  bool _loading = false;

  @override
  void dispose() {
    _contactController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_contactController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل بريدك الإلكتروني أو رقم هاتفك أولاً.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (!_codeSent) {
        if (_usePhone) {
          await auth.signInWithOtp(phone: _contactController.text.trim());
        } else {
          await auth.signInWithOtp(email: _contactController.text.trim());
        }
        if (mounted) {
          setState(() => _codeSent = true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال رمز التحقق.')));
        }
      } else {
        final response = await auth.verifyOTP(
          email: _usePhone ? null : _contactController.text.trim(),
          phone: _usePhone ? _contactController.text.trim() : null,
          token: _codeController.text.trim(),
          type: _usePhone ? OtpType.sms : OtpType.email,
        );
        if (mounted && response.session != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدخول بنجاح.')));
          Navigator.of(context).pop();
        }
      }
    } on AuthException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الاتصال بالخدمة. حاول مرة أخرى.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.account_balance_outlined, size: 58, color: Color(0xFF0A6257)),
                  const SizedBox(height: 18),
                  const Text('تسجيل الدخول', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('ادخل بأمان لمتابعة طلباتك وخدماتك البلدية.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF65716F))),
                  const SizedBox(height: 28),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, icon: Icon(Icons.email_outlined), label: Text('البريد الإلكتروني')),
                      ButtonSegment(value: true, icon: Icon(Icons.phone_android_outlined), label: Text('رسالة SMS')),
                    ],
                    selected: {_usePhone},
                    onSelectionChanged: (selection) => setState(() {
                      _usePhone = selection.first;
                      _codeSent = false;
                      _contactController.clear();
                    }),
                  ),
                  const SizedBox(height: 26),
                  Text(_usePhone ? 'رقم الهاتف' : 'البريد الإلكتروني', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contactController,
                    keyboardType: _usePhone ? TextInputType.phone : TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: _usePhone ? '+961 3 123 456' : 'name@example.com',
                      prefixIcon: Icon(_usePhone ? Icons.phone_outlined : Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_codeSent) ...[
                    const Text('رمز التحقق', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  FilledButton.icon(
                    onPressed: _loading ? null : _sendCode,
                    icon: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_codeSent ? Icons.verified_user_outlined : Icons.send_outlined),
                    label: Text(_loading ? 'يرجى الانتظار...' : _codeSent ? 'تأكيد الرمز' : 'إرسال رمز التحقق'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0A6257), padding: const EdgeInsets.symmetric(vertical: 17)),
                  ),
                  const SizedBox(height: 18),
                  const Text('لن نشارك معلوماتك الشخصية. استخدامك للتطبيق يخضع لسياسة خصوصية البلدية.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF65716F))),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
                    ),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('دخول فريق البلدية — نسخة تجريبية'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
