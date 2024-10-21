#!/bin/sh
set -e
exec 3>&1

export TPM2TOOLS_TCTI="@@MENDER/LUKS_TPM2TOOLS_TCTI_NAME@@:@@MENDER/LUKS_TPM2TOOLS_DEVICE_FILE@@"
export TPM2TOOLS_TCTI_NAME="@@MENDER/LUKS_TPM2TOOLS_TCTI_NAME@@"
export TPM2TOOLS_DEVICE_FILE="@@MENDER/LUKS_TPM2TOOLS_DEVICE_FILE@@"

INFILE="@@MENDER/LUKS_LEGACY_KEY_FILE@@"
OUTFILE="/proc/self/fd/1"

DEBUG_FLAG=false

PCRS_NONE="@@MENDER/LUKS_TPM_PCR_SET_NONE@@"
PCRS_MIN="@@MENDER/LUKS_TPM_PCR_SET_MIN@@"
PCRS_MAX="@@MENDER/LUKS_TPM_PCR_SET_MAX@@"
PCRS=$PCRS_MAX
NONE=false

# temp/working files; these will be deleted on exit
PCR_FNAME="@@MENDER/LUKS_TMP_DIR@@/tpm/.pcrs"
POLICY_FNAME="@@MENDER/LUKS_TMP_DIR@@/tpm/.policy"
PRIMARY_CTX="@@MENDER/LUKS_TMP_DIR@@/tpm/.primary.ctx"
LOAD_CTX="@@MENDER/LUKS_TMP_DIR@@/tpm/.load.ctx"
TPM_PUB_KEY="@@MENDER/LUKS_TMP_DIR@@/tpm/.tpm.TEMP.pub"
TPM_PRIV_KEY="@@MENDER/LUKS_TMP_DIR@@/tpm/.tpm.TEMP.priv"

################################################################################
function usage {
  echo "                                                                                                    "
  echo "mender-luks-tpm2-util.sh [options] <command>                                                        "
  echo "  options:                                                                                          "
  echo "    --help    | -h           # display this prompt                                                  "
  echo "    --debug   | -d           # do not suppress output; may interfere with --read output             "
  echo "    --pcrs    | -p PCR_LIST  # PCR values to seal/unseal with                                       "
  echo "                             # PCR_LIST options :                                                   "
  echo "                             #   none           : $PCRS_NONE # none will seal w/ the userwithauth attribute "
  echo "                             #   min            : $PCRS_MIN                                         "
  echo "                             #   max  (default) : $PCRS_MAX                                         "
  echo "                             #   N1,N2,..,NN    : numerical, comma separated list                   "
  echo "    --infile  | -i FILENAME  # read  LUKS key from this file                                        "
  echo "                             # default: @@MENDER/LUKS_LEGACY_KEY_FILE@@                             "
  echo "    --outfile | -o FILENAME  # write LUKS key (output of --read) to this file                       "
  echo "                             # default: stdout (/proc/self/fd/1)                                    "
  echo "                             # !!! WARNING setting this creates a file that may persist !!!         "
  echo "                             # !!! YOU ARE RESPONSIBLE FOR MANUALLY DELETING THIS FILE  !!!         "
  echo "  commands:                                                                                         "
  echo "    --clear   | -c           # clear  LUKS key from TPM2                                            "
  echo "    --write   | -w           # write  LUKS key to   TPM2 from stored keyfile                        "
  echo "    --read    | -r           # output LUKS key from TPM2, or  stored keyfile on TPM2 failure        "
  echo "                                                                                                    "
  echo "  examples:                                                                                         "
  echo "    mender-luks-tpm2-util.sh --write                                                                "
  echo "    mender-luks-tpm2-util.sh --write --pcrs none                                                    "
  echo "    mender-luks-tpm2-util.sh --write --pcrs 0,3,5 --infile /tmp/keyfile                             "
  echo "                                                                                                    "
  echo "    mender-luks-tpm2-util.sh --read                                                                 "
  echo "                                                                                                    "
}

function fatal {
  echo $@ 1>&3
  exit 1
}

function cleanup {
  if [   -d  @@MENDER/LUKS_TMP_DIR@@/tpm ]; then
    find     @@MENDER/LUKS_TMP_DIR@@/tpm -type f -exec shred --remove {} \;
    rm   -fr @@MENDER/LUKS_TMP_DIR@@/tpm
  fi
  mkdir  -p  @@MENDER/LUKS_TMP_DIR@@/tpm
}
trap cleanup EXIT

################################################################################
function _clear_tpm2 {
  # do this one last; it may fail if there is no object to clear
  tpm2_evictcontrol  -Q --hierarchy=@@MENDER/LUKS_TPM_HIERARCHY@@      \
                        --object-context=@@MENDER/LUKS_TPM_KEY_INDEX@@
}

