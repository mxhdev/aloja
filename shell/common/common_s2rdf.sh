generate_bsbm() {
  logger "INFO: Generating BSBM Data..."

  # Creating data with bsbm tool
  execute_cmd_master "$bench_name" "cd $(get_local_apps_path)/s2rdf/bsbmtools-0.2.1; export PATH=$PATH:$(get_java_home)/bin; java -cp bin:lib/* benchmark.generator.Generator -s nt -pc $bsbm_products -fn data"

	# Transform data in tab seperated values, shorten predicates to 20 characters
  execute_cmd_master "$bench_name" "python $(get_local_apps_path)/s2rdf/s2rdfconverter.py -fp $(get_local_apps_path)/s2rdf/bsbmtools-0.2.1/data.nt"

	# Put data file in hdfs
	execute_hadoop_new "$bench_name" "fs -mkdir -p /tmp/hive/s2rdf"
  execute_hadoop_new "$bench_name" "fs -put $(get_local_apps_path)/s2rdf/bsbmtools-0.2.1/data.tsv /tmp/hive/s2rdf"

	# Create VP tables
  logger "INFO: Running VP"
  execute_spark "$bench_name" "spark-submit --class runDriver --master local $(get_local_apps_path)/s2rdf/datasetcreator_2.10-1.2.jar /tmp/hive/s2rdf/ data.tsv VP $scale_ub"

	# Create SO tables
  logger "INFO: Running SO"
  execute_spark "$bench_name" "spark-submit --class runDriver --master local $(get_local_apps_path)/s2rdf/datasetcreator_2.10-1.2.jar /tmp/hive/s2rdf/ data.tsv SO $scale_ub"

	# Create OS tables
  logger "INFO: Running OS"
  execute_spark "$bench_name" "spark-submit --class runDriver --master local $(get_local_apps_path)/s2rdf/datasetcreator_2.10-1.2.jar /tmp/hive/s2rdf/ data.tsv OS $scale_ub"

	# Create SS tables
  logger "INFO: Running SS"
  execute_spark "$bench_name" "spark-submit --class runDriver --master local $(get_local_apps_path)/s2rdf/datasetcreator_2.10-1.2.jar /tmp/hive/s2rdf/ data.tsv SS $scale_ub"


	# create references to hive metastore
	execute_cmd_master "$bench_name" "cp -f ~/loadScript.hql $(get_local_apps_path)/s2rdf"

	# copy statistic files to working directory
  execute_cmd_master "$bench_name" "cp -f ~/stat_* $(get_local_apps_path)/s2rdf/stat"

	logger "INFO: Done gnerating BSBM Data!"

}

translate_bsbm() {
  logger "INFO: Generating BSBM Queries..."
	
	# make sure no old queries are still in the directory
	execute_cmd_master "$bench_name" "cd $(get_local_apps_path)/s2rdf/sparql; rm -r *"

	# generate sparql queries with bsbm testdriver (no warm up runs, 1 querymix)
	execute_cmd_master "$bench_name" "cd $(get_local_apps_path)/s2rdf/bsbmtools-0.2.1; export PATH=$PATH:$(get_java_home)/bin; java -cp bin:lib/* benchmark.testdriver.TestDriver -runs 1 -w 0 fp=$(get_local_apps_path)/s2rdf/sparql"

	logger "INFO: Translating SPARQL Queries..."
	# translate queries with s2rdf translator
	execute_cmd_master "$bench_name" "cd $(get_local_apps_path)/s2rdf; export PATH=$PATH:$(get_java_home)/bin; python translateBSBM.py -s sparql/ -t sql/ -u $scale_ub"

	# Copy new query file to main folder
	execute_cmd_master "$bench_name" "cd $(get_local_apps_path)/s2rdf; cp -f sql/compositeQueryFile.txt ./queries.txt"

}
