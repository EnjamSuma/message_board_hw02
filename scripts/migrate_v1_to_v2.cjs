
const { initializeTestEnvironment } =
  require('@firebase/rules-unit-testing');

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: 'message-board-hw02',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
    },
  });

  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const messages = db.collection('messages');

      // Seed a realistic legacy v1 message.
      const legacyRef = messages.doc('legacy-migration-demo');

      await legacyRef.set({
        authorUid: 'legacy-test-user',
        authorName: 'Legacy Test User',
        text: 'Legacy schema migration test',
        createdAt: new Date('2026-11-20T12:00:00Z'),
        schemaVersion: 1,
      });

      console.log('BEFORE MIGRATION:');
      console.log((await legacyRef.get()).data());

      // Migrate all version 1 messages to version 2.
      const snapshot = await messages.get();
      let migrated = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();

        if (data.schemaVersion !== 1) {
          continue;
        }

        await doc.ref.update({
          schemaVersion: 2,
          editedAt: null,
        });

        migrated++;
      }

      console.log(`Migrated ${migrated} document(s).`);

      console.log('AFTER MIGRATION:');
      console.log((await legacyRef.get()).data());
    });
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
