#!/bin/sh
set -e

PASSWORD=""
KEY_SLOT="@@MENDER/LUKS_PRIMARY_KEY_SLOT@@"
TMP_KEY_FILE="@@MENDER/LUKS_TMP_DIR@@/luks/.luks.new.key"
LUK_KEY_FILE="@@MENDER/LUKS_KEY_FILE@@"
DPATH="/dev/disk/by-path"
CMD=""

################################################################################
function usage {
  echo "mender-luks-util [COMMAND] [OPTIONS]"
  echo "Commands:"
  echo "  validate  : check if supplied passphrase is a LUKS key"
  echo "  password  : set primary key passphrase"
  echo "  brick     : brick LUKS partitions"
  echo "  reencrypt : generate new/unique LUKS master keys"
  echo ""
  echo "Options:"
  echo "  --recovery            : set recovery key passphrase instead of primary"
  echo "  --random              : randomly generate passphrase"
  echo "  --prompt              : prompt for passphrase"
  echo "  --password  <password>: set passphrase to this explict string"
  echo "  --key-file  <file>    : set passphrase to this key-file"
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

function _enforce_password {
  _ask_password

  local cl_out="$(echo -n $PASSWORD | cracklib-check)"

  if ! grep -qi ": OK" <<< $cl_out; then
    fatal "passphrase   :  $cl_out"
  fi

  if grep -qi "@@MENDER/LUKS_PASSWORD@@" $TMP_KEY_FILE; then
    fatal "passphrase is too similar to default password( @@MENDER/LUKS_PASSWORD@@ )"
  fi

  if grep -qi "$PASSWORD" <<< "@@MENDER/LUKS_PASSWORD@@"; then
    fatal "passphrase is too similar to default password( @@MENDER/LUKS_PASSWORD@@ )"
  fi
}

################################################################################
function _brick {
  for disk in `ls $DPATH`
  do
    local dev="$DPATH/$disk"
    local part=$( echo $disk | rev | cut -d '-' -f1 | rev )
    local header=$( find @@MENDER/LUKS_HEADER_DIR@@ -iname "*$part*" )

    if [ ! -z "$header" ]; then
      if cryptsetup isLuks --header $header $dev; then
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
    local part=$( echo $disk | rev | cut -d '-' -f1 | rev )
    local header=$( find @@MENDER/LUKS_HEADER_DIR@@ -iname "*$part*" )

    if [ ! -z "$header" ]; then
      if cryptsetup isLuks --header $header $dev; then
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
  _enforce_password

  for disk in `ls $DPATH`
  do
    local dev="$DPATH/$disk"
    local part=$( echo $disk | rev | cut -d '-' -f1 | rev )
    local header=$( find @@MENDER/LUKS_HEADER_DIR@@ -iname "*$part*" )

    if [ ! -z "$header" ]; then
      if cryptsetup isLuks --header $header $dev; then
        set +e
        cryptsetup luksAddKey    $dev --header $header --key-slot $KEY_SLOT --key-file @@MENDER/LUKS_KEY_FILE@@ $TMP_KEY_FILE 2>&1 >/dev/null
        cryptsetup luksChangeKey $dev --header $header --key-slot $KEY_SLOT --key-file @@MENDER/LUKS_KEY_FILE@@ $TMP_KEY_FILE
        set -e
      fi
    fi
  done

  mv -T $TMP_KEY_FILE $LUK_KEY_FILE
  chmod 400           $LUK_KEY_FILE
}

function _reencrypt {
  for disk in `ls $DPATH`
  do
    local dev="$DPATH/$disk"
    local part=$( echo $disk | rev | cut -d '-' -f1 | rev )
    local header=$( find @@MENDER/LUKS_HEADER_DIR@@ -iname "*$part*" )

    if [ ! -z "$header" ]; then
      if cryptsetup isLuks --header $header $dev; then
        set +e
        cryptsetup --key-file $LUK_KEY_FILE \
                   --header   $header       \
                   reencrypt  $dev
        set -e
      fi
    fi
  done
}

function _encrypt {
  _enforce_password

  fatal "#TODO _encrypt() not implemented"
}
################################################################################
if [ "$#" -lt 1 ]; then
  usage
  fatal "no command(s) provided"
fi

while [ "$#" -gt 0 ]
do
  case $1 in
    "--recovery")  KEY_SLOT=@@MENDER/LUKS_RECOVERY_KEY_SLOT@@       \
	           LUK_KEY_FILE="@@MENDER/LUKS_KEY_FILE@@.recovery" \
	                                    ; shift         ;;
    "--prompt")    PASSWORD=""              ; shift         ;;
    "--password")  PASSWORD="$2"            ; shift ; shift ;;
    "--key-file")  PASSWORD=$(cat $2)       ; shift ; shift ;;
    "--random")    PASSWORD=`head /dev/urandom | sha512sum | cut -d ' ' -f 1 | tr -d '\n'` \
	                                    ; shift         ;;
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
