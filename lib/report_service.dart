import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  static Future<void> reportContent({
    required String reporterId,
    required String contentId,
    required String contentType, // 'comment' | 'message' | 'activity'
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    final reports = FirebaseFirestore.instance.collection('reports');
    final mail = FirebaseFirestore.instance.collection('mail');

    // 1) Raporu oluştur
    final reportRef = await reports.add({
      'reporterId': reporterId,
      'contentId': contentId,
      'contentType': contentType,
      'reason': reason,
      'metadata': metadata ?? {},
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2) Admin e-posta bildirimi (Firebase Extension: Trigger Email gerekli)
    try {
      final subject = 'Yeni Rapor: $contentType ($contentId)';
      final body = [
        'Yeni bir rapor oluşturuldu:',
        'İçerik Türü: $contentType',
        'İçerik ID: $contentId',
        'Raporlayan: $reporterId',
        if (reason.isNotEmpty) 'Sebep: $reason',
        if ((metadata ?? {}).isNotEmpty) 'Metadata: ${(metadata ?? {}).toString()}',
        'Rapor Doküman ID: ${reportRef.id}',
        'Zaman: (serverTimestamp)',
      ].join('\n');

      await mail.add({
        'to': ['buraksoysal08@gmail.com', 'burak.soysal@ogr.ksbu.edu.tr'],
        // Uzantı konfigünde varsayılan from yoksa burayı doldurun
        // 'from': 'Fitmatch Moderation <no-reply@yourdomain.com>',
        // 'replyTo': 'no-reply@yourdomain.com',
        'message': {
          'subject': subject,
          'text': body,
          'html': body.replaceAll('\n', '<br/>'),
        },
      });
    } catch (e) {
      // E-posta kuyruğu yazımı opsiyonel; başarısız olsa bile rapor akışını bozmayalım
      // ignore: avoid_print
      print('E-posta bildirimi kuyruğa yazılamadı: $e');
    }
  }
}
