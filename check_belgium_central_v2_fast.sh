#!/bin/bash
# ============================================================================
# Azure Service Availability Check — Belgium Central (Method 2)
# Single bulk REST call to /providers, then local jq filtering
# Approach: GET all providers in one call, check locations locally
# ============================================================================

REGION_DISPLAY="Belgium Central"
SUB_ID=$(az account show --query id -o tsv)

echo "============================================================================"
echo " Azure Service Availability — $REGION_DISPLAY (Method 2: Bulk Providers API)"
echo " Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo " Subscription: $(az account show --query name -o tsv)"
echo "============================================================================"
echo ""
echo " Fetching all providers in a single REST call..."

# ONE call to get ALL provider data
ALL_PROVIDERS=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB_ID/providers?api-version=2021-04-01&\$expand=resourceTypes" \
  -o json 2>/dev/null)

if [ -z "$ALL_PROVIDERS" ]; then
  echo "ERROR: Failed to fetch providers. Check authentication."
  exit 1
fi

echo " Done. Analyzing locally..."
echo ""

# Function: check if a provider/resourceType supports Belgium Central
check_service() {
  local category="$1"
  local service="$2"
  local namespace="$3"
  local resource_type="$4"

  local locations
  # Case-insensitive namespace match to handle microsoft.insights vs Microsoft.Insights
  locations=$(echo "$ALL_PROVIDERS" | jq -r --arg ns "$namespace" --arg rt "$resource_type" \
    '.value[] | select(.namespace | ascii_downcase == ($ns | ascii_downcase)) | .resourceTypes[] | select(.resourceType == $rt) | .locations[]' 2>/dev/null)

  if [ -z "$locations" ]; then
    # Global services (e.g. Defender) have no regional locations
    if [[ "$namespace" == "Microsoft.Security" ]]; then
      printf "%-25s %-35s %-18s %s\n" "$category" "$service" "✅ Available" "Global service"
    else
      printf "%-25s %-35s %-18s %s\n" "$category" "$service" "⚠ UNKNOWN" "Provider/type not found"
    fi
  elif echo "$locations" | grep -qi "$REGION_DISPLAY"; then
    printf "%-25s %-35s %-18s %s\n" "$category" "$service" "✅ Available" ""
  else
    printf "%-25s %-35s %-18s %s\n" "$category" "$service" "❌ NOT Available" ""
  fi
}

printf "%-25s %-35s %-18s %s\n" "CATEGORY" "SERVICE" "STATUS" "NOTE"
printf "%-25s %-35s %-18s %s\n" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..35})" "$(printf '%0.s-' {1..18})" "$(printf '%0.s-' {1..25})"

# AI + Machine Learning
check_service "AI + Machine Learning" "Azure OpenAI"             "Microsoft.CognitiveServices"       "accounts"
check_service "AI + Machine Learning" "Azure Machine Learning"   "Microsoft.MachineLearningServices"  "workspaces"

# Analytics
check_service "Analytics" "Power BI Embedded"      "Microsoft.PowerBIDedicated" "capacities"
check_service "Analytics" "Synapse Analytics"       "Microsoft.Synapse"          "workspaces"
check_service "Analytics" "Azure Databricks"        "Microsoft.Databricks"       "workspaces"
check_service "Analytics" "Purview"                 "Microsoft.Purview"          "accounts"

# Compute
check_service "Compute" "Azure Function (App Svc)" "Microsoft.Web"              "sites"
check_service "Compute" "Azure Kubernetes Service" "Microsoft.ContainerService" "managedClusters"

# Databases
check_service "Databases" "Azure Cosmos DB"         "Microsoft.DocumentDB"       "databaseAccounts"
check_service "Databases" "Azure Data Factory"      "Microsoft.DataFactory"      "factories"
check_service "Databases" "Azure Cache for Redis"   "Microsoft.Cache"            "Redis"
check_service "Databases" "Azure DB for PostgreSQL" "Microsoft.DBforPostgreSQL"  "flexibleServers"

# Integration
check_service "Integration" "Azure Event Hub"       "Microsoft.EventHub"         "namespaces"
check_service "Integration" "Azure API Management"  "Microsoft.ApiManagement"    "service"
check_service "Integration" "Azure Event Grid"      "Microsoft.EventGrid"        "topics"
check_service "Integration" "Azure Logic App"       "Microsoft.Logic"            "workflows"
check_service "Integration" "Azure Service Bus"     "Microsoft.ServiceBus"       "namespaces"

# Management & Governance
check_service "Mgmt & Governance" "Log Analytics"         "Microsoft.OperationalInsights" "workspaces"
check_service "Mgmt & Governance" "Application Insights"  "microsoft.insights"            "components"
check_service "Mgmt & Governance" "Azure Automation"      "Microsoft.Automation"          "automationAccounts"
check_service "Mgmt & Governance" "Azure Arc"             "Microsoft.HybridCompute"       "machines"

# Networking
check_service "Networking" "Application Gateway"    "Microsoft.Network" "applicationGateways"
check_service "Networking" "VNet Gateway"            "Microsoft.Network" "virtualNetworkGateways"
check_service "Networking" "Azure Bastion"           "Microsoft.Network" "bastionHosts"
check_service "Networking" "Azure Load Balancer"     "Microsoft.Network" "loadBalancers"
check_service "Networking" "Private DNS Zones"       "Microsoft.Network" "privateDnsZones"
check_service "Networking" "Azure Private Link"      "Microsoft.Network" "privateEndpoints"
check_service "Networking" "Azure Route Server"      "Microsoft.Network" "virtualHubs"

# Security
check_service "Security" "Microsoft Defender"       "Microsoft.Security"                "pricings"
check_service "Security" "Azure Sentinel"           "Microsoft.SecurityInsights"        "alertRules"
check_service "Security" "Azure Dedicated HSM"      "Microsoft.HardwareSecurityModules" "cloudHsmClusters"

# Storage
check_service "Storage" "Azure Storage"             "Microsoft.Storage" "storageAccounts"

echo ""
echo "============================================================================"
echo " Method 1: az provider show (per-provider CLI calls)"
echo " Method 2: Single REST GET /providers bulk call + local jq filtering"
echo ""
echo " Both query ARM provider registration metadata, but via different"
echo " API endpoints and parsing paths. Discrepancies indicate caching"
echo " differences or provider registration state issues."
echo "============================================================================"
