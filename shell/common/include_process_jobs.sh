BASE_DIR=$(pwd)

source "$CUR_DIR/common/common.sh"
source "$CUR_DIR/common/import_functions.sh"

#set the path or use the default
if [ "$1" ] ; then
  IMPORT_DIR="$1"
else
  IMPORT_DIR="$CUR_DIR/../import-jobs"
fi

if [ "$2" ] ; then
  SHARE_DIR="$2"
else
  SHARE_DIR="$CUR_DIR/.."
fi

DONE_DIR="$IMPORT_DIR/DONE"
FAIL_DIR="$IMPORT_DIR/FAIL"

mkdir -p "$IMPORT_DIR" "$DONE_DIR" "$FAIL_DIR"

logger "DEBUG: IMPORT_DIR=$IMPORT_DIR"
