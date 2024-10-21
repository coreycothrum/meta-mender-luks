#!/bin/sh
set -eu

PASSWORD=""
KEY_SLOT="@@MENDER/LUKS_PRIMARY_KEY_SLOT@@"
TMP_KEY_FILE="@@MENDER/LUKS_TMP_DIR@@/luks/.luks.new.key"
LUK_KEY_FILE="@@MENDER/LUKS_LEGACY_KEY_FILE@@"
DPATH="/dev/disk/by-partuuid"
CMD=""

################################################################################
function usage {
  log "mender-luks-util [COMMAND] [OPTIONS]"
  log "Commands:"
  log "  validate  : check if supplied passphrase is a LUKS key"
  log "  password  : set primary key passphrase"
  log "  brick     : brick LUKS partitions"
  log "  reencrypt : generate new/unique LUKS master keys"
  log ""
  log "Options:"
  log "  --recovery            : set recovery key passphrase instead of primary"
  log "  --random              : randomly generate passphrase"
  log "  --prompt              : prompt for passphrase"
  log "  --password  <password>: set passphrase to this explict string"
  log "  --key-file  <file>    : set passphrase to this key-file"
}

log() {
  echo "$@"
}

function fatal {
  echo $@
  exit 1
}

function cleanup {
  if [ -f "$TMP_KEY_FILE" ]; then
    shred -u $TMP_KEY_FILE
  fi
}
trap cleanup EXIT

function _ask_password {
  if [ -z "$PASSWORD" ]; then
    read -s -p "enter new passphrase:   " && echo ""
    PASSWORD=$REPLY
    read -s -p "reenter new passphrase: " && echo ""
    PASSWORD_TEST=$REPLY
    if [ ! "$PASSWORD" == "$PASSWORD_TEST" ]; then
      fatal "passwords did not match"
    fi
  fi

  mkdir -p $(dirname     $TMP_KEY_FILE)
  echo  -n "$PASSWORD" > $TMP_KEY_FILE

  if [ ! -f "$TMP_KEY_FILE" ]; then
    fatal "key-file ($TMP_KEY_FILE) does not exist"
  fi
}

function _check_password {
  _ask_password

  local cl_out="$(echo -n $PASSWORD | cracklib-check)"

  if ! grep -qi ": OK" <<< $cl_out; then
    log                   "$cl_out"
    return 1
  fi

  if grep -qi "@@MENDER/LUKS_PASSWORD@@" $TMP_KEY_FILE; then
    log "passphrase is too similar to default password( @@MENDER/LUKS_PASSWORD@@ )"
    return 1
  fi

  if grep -qi "$PASSWORD" <<< "@@MENDER/LUKS_PASSWORD@@"; then
    log "passphrase is too similar to default password( @@MENDER/LUKS_PASSWORD@@ )"
    return 1
  fi
}

