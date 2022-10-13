import ("strings")

"log-def": {
	type: "component"
	attributes: {}
}

template: {
	parameter: {
		// +usage=Config name, e.g. "default"
		name: string
		// +usage=Config namespace, e.g. "vector"
		namespace: string

		// +usage=Target config map namespace, default is "vector"
		targetConfigMapNamespace: *"vector" | string
		// +usage=Target config map name, default is "vector"
		targetConfigMapName: *"vector" | string

		// +usage=Specify policy to discovery pods, default is to collect logs on all pods in current cluster
		pod_sd_mode: *"cluster" | "namespace" | "application" | "custom"
		// +usage=Custom label selector to discovery pods
		label_selector?: string
		// +usage=Custom field selector to discovery pods
		field_selector?: string

		// +usage=Extract logs with built-in mode
		extract_mode?: "separator" | "json" | "logfmt" | "regex" | "nginx" | "apache" | "klog"
		// +usage=Extract logs into specified field
		extract_into: *"parsed" | string
		// +usage=Extract logs with specified delimiter, enabled while extract_mode == "separator"
		extract_separator: *"|" | string
		if extract_mode != _|_ {
			if extract_mode == "regex" {
				// +usage=Extract logs with specified pattern, enabled while extract_mode == "regex"
				extract_regex: string
			}
		}

		// +usage=Extract logs with customized vrl script
		extract_custom_vrl?: string

		// +usage=Redirect logs that failed to extract
		redirect_unknown_logs: *false | true
		// +usage=Rediret logs with specified label
		redirect_unknown_logs_label: *"unknown_logs" | string

		// +usage=Filter logs with allow keywords
		filter_allow_keywords?: [...string]
		// +usage=Filter logs with block keywords
		filter_block_keywords?: [...string]
		// +usage=Filter logs with case sensitive
		filter_case_sensitive: *false | bool
		// +usage=Filter logs with customized vrl script
		filter_custom_vrl?: string

		// +usage=Output content of specified field
		output_field?: string
		// +usage=Encode field before outputing
		output_encoding: *"json" | "logfmt" | "text"
		// +usage=Output destination
		output_type: *"console" | "blackhole" | "loki"
		if output_type == "loki" {
			// +usage=Loki's endpoint, e.g. "http://127.0.0.1:3100/"
			loki_endpoint: string
			// +usage=Tenant id if required
			loki_tenant_id?: string
			// +usage=User for authentication if required
			loki_auth_user?: string
			// +usage=Password for authentication if required
			loki_auth_password?: string
			// +usage=Enable healthcheck for loki
			loki_healthcheck: *true | false
			// +usage=Auto-attach labels of k8s context
			loki_auto_k8s_labels: *true | false
			// +usage=Auto-attach labels of pod
			loki_auto_pod_labels: *true | false
			// +usage=User customized labels
			loki_user_labels?: {...}
		}
	}
	output: {
		apiVersion: "vector.oam.dev/v1alpha1"
		kind:       "Config"
		metadata: {
			name:      parameter.name
			namespace: parameter.namespace
		}
		spec: {
			role: "daemon"
			targetConfigMap: {
				name:      parameter.targetConfigMapName
				namespace: parameter.targetConfigMapNamespace
			}
			vectorConfig: {
				sources: {
					for stage in _pipelines.sources {
						if stage.impl != _|_ {
							"\(stage.id)": stage.impl
						}
					}
				}
				transforms: {
					for stage in _pipelines.transforms {
						if stage.impl != _|_ {
							"\(stage.id)": stage.impl
						}
					}
				}
				sinks: {
					for stage in _pipelines.sinks {
						if stage.impl != _|_ {
							"\(stage.id)": stage.impl
						}
					}
				}
			}
		}
	}

	_params: parameter
	_prefix: "@\(_params.namespace)/\(_params.name)"
	_stages: {
		// stage for collect_logs
		collect_logs: {
			id: "\(_prefix)/collect_logs"
			impl: {
				type: "kubernetes_logs"
				if _params.pod_sd_mode == "namespace" {
					extra_field_selector: "metadata.namespace=\(_params.namespace)"
				}
				if _params.pod_sd_mode == "application" {
					extra_label_selector: "app=\(_params.name)"
					extra_field_selector: "metadata.namespace=\(_params.namespace)"
				}
				if _params.pod_sd_mode == "custom" {
					if _params.label_selector != _|_ {
						extra_label_selector: _params.label_selector
					}
					if _params.field_selector != _|_ {
						extra_field_selector: _params.field_selector
					}
				}
			}
			output: id
		}

		// stage for extract_logs_by_mode
		extract_logs_by_mode: {
			id: "\(_prefix)/extract_logs_by_mode"
			if _params.extract_mode != _|_ {
				impl: {
					type: "remap"
					inputs: [_stages.collect_logs.output]
					if _stages.redirect_unknown_logs.enabled {
						drop_on_error:   true
						reroute_dropped: true
					}
					if _params.extract_mode == "separator" {
						source: ".\(_params.extract_into) = split!(.message, \"\(_params.extract_separator)\")"
					}
					if _params.extract_mode == "json" {
						source: ".\(_params.extract_into) = parse_json!(.message)"
					}
					if _params.extract_mode == "logfmt" {
						source: ".\(_params.extract_into) = parse_logfmt!(.message)"
					}
					if _params.extract_mode == "regex" {
						source: ".\(_params.extract_into) = parse_regex!(.message, \"\(_params.extract_regex)\")"
					}
					if _params.extract_mode == "nginx" {
						source: ".\(_params.extract_into) = parse_nginx_log!(.message, \"combined\")"
					}
					if _params.extract_mode == "apache" {
						source: ".\(_params.extract_into) = parse_apache_log!(.message, \"combined\")"
					}
					if _params.extract_mode == "klog" {
						source: ".\(_params.extract_into) = parse_klog!(.message)"
					}
				}
				output: id
			}
			if _params.extract_mode == _|_ {
				output: _stages.collect_logs.output
			}
		}

		// stage for extract_logs_by_custom_vrl
		extract_logs_by_custom_vrl: {
			id: "\(_prefix)/extract_logs_by_custom_vrl"
			if _params.extract_custom_vrl != _|_ {
				impl: {
					type: "remap"
					inputs: [_stages.extract_logs_by_mode.output]
					if _stages.redirect_unknown_logs.enabled {
						drop_on_error:   true
						reroute_dropped: true
					}
					source: _params.extract_custom_vrl
				}
				output: id
			}
			if _params.extract_custom_vrl == _|_ {
				output: _stages.extract_logs_by_mode.output
			}
		}

		// stage for redirect_unknown_logs
		redirect_unknown_logs: {
			id: "\(_prefix)/redirect_unknown_logs"
			enabled: *false | true
			if _params.redirect_unknown_logs {
				if _stages.extract_logs_by_mode.impl != _|_ {
					enabled: true
				}
				if _stages.extract_logs_by_custom_vrl.impl != _|_ {
					enabled: true
				}
			}
			if redirect_unknown_logs.enabled {
				impl: {
					type: "remap"
					inputs: [
						if _stages.extract_logs_by_mode.impl != _|_ {
							"\(_stages.extract_logs_by_mode.id).dropped"
						},
						if _stages.extract_logs_by_custom_vrl.impl != _|_ {
							"\(_stages.extract_logs_by_custom_vrl.id).dropped"
						},
					]
					source: ".\(_params.redirect_unknown_logs_label) = true"
				}
				output: id
			}
		}

		// stage for filter_logs_by_allow_keywords
		filter_logs_by_allow_keywords: {
			id: "\(_prefix)/filter_logs_by_allow_keywords"
			if _params.filter_allow_keywords != _|_ {
				impl: {
					type: "filter"
					inputs: [_stages.extract_logs_by_custom_vrl.output]
					condition: strings.Join([ for s in _params.filter_allow_keywords {"contains!(.message, \"\(s)\", \(_params.filter_case_sensitive))"}], " || ")
				}
				output: id
			}
			if _params.filter_allow_keywords == _|_ {
				output: _stages.extract_logs_by_custom_vrl.output
			}
		}

		// stage for filter_logs_by_block_keywords
		filter_logs_by_block_keywords: {
			id: "\(_prefix)/filter_logs_by_block_keywords"
			if _params.filter_block_keywords != _|_ {
				impl: {
					type: "filter"
					inputs: [_stages.filter_logs_by_allow_keywords.output]
					_expr:     strings.Join([ for s in _params.filter_block_keywords {"contains!(.message, \"\(s)\", \(_params.filter_case_sensitive))"}], " || ")
					condition: "!(\(_expr))"
				}
				output: id
			}
			if _params.filter_block_keywords == _|_ {
				output: _stages.filter_logs_by_allow_keywords.output
			}
		}

		// stage for filter_logs_by_custom_vrl
		filter_logs_by_custom_vrl: {
			id: "\(_prefix)/filter_logs_by_custom_vrl"
			if _params.filter_custom_vrl != _|_ {
				impl: {
					type: "filter"
					inputs: [_stages.filter_logs_by_block_keywords.output]
					condition: _params.filter_custom_vrl
				}
				output: id
			}
			if _params.filter_custom_vrl == _|_ {
				output: _stages.filter_logs_by_block_keywords.output
			}
		}

		// stage for encode_logs
		encode_logs: {
			id: "\(_prefix)/encode_logs"
			if _params.output_field != _|_ {
				impl: {
					type: "remap"
					inputs: [_stages.filter_logs_by_custom_vrl.output]
					if _params.output_encoding == "text" {
						source: """
							.message = to_string!(.\(_params.output_field))
							"""
					}
					if _params.output_encoding == "json" {
						source: """
							.message = encode_json(.\(_params.output_field))
							"""
					}
					if _params.output_encoding == "logfmt" {
						source: """
							.message = encode_logfmt!(.\(_params.output_field))
							"""
					}
				}
				output: id
			}
			if _params.output_field == _|_ {
				output: _stages.filter_logs_by_custom_vrl.output
			}
		}

		// stage for flush_logs
		flush_logs: {
			id: "\(_prefix)/flush_logs"
			inputs: [
				if _stages.redirect_unknown_logs.enabled {
					_stages.redirect_unknown_logs.output
				},
				_stages.encode_logs.output,
			]

			if _params.output_type == "console" {
				impl: {
					type:   "console"
					inputs: flush_logs.inputs
					encoding: codec: _params.output_encoding
				}
			}
			if _params.output_type == "blackhole" {
				impl: {
					type:                "blackhole"
					inputs:              flush_logs.inputs
					print_interval_secs: 0
				}
			}
			if _params.output_type == "loki" {
				impl: {
					type:   "loki"
					inputs: flush_logs.inputs
					encoding: codec: "text"
					endpoint: _params.loki_endpoint
					if _params.loki_tenant_id != _|_ {
						tenant_id: _params.loki_tenant_id
					}
					if _params.loki_auth_user != _|_ && _params.loki_auth_password != _|_ {
						auth: {
							strategy: "basic"
							user:     _params.loki_auth_user
							password: _params.loki_auth_password
						}
					}
					if _stages.redirect_unknown_logs.enabled {
						labels: "\(_params.redirect_unknown_logs_label)": "{{ \(_params.redirect_unknown_logs_label) }}"
					}
					if _params.loki_auto_k8s_labels {
						labels: {
							pod_node_name:   "{{ kubernetes.pod_node_name }}"
							pod_name:        "{{ kubernetes.pod_name }}"
							pod_namespace:   "{{ kubernetes.pod_namespace }}"
							pod_owner:       "{{ kubernetes.pod_owner }}"
							pod_ip:          "{{ kubernetes.pod_ip }}"
							pod_uid:         "{{ kubernetes.pod_uid }}"
							container_name:  "{{ kubernetes.container_name }}"
							container_image: "{{ kubernetes.container_image }}"
						}
					}
					if _params.loki_auto_pod_labels {
						labels: {
							"pod_labels_*": "{{ kubernetes.pod_labels }}"
						}
					}
					if _params.loki_user_labels != _|_ {
						for k, v in _params.loki_user_labels {
							labels: "\(k)": "\(v)"
						}
					}
					if _params.loki_healthcheck == false {
						healthcheck: enabled: false
					}
				}
			}
		}
	}

	_pipelines: {
		sources: [
			_stages.collect_logs,
		]
		transforms: [
			_stages.extract_logs_by_mode,
			_stages.extract_logs_by_custom_vrl,
			_stages.redirect_unknown_logs,
			_stages.filter_logs_by_allow_keywords,
			_stages.filter_logs_by_block_keywords,
			_stages.filter_logs_by_custom_vrl,
			_stages.encode_logs,
		]
		sinks: [
			_stages.flush_logs,
		]
	}
}
