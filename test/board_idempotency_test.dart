
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:message_board/firebase_options.dart';
import 'package:message_board/services/board_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Same request ID creates only one message', () async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull);

    final service = BoardService();

    final requestId =
        FirebaseFirestore.instance.collection('messages').doc().id;

    await service.createMessage(
      text: 'Idempotency test',
      authorName: 'Test User',
      requestId: requestId,
    );

    await service.createMessage(
      text: 'Idempotency test',
      authorName: 'Test User',
      requestId: requestId,
    );

    final snapshot = await FirebaseFirestore.instance
        .collection('messages')
        .doc(requestId)
        .get();

    expect(snapshot.exists, true);
    expect(snapshot.data()?['text'], 'Idempotency test');
  });
}
