# Raspberry Pi — OCI Capacity Retry Host

Use a Raspberry Pi as an always-on host that keeps retrying `terraform apply` until OCI has free A1 Flex capacity. The Pi does nothing after the VM is provisioned; it is only needed during the waiting period.

---

## Prerequisites

- Raspberry Pi running Raspberry Pi OS (Bookworm / Debian 12) — 32-bit (`armv7`) or 64-bit (`aarch64`)
- Pi is on the same local network as your Mac (or reachable via SSH)
- Your Mac already has OCI CLI configured (`~/.oci/config` + `~/.oci/oci_api_key.pem`) and a working `terraform apply` against this project
- `make`, `git`, `curl`, `unzip` available on the Pi (`sudo apt install -y make git curl unzip`)

---

## Step 1 — Install Terraform

> Install from `/tmp` — do **not** run this from inside the repo. The repo already has a `terraform/` directory and unzipping here will corrupt it.

```bash
cd /tmp
TF_VER=1.9.8
curl -LO "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_arm64.zip"
unzip -o "terraform_${TF_VER}_linux_arm64.zip"
sudo mv terraform /usr/local/bin/terraform
sudo chmod +x /usr/local/bin/terraform
terraform -version
```

Expected output:

```text
Terraform v1.9.8
on linux_arm64
```

---

## Step 2 — Install OCI CLI

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

When prompted:
- Install directory: press **Enter** (default `~/lib/oracle-cli`)
- Executable directory: press **Enter** (default `~/bin`)
- Scripts directory: press **Enter**
- Optional packages: press **Enter** (none)
- Modify PATH: enter `Y`
- rc file: press **Enter** (default `~/.bashrc`)

Reload shell:

```bash
exec -l $SHELL
```

> [!NOTE]
> If `oci iam region list` fails with `ModuleNotFoundError: No module named 'crc32c'`, try:
> ```bash
> ~/lib/oracle-cli/bin/pip install crc32c
> # or, if that fails on armv7:
> ~/lib/oracle-cli/bin/pip install google-crc32c
> ```
> OCI CLI is **not required for Terraform** — if it still fails, skip ahead. Terraform only needs `~/.oci/config` and the API key.

---

## Step 3 — Copy OCI credentials from Mac

Run these on your **Mac**:

```bash
ssh <pi-user>@<pi-ip> "mkdir -p ~/.oci && chmod 700 ~/.oci"

scp ~/.oci/config       <pi-user>@<pi-ip>:~/.oci/config
scp ~/.oci/oci_api_key.pem <pi-user>@<pi-ip>:~/.oci/oci_api_key.pem
```

Then on the **Pi**, fix permissions and the key path (the Mac path will be wrong):

```bash
chmod 600 ~/.oci/config ~/.oci/oci_api_key.pem

# Update key_file to the Pi's path
sed -i 's|key_file=.*|key_file=/home/'"$USER"'/.oci/oci_api_key.pem|' ~/.oci/config

cat ~/.oci/config
```

The `key_file` line should now read `/home/<your-pi-user>/.oci/oci_api_key.pem`.

---

## Step 4 — Copy repo + Terraform state from Mac

Run on your **Mac**:

```bash
# Clone the repo on the Pi first
ssh <pi-user>@<pi-ip> "git clone https://github.com/<your-username>/Minecraft_ARM_Server.git ~/Minecraft_ARM_Server"

# Then copy state files (critical — without these, Terraform will try to recreate the whole network)
scp terraform/terraform.tfstate \
    terraform/terraform.tfvars \
    terraform/.terraform.lock.hcl \
    <pi-user>@<pi-ip>:~/Minecraft_ARM_Server/terraform/

scp -r terraform/.terraform \
    <pi-user>@<pi-ip>:~/Minecraft_ARM_Server/terraform/
```

> [!IMPORTANT]
> Only one machine should run `terraform apply` at a time. **Stop** any `make tf-retry` running on your Mac before enabling the Pi.

---

## Step 5 — Verify

On the **Pi**:

```bash
cd ~/Minecraft_ARM_Server
make tf-init
make tf-plan
```

Expected plan output (network already exists, only VM is new):

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

