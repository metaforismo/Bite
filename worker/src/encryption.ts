/**
 * Per-user envelope encryption using Worker-native WebCrypto.
 *
 * Strategy:
 *   1. The worker holds a single 32-byte master key in `env.FILE_ENCRYPTION_MASTER_KEY`
 *      (hex-encoded). NEVER commit this — set via `wrangler secret put`.
 *   2. For each user we derive an AES-256 key via HKDF-SHA256 with `info`
 *      bound to the user's `firebase_uid`, so the same plaintext encrypted
 *      under different users yields different ciphertexts, and a leaked user
 *      key cannot decrypt other users' data.
 *   3. AES-GCM with a fresh random 12-byte IV per encryption. The output
 *      is `iv || ciphertext_with_tag` (single byte stream).
 *
 * Worker runtime: we use `crypto.subtle` only. No Node `crypto` module.
 */

const ALG = { name: "AES-GCM", length: 256 } as const;
const IV_BYTES = 12;
const KEY_BYTES = 32;

function hexToBytes(hex: string): Uint8Array {
  const clean = hex.startsWith("0x") ? hex.slice(2) : hex;
  if (clean.length % 2 !== 0) {
    throw new Error("hex string has odd length");
  }
  const out = new Uint8Array(clean.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function utf8(s: string): Uint8Array {
  return new TextEncoder().encode(s);
}

function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const out = new Uint8Array(a.length + b.length);
  out.set(a, 0);
  out.set(b, a.length);
  return out;
}

async function importMaster(masterKeyHex: string): Promise<CryptoKey> {
  const raw = hexToBytes(masterKeyHex);
  if (raw.length !== KEY_BYTES) {
    throw new Error(
      `FILE_ENCRYPTION_MASTER_KEY must be ${KEY_BYTES} bytes (${KEY_BYTES * 2} hex chars), got ${raw.length}`
    );
  }
  return crypto.subtle.importKey("raw", raw, { name: "HKDF" }, false, ["deriveKey"]);
}

/** Derive a per-user AES-GCM key bound to `uid`. */
async function deriveUserKey(uid: string, masterKeyHex: string): Promise<CryptoKey> {
  const master = await importMaster(masterKeyHex);
  return crypto.subtle.deriveKey(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: utf8("bite/file-encryption/v1"),
      info: utf8(`uid:${uid}`),
    },
    master,
    ALG,
    false,
    ["encrypt", "decrypt"]
  );
}

/**
 * Encrypts `plaintext` for user `uid`. Returns a single buffer of
 * `iv || ciphertext_with_tag` suitable for storing in R2.
 */
export async function encryptForUser(
  plaintext: ArrayBuffer | Uint8Array | string,
  uid: string,
  masterKeyHex: string
): Promise<Uint8Array> {
  const key = await deriveUserKey(uid, masterKeyHex);
  const iv = crypto.getRandomValues(new Uint8Array(IV_BYTES));
  const data: BufferSource =
    typeof plaintext === "string"
      ? utf8(plaintext)
      : plaintext instanceof Uint8Array
        ? plaintext
        : new Uint8Array(plaintext);
  const cipher = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, data);
  return concatBytes(iv, new Uint8Array(cipher));
}

/**
 * Decrypts a buffer produced by `encryptForUser` for the same `uid`.
 */
export async function decryptForUser(
  ciphertext: ArrayBuffer | Uint8Array,
  uid: string,
  masterKeyHex: string
): Promise<Uint8Array> {
  const key = await deriveUserKey(uid, masterKeyHex);
  const buf =
    ciphertext instanceof Uint8Array ? ciphertext : new Uint8Array(ciphertext);
  if (buf.length < IV_BYTES + 16) {
    throw new Error("ciphertext too short");
  }
  const iv = buf.slice(0, IV_BYTES);
  const body = buf.slice(IV_BYTES);
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, body);
  return new Uint8Array(plain);
}
