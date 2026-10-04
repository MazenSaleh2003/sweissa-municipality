import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/draft_store.dart';
import 'core/repository.dart';
import 'core/widgets.dart';
import 'core/models.dart';
import 'pages/auth_page.dart';
import 'pages/content_page.dart';
import 'pages/request_form_page.dart';
import 'pages/requests_page.dart';
import 'pages/polls_page.dart';
import 'pages/invoices_page.dart';
import 'pages/map_page.dart';
import 'supabase_config.dart';

bool _supabaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!_supabaseReady) {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
      _supabaseReady = true;
    }
    final prefs = await SharedPreferences.getInstance();
    runApp(
      SweissaApp(
        repository: MunicipalityRepository(Supabase.instance.client),
        drafts: DraftStore(prefs),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر بدء التطبيق. تحقق من الإعدادات وحاول مجدداً.'),
                TextButton(
                  onPressed: main,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SweissaApp extends StatefulWidget {
  const SweissaApp({super.key, required this.repository, required this.drafts});
  final MunicipalityRepository repository;
  final DraftStore drafts;
  @override
  State<SweissaApp> createState() => _SweissaAppState();
}

class _SweissaAppState extends State<SweissaApp> {
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _auth;
  int _sessionVersion = 0;
  @override
  void initState() {
    super.initState();
    _auth = widget.repository.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      setState(() => _sessionVersion++);
      if (state.event == AuthChangeEvent.signedOut) {
        _navigator.currentState?.popUntil((r) => r.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    repository: widget.repository,
    drafts: widget.drafts,
    child: MaterialApp(
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      title: 'بلدية السويسة',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A6257),
          primary: const Color(0xFF0A6257),
          secondary: const Color(0xFFD9A441),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ),
      home: MunicipalityHomePage(sessionVersion: _sessionVersion),
    ),
  );
}

class MunicipalityHomePage extends StatefulWidget {
  const MunicipalityHomePage({super.key, this.sessionVersion = 0});
  final int sessionVersion;
  @override
  State<MunicipalityHomePage> createState() => _MunicipalityHomePageState();
}

class _MunicipalityHomePageState extends State<MunicipalityHomePage> {
  int _tab = 0;
  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  Future<void> _request(bool service) async {
    if (!await requireSignIn(context) || !mounted) return;
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RequestFormPage(service: service)),
    );
    if (sent == true && mounted) setState(() => _tab = 1);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(['بلدية السويسة', 'طلباتي', 'خريطة طلباتي', 'حسابي'][_tab]),
      actions: [
        IconButton(
          tooltip: 'البحث في الخدمات',
          icon: const Icon(Icons.search),
          onPressed: () => _open(ServiceSearchPage(onRequest: _request)),
        ),
        IconButton(
          tooltip: 'التحديثات',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _open(const UpdatesPage()),
        ),
      ],
    ),
    body: SafeArea(
      child: switch (_tab) {
        0 => _home(),
        1 => RequestsPage(key: ValueKey(widget.sessionVersion)),
        2 => IssuesMapPage(key: ValueKey(widget.sessionVersion)),
        _ => AccountPage(key: ValueKey(widget.sessionVersion)),
      },
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          label: 'طلباتي',
        ),
        NavigationDestination(icon: Icon(Icons.map_outlined), label: 'الخريطة'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'حسابي'),
      ],
    ),
  );
  Widget _home() => LayoutBuilder(
    builder: (context, box) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0A6257),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_city, size: 40, color: Colors.white),
              SizedBox(height: 14),
              Text(
                'أهلاً بك في السويسة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'خدمات بلدتك ومتابعة طلباتك في مكان واحد',
                style: TextStyle(color: Color(0xFFD5EAE5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFFFE9D7),
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('البلاغات في التطبيق ليست قناة للطوارئ.'),
            subtitle: const Text('راجع بيانات التواصل الرسمية للبلدية.'),
            onTap: () => _open(const ContentPage(kind: 'contact')),
          ),
        ),
        const SizedBox(height: 20),
        Text('خدمات البلدية', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: box.maxWidth > 950
              ? 4
              : box.maxWidth > 650
              ? 3
              : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: box.maxWidth < 350 ? 0.95 : 1.2,
          children: [
            _card(
              'بلّغ عن مشكلة',
              'طرق، إنارة، نفايات',
              Icons.add_location_alt_outlined,
              () => _request(false),
            ),
            _card(
              'طلب خدمة',
              'معاملات واستفسارات',
              Icons.description_outlined,
              () => _request(true),
            ),
            _card(
              'مواعيد النفايات',
              'جدول الجمع المعتمد',
              Icons.calendar_month_outlined,
              () => _open(const ContentPage(kind: 'waste_schedule')),
            ),
            _card(
              'الإعلانات',
              'أخبار البلدية',
              Icons.campaign_outlined,
              () => _open(const ContentPage(kind: 'announcement')),
            ),
            _card(
              'استطلاع السكان',
              'شارك برأيك',
              Icons.how_to_vote_outlined,
              () => _open(const PollsPage()),
            ),
            _card(
              'فعاليات محلية',
              'اجتماعات ومبادرات',
              Icons.event_outlined,
              () => _open(const ContentPage(kind: 'event')),
            ),
            _card(
              'المشاريع والشفافية',
              'التقدم والميزانيات',
              Icons.account_tree_outlined,
              () => _open(const ContentPage(kind: 'project')),
            ),
            _card(
              'الفواتير',
              'الفواتير والمدفوعات',
              Icons.receipt_long_outlined,
              () => _open(const InvoicesPage()),
            ),
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => _open(const ContentPage(kind: 'contact')),
          icon: const Icon(Icons.phone_outlined),
          label: const Text('التواصل مع البلدية'),
        ),
        TextButton(
          onPressed: () => _open(const PrivacyPage()),
          child: const Text('الخصوصية واستخدام البيانات'),
        ),
      ],
    ),
  );
  Widget _card(String title, String detail, IconData icon, VoidCallback tap) =>
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: const Color(0xFF0A6257), size: 30),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class ServiceSearchPage extends StatefulWidget {
  const ServiceSearchPage({super.key, required this.onRequest});
  final Future<void> Function(bool) onRequest;
  @override
  State<ServiceSearchPage> createState() => _ServiceSearchPageState();
}

