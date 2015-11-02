# Benchmark suite for Hadoop examples
# Some of the options are based in HiBench https://github.com/intel-hadoop/HiBench

# Downalod the Hadoop examples jar
# we use the same jar for all executions of the same MR API version, to compare the same code
BENCH_REQUIRED_FILES["Hadoop-Examples"]="$ALOJA_PUBLIC_HTTP/aplic2/tarballs/Hadoop-Examples.tar.gz"
#BENCH_REQUIRED_FILES["Hadoop-Tests"]="http://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/2.7.1/hadoop-common-2.7.1-tests.jar"


[ ! "$BENCH_LIST" ] && BENCH_LIST="wordcount terasort teravalidate"

# Some benchmark specific validations
[ ! "$BENCH_DATA_SIZE" ] && die "BENCH_DATA_SIZE is not set, cannot continue"


# regular expression for grep
if [ ! "$GREP_REGEX" ]; then
  GREP_REGEX=".oo." 
fi


# Load Hadoop functions
source_file "$ALOJA_REPO_PATH/shell/common/common_hadoop.sh"
set_hadoop_requires

# Set the Hadoop examples jar (it is not compatible between MR v1 and v2
if [ "$(get_hadoop_major_version)" == "2" ]; then
  examples_jar="$(get_local_apps_path)/Hadoop-Examples/hadoop-mapreduce-examples-2.7.1.jar"
  #examples_jar="\$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar"
  tests_jar="$(get_local_apps_path)/Hadoop-Examples/hadoop-common-2.7.1-tests.jar"
else
  examples_jar="$(get_local_apps_path)/Hadoop-Examples/hadoop-examples-1.2.1.jar"
  tests_jar="$(get_local_apps_path)/Hadoop-Examples/hadoop-test-1.2.1.jar"
fi

benchmark_suite_config() {
  initialize_hadoop_vars
  prepare_hadoop_config "$NET" "$DISK" "$BENCH_SUITE"
  restart_hadoop
}

benchmark_suite_run() {
  logger "INFO: Running $BENCH_SUITE"

  local bench_suite_validates="$(get_bench_validates)"

  for bench in $BENCH_LIST ; do

    bench_input_dir="$BENCH_SUITE/$bench/input"
    bench_output_dir="$BENCH_SUITE/$bench/output"

    # Prepare run (in case defined)
    function_call "benchmark_prepare_$bench"

    # Bench Run
    function_call "benchmark_$bench"

    # Validate (eg. teravalidate)
    function_call "benchmark_validate_$bench"

  done

  logger "INFO: DONE executing $BENCH_SUITE"
}

benchmark_suite_save() {
  logger "DEBUG: No specific ${FUNCNAME[0]} defined for $BENCH_SUITE"
}

benchmark_suite_cleanup() {
  if [ "$clusterType" != "PaaS" ]; then
    stop_hadoop
  fi
}

# wrapper for randomtextwriter
benchmark_prepare_wordcount() {
  benchmark_randomtextwriter
}

benchmark_randomtextwriter() {
  local bench_name="${FUNCNAME[0]##*benchmark_}"
  logger "INFO: Running $bench_name"

  logger "INFO: making sure $bench_input_dir dir is empty first"
  hadoop_delete_path "$bench_name" "$bench_input_dir"

  if [ "$(get_hadoop_major_version)" == "2" ]; then
    local extra_configs="-D mapreduce.randomtextwriter.totalbytes=$BENCH_DATA_SIZE"
  else
    local extra_configs="-D test.randomtextwrite.total_bytes=$BENCH_DATA_SIZE"
  fi

  execute_hadoop_new "$bench_name" "jar $examples_jar randomtextwriter $(get_hadoop_job_config) $extra_configs $bench_input_dir" "time"
}

benchmark_wordcount() {
  local bench_name="${FUNCNAME[0]##*benchmark_}"
  logger "INFO: Running $bench_name"

  logger "INFO: making sure $bench_output_dir dir is empty first"
  hadoop_delete_path "$bench_name" "$bench_output_dir"

  local extra_configs
  extra_configs+=" -D mapreduce.inputformat.class=org.apache.hadoop.mapreduce.lib.input.SequenceFileInputFormat"
  extra_configs+=" -D mapreduce.outputformat.class=org.apache.hadoop.mapreduce.lib.output.SequenceFileOutputFormat"
  extra_configs+=" -D mapreduce.job.inputformat.class=org.apache.hadoop.mapreduce.lib.input.SequenceFileInputFormat"
  extra_configs+=" -D mapreduce.job.outputformat.class=org.apache.hadoop.mapreduce.lib.output.SequenceFileOutputFormat"

  execute_hadoop_new "$bench_name" "jar $examples_jar wordcount $(get_hadoop_job_config) $extra_configs $bench_input_dir $bench_output_dir" "time"
}

# wrapper for teragen
benchmark_prepare_terasort() {
  benchmark_teragen
}

