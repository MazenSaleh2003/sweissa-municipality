import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class MunicipalityRepository {
  MunicipalityRepository(this.client);
  final SupabaseClient client;
  String? get userId => client.auth.currentUser?.id;
  Future<Membership> membership() async {
    if (userId == null) return const Membership();
    final row = await client
        .from('staff_members')
        .select('role,department_id')
        .eq('user_id', userId!)
        .maybeSingle();
    return row == null
        ? const Membership()
        : Membership(
            role: row['role'] as String,
            departmentId: row['department_id'] as String?,
          );
  }

  Future<void> submit(RequestDraft draft) async {
    if (userId == null || userId != draft.ownerId) {
      throw const AuthException('Please sign in again');
    }
    // A stable UUID makes retries safe when the insert committed but its response was lost.
    final fingerprint = draftFingerprint(draft);
    final existing = await client
        .from('requests')
        .select('id,submission_fingerprint')
        .eq('id', draft.id)
        .maybeSingle();
    if (existing != null) {
      if (existing['submission_fingerprint'] != fingerprint) {
        throw SubmittedDraftChanged();
      }
      return;
    }
    if (draft.photo != null) {
      final mime = draft.photoExtension == 'jpg'
          ? 'image/jpeg'
          : 'image/${draft.photoExtension}';
      await client.storage
          .from('request-photos')
          .uploadBinary(
            draft.photoPath!,
            draft.photo!,
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );
    }
    try {
      await client
          .from('requests')
          .insert({...draft.toRow(), 'submission_fingerprint': fingerprint})
          .select('id')
          .single();
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final row = await client
          .from('requests')
          .select('id,submission_fingerprint')
          .eq('id', draft.id)
          .maybeSingle();
      if (row == null) rethrow;
      if (row['submission_fingerprint'] != fingerprint) {
        throw SubmittedDraftChanged();
      }
    }
  }

  Future<List<Map<String, dynamic>>> requests({
    bool staff = false,
    int offset = 0,
  }) async {
    if (userId == null) throw const AuthException('Please sign in');
    var query = client.from('requests').select();
    if (!staff) {
      query = query.eq('resident_id', userId!);
    } else {
      final member = await membership();
      if (!member.isStaff) throw const AuthException('Staff access required');
      if (!member.isAdmin) {
        query = query.eq('department_id', member.departmentId!);
      }
    }
    return await query
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + 29);
  }

  Future<Map<String, dynamic>> request(String id) async =>
      await client.from('requests').select().eq('id', id).single();
  Future<List<Map<String, dynamic>>> history(String id) async => await client
      .from('request_history')
      .select()
      .eq('request_id', id)
      .order('created_at');
  Future<String> photoUrl(String path) =>
      client.storage.from('request-photos').createSignedUrl(path, 300);
  Future<List<Map<String, dynamic>>> departments() async =>
      await client.from('departments').select().order('name');
  Future<void> updateRequest(
    String id,
    String status,
    String note,
    String? department,
  ) => client.rpc(
    'update_request',
    params: {
      'target_id': id,
      'next_status': status,
      'note': note,
      'assigned_department': department,
    },
  );
  Future<List<Map<String, dynamic>>> content(
    String kind, {
    bool admin = false,
    int offset = 0,
  }) async {
    var query = client.from('public_content').select().eq('kind', kind);
    if (!admin) query = query.eq('published', true);
    return await query
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + 29);
  }

  Future<void> saveContent(Map<String, dynamic> row) async =>
      await client.from('public_content').upsert(row);
  Future<void> deleteContent(String id) async =>
      await client.from('public_content').delete().eq('id', id);
  Future<List<Map<String, dynamic>>> polls({bool admin = false}) async {
    var query = client.from('polls').select();
    if (!admin) query = query.eq('published', true);
    return await query.order('created_at', ascending: false).limit(100);
  }

  Future<List<Map<String, dynamic>>> pollResults(String id) async =>
      List<Map<String, dynamic>>.from(
        await client.rpc('poll_results', params: {'target_id': id}) as List,
      );
  Future<int?> myVote(String id) async {
    if (userId == null) return null;
    final row = await client
        .from('poll_votes')
        .select('option_index')
        .eq('poll_id', id)
        .eq('voter_id', userId!)
        .maybeSingle();
    return row?['option_index'] as int?;
  }

  Future<void> vote(String id, int index) async => await client
      .from('poll_votes')
      .insert({'poll_id': id, 'voter_id': userId, 'option_index': index});
  Future<void> createPoll(Map<String, dynamic> row) async =>
      await client.from('polls').insert(row);
  Future<void> deletePoll(String id) async =>
      await client.from('polls').delete().eq('id', id);
  Future<List<Map<String, dynamic>>> invoices({
    bool admin = false,
    int offset = 0,
  }) async {
    var query = client.from('invoices').select();
    if (!admin) query = query.eq('resident_id', userId!);
    return await query
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + 29);
  }

  Future<void> createInvoice(Map<String, dynamic> row) async =>
      await client.from('invoices').insert(row);
  Future<void> recordPayment(String id, String receipt) => client.rpc(
    'record_payment',
    params: {'target_id': id, 'receipt_reference': receipt},
  );
  Future<List<Map<String, dynamic>>> members() async =>
      await client.from('staff_members').select().order('created_at');
  Future<Map<String, dynamic>> metrics() async =>
      Map<String, dynamic>.from(await client.rpc('request_metrics') as Map);
  Future<void> manageMember(String id, String role, String? department) =>
      client.rpc(
        'manage_member',
        params: {
          'target_id': id,
          'new_role': role,
          'assigned_department': department,
        },
      );
}

String friendlyError(Object error) {
  if (error is SubmittedDraftChanged) {
    return 'هذا الطلب أُرسل سابقاً. التعديلات الجديدة لم تُرسل. راجع الطلب في طلباتي، ثم احذف المسودة لبدء طلب جديد.';
  }
  if (error is AuthException) {
    return 'تعذر تسجيل الدخول. تحقق من بياناتك والرمز أو سجّل الدخول مجدداً.';
  }
  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'ليس لديك صلاحية لهذا الإجراء. حدّث الصفحة أو سجّل الدخول مجدداً.';
    }
    if (error.code == '23505') {
      return 'تم تسجيل هذا الإجراء مسبقاً. حدّث الصفحة.';
    }
    if (error.code == '42P01' ||
        error.code == 'PGRST205' ||
        error.code == 'PGRST202') {
      return 'الخدمة غير مهيّأة بعد. تواصل مع إدارة البلدية.';
    }
    if (error.code == '23514' || error.code == '22P02') {
      return 'تحقق من البيانات المدخلة وحاول مجدداً.';
    }
  }
  return 'تعذر إكمال العملية. تحقق من الاتصال وحاول مجدداً.';
}
