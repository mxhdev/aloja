

# Known issues and how to solve them

# The following errors might occur depending on how the script is used

# PROBLEM: Executor: JDBC / Thrift server connection refused
# SOLUTION: Increase sleep (waiting for hive server to start) to a bigger value (i.e. 120)
 
# PROBLEM: Executor: JDBC OutOfMemory error when executing the map reduce job for each query (especially the query at position 11)
# SOLUTION: Increase HiveServer2 JDBC memory in executor.urisuffix setting (see below)
# References
# 1: http://stackoverflow.com/questions/34873037/java-heap-size-memory-at-map-step-on-hive-sql, 
# 2: https://documentation.altiscale.com/heapsize-for-mappers-and-reducers
 # AND increase memory in HADOOP_CLIENT_OPTS (and/or HADOOP_OPTS) in the file hadoop-env.sh
 
# PROBLEM: Translator: Can't find table inside statistics file
# SOLUTION: Increase scale factor to at least 5 products, or use a predefined test (triples, bsbmrestest, 1000)

# The following problem solutions are already implemented.

# PROBLEM: OutOfMemory: PermGen
# SOLUTION1: Increase '-XX:MaxPermSize=128m' memory in HADOOP_OPTS variable of hadoop_env.sh
# SOLUTION2: Upgrade to Java 8+

# PROBLEM: Executor: Can't find table
# SOLUTION: Make sure the metastore of the hive cli and the thrift server are in the same directory (Defining a metastore in config/bench/config_files/hive1_conf_template/hive-site.xml should fix the problem)

# PROBLEM: run_monit and restart_monit don't terminate (common_benchmark)
# SOLUTION: Replace wait with sleep 5

# PROBLEM: Hadoop commands can't be used in DatasetCreator Spark jar file
# SOLUTION: Add hadoop path in common_spark

# Known Issues - end



# Scale factor
bsbm_products=50000
scale_ub=1
exec_engine=hive


# Spark parameters (used for DataSetCreator or query execution if exec_engine=spark)
driver_memory=8g
spark_master=local[*]

source_file "$ALOJA_REPO_PATH/shell/common/common_s2rdf.sh"


# import hive
# hive version is defined in conf/benchmarks_defaults.conf
source_file "$ALOJA_REPO_PATH/shell/common/common_hive.sh"
set_hive_requires

SPARK_VERSION="spark-1.6.1-bin-hadoop2.6"
source_file "$ALOJA_REPO_PATH/shell/common/common_spark.sh"
set_spark_requires

[ ! "$BENCH_LIST" ] && BENCH_LIST="bsbm"

# Delete all files from previous executions
rm -R $(get_local_apps_path)/s2rdf

# load data and queries
if [ $bsbm_products == "bsbmrestest" ]; then
	BENCH_REQUIRED_FILES["S2RDF"]="http://szene-limburg.de/s2rdf/s2rdf_bsbmrestest.tar.gz"
elif [ $bsbm_products == "triples" ]; then
	BENCH_REQUIRED_FILES["S2RDF"]="http://szene-limburg.de/s2rdf/s2rdf_triples.tar.gz"
elif [ $bsbm_products = 1000 ]; then
	BENCH_REQUIRED_FILES["S2RDF"]="http://szene-limburg.de/s2rdf/data1k.tar.gz"
else
	BENCH_REQUIRED_FILES["S2RDF"]="http://szene-limburg.de/s2rdf/s2rdf_DataGenerator.tar.gz"
  generate_data=1
fi

BENCH_REQUIRED_FILES["JDBC4RDF"]="http://szene-limburg.de/s2rdf/jdbc4rdf.tar.gz"


# Iterate the specified benchmarks in the suite
benchmark_suite_run() {
  logger "INFO: Running $BENCH_SUITE"

  for bench in $BENCH_LIST ; do

    # Prepare run (in case defined)
    function_call "benchmark_prepare_$bench"

    # Bench Run
    function_call "benchmark_$bench"

    # Validate (eg. teravalidate)
    #function_call "benchmark_validate_$bench"

    # Clean-up HDFS space (in case necessary)
    clean_HDFS "$bench_name" "$BENCH_SUITE"

  done

  logger "INFO: DONE executing $BENCH_SUITE"
}



