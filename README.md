# Minecraft Bedrock ARM Server (OCI)

Terraform provisions an OCI ARM VM and network. Docker runs Bedrock on port `19132/udp`.

## Set Up Oracle CLI

Install (macOS):

```bash
brew update
brew install oci-cli
```

Configure:

```bash
oci setup config
```

Verify auth + region:

```bash
oci iam region list --output table
```

Notes:
- `oci setup config` creates `~/.oci/config` and asks for your API key details.
- Terraform in this repo can use that OCI CLI config automatically.

## Quick Start

```bash
make keygen
make tfvars-init
```

Edit `terraform/terraform.tfvars` with:
- `compartment_id`
- `region`
- `ssh_public_key` (from `make spub`)
- `ubuntu_aarch64_image_id`

Get the Ubuntu 22.04 ARM image OCID:

```bash
oci compute image list \
  --compartment-id <tenancy-ocid> \
  --operating-system "Canonical Ubuntu" \
  --operating-system-version "22.04" \
  --shape "VM.Standard.A1.Flex" \
  --query "data[?contains(\"display-name\", 'aarch64')].{name:\"display-name\",id:id}" \
  --output table
```

Deploy infra:

```bash
make tf-init
make tf-plan
make tf-apply
```

Deploy app files and restart container:

```bash
make deploy
```

Connect from Minecraft Bedrock:
- Host: `$(cd terraform && terraform output -raw public_ip)`
- Port: `19132`

## Makefile Commands

```bash
make help
```

Common:
- `make keygen` generate SSH key pair (`~/.ssh/minecraft_oci`)
- `make spub` show public key
- `make spri` show private key
- `make tf-init|tf-plan|tf-apply|tf-output|tf-destroy`
- `make sync-app` copy `docker-compose.yml` and `addons/` to VM
- `make restart-app` pull image and restart Bedrock
- `make deploy` sync + restart

Use custom key/user:

```bash
make deploy SSH_KEY_PATH=~/.ssh/custom_key SSH_USER=ubuntu
```

## GitHub Actions CD

Workflow: `.github/workflows/cd.yml` (runs on push to `main`).

Required repository secrets:
- `SSH_HOST`
- `SSH_USER`
- `SSH_PRIVATE_KEY`

`SSH_PRIVATE_KEY` must match the public key used in `terraform.tfvars`.

## Notes

- Do not put OCI credentials in `terraform.tfvars`.
- OCI auth comes from OCI CLI config, env vars, or instance principal.

## Troubleshooting

- SSH fails: check key pair + security rule for TCP `22`.
- Cannot join server: check UDP `19132` rule/firewall.
- Container issue: `sudo docker compose logs -f bedrock`.

