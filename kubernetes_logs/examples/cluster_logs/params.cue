template: parameter: {
	name:      "cluster-logs"
	namespace: "vector"

	output_type:      "loki"
	loki_healthcheck: false
	loki_user_labels: {
		job: "cluster_logs"
		env: "prod"
	}
}
