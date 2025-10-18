import 'package:cloud_firestore/cloud_firestore.dart';

class ContentModerationService {
  // Basic keyword list for objectionable content. You can expand this list.
  static final List<String> _bannedKeywords = [
    // Profanity (sample, keep lowercase)
    'salak', 'aptal', 'gerizekali', 'orospu', 'siktir', 'amk', 'piç', 'oç',
    // Hate speech / harassment (examples)
    'nefret', 'ırkçı', 'linç','gerizekalı',"mal","embesil","orospu çocuğu"
  ];

  static bool isObjectionable(String text) {
    final lower = text.toLowerCase();
    for (final kw in _bannedKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  static String? findFirstMatch(String text) {
    final lower = text.toLowerCase();
    for (final kw in _bannedKeywords) {
      if (lower.contains(kw)) return kw;
    }
    return null;
  }

  // Optional: store flagged attempts (for audit)
  static Future<void> logBlockedSubmission({
    required String userId,
    required String contentType,
    required String content,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('moderation_logs').add({
        'userId': userId,
        'contentType': contentType, // e.g., 'message' | 'comment' | 'activity'
        'content': content,
        'blockedBy': 'keyword_filter',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
