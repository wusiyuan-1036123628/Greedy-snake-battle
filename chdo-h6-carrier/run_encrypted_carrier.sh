#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$ROOT/../.." && pwd)
PAYLOAD_DIR="$ROOT/payload"
MANIFEST="$ROOT/PUBLIC_MANIFEST_V1.0.json"
WORK="$RUNNER_TEMP/chdo-h6-encrypted-carrier"
CIPHER="$WORK/carrier.zip.gpg"
PLAIN="$WORK/carrier.zip"
UNPACK="$WORK/unpacked"
PUBLIC_OUT="$REPO_ROOT/public-encrypted-output"

: "${CHDO_CARRIER_KEY_B64:?Missing repository secret CHDO_CARRIER_KEY_B64}"
rm -rf "$WORK" "$PUBLIC_OUT"
mkdir -p "$WORK" "$UNPACK" "$PUBLIC_OUT"

mapfile -t PARTS < <(find "$PAYLOAD_DIR" -maxdepth 1 -type f -name 'ciphertext.b64.part-*' -print | sort)
python3 - "$PAYLOAD_DIR" "$CIPHER" "$MANIFEST" "${PARTS[@]}" <<'PY'
import base64
import hashlib
import json
import pathlib
import sys

out = pathlib.Path(sys.argv[2])
manifest = json.loads(pathlib.Path(sys.argv[3]).read_text(encoding="utf-8"))
parts = [pathlib.Path(p) for p in sys.argv[4:]]
transport = manifest["ciphertext_transport"]

assert len(parts) == transport["part_count"], (len(parts), transport["part_count"])
assert [p.name for p in parts] == [row["name"] for row in transport["parts"]]
chunks = []
for part, expected in zip(parts, transport["parts"]):
    raw = part.read_bytes()
    assert len(raw) == expected["size_bytes"], (part.name, len(raw), expected["size_bytes"])
    actual_hash = hashlib.sha256(raw).hexdigest()
    assert actual_hash == expected["sha256"], (part.name, actual_hash, expected["sha256"])
    chunks.append(raw.decode("ascii"))

joined = "".join(chunks)
assert len(joined) == transport["concatenated_base64_length"]
ciphertext = base64.b64decode(joined, validate=True)
out.write_bytes(ciphertext)
assert len(ciphertext) == manifest["ciphertext_size_bytes"]
assert hashlib.sha256(ciphertext).hexdigest() == manifest["ciphertext_sha256"]
print("PAYLOAD_PARTS=PASS")
print("CIPHERTEXT_SHA256=PASS")
PY

printf '%s' "$CHDO_CARRIER_KEY_B64" | gpg --batch --yes --no-symkey-cache \
  --pinentry-mode loopback --passphrase-fd 0 --output "$PLAIN" --decrypt "$CIPHER"

python3 - "$PLAIN" "$MANIFEST" <<'PY'
import hashlib
import json
import pathlib
import sys

plain = pathlib.Path(sys.argv[1])
manifest = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
actual_hash = hashlib.sha256(plain.read_bytes()).hexdigest()
assert actual_hash == manifest["plaintext_sha256"], (actual_hash, manifest["plaintext_sha256"])
assert plain.stat().st_size == manifest["plaintext_size_bytes"]
print("PLAINTEXT_CARRIER_SHA256=PASS")
PY

unzip -q "$PLAIN" -d "$UNPACK"
CARRIER="$UNPACK/chdo_alt_carrier_v1"
test -d "$CARRIER"

# Downloads occur before inference. During model invocation, the unchanged
# carrier enters a child Linux network namespace with loopback only.
cd "$CARRIER"
./scripts/download_pinned_assets.sh

set +e
./run_local_linux.sh
RUN_RC=$?
set -e
printf '%s\n' "$RUN_RC" > "$WORK/run_exit_code.txt"

ARTIFACT=$(find "$CARRIER/work" -maxdepth 1 -type f -name 'PILOT-TR-01-V0.3-ALT-CARRIER-*.zip' -print | sort | tail -1)
if [[ -z "$ARTIFACT" ]]; then
  printf '%s\n' "No plaintext execution artifact was produced; run_exit_code=$RUN_RC" > "$WORK/NO_ARTIFACT.txt"
  ARTIFACT="$WORK/NO_ARTIFACT.txt"
fi

OUTPUT_CIPHER="$PUBLIC_OUT/PILOT-TR-01-V0.3-ENCRYPTED-RUN-${GITHUB_RUN_ID}.gpg"
printf '%s' "$CHDO_CARRIER_KEY_B64" | gpg --batch --yes --no-symkey-cache \
  --pinentry-mode loopback --passphrase-fd 0 --symmetric --cipher-algo AES256 \
  --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65011712 \
  --output "$OUTPUT_CIPHER" "$ARTIFACT"

{
  echo "carrier=encrypted_public_github_hosted"
  echo "github_run_id=$GITHUB_RUN_ID"
  echo "source_ciphertext_sha256=$(sha256sum "$CIPHER" | awk '{print $1}')"
  echo "encrypted_output_sha256=$(sha256sum "$OUTPUT_CIPHER" | awk '{print $1}')"
  echo "run_exit_code=$RUN_RC"
  echo "plaintext_prompts_uploaded=false"
  echo "plaintext_outputs_uploaded=false"
  echo "sealed_analysis_present=false"
  echo "h6_status=NOT_TESTED_UNTIL_INDEPENDENT_8_OF_8_VALID_VERIFICATION"
} > "$PUBLIC_OUT/PUBLIC_RUN_RECEIPT.txt"

# Delete plaintext carrier, outputs, logs and model assets before artifact upload.
rm -rf "$WORK"
unset CHDO_CARRIER_KEY_B64

echo "ENCRYPTED_OUTPUT_READY=$OUTPUT_CIPHER"
echo "RUN_EXIT_CODE=$RUN_RC"
exit "$RUN_RC"
