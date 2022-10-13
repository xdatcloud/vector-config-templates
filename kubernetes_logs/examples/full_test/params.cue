template: parameter: {
	name:         "spring-app"
	namespace:    "full-test"

	pd_sd_mode: "custom"
	label_selector: "app in (app1, app2)"

	extract_mode: "json"
	extract_custom_vrl: ".extras = parse_logfmt!(.parsed.extra_info)"
	redirect_unknown_logs: true
	filter_allow_keywords: ["allow_keyword_1", "allow_keyword_2"]
	filter_block_keywords: ["block_keyword_2", "allow_keyword_2"]
	filter_custom_vrl: "to_int!(.extras.level) > 200"

	output_type:      "loki"
	output_field:     "parsed"
	loki_healthcheck: false
	loki_user_labels: {
		job: "full_test"
		env: "prod"
	}
}