benchmark_teragen() {
  local bench_name="${FUNCNAME[0]##*benchmark_}"
  logger "INFO: Running $bench_name"

  logger "INFO: making sure $bench_input_dir dir is empty first"
  hadoop_delete_path "$bench_name" "$bench_input_dir"

  # Teragen uses 100 byte rows, need to divide the datasize
  local teragen_data_size="$(( $BENCH_DATA_SIZE /100 ))"
  [ ! "$teragen_data_size" ] && die "Cannot determine teragen data size"

  execute_hadoop_new "$bench_name" "jar $examples_jar teragen $(get_hadoop_job_config) $teragen_data_size $bench_input_dir" "time"
}

benchmark_terasort() {
  local bench_name="${FUNCNAME[0]##*benchmark_}"
  logger "INFO: Running $bench_name"

  logger "INFO: making sure $bench_output_dir dir is empty first"
  hadoop_delete_path "$bench_name" "$bench_output_dir"

  execute_hadoop_new "$bench_name" "jar $examples_jar terasort $(get_hadoop_job_config) $bench_input_dir $bench_output_dir" "time"
}

# wrapper for teravalidate
benchmark_validate_terasort() {
  benchmark_teravalidate
}

benchmark_teravalidate() {
  local bench_name="${FUNCNAME[0]##*benchmark_}"
  logger "INFO: Running $bench_name"

  local teravalidate_input_dir="$bench_output_dir"
  local teravalidate_output_dir="$BENCH_SUITE/$bench/validate_output"

  logger "INFO: making sure $bench_output_dir dir is empty first"
  hadoop_delete_path "$bench_name" "$teravalidate_output_dir"

  execute_hadoop_new "$bench_name" "jar $examples_jar teravalidate $(get_hadoop_job_config) $teravalidate_input_dir $teravalidate_output_dir" "time"
}

# wrapper for sort
benchmark_prepare_sort() {
  benchmark_randomtextwriter
}

benchmark_sort() {
  local bench_name="${FUNCNAME[0]##*benchmark_}"
  logger "INFO: Running $bench_name"

  logger "INFO: making sure $bench_output_dir dir is empty first"
  hadoop_delete_path "$bench_name" "$bench_output_dir"

  local extra_configs
  extra_configs+=" -outKey org.apache.hadoop.io.Text"
  extra_configs+=" -outValue org.apache.hadoop.io.Text"

  execute_hadoop_new "$bench_name" "jar $examples_jar sort $(get_hadoop_job_config) $extra_configs $bench_input_dir $bench_output_dir" "time"
}

# wrapper for TestDFSIO prepare
benchmark_prepare_dfsio() {
  
  logger "INFO: Nothing to prepare for $bench_name"

  # TestDFSIO input parameters
  # number of files to write/read
  if [ ! "$DFSIO_NUM_FILES" ]; then
    DFSIO_NUM_FILES="10" 
  fi

  # size of each file in MB
  if [ ! "$DFSIO_FILE_SIZE" ]; then
    DFSIO_FILE_SIZE="10" 
  fi
  # execute the write dfsio to generate files for the read dfsio
  benchmark_dfsio_write
  benchmark_dfsio_read
  
}

# wrapper for TestDFSIO
benchmark_dfsio_write() {
  local bench_name="${FUNCNAME[0]##*benchmark_}"
  logger "INFO: Running $bench_name"

  logger "INFO: making sure $bench_output_dir dir is empty first"
  hadoop_delete_path "$bench_name" "$bench_output_dir"

  #local extra_configs
  # extra_configs+=" -outKey org.apache.hadoop.io.Text"
  # extra_configs+=" -outValue org.apache.hadoop.io.Text"

  execute_hadoop_new "$bench_name" "jar $tests_jar TestDFSIO $(get_hadoop_job_config) -write -nrFiles $DFSIO_NUM_FILES -fileSize $DFSIO_FILE_SIZE $bench_output_dir" "time"
}

benchmark_dfsio_read() {
  local bench_name="${FUNCNAME[0]##*benchmark_}"
  logger "INFO: Running $bench_name"

  logger "INFO: making sure $bench_output_dir dir is empty first"
  hadoop_delete_path "$bench_name" "$bench_output_dir"

  #local extra_configs
  # extra_configs+=" -outKey org.apache.hadoop.io.Text"
  # extra_configs+=" -outValue org.apache.hadoop.io.Text"

  execute_hadoop_new "$bench_name" "jar $tests_jar TestDFSIO $(get_hadoop_job_config) -read -nrFiles $DFSIO_NUM_FILES -fileSize $DFSIO_FILE_SIZE $bench_output_dir" "time"
}

# wrapper for grep
benchmark_prepare_grep() {
  benchmark_randomtextwriter
}

benchmark_grep() {
  local bench_name="${FUNCNAME[0]##*benchmark_}"
  logger "INFO: Running $bench_name"

  logger "INFO: making sure $bench_output_dir dir is empty first"
  hadoop_delete_path "$bench_name" "$bench_output_dir"

  execute_hadoop_new "$bench_name" "jar $examples_jar grep $(get_hadoop_job_config) $bench_input_dir $bench_output_dir $GREP_REGEX" "time"
}
