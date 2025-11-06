# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/synapse_sql_pool

resource "azurerm_synapse_sql_pool" "syn_syndp" {
  name                 = "syndp-${var.basename}"
  synapse_workspace_id = var.synapse_workspace_id
  sku_name             = var.sku_name
  create_mode          = var.create_mode
  storage_account_type = var.storage_account_type

  count = var.module_enabled ? 1 : 0
}