If you see more than 1 resource to add, the state files were not copied correctly — re-run Step 4.

---

## Step 6 — Set up cron

```bash
crontab -e
```

Add this line:

```cron
*/5 * * * * cd /home/<pi-user>/Minecraft_ARM_Server && PATH=/usr/local/bin:/usr/bin:/bin INTERVAL=300 MAX_ATTEMPTS=1 /usr/bin/make tf-retry
```

Replace `<pi-user>` with your Pi username (e.g. `khatruong`).

The retry script handles logging internally — do **not** append `>> /tmp/tf-retry.log` here.

Verify cron is registered:

```bash
crontab -l
```

**Optional: prevent overlapping runs** with `flock` (useful if apply ever takes longer than 5 minutes):

```cron
*/5 * * * * flock -n /tmp/tf-retry.lock -c 'cd /home/<pi-user>/Minecraft_ARM_Server && PATH=/usr/local/bin:/usr/bin:/bin INTERVAL=300 MAX_ATTEMPTS=1 /usr/bin/make tf-retry'
```

---

## Step 7 — Monitor from Mac

Add the aliases in [`mac-aliases.sh`](mac-aliases.sh) to your `~/.zshrc`:

```bash
cat raspberry-pi/mac-aliases.sh >> ~/.zshrc
source ~/.zshrc
```

Then:

| Command | What it does |
| ------- | ------------ |
| `check` | Last 50 lines of summary log |
| `check 100` | Last 100 lines |
| `check -f` | Follow summary log live |
| `check -r` | Follow full Terraform output live |
| `pi` | Open interactive SSH shell on Pi |

Summary log (`/tmp/tf-retry.log`) looks like:

```text
2026-06-19 00:45:01 AEST | ATTEMPT 1 started
2026-06-19 00:45:15 AEST | FAILED | out of host capacity
2026-06-19 01:10:02 AEST | ATTEMPT 1 started
2026-06-19 01:12:30 AEST | SUCCESS | public_ip=203.0.113.42
```

Full Terraform output is in `/tmp/tf-retry-raw.log`.

---

## Step 8 — After success

1. **Remove the cron job** — capacity is taken, no more retrying needed:

   ```bash
   crontab -e
   # delete the tf-retry line
   ```

2. **Get the public IP**:

   ```bash
   cd ~/Minecraft_ARM_Server
   make tf-output
   ```

3. **Wait ~2–5 minutes** for cloud-init to finish (Docker + Tailscale install on the VM).

4. **Find the VM in Tailscale admin** → note the MagicDNS hostname.

5. **Set GitHub secrets** (for CD): `SSH_HOST_TS`, `SSH_USER`, `SSH_PRIVATE_KEY`, `TAILSCALE_AUTHKEY_CI`.

6. **Deploy from your Mac**:

   ```bash
   cd ~/Downloads/Project/Minecraft_ARM_Server
   make deploy SSH_HOST=<magicdns-hostname>
   ```

7. **Connect in Minecraft Bedrock**: `<public_ip>:19132`

---

## Troubleshooting

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| `terraform: command not found` after install | Binary not in `PATH` | Run `export PATH="/usr/local/bin:$PATH"` or open a new shell |
| `error: cannot delete old terraform / Is a directory` | Unzipped inside repo root | Remove `LICENSE.txt`, re-run install from `/tmp` (Step 1) |
| `did not find a proper configuration for tenancy` | `~/.oci/config` missing on Pi | Re-run Step 3 |
| `did not find a proper configuration for private key` | `key_file=` still points to Mac path | Run the `sed` fix in Step 3 |
| `ModuleNotFoundError: No module named 'crc32c'` | OCI CLI pip dep missing on ARM | `pip install crc32c` or `pip install google-crc32c` (Terraform still works without it) |
| `make: No rule to make target 'tf-output'` | Running `make` from inside `terraform/` | Run `make` from `~/Minecraft_ARM_Server`, not from `~/Minecraft_ARM_Server/terraform/` |
| Plan shows more than 1 to add | Terraform state not copied | Re-run `scp` for `terraform.tfstate` and `.terraform/` from Mac |
| Log empty after 5+ minutes | cron daemon not running | `sudo systemctl status cron` — start if needed |
