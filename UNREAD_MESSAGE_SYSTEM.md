# Firebase Firestore Unread Message Tracking Sistemi

Bu doküman, Firebase Firestore kullanan chat uygulamanızda okunmamış mesajları takip eden kapsamlı bir sistemin nasıl çalıştığını açıklar.

## 🏗️ Veri Yapısı

### Firestore Koleksiyon Yapısı

```
chats/{chatId}
├── participants: [userId1, userId2]
├── participantNames: [name1, name2]
├── lastMessage: string
├── lastMessageTime: timestamp
├── createdAt: timestamp
└── messages/{messageId}
    ├── text: string
    ├── senderId: string
    ├── senderName: string
    ├── timestamp: timestamp
    └── readBy: [userId1, userId2] // YENİ ALAN
```

### readBy Alanı

Her mesaj dokümanında `readBy` adında bir array alanı bulunur. Bu alan:
- Mesajı kimin gördüğünü (okuduğunu) saklar
- Yeni mesaj gönderildiğinde, gönderen kullanıcı otomatik olarak bu listeye eklenir
- Kullanıcı bir sohbeti açtığında, o sohbet içindeki tüm mesajlar için kendi userId'si `readBy` array'ine eklenir

## 🔧 Sistem Bileşenleri

### 1. UnreadMessageService (lib/unread_message_service.dart)

Merkezi servis sınıfı. Tüm unread message işlemlerini yönetir:

```dart
// Bir chat'teki okunmamış mesaj sayısını al
UnreadMessageService.getUnreadMessageCount(chatId, currentUserId)

// Kullanıcının tüm chat'lerinde okunmamış mesaj var mı kontrol et
UnreadMessageService.hasAnyUnreadMessages(currentUserId)

// Bir chat'teki tüm mesajları okundu olarak işaretle
UnreadMessageService.markChatAsRead(chatId, currentUserId)

// Real-time unread count stream'i
UnreadMessageService.getUnreadCountStream(chatId, currentUserId)

// Genel unread durumu stream'i
UnreadMessageService.getAnyUnreadStream(currentUserId)
```

### 2. HomePage (lib/home_page.dart)

Ana sayfada mesaj ikonunda kırmızı nokta gösterir:

- **Real-time tracking**: `UnreadMessageService.getAnyUnreadStream()` kullanır
- **Optimized performance**: Paralel query'ler ile hızlı kontrol
- **Automatic updates**: StreamBuilder ile otomatik güncelleme

### 3. MessagePage (lib/message_page.dart)

Konuşma listesinde unread bildirimleri gösterir:

- **Per-chat unread count**: Her chat için ayrı unread sayısı
- **Real-time updates**: StreamBuilder ile anlık güncelleme
- **Visual indicators**: Kırmızı badge ile unread sayısı gösterimi

### 4. ChatPage (lib/chat_page.dart)

Mesaj okundu işaretleme sistemi:

- **Auto-mark as read**: Chat açıldığında tüm mesajlar otomatik okundu işaretlenir
- **New message tracking**: Yeni mesajlar geldiğinde otomatik okundu işaretlenir
- **Message creation**: Yeni mesaj gönderirken `readBy` alanı otomatik başlatılır

## 🚀 Özellikler

### ✅ Gerçekleştirilen Özellikler

1. **Homepage'de kırmızı nokta**: Okunmamış mesaj varsa mesaj ikonunda kırmızı nokta
2. **MessagePage'de bildirim**: Her sohbet için unread mesaj sayısı gösterimi
3. **Otomatik okundu işaretleme**: Kullanıcı sohbete girdiğinde tüm mesajlar okundu sayılır
4. **Real-time updates**: StreamBuilder ile anlık güncellemeler
5. **Optimized performance**: Paralel query'ler ve efficient data structures
6. **Her iki taraf için çalışma**: Hem gönderen hem alıcı için doğru tracking

### 🔄 Sistem Akışı

1. **Mesaj Gönderme**:
   ```dart
   // Yeni mesaj oluşturulurken readBy alanı başlatılır
   UnreadMessageService.createMessageData(
     text: messageText,
     senderId: currentUserId,
     senderName: senderName,
   )
   ```

2. **Chat Açma**:
   ```dart
   // Chat açıldığında tüm mesajlar okundu işaretlenir
   UnreadMessageService.markChatAsRead(chatId, currentUserId)
   ```

3. **Real-time Tracking**:
   ```dart
   // HomePage'de genel unread durumu
   UnreadMessageService.getAnyUnreadStream(currentUserId)
   
   // MessagePage'de per-chat unread count
   UnreadMessageService.getUnreadCountStream(chatId, currentUserId)
   ```

## 📊 Performans Optimizasyonları

1. **Paralel Query'ler**: Tüm chat'ler paralel olarak kontrol edilir
2. **Limit Queries**: Sadece son 10 mesaj kontrol edilir (performans için)
3. **StreamBuilder**: Real-time updates için efficient listeners
4. **Batch Operations**: Mesaj okundu işaretleme için batch updates
5. **Caching**: SharedPreferences ile local caching

## 🛠️ Kullanım

### Yeni Mesaj Gönderme

```dart
// ChatPage'de mesaj gönderme
await FirebaseFirestore.instance
    .collection('chats')
    .doc(chatId)
    .collection('messages')
    .add(UnreadMessageService.createMessageData(
      text: messageText,
      senderId: currentUserId,
      senderName: senderName,
    ));
```

### Chat Açma

```dart
// ChatPage'de chat açıldığında
await UnreadMessageService.markChatAsRead(chatId, currentUserId);
```

### Real-time Unread Tracking

```dart
// HomePage'de genel unread durumu
StreamBuilder<bool>(
  stream: UnreadMessageService.getAnyUnreadStream(currentUserId),
  builder: (context, snapshot) {
    final hasUnread = snapshot.data ?? false;
    return hasUnread ? RedDotWidget() : SizedBox.shrink();
  },
)

// MessagePage'de per-chat unread count
StreamBuilder<int>(
  stream: UnreadMessageService.getUnreadCountStream(chatId, currentUserId),
  builder: (context, snapshot) {
    final unreadCount = snapshot.data ?? 0;
    return unreadCount > 0 ? UnreadBadge(count: unreadCount) : SizedBox.shrink();
  },
)
```

## 🔍 Debug ve Test

Sistem debug log'ları ile izlenebilir:

```
DEBUG: Unread messages listener başlatılıyor...
DEBUG: Unread messages durumu: true
DEBUG: Chat abc123'deki tüm mesajlar okundu olarak işaretlendi
DEBUG: Yeni mesajlar okundu olarak işaretlendi
```

## ⚠️ Önemli Notlar

1. **Firestore Rules**: `readBy` alanı için uygun security rules gerekli
2. **Data Migration**: Mevcut mesajlar için `readBy` alanı eklenmeli
3. **Performance**: Çok fazla mesaj olan chat'lerde limit kullanılmalı
4. **Error Handling**: Network hatalarında graceful fallback

## 🎯 Sonuç

Bu sistem, Firebase Firestore kullanan chat uygulamalarında güvenilir ve performanslı bir unread message tracking çözümü sunar. Real-time updates, optimized queries ve user-friendly interface ile kullanıcı deneyimini artırır.
