import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Local, account-scoped drafts; never presented as submitted municipality work.
class DraftStore {
  DraftStore(this.preferences);
  final SharedPreferences preferences;
  Future<void> _pending = Future.value();
  String _key(String owner, bool service) => 'sweissa.draft.v1.$owner.$service';
  RequestDraft? read(String owner, bool service) {
    final value = preferences.getString(_key(owner, service));
    if (value == null) return null;
    try {
      final d = RequestDraft.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
      return d.ownerId == owner && d.service == service ? d : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RequestDraft draft) {
    final encoded = jsonEncode(draft.toJson());
    final next = _pending.catchError((_) {}).then((_) async {
      if (!await preferences.setString(
        _key(draft.ownerId, draft.service),
        encoded,
      )) {
        throw StateError('Could not save draft');
      }
    });
    _pending = next;
    return next;
  }

  Future<void> clear(String owner, bool service) {
    final next = _pending.catchError((_) {}).then((_) async {
      if (!await preferences.remove(_key(owner, service))) {
        throw StateError('Could not clear draft');
      }
    });
    _pending = next;
    return next;
  }
}
