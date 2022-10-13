template: parameter: {
	name:      "json-logs"
	namespace: "vector"

	pd_sd_mode:     "custom"
	label_selector: "app in (app1, app2)"

	extract_mode:          "json"
	redirect_unknown_logs: true

	output_type:      "loki"
	loki_healthcheck: false
	loki_user_labels: {
		job:   "json_logs"
		env:   "prod"
		level: "{{ parsed.level }}"
	}
}
