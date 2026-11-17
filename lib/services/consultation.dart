import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'occasions.dart';

/// حجز استشارة عطرية — بلا خادم: يُرسَل عبر واتساب برسالة جاهزة
/// للدار، ويُحفظ الطلب محلياً ليعرضه العميل في «استشاراتي».

/// رقم واتساب الدار لاستقبال طلبات الاستشارة.
const String consultationWhatsAppNumber = '201042881176';

/// أوقات الاستشارة المتاحة (12 ظهراً حتى 10 مساءً، كل ساعة).
const List<String> consultationTimeSlots = <String>[
  '12:00',
  '13:00',
  '14:00',
  '15:00',
  '16:00',
  '17:00',
  '18:00',
  '19:00',
  '20:00',
  '21:00',
  '22:00',
];

/// ينسّق خانة وقت «HH:MM» عربياً: 12:00 ظهراً، 1:00 مساءً...
String formatTimeSlotAr(String slot) {
  final hour = int.tryParse(slot.split(':').first) ?? 12;
  if (hour == 12) return '12:00 ظهراً';
  if (hour > 12) return '${hour - 12}:00 مساءً';
  return '$hour:00 صباحاً';
}

/// طلب استشارة محفوظ محلياً.
class ConsultationRequest {
  const ConsultationRequest({
    required this.id,
    required this.date,
    required this.timeSlot,
    required this.type,
    this.notes = '',
    required this.createdAt,
    this.status = 'pending',
  });

  /// معرّف محلي فريد.
  final String id;

  /// اليوم المفضل 'YYYY-MM-DD'.
  final String date;

  /// الوقت المفضل 'HH:MM' (24 ساعة).
  final String timeSlot;

  /// نوع الاستشارة: 'call' (مكالمة) أو 'whatsapp' (واتساب).
  final String type;

  final String notes;

  final DateTime createdAt;

  /// الحالة: 'pending' (بانتظار التأكيد) — تُحدَّث يدوياً من الدار لاحقاً.
  final String status;

  String get typeLabel => type == 'call' ? 'مكالمة هاتفية' : 'واتساب';
  String get timeLabel => formatTimeSlotAr(timeSlot);
  String get statusLabel =>
      status == 'pending' ? 'بانتظار التأكيد' : status;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date,
        'timeSlot': timeSlot,
        'type': type,
        'notes': notes,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'status': status,
      };

  factory ConsultationRequest.fromJson(Map<String, dynamic> json) =>
      ConsultationRequest(
        id: '${json['id'] ?? ''}',
        date: '${json['date'] ?? ''}',
        timeSlot: '${json['timeSlot'] ?? '18:00'}',
        type: '${json['type'] ?? 'whatsapp'}',
        notes: '${json['notes'] ?? ''}',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num?)?.toInt() ?? 0,
        ),
        status: '${json['status'] ?? 'pending'}',
      );
}

/// نص رسالة واتساب الجاهزة لحجز استشارة — يحمل اليوم والوقت والنوع.
String buildConsultationMessage(ConsultationRequest request) {
  final date = DateTime.tryParse(request.date);
  final day = date == null ? request.date : formatArabicDate(date);
  final lines = <String>[
    'مرحباً دار زخم، أود حجز استشارة عطرية.',
    'اليوم: $day',
    'الوقت المفضل: ${request.timeLabel}',
    'نوع الاستشارة: ${request.typeLabel}',
  ];
  if (request.notes.trim().isNotEmpty) {
    lines.add('ملاحظات: ${request.notes.trim()}');
  }
  return lines.join('\n');
}

/// رابط واتساب الجاهز بالرسالة كاملة.
String consultationWhatsAppUrl(ConsultationRequest request) =>
    'https://wa.me/$consultationWhatsAppNumber'
    '?text=${Uri.encodeComponent(buildConsultationMessage(request))}';

/// تخزين طلبات الاستشارة محلياً (مفتاح لكل حساب — يفصل طلبات حساب
/// عن آخر على الجهاز نفسه). best-effort: أي فشل يُرجع قائمة فارغة
/// ولا يكسر أي شاشة.
class ConsultationService {
  static const String _keyPrefix = 'zakham_consultations_v1_';

  Future<List<ConsultationRequest>> load({
    required String ownerKey,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$ownerKey');
      if (raw == null || raw.isEmpty) return const <ConsultationRequest>[];
      final list = jsonDecode(raw) as List<dynamic>;
      final requests = list
          .whereType<Map<String, dynamic>>()
          .map(ConsultationRequest.fromJson)
          .where((r) => r.id.isNotEmpty && r.date.isNotEmpty)
          .toList(growable: false);
      requests.sort((a, b) => a.date.compareTo(b.date));
      return requests;
    } catch (_) {
      return const <ConsultationRequest>[];
    }
  }

  /// يحفظ طلباً جديداً ويعيده (بمعرّف وتاريخ إنشاء).
  Future<ConsultationRequest> save({
    required String ownerKey,
    required String date,
    required String timeSlot,
    required String type,
    String notes = '',
  }) async {
    final request = ConsultationRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date,
      timeSlot: timeSlot,
      type: type,
      notes: notes.trim(),
      createdAt: DateTime.now(),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await load(ownerKey: ownerKey);
      final all = <ConsultationRequest>[...existing, request];
      await prefs.setString(
        '$_keyPrefix$ownerKey',
        jsonEncode(all.map((r) => r.toJson()).toList()),
      );
    } catch (_) {
      // الحفظ المحلي فشل — الطلب يُرسَل واتساب على أي حال.
    }
    return request;
  }
}
