.PHONY: help keygen spub spri tfvars-init tf-init tf-plan tf-apply tf-output tf-destroy sync-app restart-app deploy

SSH_KEY_PATH ?= $(HOME)/.ssh/minecraft_oci
SSH_USER ?= ubuntu

help:
	@echo "Available targets:"
	@echo "  make keygen       - Generate SSH key pair at $(SSH_KEY_PATH) and print public key"
	@echo "  make spub         - Show public key at $(SSH_KEY_PATH).pub"
	@echo "  make spri         - Show private key at $(SSH_KEY_PATH)"
	@echo "  make tfvars-init  - Copy terraform.tfvars.example to terraform.tfvars (if missing)"
	@echo "  make tf-init      - Run terraform init"
	@echo "  make tf-plan      - Run terraform plan"
	@echo "  make tf-apply     - Run terraform apply"
	@echo "  make tf-output    - Show terraform outputs"
	@echo "  make tf-destroy   - Run terraform destroy"
	@echo "  make sync-app     - Copy docker-compose.yml and addons/ to VM"
	@echo "  make restart-app  - Pull and restart Bedrock container on VM"
	@echo "  make deploy       - sync-app + restart-app"

keygen:
	@if [ -f "$(SSH_KEY_PATH)" ] || [ -f "$(SSH_KEY_PATH).pub" ]; then \
		echo "Key already exists at $(SSH_KEY_PATH)"; \
		echo "Set SSH_KEY_PATH to generate elsewhere, e.g. make keygen SSH_KEY_PATH=$$HOME/.ssh/minecraft_oci_new"; \
		exit 1; \
	fi
	ssh-keygen -t ed25519 -C "minecraft-server" -f "$(SSH_KEY_PATH)"
	@echo ""
	@echo "Public key (put this into terraform/terraform.tfvars -> ssh_public_key):"
	@echo "------------------------------------------------------------"
	@cat "$(SSH_KEY_PATH).pub"
	@echo "------------------------------------------------------------"

spub:
	@if [ ! -f "$(SSH_KEY_PATH).pub" ]; then \
		echo "Public key not found at $(SSH_KEY_PATH).pub"; \
		exit 1; \
	fi
	@cat "$(SSH_KEY_PATH).pub"

spri:
	@if [ ! -f "$(SSH_KEY_PATH)" ]; then \
		echo "Private key not found at $(SSH_KEY_PATH)"; \
		exit 1; \
	fi
	@cat "$(SSH_KEY_PATH)"

tfvars-init:
	@if [ ! -f terraform/terraform.tfvars ]; then \
		cp terraform/terraform.tfvars.example terraform/terraform.tfvars; \
		echo "Created terraform/terraform.tfvars"; \
	else \
		echo "terraform/terraform.tfvars already exists"; \
	fi

tf-init:
	cd terraform && terraform init

tf-plan:
	cd terraform && terraform plan

tf-apply:
	cd terraform && terraform apply

tf-output:
	cd terraform && terraform output

tf-destroy:
	cd terraform && terraform destroy

sync-app:
	scp -i "$(SSH_KEY_PATH)" -r docker-compose.yml addons $(SSH_USER)@$$(cd terraform && terraform output -raw public_ip):/opt/minecraft/

restart-app:
	ssh -i "$(SSH_KEY_PATH)" $(SSH_USER)@$$(cd terraform && terraform output -raw public_ip) 'cd /opt/minecraft && sudo docker compose pull && sudo docker compose up -d --remove-orphans && sudo docker compose ps'

deploy: sync-app restart-app