benchmark_prepare_bsbm() {
  #cp /vagrant/hive-site.xml /scratch/local/aloja-bench_3/hive_conf/
  #mkdir /vagrant/test
  local bench_name="${FUNCNAME[0]##*benchmark_}_$exec_engine$bsbm_products"
  logger "INFO: Preparing $bench_name"

	if [ $generate_data ]; then
  	function_call "generate_bsbm"
		function_call "translate_bsbm"
	else
		# load data and queries in hdfs
		execute_hadoop_new "$bench_name" "fs -put $(get_local_apps_path)/s2rdf/bsbmrestest /tmp/hive/s2rdf"
		execute_hadoop_new "$bench_name" "fs -chmod -R 777 /tmp/hive/s2rdf"
	fi

  logger "INFO: Dataset size:"
  execute_hadoop_new "$bench_name" "fs -ls /tmp/hive/s2rdf"
  # $(get_local_apps_path)/s2rdf/bsbmtools-0.2.1/data.tsv /tmp/hive/s2rdf
  # execute_hadoop_new "$bench_name" "fs -copyToLocal /tmp/hive/s2rdf $(get_local_apps_path)/s2rdf/hdfs_backup"
  # du -hcs $(get_local_apps_path)/s2rdf/*

	# Copy hive-site.xml to hive and spark conf folder (for hive cli and hive/spark thrift server use same metastore)
  cp $(get_base_configs_path)/hive1_conf_template/hive-site.xml $(get_local_apps_path)/apache-hive-1.2.1-bin/conf/
	cp $(get_base_configs_path)/hive1_conf_template/hive-site.xml $(get_local_apps_path)/spark-1.6.1-bin-hadoop2.6/conf/

  # run hive import script
  execute_hive "$bench_name" "-hiveconf prepath='' -f $(get_local_apps_path)/s2rdf/loadScript.hql" "time"

	logger "INFO: Starting HiveServer2"
  if [ $exec_engine == "spark" ]; then
		# For Spark
		logger "INFO: Executing with spark"		
		execute_cmd_master "$bench_name" "cd $(get_local_apps_path)/$SPARK_VERSION/sbin; $(get_spark_exports) ./start-thriftserver.sh --master $spark_master --driver-memory $driver_memory &"
	else
		# For Hive
		#execute_cmd_master "$bench_name" "$(get_hive_exports) $HIVE_HOME/bin/hive --service hiveserver2 &&"
		logger "INFO: Executing with hive"
		local hive_exports="$(get_hive_exports)"
		local hive_bin="$HIVE_HOME/bin/hive"
		local hive_cmd="$hive_exports
	$hive_bin --service hiveserver2 &"
		eval $hive_cmd
	fi

	logger "INFO: Wait 30 seconds to get server started..."
	sleep 30

}

benchmark_suite_config() {

  initialize_hadoop_vars
  prepare_hadoop_config "$NET" "$DISK" "$BENCH_SUITE"
  start_hadoop

  initialize_hive_vars
  prepare_hive_config "$HIVE_SETTINGS_FILE" "$HIVE_SETTINGS_FILE_PATH"

  initialize_spark_vars
}

benchmark_bsbm() {
  logger "INFO: Running $BENCH_SUITE"
  
  chmod +rwx $(get_local_apps_path)/s2rdf/jdbc4rdf/jdbc4rdf_0.4.jar
  local bench_name="${FUNCNAME[0]##*benchmark_}_$exec_engine$bsbm_products"

  # edit the config file for increasing the memory. Passing this argument as command line modifier to jdbc4rdf will not work (only the first parameter until ; will be used)
  ## two >s means append line
  echo "executor.urisuffix=?mapreduce.map.memory.mb=8000;mapreduce.map.java.opts=-Xmx8000m;mapreduce.reduce.memory.mb=8000;mapreduce.reduce.java.opts=-Xmx8000m" >> $(get_local_apps_path)/s2rdf/jdbc4rdf/jdbc4rdf_vagrant.properties

  # default hive credentials: user=s2rdf, password= 
	# For using spark db.driver=spark has to be changed!
  execute_cmd_master "$bench_name" "$(get_java_home)/bin/java -jar $(get_local_apps_path)/s2rdf/jdbc4rdf/jdbc4rdf_0.4.jar exec $(get_local_apps_path)/s2rdf/jdbc4rdf/jdbc4rdf_vagrant.properties executor.queryfile=$(get_local_apps_path)/s2rdf/queries.txt db.driver=$exec_engine db.auth.user=s2rdf" "time"
  #execute_cmd_master "$bench_name" "$(get_java_home)/bin/java -jar $(get_local_apps_path)/s2rdf/jdbc4rdf/jdbc4rdf_0.4.jar exec $(get_local_apps_path)/s2rdf/jdbc4rdf/jdbc4rdf_vagrant.properties executor.queryfile=$(get_local_apps_path)/restest.txt db.driver=$exec_engine db.auth.user=s2rdf" "time"

  logger "INFO: DONE executing $BENCH_SUITE"

  logger "DEBUG: Creating backups at scratch/local"
  cp -R /scratch/attached/1/aloja-bench_3 /scratch/local/backup_s2rdf1
  cp -R /scratch/local/aloja-bench_3 /scratch/local/backup_s2rdf2
}

benchmark_suite_save() {
  logger "DEBUG: No specific ${FUNCNAME[0]} defined for $BENCH_SUITE"
}

benchmark_suite_cleanup() {
  # kill hiveserver2 since there is no command to stop it...
  kill -9 $(ps aux | grep '[j]ava' | awk '{print $2}')
  
  clean_hadoop
}


