// Firestore rules (infra/firestore.rules) against the emulator. Run: npm test (in infra/rules-test).
import { readFileSync } from "node:fs";
import { after, before, beforeEach, test } from "node:test";
import { assertFails, assertSucceeds, initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, collectionGroup, deleteField, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from "firebase/firestore";

let env;
const SAVE = "spaces/h_home/saves/s1";

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-reelbrain",
    firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") },
  });
});
after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  // What the backend writes (bypassing rules).
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/me"), { name: "Me", spaces: { me: "p_me", home: "h_home" } });
    await setDoc(doc(db, "spaces/h_home"), { name: "Home", type: "household", members: ["me", "wife"] });
    await setDoc(doc(db, "spaces/p_me"), { name: "Me", type: "personal", members: ["me"] });
    await setDoc(doc(db, SAVE), { source_url: "https://x", status: "ready", note: null, summary: "AI text" });
    await setDoc(doc(db, `${SAVE}/items/0-recipe`), { section: "recipe", user_state: null, data: {}, space_id: "h_home" });
    await setDoc(doc(db, "spaces/p_me/saves/s9/items/0-tools"), { section: "tools", user_state: null, space_id: "p_me" });
    await setDoc(doc(db, "spaces/h_home/lists/l1"), { name: "Date night", item_refs: [] });
    await setDoc(doc(db, "invites/abcd2345"), { space_id: "h_home", created_by: "me" });
    await setDoc(doc(db, "config/backend"), { url: "https://x.trycloudflare.com" });
    // V5: a wall post the backend wrote, with a comment.
    await setDoc(doc(db, "spaces/h_home/posts/p1"), {
      kind: "plan", by: "wife", title: "Al-Muizz Street", rsvp: { wife: "going", me: "done" }, likes: {}, comment_count: 1,
    });
    await setDoc(doc(db, "spaces/h_home/posts/p1/comments/c1"), { by: "wife", text: "Friday?" });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

test("members read their spaces, saves and items; others read nothing", async () => {
  await assertSucceeds(getDoc(doc(as("wife"), "spaces/h_home")));
  await assertSucceeds(getDoc(doc(as("wife"), SAVE)));
  await assertSucceeds(getDoc(doc(as("wife"), `${SAVE}/items/0-recipe`)));
  await assertFails(getDoc(doc(as("wife"), "spaces/p_me")));
  await assertFails(getDoc(doc(as("stranger"), "spaces/h_home")));
  await assertFails(getDoc(doc(as("stranger"), SAVE)));
  await assertFails(getDoc(doc(anon(), SAVE)));
});

test("a user reads only their own user doc; invites and the save index are backend-only", async () => {
  await assertSucceeds(getDoc(doc(as("me"), "users/me")));
  await assertFails(getDoc(doc(as("wife"), "users/me")));
  await assertFails(getDoc(doc(as("me"), "invites/abcd2345")));
  await assertFails(getDoc(doc(as("me"), "save_index/s1")));
});

test("nobody can add themselves to a space or create one", async () => {
  await assertFails(updateDoc(doc(as("stranger"), "spaces/h_home"), { members: ["me", "wife", "stranger"] }));
  await assertFails(updateDoc(doc(as("wife"), "spaces/h_home"), { members: ["me", "wife", "friend"] }));
  await assertFails(setDoc(doc(as("stranger"), "spaces/mine"), { members: ["stranger"], type: "household" }));
  await assertFails(setDoc(doc(as("me"), "users/me"), { spaces: { home: "h_other" } }));
});

test("members may change only the note on a save", async () => {
  await assertSucceeds(updateDoc(doc(as("wife"), SAVE), { note: "try this weekend" }));
  await assertFails(updateDoc(doc(as("wife"), SAVE), { summary: "edited AI text" }));
  await assertFails(updateDoc(doc(as("wife"), SAVE), { note: "x".repeat(2001) }));
  await assertFails(updateDoc(doc(as("stranger"), SAVE), { note: "hi" }));
  await assertFails(setDoc(doc(as("me"), "spaces/h_home/saves/s2"), { source_url: "https://y" }));
});

test("members may change only user_state on an item, to a known value", async () => {
  await assertSucceeds(updateDoc(doc(as("me"), `${SAVE}/items/0-recipe`), { user_state: "cooked" }));
  await assertSucceeds(updateDoc(doc(as("me"), `${SAVE}/items/0-recipe`), { user_state: "not_useful" }));
  await assertFails(updateDoc(doc(as("me"), `${SAVE}/items/0-recipe`), { user_state: "eaten" }));
  await assertFails(updateDoc(doc(as("me"), `${SAVE}/items/0-recipe`), { data: { title: "x" } }));
});

test("Recall: members may snooze an item or archive it", async () => {
  const item = doc(as("wife"), `${SAVE}/items/0-recipe`);
  await assertSucceeds(updateDoc(item, { recall_after: 1793000000 }));
  await assertSucceeds(updateDoc(item, { user_state: "archived", recall_after: null }));
  await assertFails(updateDoc(item, { recall_after: "tomorrow" }));
  await assertFails(updateDoc(doc(as("stranger"), `${SAVE}/items/0-recipe`), { recall_after: 1 }));
});

