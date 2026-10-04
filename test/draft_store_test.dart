import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweissa_municipality/core/draft_store.dart';
import 'package:sweissa_municipality/core/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'draft and photo survive reload and are isolated by account and form type',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final store = DraftStore(preferences);
      final draft =
          RequestDraft(id: 'request-1', ownerId: 'resident-1', service: false)
            ..category = 'مياه'
            ..description = 'A leaking public water pipe'
            ..latitude = 34.5
            ..longitude = 36.1
            ..photo = Uint8List.fromList([0xff, 0xd8, 0xff, 1, 2])
            ..photoExtension = 'jpg';
      await store.save(draft);
      final reloaded = DraftStore(preferences).read('resident-1', false)!;
      expect(reloaded.id, draft.id);
      expect(reloaded.description, draft.description);
      expect(reloaded.photo, draft.photo);
      expect(reloaded.latitude, 34.5);
      expect(store.read('resident-2', false), isNull);
      expect(store.read('resident-1', true), isNull);
      await store.clear('resident-1', false);
      expect(store.read('resident-1', false), isNull);
    },
  );
  test(
    'queued saves snapshot their content and clear cannot race a pending save',
    () async {
      final store = DraftStore(await SharedPreferences.getInstance());
      final draft = RequestDraft(id: 'r', ownerId: 'u', service: false)
        ..description = 'first version';
      final first = store.save(draft);
      draft.description = 'new version';
      final second = store.save(draft);
      await Future.wait([first, second]);
      expect(store.read('u', false)!.description, 'new version');
      final pending = store.save(draft);
      final clear = store.clear('u', false);
      await Future.wait([pending, clear]);
      expect(store.read('u', false), isNull);
    },
  );
}