class _ServiceSearchPageState extends State<ServiceSearchPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final entries = <String, VoidCallback>{
      'بلّغ عن مشكلة': () => widget.onRequest(false),
      'طلب خدمة': () => widget.onRequest(true),
      for (final e in contentLabels.entries)
        e.value: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContentPage(kind: e.key)),
        ),
      'استطلاع السكان': () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PollsPage()),
      ),
      'الفواتير والمدفوعات': () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InvoicesPage()),
      ),
    };
    final results = entries.entries
        .where((e) => e.key.contains(_query))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('البحث في الخدمات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                labelText: 'ابحث عن خدمة',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const EmptyState('لا توجد نتائج مطابقة.')
                : ListView(
                    children: results
                        .map(
                          (e) => ListTile(
                            title: Text(e.key),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: e.value,
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class UpdatesPage extends StatelessWidget {
  const UpdatesPage({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('التحديثات'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'طلباتك'),
            Tab(text: 'إعلانات البلدية'),
          ],
        ),
      ),
      body: const TabBarView(children: [RequestsPage(), _AnnouncementsTab()]),
    ),
  );
}

class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab();
  @override
  Widget build(BuildContext context) => PagedList(
    load: (offset) =>
        AppScope.of(context).repository.content('announcement', offset: offset),
    empty: 'لا توجد إعلانات منشورة بعد.',
    item: (row, refresh) => Card(
      child: ListTile(
        title: Text('${row['title']}'),
        subtitle: Text('${row['body']}\n${dateLabel(row['created_at'])}'),
      ),
    ),
  );
}
