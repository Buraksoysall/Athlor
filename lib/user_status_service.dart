import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

class UserStatusService {
  static final UserStatusService _instance = UserStatusService._internal();
  factory UserStatusService() => _instance;
  UserStatusService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Kullanıcının çevrimiçi durumunu güncelle
  Future<void> updateUserStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Kullanıcı durumu güncellenirken hata: $e');
    }
  }

  // Kullanıcının çevrimiçi durumunu al
  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['isOnline'] ?? false);
  }

  // Kullanıcının son görülme zamanını al
  Stream<DateTime?> getUserLastSeen(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      final lastSeen = doc.data()?['lastSeen'] as Timestamp?;
      return lastSeen?.toDate();
    });
  }

  // Kullanıcı giriş yaptığında çevrimiçi yap
  Future<void> setUserOnline() async {
    await updateUserStatus(true);
  }

  // Kullanıcı çıkış yaptığında çevrimdışı yap
  Future<void> setUserOffline() async {
    await updateUserStatus(false);
  }

  // App lifecycle değişikliklerini dinle
  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        setUserOnline();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        setUserOffline();
        break;
      case AppLifecycleState.hidden:
        // iOS için yeni durum
        setUserOffline();
        break;
    }
  }
}
