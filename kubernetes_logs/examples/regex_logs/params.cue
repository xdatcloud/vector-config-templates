template: parameter: {
	name:      "regex-logs"
	namespace: "vector"

	pd_sd_mode:     "custom"
	label_selector: "app in (app1, app2)"

	extract_mode:          "regex"
	extract_regex:         "\\[(?P<timestamp>\\S+?)\\]\\[(?P<level>\\S+?\\] (?P<message>\\S+)"
	redirect_unknown_logs: true

	output_type:      "loki"
	output_field:     "parsed"
	loki_healthcheck: false
	loki_user_labels: {
		job:   "regex_logs"
		env:   "prod"
		level: "{{ parsed.level }}"
	}
}
