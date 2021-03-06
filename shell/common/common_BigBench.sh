#BIG_BENCH SPECIFIC FUNCTIONS
source_file "$ALOJA_REPO_PATH/shell/common/common_hadoop.sh"
set_hadoop_requires

# Benchmark to test Hive installation and configurations
source_file "$ALOJA_REPO_PATH/shell/common/common_hive.sh"
set_hive_requires

BIG_BENCH_FOLDER="Big-Data-Benchmark-for-Big-Bench-master"
BIG_BENCH_CONF_DIR="BigBench_conf_template"

# Sets the required files to download/copy
set_BigBench_requires() {

  BENCH_REQUIRED_FILES["$BIG_BENCH_FOLDER"]="https://github.com/Aloja/Big-Data-Benchmark-for-Big-Bench/archive/master.zip"

  #also set the config here
  BENCH_CONFIG_FOLDERS="$BENCH_CONFIG_FOLDERS $BIG_BENCH_CONF_DIR"
}

# Helper to print a line with requiered exports
get_BigBench_exports() {
  local to_export

  to_export="$(get_hadoop_exports)
$(get_hive_exports)
USER_SETTINGS='$(get_BigBench_conf_dir)/userSettings.conf';
"

  echo -e "$to_export\n"
}

# Returns the the path to the hadoop binary with the proper exports
get_BigBench_cmd() {
  local BigBench_exports
  local BigBench_cmd

  BigBench_exports="$(get_BigBench_exports)"

  BigBench_cmd="$BigBench_exports\n$(get_local_apps_path)/$BIG_BENCH_FOLDER/bin/bigBench"

  echo -e "$BigBench_cmd"
}

# Performs the actual benchmark execution
# $1 benchmark name
# $2 command
# $3 if to time exec
execute_BigBench(){
  local bench="$1"
  local cmd="$2"
  local time_exec="$3"

  local BigBench_cmd="$(get_BigBench_cmd) $cmd"

  # Start metrics monitor (if needed)
  if [ "$time_exec" ] ; then
    save_disk_usage "BEFORE"
    restart_monit
    set_bench_start "$bench"
  fi

  logger "DEBUG: BigBench command:\n$BigBench_cmd"

  # Run the command and time it
  time_cmd_master "$BigBench_cmd" "$time_exec"

  # Stop metrics monitors and save bench (if needed)
  if [ "$time_exec" ] ; then
    set_bench_end "$bench"
    stop_monit
    save_disk_usage "AFTER"
    save_BigBench "$bench"
  fi
}

initialize_BigBench_vars() {
    :
    #BIG_BENCH_HOME="$(get_local_apps_path)/$BIG_BENCH_FOLDER"
}

# Sets the substitution values for the BigBench config
get_BigBench_substitutions() {

  cat <<EOF
s,##JAVA_HOME##,$(get_java_home),g;
s,##HADOOP_HOME##,$BENCH_HADOOP_DIR,g;
s,##JAVA_XMS##,$JAVA_XMS,g;
s,##JAVA_XMX##,$JAVA_XMX,g;
s,##JAVA_AM_XMS##,$JAVA_AM_XMS,g;
s,##JAVA_AM_XMX##,$JAVA_AM_XMX,g;
s,##LOG_DIR##,$HDD/BigBench_logs,g;
s,##REPLICATION##,$REPLICATION,g;
s,##MASTER##,$master_name,g;
s,##NAMENODE##,$master_name,g;
s,##TMP_DIR##,$HDD_TMP,g;
s,##HDFS_NDIR##,$HDFS_NDIR,g;
s,##HDFS_DDIR##,$HDFS_DDIR,g;
s,##MAX_MAPS##,$MAX_MAPS,g;
s,##MAX_REDS##,$MAX_REDS,g;
s,##IFACE##,$IFACE,g;
s,##IO_FACTOR##,$IO_FACTOR,g;
s,##IO_MB##,$IO_MB,g;
s,##PORT_PREFIX##,$PORT_PREFIX,g;
s,##IO_FILE##,$IO_FILE,g;
s,##BLOCK_SIZE##,$BLOCK_SIZE,g;
s,##PHYS_MEM##,$PHYS_MEM,g;
s,##NUM_CORES##,$NUM_CORES,g;
s,##CONTAINER_MIN_MB##,$CONTAINER_MIN_MB,g;
s,##CONTAINER_MAX_MB##,$CONTAINER_MAX_MB,g;
s,##MAPS_MB##,$MAPS_MB,g;
s,##REDUCES_MB##,$REDUCES_MB,g;
s,##AM_MB##,$AM_MB,g;
s,##BENCH_LOCAL_DIR##,$BENCH_LOCAL_DIR,g;
s,##HDD##,$HDD,g;
EOF
}

get_BigBench_conf_dir() {
  echo -e "$HDD/$BIG_BENCH_CONF_DIR"
}

prepare_BigBench_config() {

  logger "INFO: Preparing BigBench run specific config"
  $DSH "mkdir -p $(get_BigBench_conf_dir) && cp -r $(get_local_configs_path)/$BIG_BENCH_CONF_DIR/* $(get_BigBench_conf_dir)/;"

  # Get the values
  subs=$(get_BigBench_substitutions)
  $DSH "/usr/bin/perl -i -pe \"$subs\" $(get_BigBench_conf_dir)/userSettings.conf"

}