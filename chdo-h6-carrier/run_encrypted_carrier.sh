#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$ROOT/../.." && pwd)
CIPHER="$ROOT/CHDO_P0_08_Alternative_Execution_Carrier_V1.0.zip.gpg"
MANIFEST="$ROOT/PUBLIC_MANIFEST_V1.0.json"
WORK="$RUNNER_TEMP/chdo-h6-encrypted-carrier"
PLAIN="$WORK/carrier.zip"
UNPACK="$WORK/unpacked"
PUBLIC_OUT="$REPO_ROOT/public-encrypted-output"

: "${CHDO_CARRIER_KEY_B64:?Missing repository secret CHDO_CARRIER_KEY_B64}"
rm -rf "$WORK" "$PUBLIC_OUT"
mkdir -p "$WORK" "$UNPACK" "$PUBLIC_OUT"

python3 - "$CIPHER" "$MANIFEST" <<'PY'
import hashlib, json, pathlib, sys
cipher=pathlib.Path(sys.argv[1]); manifest=json.loads(pathlib.Path(sys.argv[2]).read_text())
h=hashlib.sha256(cipher.read_bytes()).hexdigest()
assert h == manifest['ciphertext_sha256'], (h, manifest['ciphertext_sha256'])
print('CIPHERTEXT_SHA256=PASS')
PY

printf '%s' "$CHDO_CARRIER_KEY_B64" | gpg --batch --yes --no-symkey-cache \
  --pinentry-mode loopback --passphrase-fd 0 --output "$PLAIN" --decrypt "$CIPHER"

python3 - "$PLAIN" "$MANIFEST" <<'PY'
import hashlib, json, pathlib, sys
plain=pathlib.Path(sys.argv[1]); manifest=json.loads(pathlib.Path(sys.argv[2]).read_text())
h=hashlib.sha256(plain.read_bytes()).hexdigest()
assert h == manifest['plaintext_sha256'], (h, manifest['plaintext_sha256'])
print('PLAINTEXT_CARRIER_SHA256=PASS')
PY

unzip -q "$PLAIN" -d "$UNPACK"
CARRIER="$UNPACK/chdo_alt_carrier_v1"
test -d "$CARRIER"

# Downloads occur before inference. The frozen child network namespace still
# blocks all non-loopback traffic during model invocation.
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

# Remove plaintext carrier/output material before upload-artifact runs.
rm -rf "$WORK" "$UNPACK" "$PLAIN"
unset CHDO_CARRIER_KEY_B64

echo "ENCRYPTED_OUTPUT_READY=$OUTPUT_CIPHER"
echo "RUN_EXIT_CODE=$RUN_RC"
exit "$RUN_RC"
