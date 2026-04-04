import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 CONFIG FIREBASE (substitua pelos seus dados)
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "Nc2VcpVSScdgUM3DXfhqawGW8giuVxRMgWlNDn8y", // Seu API Key
      authDomain: "tabuapp-4325a.firebaseapp.com",
      databaseURL: "https://tabuapp-4325a-default-rtdb.firebaseio.com",
      projectId: "tabuapp-4325a",
      storageBucket: "tabuapp-4325a.firebasestorage.app",
      messagingSenderId: "123456789",
      appId: "1:123456789:android:xxxxxxxxxxxxxxxx",
    ),
  );

  print('🔥 Firebase conectado!');
  await fixStilesChat();
  print('🎉 FINALIZADO! Teste no app como STILES');
}

Future<void> fixStilesChat() async {
  final db = FirebaseDatabase.instance.ref();
  final stilesUid = '6mrxsCc7FDSNwnRY7T165FSC4Jq2';
  final natalliaUid = 'tOjCDjgUhpYS5OZVTOp5eTYXV3u1';
  final chatId = '${stilesUid}_${natalliaUid}';

  print('🔧 Fixando chat: $chatId');

  try {
    // 1. Aceitar chat (2 lados)
    print('✅ 1/5 Aceitando chat...');
    await db.child('UserChatRequests/$stilesUid/$chatId').set('accepted');
    await db.child('UserChatRequests/$natalliaUid/$chatId').set('accepted');

    // 2. UserChats (2 lados)
    print('✅ 2/5 Criando UserChats...');
    await db.child('UserChats/$stilesUid/$chatId').set(true);
    await db.child('UserChats/$natalliaUid/$chatId').set(true);

    // 3. Verificar/criar Chat
    print('✅ 3/5 Verificando Chat...');
    final chatSnap = await db.child('Chats/$chatId').get();
    if (!chatSnap.exists) {
      print('✅ 4/5 CRIANDO Chat...');
      await db.child('Chats/$chatId').set({
        'metadata': {
          'created_at': ServerValue.timestamp,
          'last_message': 'Oi Natallia! Tudo bem? 😊',
          'last_sender': stilesUid,
          'last_timestamp': ServerValue.timestamp,
        },
        'participants': {
          stilesUid: {'last_seen': ServerValue.timestamp, 'status': 'offline'},
          natalliaUid: {
            'last_seen': ServerValue.timestamp,
            'status': 'offline'
          },
        },
        'unreadCount': {
          stilesUid: 0,
          natalliaUid: 5, // 5 mensagens não lidas
        },
        'user1': stilesUid,
        'user2': natalliaUid,
      });
      print('✅ 5/5 Chat CRIADO com 5 não lidos!');
    } else {
      print('✅ 4/5 Chat já existe!');
      // Atualizar unread
      await db.child('Chats/$chatId/unreadCount/$natalliaUid').set(5);
      print('✅ 5/5 Unread atualizado!');
    }
  } catch (e) {
    print('❌ ERRO: $e');
  }
}
