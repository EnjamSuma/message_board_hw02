
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  Timestamp,
} = require('firebase/firestore');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'message-board-hw02',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync('firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();

  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'messages', 'message1'),
      {
        text: 'Original message',
        authorUid: 'userA',
        authorName: 'User A',
        createdAt: Timestamp.now(),
        editedAt: null,
        schemaVersion: 2,
      }
    );
  });
});

after(async () => {
  if (env) await env.cleanup();
});

test('User A can read a message', async () => {
  const db = env.authenticatedContext('userA').firestore();
  await assertSucceeds(getDoc(doc(db, 'messages', 'message1')));
});

test('User B can read a message', async () => {
  const db = env.authenticatedContext('userB').firestore();
  await assertSucceeds(getDoc(doc(db, 'messages', 'message1')));
});

test('Signed-out user cannot read messages', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'messages', 'message1')));
});

test('User B cannot edit User A message', async () => {
  const db = env.authenticatedContext('userB').firestore();
  await assertFails(
    updateDoc(doc(db, 'messages', 'message1'), {
      text: 'Unauthorized edit',
    })
  );
});

test('User B cannot delete User A message', async () => {
  const db = env.authenticatedContext('userB').firestore();
  await assertFails(deleteDoc(doc(db, 'messages', 'message1')));
});

test('User A can delete their own message', async () => {
  const db = env.authenticatedContext('userA').firestore();
  await assertSucceeds(deleteDoc(doc(db, 'messages', 'message1')));
});

test('Invalid message schema is rejected', async () => {
  const db = env.authenticatedContext('userA').firestore();
  await assertFails(
    setDoc(doc(db, 'messages', 'invalid'), {
      text: '',
      authorUid: 'userA',
      authorName: 'User A',
      createdAt: Timestamp.now(),
      editedAt: null,
      schemaVersion: 2,
    })
  );
});

test('User cannot spoof another author UID', async () => {
  const db = env.authenticatedContext('userB').firestore();
  await assertFails(
    setDoc(doc(db, 'messages', 'spoofed'), {
      text: 'Spoofed message',
      authorUid: 'userA',
      authorName: 'User A',
      createdAt: Timestamp.now(),
      editedAt: null,
      schemaVersion: 2,
    })
  );
});
