import 'package:cloud_firestore/cloud_firestore.dart';

class UnreadMessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Bir chat'teki okunmamış mesaj sayısını al
  static Future<int> getUnreadMessageCount(String chatId, String currentUserId) async {
    try {
      QuerySnapshot messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      if (messagesSnapshot.docs.isEmpty) return 0;

      int unreadCount = 0;
      
      for (var doc in messagesSnapshot.docs) {
        Map<String, dynamic> messageData = doc.data() as Map<String, dynamic>;
        String senderId = messageData['senderId'] ?? '';
        List<dynamic> readBy = messageData['readBy'] ?? [];
        
        // Eğer mesaj başka kullanıcıdan geliyorsa ve kullanıcı readBy listesinde yoksa
        if (senderId != currentUserId && !readBy.contains(currentUserId)) {
          unreadCount++;
        }
      }
      
      return unreadCount;
    } catch (e) {
      print('Okunmamış mesaj sayısı alınırken hata: $e');
      return 0;
    }
  }

  /// Bir chat'te okunmamış mesaj var mı kontrol et
  static Future<bool> hasUnreadMessages(String chatId, String currentUserId) async {
    try {
      int unreadCount = await getUnreadMessageCount(chatId, currentUserId);
      return unreadCount > 0;
    } catch (e) {
      print('Okunmamış mesaj kontrolü hatası: $e');
      return false;
    }
  }

  /// Kullanıcının tüm chat'lerinde okunmamış mesaj var mı kontrol et
  static Future<bool> hasAnyUnreadMessages(String currentUserId) async {
    try {
      // Kullanıcının katıldığı tüm chat'leri al
      QuerySnapshot chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      if (chatsSnapshot.docs.isEmpty) return false;

      // Paralel olarak tüm chat'lerin son mesajlarını kontrol et
      List<Future<bool>> chatChecks = [];
      
      for (var doc in chatsSnapshot.docs) {
        String chatId = doc.id;
        chatChecks.add(hasUnreadMessages(chatId, currentUserId));
      }

      // Tüm chat'leri paralel olarak kontrol et
      List<bool> results = await Future.wait(chatChecks);
      
      // Herhangi bir chat'te okunmamış mesaj var mı kontrol et
      return results.any((hasUnreadInChat) => hasUnreadInChat);
    } catch (e) {
      print('Genel okunmamış mesaj kontrolü hatası: $e');
      return false;
    }
  }

  /// Bir chat'teki tüm mesajları okundu olarak işaretle
  static Future<void> markChatAsRead(String chatId, String currentUserId) async {
    try {
      // Bu chat'teki tüm mesajları al
      QuerySnapshot messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      if (messagesSnapshot.docs.isEmpty) return;

      // Batch işlem başlat
      WriteBatch batch = _firestore.batch();

      // Her mesaj için readBy listesine kullanıcıyı ekle
      for (var doc in messagesSnapshot.docs) {
        Map<String, dynamic> messageData = doc.data() as Map<String, dynamic>;
        List<dynamic> readBy = messageData['readBy'] ?? [];
        
        // Eğer kullanıcı zaten readBy listesinde değilse ekle
        if (!readBy.contains(currentUserId)) {
          readBy.add(currentUserId);
          batch.update(doc.reference, {'readBy': readBy});
        }
      }

      // Batch işlemi çalıştır
      await batch.commit();
      
      print('DEBUG: Chat $chatId\'deki tüm mesajlar okundu olarak işaretlendi');
    } catch (e) {
      print('DEBUG: Mesajları okundu olarak işaretleme hatası: $e');
    }
  }

  /// Yeni gelen mesajları okundu olarak işaretle
  static Future<void> markNewMessagesAsRead(List<QueryDocumentSnapshot> messages, String currentUserId) async {
    try {
      // Batch işlem başlat
      WriteBatch batch = _firestore.batch();
      bool hasUpdates = false;

      // Her mesaj için readBy listesine kullanıcıyı ekle
      for (var doc in messages) {
        Map<String, dynamic> messageData = doc.data() as Map<String, dynamic>;
        List<dynamic> readBy = messageData['readBy'] ?? [];
        
        // Eğer kullanıcı zaten readBy listesinde değilse ekle
        if (!readBy.contains(currentUserId)) {
          readBy.add(currentUserId);
          batch.update(doc.reference, {'readBy': readBy});
          hasUpdates = true;
        }
      }

      // Eğer güncelleme varsa batch işlemi çalıştır
      if (hasUpdates) {
        await batch.commit();
        print('DEBUG: Yeni mesajlar okundu olarak işaretlendi');
      }
    } catch (e) {
      print('DEBUG: Yeni mesajları okundu olarak işaretleme hatası: $e');
    }
  }

  /// Mesaj gönderirken readBy alanını başlat
  static Map<String, dynamic> createMessageData({
    required String text,
    required String senderId,
    required String senderName,
  }) {
    return {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [senderId], // Gönderen kullanıcı otomatik olarak okundu sayılır
    };
  }

  /// Chat'lerin real-time unread count stream'i
  static Stream<int> getUnreadCountStream(String chatId, String currentUserId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
      int unreadCount = 0;
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> messageData = doc.data() as Map<String, dynamic>;
        String senderId = messageData['senderId'] ?? '';
        List<dynamic> readBy = messageData['readBy'] ?? [];
        
        // Eğer mesaj başka kullanıcıdan geliyorsa ve kullanıcı readBy listesinde yoksa
        if (senderId != currentUserId && !readBy.contains(currentUserId)) {
          unreadCount++;
        }
      }
      
      return unreadCount;
    });
  }

  /// Tüm chat'lerin genel unread durumu stream'i
  static Stream<bool> getAnyUnreadStream(String currentUserId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return false;

      // Paralel olarak tüm chat'lerin son mesajlarını kontrol et
      List<Future<bool>> chatChecks = [];
      
      for (var doc in snapshot.docs) {
        String chatId = doc.id;
        chatChecks.add(hasUnreadMessages(chatId, currentUserId));
      }

      // Tüm chat'leri paralel olarak kontrol et
      List<bool> results = await Future.wait(chatChecks);
      
      // Herhangi bir chat'te okunmamış mesaj var mı kontrol et
      return results.any((hasUnreadInChat) => hasUnreadInChat);
    });
  }
}
