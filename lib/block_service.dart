import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockService {
  static CollectionReference<Map<String, dynamic>> _blockedRef(String userId) =>
      FirebaseFirestore.instance.collection('users').doc(userId).collection('blocked');

  static Future<void> blockUser(String targetUserId) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;

    await _blockedRef(current.uid).doc(targetUserId).set({
      'blockedUserId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> unblockUser(String targetUserId) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;

    await _blockedRef(current.uid).doc(targetUserId).delete();
  }

  static Future<bool> isBlocked(String currentUserId, String otherUserId) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return false;
    if (current.uid != currentUserId) return false;
    try {
      final doc = await _blockedRef(currentUserId).doc(otherUserId).get();
      return doc.exists;
    } catch (e) {
      // Permission veya ağ hatasında güvenli varsayılan
      return false;
    }
  }

  static Stream<bool> isBlockedStream(String currentUserId, String otherUserId) {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || current.uid != currentUserId) {
      return Stream<bool>.value(false);
    }
    return _blockedRef(currentUserId)
        .doc(otherUserId)
        .snapshots()
        .map((d) => d.exists);
  }
}
