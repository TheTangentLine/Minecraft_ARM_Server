# raspberry-pi/mac-aliases.sh
#
# Mac aliases and functions for monitoring the Raspberry Pi capacity retry.
# Add to ~/.zshrc:
#
#   cat ~/path/to/Minecraft_ARM_Server/raspberry-pi/mac-aliases.sh >> ~/.zshrc
#   source ~/.zshrc
#
# Adjust PI_HOST and PI_USER if your Pi's IP or username is different.

PI_USER="someone"
PI_HOST="192.168.20.44"

alias pi='ssh ${PI_USER}@${PI_HOST}'

check() {
  local host="${PI_USER}@${PI_HOST}"
  local log='/tmp/tf-retry.log'
  local raw='/tmp/tf-retry-raw.log'

  case "${1:-}" in
    -f|--follow)
      ssh -t "$host" "tail -f $log"
      ;;
    -r|--raw)
      ssh -t "$host" "tail -f $raw"
      ;;
    -h|--help)
      echo "Usage: check [lines] | check -f | check -r"
      echo "  check         last 50 lines of summary log"
      echo "  check 100     last 100 lines of summary log"
      echo "  check -f      follow summary log live (Ctrl+C to stop)"
      echo "  check -r      follow full terraform log live"
      echo "  pi            open SSH shell on Pi"
      ;;
    ''|*[!0-9]*)
      ssh "$host" "tail -n 50 $log"
      ;;
    *)
      ssh "$host" "tail -n ${1} $log"
      ;;
  esac
}
