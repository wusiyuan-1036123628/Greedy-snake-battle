# CHDO H6 Encrypted Public Carrier V1.0

**DO NOT MERGE. Do not open the PR until the repository secret exists.**

This temporary public-repository carrier is a fallback for the current private-repository GitHub-hosted Actions restriction. It does not publish plaintext prompts, the frozen runner, or model outputs.

## Public contents

- GPG-encrypted alternative carrier: `chdo-h6-carrier/CHDO_P0_08_Alternative_Execution_Carrier_V1.0.zip.gpg`
- Public integrity manifest.
- Public decrypt/run/re-encrypt wrapper.
- Workflow that uploads encrypted output only.

Plaintext carrier SHA256: `e2a6049f6e3e30bfd67af99ecc0bdd268ca0584efb6635c95d10a6bc82bbb41c`

Ciphertext SHA256: `5ecfd5acef063e1c6e5772794b8e43842884decdc7b7428183152f3102e316cb`

## Activation

1. Add repository Actions secret `CHDO_CARRIER_KEY_B64` using the separately delivered secret file.
2. Open a same-repository draft PR from branch `chdo/h6-encrypted-carrier-v0.1` to `main`.
3. The job decrypts only on the ephemeral runner, verifies the plaintext hash, downloads and verifies the exact pinned model/backend, executes the unchanged carrier inside the child loopback-only network namespace, encrypts the run artifact, deletes plaintext working material, and uploads encrypted output only.
4. Close the PR without merge after artifact intake.

## Scientific boundary

- No model/prompt/config/order/validator/isolation change.
- No sealed analysis included.
- A run is not H6 evidence unless the decrypted artifact independently verifies 8/8 VALID under the original contract.

## Security boundary

- The passphrase is never committed.
- Plaintext prompts and outputs are never uploaded as repository content or Actions artifacts.
- The public artifact contains ciphertext plus a non-sensitive receipt only.
- The branch is temporary operational infrastructure and must not be merged.
