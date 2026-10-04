import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

const issueCategories = [
  'إنارة الشوارع',
  'الطرق والحفر',
  'النفايات',
  'مياه',
  'أخرى',
];
const serviceCategories = ['إفادة سكن', 'طلب موعد', 'استفسار', 'خدمة أخرى'];
const statusLabels = {
  'received': 'تم الاستلام',
  'in_progress': 'قيد المعالجة',
  'resolved': 'تم الحل',
  'rejected': 'مرفوض',
};
const contentLabels = {
  'announcement': 'الإعلانات',
  'event': 'الفعاليات',
  'project': 'المشاريع والشفافية',
  'waste_schedule': 'مواعيد جمع النفايات',
  'contact': 'التواصل مع البلدية',
};

class Membership {
  const Membership({this.role = 'resident', this.departmentId});
  final String role;
  final String? departmentId;
  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff' || isAdmin;
  String get label => isAdmin
      ? 'مدير البلدية'
      : isStaff
      ? 'فريق البلدية'
      : 'مقيم';
}

class RequestDraft {
  RequestDraft({
    required this.id,
    required this.ownerId,
    required this.service,
  });
  final String id;
  final String ownerId;
  final bool service;
  String category = '', description = '', location = '', phone = '';
  double? latitude, longitude;
  Uint8List? photo;
  String? photoExtension;
  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'service': service,
    'category': category,
    'description': description,
    'location': location,
    'phone': phone,
    'latitude': latitude,
    'longitude': longitude,
    'photo': photo == null ? null : base64Encode(photo!),
    'photo_extension': photoExtension,
  };
  factory RequestDraft.fromJson(Map<String, dynamic> json) {
    final d = RequestDraft(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      service: json['service'] as bool,
    );
    d.category = json['category'] as String? ?? '';
    d.description = json['description'] as String? ?? '';
    d.location = json['location'] as String? ?? '';
    d.phone = json['phone'] as String? ?? '';
    d.latitude = (json['latitude'] as num?)?.toDouble();
    d.longitude = (json['longitude'] as num?)?.toDouble();
    d.photo = json['photo'] == null
        ? null
        : base64Decode(json['photo'] as String);
    d.photoExtension = json['photo_extension'] as String?;
    return d;
  }
  String? get photoPath =>
      photo == null ? null : '$ownerId/$id/photo.$photoExtension';
  Map<String, dynamic> toRow() => {
    'id': id,
    'resident_id': ownerId,
    'request_type': service ? 'service_request' : 'issue_report',
    'category': category,
    'description': description.trim(),
    'location_text': location.trim().isEmpty ? null : location.trim(),
    'contact_phone': phone.trim().isEmpty ? null : phone.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'photo_path': photoPath,
  };
}

String draftFingerprint(RequestDraft draft) => sha256
    .convert(
      utf8.encode(
        jsonEncode({
          ...draft.toRow(),
          'photo_digest': draft.photo == null
              ? null
              : sha256.convert(draft.photo!).toString(),
        }),
      ),
    )
    .toString();

class SubmittedDraftChanged implements Exception {}

String dateLabel(Object? value) {
  final d = DateTime.tryParse('$value')?.toLocal();
  if (d == null) return '';
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String shortId(Object? value) =>
    '$value'.substring(0, '$value'.length.clamp(0, 8)).toUpperCase();
String? detectPhotoExtension(Uint8List data) {
  if (data.length >= 3 &&
      data[0] == 0xff &&
      data[1] == 0xd8 &&
      data[2] == 0xff) {
    return 'jpg';
  }
  if (data.length >= 8 &&
      data[0] == 0x89 &&
      data[1] == 0x50 &&
      data[2] == 0x4e &&
      data[3] == 0x47) {
    return 'png';
  }
  if (data.length >= 12 &&
      ascii.decode(data.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(data.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'webp';
  }
  return null;
}