################################################################################
function _brick {
  for disk in `ls $DPATH`
  do
    local dev="$DPATH/$disk"
    local part=$(echo $(basename $(readlink $dev)) | grep -Eo '[0-9]+' | tail -1)
    local header=$( find @@MENDER/LUKS_HEADER_DIR@@ -iname "*$part*" )

    if [ ! -z "$header" ]; then
      if cryptsetup isLuks   $dev --header $header; then
        set +e
        cryptsetup luksErase $dev --header $header
        set -e
      fi
    fi
  done

  shred -u @@MENDER/LUKS_HEADER_DIR@@/*
}

function _validate_password {
  _ask_password

  for disk in `ls $DPATH`
  do
    local dev="$DPATH/$disk"
    local part=$(echo $(basename $(readlink $dev)) | grep -Eo '[0-9]+' | tail -1)
    local header=$( find @@MENDER/LUKS_HEADER_DIR@@ -iname "*$part*" )

    if [ ! -z "$header" ]; then
      if cryptsetup isLuks $dev --header $header; then
        set +e
        if ! cryptsetup luksOpen $dev --test-passphrase --header $header --key-file $TMP_KEY_FILE; then
	  fatal "not a known passphrase for $dev"
	fi
        set -e
      fi
    fi
  done
}

function _set_password {
  _check_password || exit 1

  for disk in `ls $DPATH`
  do
    local dev="$DPATH/$disk"
    local part=$(echo $(basename $(readlink $dev)) | grep -Eo '[0-9]+' | tail -1)
    local header=$( find @@MENDER/LUKS_HEADER_DIR@@ -iname "*$part*" )

    if [ ! -z "$header" ]; then
      if cryptsetup isLuks $dev --header $header; then
         set +e
         cryptsetup luksAddKey    $dev --header $header --key-slot $KEY_SLOT --key-file $LUK_KEY_FILE $TMP_KEY_FILE
         cryptsetup luksChangeKey $dev --header $header --key-slot $KEY_SLOT --key-file $LUK_KEY_FILE $TMP_KEY_FILE
slots=($(cryptsetup luksDump      $dev --header $header --key-slot $KEY_SLOT --key-file               $TMP_KEY_FILE --dump-json-metadata | jq -r '.keyslots | keys | @sh' | tr -d [:alpha:][:punct:]))
         for slot in "${slots[@]}"; do
           if   [ "$slot" == "@@MENDER/LUKS_PRIMARY_KEY_SLOT@@"  ]; then :
           elif [ "$slot" == "@@MENDER/LUKS_RECOVERY_KEY_SLOT@@" ]; then :
           else
             cryptsetup luksKillSlot $dev $slot --header $header --key-file $TMP_KEY_FILE
           fi
         done
        set -e
      fi
    fi
  done

  mv -T $TMP_KEY_FILE $LUK_KEY_FILE
  chmod 400           $LUK_KEY_FILE
}

function _encrypt {
  _check_password || exit 1

  fatal "#TODO _encrypt() not implemented"
}

function _reencrypt {
  for disk in `ls $DPATH`
  do
    local dev="$DPATH/$disk"
    local part=$(echo $(basename $(readlink $dev)) | grep -Eo '[0-9]+' | tail -1)
    local header=$( find @@MENDER/LUKS_HEADER_DIR@@ -iname "*$part*" )

    if [ ! -z "$header" ]; then
      if cryptsetup isLuks $dev --header $header; then
        cryptsetup reencrypt  $dev          \
                   --key-slot $KEY_SLOT     \
                   --key-file $LUK_KEY_FILE \
                   --header   $header       \
                   --progress-frequency 30
      fi
    fi
  done
}

function _gen_random_password {
  while true; do
    PASSWORD=`head /dev/urandom | sha512sum | cut -d ' ' -f 1 | tr -d '\n'`
    _check_password && return 0
  done

  fatal "failed to generate sufficient random password"
}
################################################################################
if [ "$#" -lt 1 ]; then
  usage
  fatal "no command(s) provided"
fi

while [ "$#" -gt 0 ]
do
  case $1 in
    "--recovery")  KEY_SLOT=@@MENDER/LUKS_RECOVERY_KEY_SLOT@@              \
	           LUK_KEY_FILE="@@MENDER/LUKS_LEGACY_KEY_FILE@@.recovery" \
	                                    ; shift         ;;
    "--prompt")    PASSWORD=""              ; shift         ;;
    "--password")  PASSWORD="$2"            ; shift ; shift ;;
    "--key-file")  PASSWORD=$(cat $2)       ; shift ; shift ;;
    "--random")    _gen_random_password     ; shift         ;;
    "password")    CMD="_set_password"      ; shift         ;;
    "encrypt")     CMD="_encrypt"           ; shift         ;;
    "reencrypt")   CMD="_reencrypt"         ; shift         ;;
    "brick")       CMD="_brick"             ; shift         ;;
    "validate")    CMD="_validate_password" ; shift         ;;
    "--help"|"-h") usage                    ; exit 0        ;;
    *)             usage; fatal "invalid argument: $1"
  esac
done

eval $CMD

exit
