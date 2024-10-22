#!/usr/bin/bash
################################################################################
set -eu
exec 3>&1

source mender-luks-tpm2-vars.sh

WORKDIR="$(mktemp --directory)"

INFILE="@@MENDER/LUKS_LEGACY_KEY_FILE@@"
OUTFILE="/proc/self/fd/1"

DEBUG=false

PCRS="${TPM_PCRS_UNSEAL}"
NONE=false

################################################################################
################################################################################
################################################################################
function usage {
  echo "                                                                                                 "
  echo "mender-luks-tpm2-util.sh [options] <command>                                                     "
  echo "  options:                                                                                       "
  echo "    --help    | -h           # display this prompt                                               "
  echo "    --debug   | -d           # do not suppress output; NOTE: may interfere with --read output    "
  echo "    --pcrs    | -p PCR_LIST  # PCR values to seal/unseal with                                    "
  echo "                             # PCR_LIST options :                                                "
  echo "                             #   unseal           : $TPM_PCRS_UNSEAL # w/ userwithauth attribute "
  echo "                             #     seal (default) : $TPM_PCRS_SEAL                               "
  echo "                             #   N1,N2,..,NN      : numerical, comma separated list              "
  echo "    --infile  | -i FILENAME  # read/use LUKS key from this file                                  "
  echo "                             # default: @@MENDER/LUKS_LEGACY_KEY_FILE@@                          "
  echo "    --outfile | -o FILENAME  # write LUKS key (output of --read) to this file                    "
  echo "                             # default: stdout (/proc/self/fd/1)                                 "
  echo "                             # !!! WARNING setting this creates a file that may persist !!!      "
  echo "                             # !!! YOU ARE RESPONSIBLE FOR MANUALLY DELETING THIS FILE  !!!      "
  echo "  commands:                                                                                      "
  echo "    --clear   | -c           # clear  LUKS key from TPM2                                         "
  echo "    --write   | -w           # write  LUKS key to   TPM2 from stored keyfile                     "
  echo "    --read    | -r           # output LUKS key from TPM2, or  stored keyfile on TPM2 failure     "
  echo "                                                                                                 "
  echo "  Examples:                                                                                      "
  echo "    mender-luks-tpm2-util.sh --write                                                             "
  echo "    mender-luks-tpm2-util.sh --write --pcrs unseal                                               "
  echo "    mender-luks-tpm2-util.sh --write --pcrs 0,3,5 --infile /tmp/keyfile                          "
  echo "                                                                                                 "
}

################################################################################
function fatal {
  echo $@ 1>&3
  exit 1
}

################################################################################
function cleanup {
  if [[   -d  "${WORKDIR}" ]]; then
    find      "${WORKDIR}" -type f -exec shred --remove {} \;
    rm   -fr  "${WORKDIR}"
  fi
}
trap cleanup EXIT

################################################################################
################################################################################
################################################################################
function _clear_tpm2 {
  # do last; it may fail if there is no object to clear
  tpm2_evictcontrol -Q --hierarchy=${TPM_HIERARCHY} --object-context=${TPM_KEY_INDEX}
}

################################################################################
function _read_tpm2 {
  local PCR_ARRAY=( $PCRS $TPM_PCRS_SEAL $TPM_PCRS_UNSEAL )
  for P in "${PCR_ARRAY[@]}"
  do
    if   tpm2_unseal -Q --object-context=${TPM_KEY_INDEX}                                2>&1 >/dev/null; then
         tpm2_unseal -Q --object-context=${TPM_KEY_INDEX}                                1>&3 >$OUTFILE ; return
    elif tpm2_unseal -Q --object-context=${TPM_KEY_INDEX} --auth=pcr:${TPM_PCR_ALG}:${P} 2>&1 >/dev/null; then
         tpm2_unseal -Q --object-context=${TPM_KEY_INDEX} --auth=pcr:${TPM_PCR_ALG}:${P} 1>&3 >$OUTFILE ; return
    fi
  done

  [[ -f "${INFILE}" ]] && cat $INFILE 1>&3 >$OUTFILE && return

  fatal "failed to unseal TPM2"
}

