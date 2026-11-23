
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/main.dart';

void main() {
  testWidgets('MessageBoardApp can be created', (tester) async {
    expect(const MessageBoardApp(), isA<Widget>());
  });
}
