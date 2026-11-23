
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BoardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('messages');

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages() {
    return _messages
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> createMessage({
    required String text,
    required String authorName,
    required String requestId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('User is not signed in');
    }

    final content = text.trim();

    if (content.isEmpty || content.length > 1000) {
      throw ArgumentError('Message must contain 1-1000 characters');
    }

    final ref = _messages.doc(requestId);

    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);

      if (existing.exists) return;

      transaction.set(ref, {
        'text': content,
        'authorUid': user.uid,
        'authorName': authorName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        'schemaVersion': 2,
      });
    });

    return ref.id;
  }

  Future<void> updateMessage(
    String messageId,
    String newText,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('User is not signed in');
    }

    final content = newText.trim();

    if (content.isEmpty || content.length > 1000) {
      throw ArgumentError('Message must contain 1-1000 characters');
    }

    await _messages.doc(messageId).update({
      'text': content,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String messageId) async {
    if (_auth.currentUser == null) {
      throw StateError('User is not signed in');
    }

    await _messages.doc(messageId).delete();
  }
}