test("members may change only list membership", async () => {
  await assertSucceeds(updateDoc(doc(as("wife"), "spaces/h_home/lists/l1"), { item_refs: ["s1/0-recipe"] }));
  await assertFails(updateDoc(doc(as("wife"), "spaces/h_home/lists/l1"), { name: "renamed" }));
  await assertSucceeds(updateDoc(doc(as("wife"), "spaces/h_home/lists/l1"), { overrides: { "s1/0-workout#0": { duration_s: 45 } } }));
  await assertFails(updateDoc(doc(as("wife"), "spaces/h_home/lists/l1"), { overrides: "nope" }));
  await assertFails(updateDoc(doc(as("stranger"), "spaces/h_home/lists/l1"), { item_refs: ["x"] }));
});

test("items across saves: only a query filtered to a space you're in", async () => {
  const items = (db, space) => getDocs(query(collectionGroup(db, "items"), where("space_id", "==", space)));
  await assertSucceeds(items(as("wife"), "h_home"));
  await assertSucceeds(items(as("me"), "p_me"));
  await assertFails(items(as("wife"), "p_me"));
  await assertFails(items(as("stranger"), "h_home"));
  await assertFails(getDocs(collectionGroup(as("me"), "items")));
});

test("signed-in users read the backend address; nobody writes it", async () => {
  await assertSucceeds(getDoc(doc(as("stranger"), "config/backend")));
  await assertFails(getDoc(doc(anon(), "config/backend")));
  await assertFails(setDoc(doc(as("me"), "config/backend"), { url: "https://evil.example" }));
});

test("V5: members stamp the new states, record when they finished and their own seen time", async () => {
  const item = doc(as("me"), `${SAVE}/items/0-recipe`);
  for (const state of ["in_progress", "compared", "purchased"]) {
    await assertSucceeds(updateDoc(item, { user_state: state }));
  }
  await assertSucceeds(updateDoc(item, { user_state: "cooked", done_at: 1793000000 }));
  await assertSucceeds(updateDoc(item, { user_state: "to_try", done_at: null }));
  await assertFails(updateDoc(item, { done_at: "yesterday" }));
  await assertSucceeds(updateDoc(item, { "seen.me": 1793000000 }));
  await assertSucceeds(updateDoc(doc(as("wife"), `${SAVE}/items/0-recipe`), { "seen.wife": 1793000100 }));
  // Only your own entry, and only a time.
  await assertFails(updateDoc(item, { "seen.wife": 1 }));
  await assertFails(updateDoc(item, { "seen.me": "now" }));
  await assertFails(updateDoc(doc(as("stranger"), `${SAVE}/items/0-recipe`), { "seen.stranger": 1 }));
});

test("V5: members read the wall and its comments; others read nothing", async () => {
  await assertSucceeds(getDoc(doc(as("wife"), "spaces/h_home/posts/p1")));
  await assertSucceeds(getDocs(collection(as("me"), "spaces/h_home/posts/p1/comments")));
  await assertFails(getDoc(doc(as("stranger"), "spaces/h_home/posts/p1")));
  await assertFails(getDocs(collection(as("stranger"), "spaces/h_home/posts/p1/comments")));
});

test("V5: members RSVP and like for themselves only; posts and comments are the backend's", async () => {
  const post = doc(as("me"), "spaces/h_home/posts/p1");
  await assertSucceeds(updateDoc(post, { "likes.me": true }));
  await assertSucceeds(updateDoc(post, { "likes.me": deleteField() }));
  // Liking keeps working after the backend marked my challenge done.
  await assertSucceeds(updateDoc(post, { "likes.me": true }));
  await assertSucceeds(updateDoc(doc(as("wife"), "spaces/h_home/posts/p1"), { "rsvp.wife": "maybe" }));
  await assertSucceeds(updateDoc(doc(as("wife"), "spaces/h_home/posts/p1"), { "rsvp.wife": deleteField() }));
  await assertFails(updateDoc(post, { "rsvp.wife": "no" })); // someone else's answer
  // Proof is the backend's to mark: nobody sets themselves "done".
  await assertFails(updateDoc(doc(as("wife"), "spaces/h_home/posts/p1"), { "rsvp.wife": "done" }));
  await assertFails(updateDoc(post, { "likes.me": 5 }));
  await assertFails(updateDoc(post, { title: "edited" }));
  await assertFails(updateDoc(post, { comment_count: 99 }));
  await assertFails(updateDoc(doc(as("stranger"), "spaces/h_home/posts/p1"), { "likes.stranger": true }));
  await assertFails(setDoc(doc(as("me"), "spaces/h_home/posts/p2"), { kind: "share", by: "me" }));
  await assertFails(setDoc(doc(as("me"), "spaces/h_home/posts/p1/comments/c2"), { by: "me", text: "hi" }));
});
