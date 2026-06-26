#!/usr/bin/env bash
# raspberry-pi/scripts/setup.sh
#
# Run this on the Raspberry Pi to install Terraform and OCI CLI,
# then fix the key_file path in ~/.oci/config.
#
# Usage:
#   bash raspberry-pi/scripts/setup.sh
#
# Prerequisites:
#   - ~/.oci/config and ~/.oci/oci_api_key.pem already copied from your Mac
#   - sudo access on the Pi

set -euo pipefail

TF_VER="1.9.8"

echo "=== [1/4] Installing Terraform ${TF_VER} ==="

if command -v terraform &>/dev/null && terraform -version 2>/dev/null | grep -q "Terraform v${TF_VER}"; then
  echo "Terraform ${TF_VER} already installed, skipping."
else
  cd /tmp
  rm -f "terraform_${TF_VER}_linux_arm64.zip" terraform
  curl -LO "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_arm64.zip"
  unzip -o "terraform_${TF_VER}_linux_arm64.zip" terraform
  sudo mv terraform /usr/local/bin/terraform
  sudo chmod +x /usr/local/bin/terraform
  rm -f "terraform_${TF_VER}_linux_arm64.zip"
  cd - > /dev/null
  echo "Terraform installed."
fi

terraform -version

echo ""
echo "=== [2/4] Installing OCI CLI ==="

if command -v oci &>/dev/null; then
  echo "OCI CLI already installed, skipping."
else
  bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
  # Reload PATH so oci is findable in this session
  export PATH="$HOME/bin:$PATH"
fi

echo ""
echo "=== [3/4] Fixing key_file path in ~/.oci/config ==="

OCI_CONFIG="$HOME/.oci/config"
OCI_KEY="$HOME/.oci/oci_api_key.pem"

if [[ ! -f "$OCI_CONFIG" ]]; then
  echo "ERROR: $OCI_CONFIG not found."
  echo "Copy it from your Mac first:"
  echo "  scp ~/.oci/config $(whoami)@$(hostname -I | awk '{print $1}'):~/.oci/config"
  echo "  scp ~/.oci/oci_api_key.pem $(whoami)@$(hostname -I | awk '{print $1}'):~/.oci/oci_api_key.pem"
  exit 1
fi

if [[ ! -f "$OCI_KEY" ]]; then
  echo "ERROR: $OCI_KEY not found."
  echo "Copy it from your Mac: scp ~/.oci/oci_api_key.pem $(whoami)@<pi-ip>:~/.oci/oci_api_key.pem"
  exit 1
fi

chmod 600 "$OCI_CONFIG" "$OCI_KEY"

# Replace whatever key_file= points to with the correct Pi path
sed -i "s|key_file=.*|key_file=${OCI_KEY}|" "$OCI_CONFIG"
echo "key_file updated to: $OCI_KEY"

echo ""
echo "=== [4/4] Verifying ==="

echo "--- terraform -version ---"
terraform -version

echo ""
echo "--- ~/.oci/config ---"
cat "$OCI_CONFIG"

echo ""
echo "--- oci iam region list (requires network) ---"
if command -v oci &>/dev/null; then
  oci iam region list --output table || echo "OCI CLI auth failed — check config values above."
else
  echo "oci not in PATH yet. Run: exec -l \$SHELL   then:   oci iam region list --output table"
fi

echo ""
echo "Setup complete. Next steps:"
echo "  1. Copy Terraform state from Mac (see raspberry-pi/README.md Step 4)"
echo "  2. cd ~/Minecraft_ARM_Server && make tf-plan  (should show 1 to add)"
echo "  3. Add cron job (see raspberry-pi/README.md Step 6)"