################################################################################
function _write_tpm2 {
  # NOOP if trying to write the same key at the same seal level
  set +e
  local KEY=$(tpm2_unseal -Q --object-context=${TPM_KEY_INDEX} --auth=pcr:${TPM_PCR_ALG}:${PCRS} 2>/dev/null)
  set -e
  test $? && test "$KEY" == "$(cat ${INFILE})" && exit

  local KSIZE="$(wc -c ${INFILE} | cut -d ' ' -f1)"
  local MSIZE="${TPM_KEY_SIZE_MAX}"
  local ATTRS="${TPM_ATTRIBUTES}"

  mkdir -p       "${WORKDIR}"
  local PCR_FILE="${WORKDIR}/.pcrs"
  local POLICY_FILE="${WORKDIR}/.policy"
  local PRIMARY_CTX="${WORKDIR}/.primary.ctx"
  local LOAD_CTX="${WORKDIR}/.load.ctx"
  local PUB_KEY="${WORKDIR}/.key.pub"
  local PRI_KEY="${WORKDIR}/.key.priv"

  [[ "${NONE}"   == true       ]] && ATTRS="${ATTRS}|userwithauth"
  [[ "${KSIZE}" -le "${MSIZE}" ]] || fatal "key in ${INFILE} is > max allowed (${MSIZE})"

  _clear_tpm2 || true

  tpm2_pcrread       -Q ${TPM_PCR_ALG}:${PCRS}            \
                        --output=${PCR_FILE}

  tpm2_createpolicy  -Q --policy-pcr                      \
                        --policy=${POLICY_FILE}           \
                        --pcr=${PCR_FILE}                 \
                        --pcr-list=${TPM_PCR_ALG}:${PCRS}

  # create and load an object; sealed to policy
  tpm2_createprimary -Q --hierarchy=${TPM_HIERARCHY}      \
                        --hash-algorithm=${TPM_HASH_ALG}  \
                        --key-algorithm=${TPM_KEY_ALG}    \
                        --key-context=${PRIMARY_CTX}

  tpm2_create        -Q --attributes=${ATTRS}             \
                        --hash-algorithm=${TPM_HASH_ALG}  \
                        --public=${PUB_KEY}               \
                        --private=${PRI_KEY}              \
                        --parent-context=${PRIMARY_CTX}   \
                        --policy=${POLICY_FILE}           \
                        --sealing-input=${INFILE}

  #TODO - try --key-context in tpm2_create and remove tpm2_load
  tpm2_load          -Q --public=${PUB_KEY}               \
                        --private=${PRI_KEY}              \
                        --parent-context=${PRIMARY_CTX}   \
                        --key-context=${LOAD_CTX}

  # make persistent
  tpm2_evictcontrol  -Q --hierarchy=${TPM_HIERARCHY}      \
                        --object-context=${LOAD_CTX}      \
                        ${TPM_KEY_INDEX}
}

################################################################################
################################################################################
################################################################################
[[ "$#" -lt 1 ]] && usage

CMD=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    "--pcrs"|"-p")    case $2 in
                        "unseal" | "none" | "min") PCRS="${TPM_PCRS_UNSEAL}"
                                                   NONE=true
                                                   ;;
                          "seal"          | "max") PCRS="${TPM_PCRS_SEAL}"
                                                   ;;
                        *)                         PCRS="$2"
                                                   ;;
                      esac             ; shift ; shift ;;
    "--infile"|"-i")  INFILE="$2"      ; shift ; shift ;;
    "--outfile"|"-o") OUTFILE="$2"     ; shift ; shift ;;
    "--debug"|"-d")   DEBUG=true       ; shift         ;;
    "--read"|"-r")    CMD="_read_tpm2" ; shift         ;;
    "--clear"|"-c")   CMD="_clear_tpm2"; shift         ;;
    "--write"|"-w")   CMD="_write_tpm2"; shift         ;;
    "--help"|"-h")    usage            ; exit 0        ;;
    *)                usage; fatal "invalid argument: $1"
  esac
done

grep -E -q "^[[:digit:]]+(,[[:digit:]]+)*$" <(echo "${PCRS}") || fatal "${PCRS}: invalid PCR format"
# suppress all output by default...
# --read needs to reliably pipe stdout to cryptsetup --key-file=-
[[ "${DEBUG}" == true ]] || exec 2>&1 >/dev/null

eval $CMD

################################################################################