function _read_tpm2 {
  local PCR_ARRAY=( $PCRS $PCRS_NONE $PCRS_MIN $PCRS_MAX )
  local pcrs
  for pcrs in "${PCR_ARRAY[@]}"
  do
    if   tpm2_unseal -Q --object-context=@@MENDER/LUKS_TPM_KEY_INDEX@@                                              2>&1 >/dev/null; then
         tpm2_unseal -Q --object-context=@@MENDER/LUKS_TPM_KEY_INDEX@@                                              1>&3 >$OUTFILE ; return
    elif tpm2_unseal -Q --object-context=@@MENDER/LUKS_TPM_KEY_INDEX@@ --auth=pcr:@@MENDER/LUKS_TPM_PCR_ALG@@:$pcrs 2>&1 >/dev/null; then
         tpm2_unseal -Q --object-context=@@MENDER/LUKS_TPM_KEY_INDEX@@ --auth=pcr:@@MENDER/LUKS_TPM_PCR_ALG@@:$pcrs 1>&3 >$OUTFILE ; return
    fi
  done

  test -f $INFILE && cat $INFILE 1>&3 >$OUTFILE && return

  fatal "failed to unseal TPM2"
}

function _write_tpm2 {
  test -f $INFILE || fatal "LUKS key file $INFILE does not exist"

  #noop if trying to write the same key at the same seal level
  set +e
  local KEY=$(tpm2_unseal -Q --object-context=@@MENDER/LUKS_TPM_KEY_INDEX@@ --auth=pcr:@@MENDER/LUKS_TPM_PCR_ALG@@:$PCRS 2>/dev/null)
  set -e
  test $? && test "$KEY" == "$(cat $INFILE)" && exit

  local KSIZE="$(wc -c $INFILE | cut -d ' ' -f1)"
  local MSIZE="@@MENDER/LUKS_TPM_KEY_SIZE_MAX@@"
  local ATTRS="@@MENDER/LUKS_TPM_ATTRIBUTES@@"

  $NONE                      && ATTRS="${ATTRS}|userwithauth"
  test "$KSIZE" -le "$MSIZE" || fatal "key in $INFILE is > max allowed ($MSIZE)"

  _clear_tpm2 || true

  tpm2_pcrread       -Q @@MENDER/LUKS_TPM_PCR_ALG@@:$PCRS             \
                        --output=$PCR_FNAME

  tpm2_createpolicy  -Q --policy-pcr                                  \
                        --policy=$POLICY_FNAME                        \
                        --pcr=$PCR_FNAME                              \
                        --pcr-list=@@MENDER/LUKS_TPM_PCR_ALG@@:$PCRS

  # create and load an object; sealed to policy
  tpm2_createprimary -Q --hierarchy=@@MENDER/LUKS_TPM_HIERARCHY@@     \
                        --hash-algorithm=@@MENDER/LUKS_TPM_HASH_ALG@@ \
                        --key-algorithm=@@MENDER/LUKS_TPM_KEY_ALG@@   \
                        --key-context=$PRIMARY_CTX

  tpm2_create        -Q --attributes=$ATTRS                           \
                        --hash-algorithm=@@MENDER/LUKS_TPM_HASH_ALG@@ \
                        --public=$TPM_PUB_KEY                         \
                        --private=$TPM_PRIV_KEY                       \
                        --parent-context=$PRIMARY_CTX                 \
                        --policy=$POLICY_FNAME                        \
                        --sealing-input=$INFILE

  #TODO - try --key-context in tpm2_create and remove tpm2_load
  tpm2_load          -Q --public=$TPM_PUB_KEY                         \
                        --private=$TPM_PRIV_KEY                       \
                        --parent-context=$PRIMARY_CTX                 \
                        --key-context=$LOAD_CTX

  # make persistent
  tpm2_evictcontrol  -Q --hierarchy=@@MENDER/LUKS_TPM_HIERARCHY@@     \
                        --object-context=$LOAD_CTX                    \
                        @@MENDER/LUKS_TPM_KEY_INDEX@@
}

################################################################################
if [ "$#" -lt 1 ]; then
  usage
  fatal "no command(s) provided"
fi

CMD=""

while [ "$#" -gt 0 ]
do
  case $1 in
    "--pcrs"|"-p")    case $2 in
                        "none") PCRS=$PCRS_NONE
                                NONE=true
                                ;;
                        "min")  PCRS=$PCRS_MIN
                                ;;
                        "max")  PCRS=$PCRS_MAX
                                ;;
                        *)      PCRS="$2"
                                ;;
                      esac             ; shift ; shift ;;
    "--infile"|"-i")  INFILE="$2"      ; shift ; shift ;;
    "--outfile"|"-o") OUTFILE="$2"     ; shift ; shift ;;
    "--debug"|"-d")   DEBUG_FLAG=true  ; shift         ;;
    "--read"|"-r")    CMD="_read_tpm2" ; shift         ;;
    "--clear"|"-c")   CMD="_clear_tpm2"; shift         ;;
    "--write"|"-w")   CMD="_write_tpm2"; shift         ;;
    "--help"|"-h")    usage            ; exit 0        ;;
    *)                usage; fatal "invalid argument: $1"
  esac
done

echo "$PCRS" | grep -E -q "^[[:digit:]]+(,[[:digit:]]+)*$" || fatal "$PCRS : invalid PCR format; must be a numerical, comma seperated list"

# suppress all output by default...
# --read needs to reliably pipe stdout to cryptsetup --key-file=-
$DEBUG_FLAG || exec 2>&1 >/dev/null

cleanup

eval $CMD

exit
