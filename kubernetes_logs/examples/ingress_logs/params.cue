template: parameter: {
	name:      "ingress-nginx"
	namespace: "kube-system"

	pod_sd_mode: "application"

	extract_mode:          "nginx"
	redirect_unknown_logs: true

	output_field:     "parsed"
	output_type:      "loki"
	loki_healthcheck: false
	loki_user_labels: {
		job: "ingress_logs"
		env: "prod"
	}
}
