// Firestore rules tests for guardian live sharing (shared_trips) and the
// owner-only trips collection. Run from rules-test/: npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const TOKEN = 'a'.repeat(32) + '0123456789abcdef'.repeat(2); // 64 hex chars
const mirror = (overrides = {}) => ({
  userId: 'alice',
  currentLocation: { lat: 6.92, lng: 79.86 },
  destination: { lat: 6.93, lng: 79.87 },
  status: 'active',
  alerted: false,
  updatedAt: serverTimestamp(),
  ...overrides,
});

let env;
const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const guest = () => env.unauthenticatedContext().firestore();

async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-aegis',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => env?.cleanup());
beforeEach(async () => env.clearFirestore());

describe('shared_trips: create', () => {
  test('owner creates a mirror with a 64-hex token', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'shared_trips', TOKEN), mirror()));
  });
  test('owner creates trip and mirror in one batch (createTrip)', async () => {
    const db = alice();
    const batch = writeBatch(db);
    batch.set(doc(db, 'trips', 't1'), { tripId: 't1', userId: 'alice', status: 'active', shareToken: TOKEN });
    batch.set(doc(db, 'shared_trips', TOKEN), mirror());
    await assertSucceeds(batch.commit());
  });
  test('signed-out user cannot create', async () => {
    await assertFails(setDoc(doc(guest(), 'shared_trips', TOKEN), mirror()));
  });
  test('cannot create a mirror for someone else', async () => {
    await assertFails(setDoc(doc(bob(), 'shared_trips', TOKEN), mirror()));
  });
  test('short or non-hex token IDs are rejected', async () => {
    for (const id of ['short', TOKEN.slice(1), TOKEN.toUpperCase(), '00000000-0000-4000-8000-000000000000']) {
      await assertFails(setDoc(doc(alice(), 'shared_trips', id), mirror()));
    }
  });
  test('extra fields and non-active start are rejected', async () => {
    await assertFails(setDoc(doc(alice(), 'shared_trips', TOKEN), mirror({ tripId: 't1' })));
    await assertFails(setDoc(doc(alice(), 'shared_trips', TOKEN), mirror({ bloodType: 'O+' })));
    await assertFails(setDoc(doc(alice(), 'shared_trips', TOKEN), mirror({ status: 'ended' })));
  });
});

describe('shared_trips: read', () => {
  test('anyone with the token can get an active mirror, even signed out', async () => {
    await seed(`shared_trips/${TOKEN}`, mirror());
    await assertSucceeds(getDoc(doc(guest(), 'shared_trips', TOKEN)));
    await assertSucceeds(getDoc(doc(bob(), 'shared_trips', TOKEN)));
  });
  test('alerted trips stay readable', async () => {
    await seed(`shared_trips/${TOKEN}`, mirror({ alerted: true }));
    await assertSucceeds(getDoc(doc(guest(), 'shared_trips', TOKEN)));
  });
  test('ended mirrors cannot be read', async () => {
    await seed(`shared_trips/${TOKEN}`, mirror({ status: 'ended' }));
    await assertFails(getDoc(doc(guest(), 'shared_trips', TOKEN)));
    await assertFails(getDoc(doc(alice(), 'shared_trips', TOKEN)));
  });
  test('listing is denied for everyone', async () => {
    await seed(`shared_trips/${TOKEN}`, mirror());
    await assertFails(getDocs(collection(guest(), 'shared_trips')));
    await assertFails(getDocs(collection(bob(), 'shared_trips')));
    await assertFails(getDocs(collection(alice(), 'shared_trips')));
  });
});

describe('shared_trips: update and delete', () => {
  beforeEach(async () => seed(`shared_trips/${TOKEN}`, mirror()));

  test('owner updates location, alerted flag and ends the trip', async () => {
    const ref = doc(alice(), 'shared_trips', TOKEN);
    await assertSucceeds(updateDoc(ref, { currentLocation: { lat: 6.925, lng: 79.865 }, updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { alerted: true, updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { status: 'ended', updatedAt: serverTimestamp() }));
  });
  test('another user or a guest cannot update', async () => {
    await assertFails(updateDoc(doc(bob(), 'shared_trips', TOKEN), { currentLocation: { lat: 0, lng: 0 } }));
    await assertFails(updateDoc(doc(guest(), 'shared_trips', TOKEN), { status: 'ended' }));
  });
  test('owner cannot hand over the mirror, add fields or set a bad status', async () => {
    const ref = doc(alice(), 'shared_trips', TOKEN);
    await assertFails(updateDoc(ref, { userId: 'bob' }));
    await assertFails(updateDoc(ref, { emergencyNote: 'x' }));
    await assertFails(updateDoc(ref, { status: 'alerted' }));
  });
  test('only the owner can delete', async () => {
    await assertFails(deleteDoc(doc(bob(), 'shared_trips', TOKEN)));
    await assertSucceeds(deleteDoc(doc(alice(), 'shared_trips', TOKEN)));
  });
});

describe('trips: unchanged owner-only access', () => {
  beforeEach(async () => seed('trips/t1', { tripId: 't1', userId: 'alice', status: 'active', shareToken: TOKEN }));

  test('owner can read; other users and guests cannot, even with the token', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'trips', 't1')));
    await assertFails(getDoc(doc(bob(), 'trips', 't1')));
    await assertFails(getDoc(doc(guest(), 'trips', 't1')));
  });
  test('owner can update location; others cannot', async () => {
    await assertSucceeds(updateDoc(doc(alice(), 'trips', 't1'), { currentLocation: { lat: 1, lng: 2 } }));
    await assertFails(updateDoc(doc(bob(), 'trips', 't1'), { currentLocation: { lat: 1, lng: 2 } }));
  });
});
