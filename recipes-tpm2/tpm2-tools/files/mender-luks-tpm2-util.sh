#!/bin/sh
set -e
exec 3>&1
# Compatibility-only utility.
# Preserved interfaces:
#   mender-luks-tpm2-util.sh --read
#   mender-luks-tpm2-util.sh --write [--pcrs <none|min|max|N1,N2,...>]

export TPM2TOOLS_TCTI="@@TPM2TOOLS_TCTI_NAME@@:@@TPM2TOOLS_DEVICE_FILE@@"
export TPM2TOOLS_TCTI_NAME="@@TPM2TOOLS_TCTI_NAME@@"
export TPM2TOOLS_DEVICE_FILE="@@TPM2TOOLS_DEVICE_FILE@@"

INFILE="@@MENDER/LUKS_LEGACY_KEY_FILE@@"

PCRS_NONE="@@TPM_PCR_SET_NONE@@"
PCRS_MIN="@@TPM_PCR_SET_MIN@@"
PCRS_MAX="@@TPM_PCR_SET_MAX@@"
PCRS=$PCRS_MAX
NONE=false

# temp/working files; deleted on exit
TMPDIR="${TMPDIR:-"/tmp"}/mender-luks-tpm2"
WORKDIR="$(mktemp --directory)"
PCR_FNAME="${WORKDIR}/.pcrs"
POLICY_FNAME="${WORKDIR}/.policy"
PRIMARY_CTX="${WORKDIR}/.primary.ctx"
LOAD_CTX="${WORKDIR}/.load.ctx"
TPM_PUB_KEY="${WORKDIR}/.tpm.TEMP.pub"
TPM_PRIV_KEY="${WORKDIR}/.tpm.TEMP.priv"

mkdir -p "${WORKDIR}"

################################################################################
usage() {
  echo ""
  echo "mender-luks-tpm2-util.sh [--read] [--write] [--pcrs PCR_LIST]"
  echo "  --read | -r                         output LUKS key from TPM2, fallback to legacy key file"
  echo "  --write | -w                        write LUKS key from legacy key file into TPM2"
  echo "  --pcrs | -p PCR_LIST                PCR list for write/read auth"
  echo "                                      none: $PCRS_NONE"
  echo "                                      min : $PCRS_MIN"
  echo "                                      max : $PCRS_MAX (default)"
  echo "                                      N1,N2,...,NN"
  echo "  --help | -h                         display this help"
  echo ""
  echo "  examples:"
  echo "    mender-luks-tpm2-util.sh --write"
  echo "    mender-luks-tpm2-util.sh --write --pcrs none"
  echo "    mender-luks-tpm2-util.sh --write --pcrs 0,3,5"
  echo ""
  echo "    mender-luks-tpm2-util.sh --read"
  echo ""
}

fatal() {
  echo $@ 1>&3
  exit 1
}

cleanup() {
  if [ -d  "${WORKDIR}" ]; then
    find   "${WORKDIR}" -type f -exec shred --remove {} \; 2>/dev/null || true
    rm -fr "${WORKDIR}"
  fi
}
trap cleanup EXIT

################################################################################
read_tpm2() {
  # First try unseal without PCR auth for userwithauth-sealed keys.
  if tpm2_unseal -Q --object-context=@@TPM_KEY_INDEX@@ 2>/dev/null; then
    return
  fi

  for pcrs in "$PCRS" "$PCRS_NONE" "$PCRS_MIN" "$PCRS_MAX"
  do
    if tpm2_unseal -Q --object-context=@@TPM_KEY_INDEX@@ --auth=pcr:@@TPM_PCR_ALG@@:$pcrs 2>/dev/null; then
      return
    fi
  done

  if [ -f "$INFILE" ]; then
    cat "$INFILE"
    return
  fi

  fatal "failed to unseal TPM2"
}

write_tpm2() {
  test -f "$INFILE" || fatal "LUKS key file $INFILE does not exist"

  KSIZE="$(wc -c < "$INFILE")"
  MSIZE="@@TPM_KEY_SIZE_MAX@@"
  ATTRS="@@TPM_ATTRIBUTES@@"

  $NONE                      && ATTRS="${ATTRS}|userwithauth"
  test "$KSIZE" -le "$MSIZE" || fatal "key in $INFILE is > max allowed ($MSIZE)"

  tpm2_evictcontrol  -Q --hierarchy=@@TPM_HIERARCHY@@      \
                        --object-context=@@TPM_KEY_INDEX@@ || true

  tpm2_pcrread       -Q @@TPM_PCR_ALG@@:$PCRS             \
                        --output=$PCR_FNAME

  tpm2_createpolicy  -Q --policy-pcr                                  \
                        --policy=$POLICY_FNAME                        \
                        --pcr=$PCR_FNAME                              \
                        --pcr-list=@@TPM_PCR_ALG@@:$PCRS

  # create and load an object; sealed to policy
  tpm2_createprimary -Q --hierarchy=@@TPM_HIERARCHY@@     \
                        --hash-algorithm=@@TPM_HASH_ALG@@ \
                        --key-algorithm=@@TPM_KEY_ALG@@   \
                        --key-context=$PRIMARY_CTX

  tpm2_create        -Q --attributes=$ATTRS                           \
                        --hash-algorithm=@@TPM_HASH_ALG@@ \
                        --public=$TPM_PUB_KEY                         \
                        --private=$TPM_PRIV_KEY                       \
                        --parent-context=$PRIMARY_CTX                 \
                        --policy=$POLICY_FNAME                        \
                        --sealing-input=$INFILE

  tpm2_load          -Q --public=$TPM_PUB_KEY                         \
                        --private=$TPM_PRIV_KEY                       \
                        --parent-context=$PRIMARY_CTX                 \
                        --key-context=$LOAD_CTX

  # make persistent
  tpm2_evictcontrol  -Q --hierarchy=@@TPM_HIERARCHY@@     \
                        --object-context=$LOAD_CTX                    \
                        @@TPM_KEY_INDEX@@
}

################################################################################
if [ "$#" -lt 1 ]; then
  usage
  fatal "no command provided"
fi

CMD=""

while [ "$#" -gt 0 ]
do
  case $1 in
    "--read"|"-r")
      [ -n "$CMD" ] && fatal "only one command may be provided"
      CMD="read"
      shift
      ;;
    "--write"|"-w")
      [ -n "$CMD" ] && fatal "only one command may be provided"
      CMD="write"
      shift
      ;;
    "--pcrs"|"-p")
      [ -n "$2" ] || fatal "missing value for --pcrs"
      case $2 in
        -*) fatal "missing value for --pcrs" ;;
      esac
      case $2 in
        "none") PCRS=$PCRS_NONE; NONE=true ;;
        "min")  PCRS=$PCRS_MIN ;;
        "max")  PCRS=$PCRS_MAX ;;
        *)      PCRS="$2" ;;
      esac
      shift
      shift
      ;;
    "--help"|"-h")
      usage
      exit 0
      ;;
    *)
      usage
      fatal "unsupported argument: $1"
      ;;
  esac
done

[ -n "$CMD" ] || fatal "no command provided"

echo "$PCRS" | grep -E -q "^[[:digit:]]+(,[[:digit:]]+)*$" || fatal "$PCRS : invalid PCR format; must be a numerical, comma seperated list"

# suppress non-key output by default so --read emits key material only
exec 2>/dev/null

case "$CMD" in
  "read")  read_tpm2 ;;
  "write") write_tpm2 ;;
esac

exit
