template: parameter: {
	name: "vela-logs",
	namespace: "vela-system",

	pod_sd_mode: "custom",
	field_selector: "metadata.namespace=\(namespace)"

	extract_mode: "klog"
	redirect_unknown_logs: true

	output_field:     "parsed"
	output_type:      "loki"
	loki_healthcheck: false
	loki_user_labels: {
		job: "vela_logs"
		env: "prod"
	}
}
