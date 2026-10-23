// Firestore rules (infra/firestore.rules) against the emulator. Run: npm test (in infra/rules-test).
import { readFileSync } from "node:fs";
import { after, before, beforeEach, test } from "node:test";
import { assertFails, assertSucceeds, initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { collectionGroup, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from "firebase/firestore";

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
  await assertFails(updateDoc(doc(as("me"), `${SAVE}/items/0-recipe`), { user_state: "eaten" }));
  await assertFails(updateDoc(doc(as("me"), `${SAVE}/items/0-recipe`), { data: { title: "x" } }));
});

test("members may change only list membership", async () => {
  await assertSucceeds(updateDoc(doc(as("wife"), "spaces/h_home/lists/l1"), { item_refs: ["s1/0-recipe"] }));
  await assertFails(updateDoc(doc(as("wife"), "spaces/h_home/lists/l1"), { name: "renamed" }));
});

test("items across saves: only a query filtered to a space you're in", async () => {
  const items = (db, space) => getDocs(query(collectionGroup(db, "items"), where("space_id", "==", space)));
  await assertSucceeds(items(as("wife"), "h_home"));
  await assertSucceeds(items(as("me"), "p_me"));
  await assertFails(items(as("wife"), "p_me"));
  await assertFails(items(as("stranger"), "h_home"));
  await assertFails(getDocs(collectionGroup(as("me"), "items")));
});
