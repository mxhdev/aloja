# TPC-Hive version
source_file "$ALOJA_REPO_PATH/shell/common/common_hive.sh"
set_hive_requires

BENCH_REQUIRED_FILES["tpch-hive"]="$ALOJA_PUBLIC_HTTP/aplic2/tarballs/tpch-hive.tar.gz"

[ ! "$BENCH_LIST" ] && BENCH_LIST="$(seq -f "query%g" 1 22)"

# Some benchmark specific validations
[ ! "$TPCH_SCALE_FACTOR" ] && die "TPCH_SCALE_FACTOR is not set, cannot continue"

[ "$(get_hadoop_major_version)" != "2" ] && die "Need to use Hadoop v2"


# Load Hadoop functions
source_file "$ALOJA_REPO_PATH/shell/common/common_hadoop.sh"
set_hadoop_requires


benchmark_suite_config() {


  [ ! "$TPCH_SETTINGS_FILE_NAME" ] && export HIVE_SETTINGS_FILENAME="hive.settings"
  [ ! "$TPCH_DATA_DIR" ] && export TPCH_DATA_DIR=/tpch/tpch-generate
  BENCH_SAVE_PREPARE_LOCATION="${BENCH_LOCAL_DIR}${TPCH_DATA_DIR}"

  EXECUTE_TPCH=true
  TPCH_HOME=$(get_local_apps_path)/tpch-hive

  initialize_hadoop_vars
  prepare_hadoop_config "$NET" "$DISK" "$BENCH_SUITE"
  prepare_hive_config

  start_hadoop
}

benchmark_suite_run() {
  logger "INFO: Running $BENCH_SUITE"

  # TODO: review to generate data first time when DELETE_HDFS=0
  if [ "$DELETE_HDFS" == "1" ]; then
    generate_TPCH_data "prep_tpch" "$TPCH_SCALE_FACTOR"
  else
    logger "INFO: Reusing previous RUN TPCH data"
    #deleting old history files
    logger "INFO: delete old history files"
  fi

  for query in $BENCH_LIST ; do
    logger "INFO: RUNNING QUERY $query"
    execute_TPCH_query "$query"
  done

  logger "INFO: DONE executing $BENCH_SUITE"
}

benchmark_suite_save() {
  : # Empty
}

benchmark_suite_cleanup() {
  stop_hadoop
}

get_tpch_exports() {
  local to_export

  to_export="$(get_java_exports)
    $(get_hadoop_exports)
    $(get_hive_exports)
    export TPCH_SOURCE_DIR='$(get_local_apps_path)/tpch-hive';
    export TPCH_HOME='$TPCH_SOURCE_DIR';"

  echo -e "$to_export\n"
}

# $1 query number
# $2 table name
execute_TPCH_query() {

  local query=$1
  TABLE_NAME="tpch_bin_flat_orc_${TPCH_SCALE_FACTOR}"
  if [ ! -z $2 ]; then
    TABLE_NAME="$2"
  fi

  logger "INFO: # EXECUTING TPCH Q${query}"

  execute_hive "tpch-${query}" "-f ${TPCH_HOME}/sample-tpch-queries/tpch_${1}.sql --database ${TABLE_NAME}" "time"

  logger "INFO: # DONE TPCH Q${query}"
}

# $2 scale factor
generate_TPCH_data() {
  EXP=$(get_hive_exports)
  DATA_GENERATOR="tpch-setup.sh $2 $TPCH_DATA_DIR"

  if [ ! -f "${TPCH_HOME}/tpch-gen/target/tpch-gen-1.0-SNAPSHOT.jar" ]; then
    logger "INFO: Building TPCH data generator"
    logger "DEBUG: COMMAND: $EXP cd ${TPCH_HOME} && bash tpch-build.sh"
    time_cmd_master "$EXP cd ${TPCH_HOME} && bash tpch-build.sh" "$time_exec"
     if [ "${PIPESTATUS[0]}" -ne 0 ]; then
      logger "INFO: ERROR WHEN BUILDING DATA GENERATOR FOR TCPH, exiting..."
      exit 1;
     fi
  else
    logger "INFO: Data generator already built, skipping..."
  fi

  logger "INFO: # GENERATING TPCH DATA WITH SCALE FACTOR ${2}"
  logger "DEBUG: COMMAND: $EXP cd ${TPCH_HOME} && export TIMEFORMAT='Time data generator %R' && time $DATA_GENERATOR"

  time_cmd_master "$EXP cd ${TPCH_HOME} && bash $DATA_GENERATOR" "$time_exec"

  if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    logger "INFO: ERROR: GENERATING DATA FAILED, exiting..."
    exit 1
  fi
}
