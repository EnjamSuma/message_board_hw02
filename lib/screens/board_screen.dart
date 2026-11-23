
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/board_services.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final BoardService _boardService = BoardService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController =
      TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
      _messagesStream;

  String? _pendingRequestId;
  bool _posting = false;
  String? _postError;

  @override
  void initState() {
    super.initState();
    _messagesStream = _boardService.getMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<String> _getAuthorName(User user) async {
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = profile.data();

    final name = [
      data?['firstName'],
      data?['lastName'],
    ].whereType<String>().join(' ').trim();

    return name.isNotEmpty
        ? name
        : (user.displayName ?? user.email ?? 'User');
  }

  Future<void> _postMessage() async {
    if (_posting) return;

    final text = _messageController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _postError = 'Please enter a message.';
      });
      return;
    }

    final user = _authService.currentUser;
    if (user == null) return;

    // Preserve the ID when retrying the same message.
    final requestId = _pendingRequestId ?? FirebaseFirestore
        .instance.collection('messages').doc().id;

    _pendingRequestId = requestId;

    setState(() {
      _posting = true;
      _postError = null;
    });

    try {
      final authorName = await _getAuthorName(user);

      await _boardService.createMessage(
        text: text,
        authorName: authorName,
        requestId: requestId,
      );

      if (!mounted) return;

      _messageController.clear();
      _pendingRequestId = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message posted successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _postError = 'Unable to confirm post: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _posting = false);
      }
    }
  }

  Future<void> _editMessage(
    String messageId,
    String currentText,
  ) async {
    final controller = TextEditingController(
      text: currentText,
    );

    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                controller.text.trim(),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    //controller.dispose();

    if (newText == null ||
        newText.isEmpty ||
        newText == currentText) {
      return;
    }

    try {
      await _boardService.updateMessage(
        messageId,
        newText,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message updated'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Edit failed: $e');
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Message?'),
          content: const Text(
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _boardService.deleteMessage(messageId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Delete failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildMessageCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final schemaVersion = data['schemaVersion'] is int
        ? data['schemaVersion'] as int
        : 1;

    final isLegacyMessage = schemaVersion == 1;
    final user = _authService.currentUser;

    final isOwner = user != null &&
        data['authorUid'] == user.uid;

    final text = data['text'] as String? ?? '';
    final author =
        data['authorName'] as String? ?? 'Unknown';

    final createdAt = data['createdAt'];

    final Timestamp? editedAt =
        data['editedAt'] is Timestamp
            ? data['editedAt'] as Timestamp
            : null;

    final createdLabel = createdAt is Timestamp
        ? createdAt.toDate().toLocal().toString()
        : 'Sending...';

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 6,
        horizontal: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLegacyMessage)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Legacy message (v1)',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ),
                const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    author,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editMessage(doc.id, text);
                      } else if (value == 'delete') {
                        _deleteMessage(doc.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              createdLabel,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (editedAt != null)
              const Text(
                'Edited',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Board'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await _authService.logout();
              } catch (e) {
                if (mounted) {
                  _showError('Logout failed: $e');
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load messages:\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.\n'
                      'Be the first to post!',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageCard(
                      messages[index],
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_postError != null)
                    Text(
                      _postError!,
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLines: 3,
                          minLines: 1,
                          maxLength: 1000,
                          onChanged: (_) {
                            // Editing the draft starts a new
                            // logical post request.
                            _pendingRequestId = null;
                          },
                          decoration: const InputDecoration(
                            hintText: 'Write a message...',
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Post message',
                        onPressed:
                            _posting ? null : _postMessage,
                        icon: _posting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
