import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sweissa_municipality/core/draft_store.dart';
import 'package:sweissa_municipality/core/models.dart';
import 'package:sweissa_municipality/core/repository.dart';
import 'package:sweissa_municipality/core/widgets.dart';
import 'package:sweissa_municipality/pages/request_form_page.dart';
import 'package:sweissa_municipality/staff_dashboard_page.dart';
import 'package:sweissa_municipality/main.dart';

class FakeRepository extends MunicipalityRepository {
  FakeRepository()
    : super(
        SupabaseClient(
          'https://example.test',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final completion = Completer<void>();
  int calls = 0;
  @override
  String? get userId => '10000000-0000-0000-0000-000000000001';
  @override
  Future<void> submit(RequestDraft draft) {
    calls++;
    return completion.future;
  }

  @override
  Future<Membership> membership() async => const Membership();
}

Widget shell(MunicipalityRepository repo, DraftStore drafts, Widget page) =>
    AppScope(
      repository: repo,
      drafts: drafts,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: page,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<DraftStore> prepare() async {
    final store = DraftStore(await SharedPreferences.getInstance());
    await store.save(
      RequestDraft(
          id: '20000000-0000-0000-0000-000000000001',
          ownerId: '10000000-0000-0000-0000-000000000001',
          service: false,
        )
        ..category = issueCategories.first
        ..description = 'Broken street light near the school'
        ..location = 'Near school',
    );
    return store;
  }

  testWidgets('failed submission preserves draft and never shows receipt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeRepository();
    final store = await prepare();
    await tester.pumpWidget(shell(repo, store, const RequestFormPage()));
    await tester.pumpAndSettle();
    final send = find.widgetWithText(FilledButton, 'إرسال الطلب');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(repo.calls, 1);
    expect(find.text('جارٍ إرسال الطلب…'), findsOneWidget);
    expect(find.textContaining('تم استلام الطلب'), findsNothing);
    repo.completion.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(store.read(repo.userId!, false), isNotNull);
    expect(find.textContaining('تم استلام الطلب'), findsNothing);
    expect(find.text('إرسال الطلب'), findsOneWidget);
  });
  testWidgets('success waits for acknowledgement and clears draft', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeRepository();
    final store = await prepare();
    await tester.pumpWidget(shell(repo, store, const RequestFormPage()));
    await tester.pumpAndSettle();
    final send = find.widgetWithText(FilledButton, 'إرسال الطلب');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(repo.calls, 1);
    expect(store.read(repo.userId!, false), isNotNull);
    final busy = find.widgetWithText(FilledButton, 'جارٍ إرسال الطلب…');
    expect(tester.widget<FilledButton>(busy).onPressed, isNull);
    repo.completion.complete();
    await tester.pumpAndSettle();
    expect(store.read(repo.userId!, false), isNull);
  });
  testWidgets('resident cannot open the staff tools', (tester) async {
    final repo = FakeRepository();
    final store = await prepare();
    await tester.pumpWidget(shell(repo, store, const StaffDashboardPage()));
    await tester.pumpAndSettle();
    expect(
      find.text('هذا الحساب لا يملك صلاحية دخول فريق البلدية.'),
      findsOneWidget,
    );
    expect(find.text('الإدارة'), findsNothing);
    expect(find.text('إدارة الفريق والصلاحيات'), findsNothing);
  });
  testWidgets('Arabic home has no layout overflow on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeRepository();
    final store = await prepare();
    await tester.pumpWidget(SweissaApp(repository: repo, drafts: store));
    await tester.pumpAndSettle();
    expect(find.text('بلدية السويسة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
