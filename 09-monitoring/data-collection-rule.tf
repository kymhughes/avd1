resource "azurerm_monitor_data_collection_rule" "session_hosts" {
  name                = var.data_collection_rule_name
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = var.avdLocation
  tags                = var.tags

  destinations {
    log_analytics {
      name                  = "log-analytics"
      workspace_resource_id = module.avm_res_operationalinsights_workspace.resource.id
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf"]
    destinations = ["log-analytics"]
  }

  data_flow {
    streams      = ["Microsoft-WindowsEvent"]
    destinations = ["log-analytics"]
  }

  data_sources {
    performance_counter {
      name                          = "session-host-performance"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers            = var.session_host_perf_counters
    }

    windows_event_log {
      name           = "session-host-windows-events"
      streams        = ["Microsoft-WindowsEvent"]
      x_path_queries = var.session_host_windows_event_logs
    }
  }
}
