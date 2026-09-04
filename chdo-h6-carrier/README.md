# CHDO H6 Encrypted Public Carrier V1.0

**DO NOT MERGE.** This temporary public-repository branch is an execution carrier only.

The public branch contains only:

- GPG ciphertext transported as ten base64 ASCII parts under `payload/`;
- a public integrity manifest with per-part and reconstructed-ciphertext hashes;
- a public decrypt/run/re-encrypt wrapper;
- a workflow that verifies ciphertext publicly and uploads encrypted output only.

It does **not** contain plaintext prompts, the plaintext Frozen Runner, plaintext model outputs, the decryption secret, or the sealed-analysis package.

## Integrity

- Plaintext carrier SHA256: `e2a6049f6e3e30bfd67af99ecc0bdd268ca0584efb6635c95d10a6bc82bbb41c`
- Plaintext carrier size: `66728` bytes
- Reconstructed ciphertext SHA256: `5ecfd5acef063e1c6e5772794b8e43842884decdc7b7428183152f3102e316cb`
- Reconstructed ciphertext size: `66850` bytes
- Transport: ten base64 ASCII parts; each part size and hash is frozen in `PUBLIC_MANIFEST_V1.0.json`.

## Activation sequence

1. Open a same-repository draft PR from `chdo/h6-encrypted-carrier-v0.1` to `main`. The first run verifies the public encrypted transport and records `WAITING_USER_ACTION` when the secret is absent.
2. Add repository Actions secret `CHDO_CARRIER_KEY_B64` using the separately delivered secret file.
3. Rerun the `frozen-run` job. The runner reconstructs and verifies ciphertext, decrypts only on the ephemeral runner, verifies the plaintext carrier hash, downloads and verifies the exact pinned model/backend, then executes the unchanged carrier inside the child loopback-only network namespace.
4. The plaintext execution artifact is symmetrically encrypted before upload. Only ciphertext plus a non-sensitive receipt is uploaded.
5. Close the PR without merge after artifact intake.

## Scientific boundary

- No model, prompt, generation config, call order, validator, output policy, network isolation, or H6 threshold is changed.
- No sealed analysis is present.
- Carrier or transport readiness is not a model run.
- Only an independently decrypted and verified 8/8 VALID artifact may unlock the original sealed-analysis gate.

## Security boundary

- The passphrase is never committed or printed.
- Stable ciphertext hashes are public; plaintext payloads remain encrypted at rest in the repository and Actions artifact store.
- Plaintext prompts, model outputs, downloaded model assets, and temporary work files are deleted from the runner before upload.
- The branch and PR are temporary operational infrastructure and must not be merged.
