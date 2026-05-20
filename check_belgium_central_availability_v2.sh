#!/bin/bash
# ============================================================================
# Azure Service Availability Check — Belgium Central (Method 2)
# Cross-verification using per-service SKU / capability / version APIs
# ============================================================================

REGION="belgiumcentral"
DISPLAY_REGION="Belgium Central"

echo "============================================================================"
echo " Azure Service Availability — $DISPLAY_REGION (SKU / Capability APIs)"
echo " Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo " Subscription: $(az account show --query name -o tsv)"
echo "============================================================================"
echo ""
printf "%-25s %-35s %-15s %s\n" "CATEGORY" "SERVICE" "STATUS" "DETAIL"
printf "%-25s %-35s %-15s %s\n" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..35})" "$(printf '%0.s-' {1..15})" "$(printf '%0.s-' {1..30})"

AVAILABLE=0
NOT_AVAILABLE=0
ERROR=0

check() {
  local category="$1" service="$2" status="$3" detail="$4"
  printf "%-25s %-35s %-15s %s\n" "$category" "$service" "$status" "$detail"
  if [[ "$status" == *"Available"* ]]; then ((AVAILABLE++));
  elif [[ "$status" == *"NOT"* ]]; then ((NOT_AVAILABLE++));
  else ((ERROR++)); fi
}

# --- AI + Machine Learning ---

# Azure OpenAI: list models available in region
count=$(az cognitiveservices account list-skus --kind OpenAI --location "$REGION" --query "length(@)" -o tsv 2>/dev/null)
if [[ "$count" -gt 0 ]] 2>/dev/null; then
  check "AI + Machine Learning" "Azure OpenAI" "✅ Available" "$count SKUs"
else
  check "AI + Machine Learning" "Azure OpenAI" "❌ NOT Available" "No SKUs in region"
fi

# Azure Machine Learning: list VM sizes (workspace compute)
count=$(az ml compute list-sizes --location "$REGION" --query "length(@)" -o tsv 2>/dev/null)
if [[ "$count" -gt 0 ]] 2>/dev/null; then
  check "AI + Machine Learning" "Azure Machine Learning" "✅ Available" "$count VM sizes"
else
  check "AI + Machine Learning" "Azure Machine Learning" "❌ NOT Available" "No compute sizes"
fi

# --- Analytics ---

# Power BI Embedded: check SKUs via REST
count=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.PowerBIDedicated/skus?api-version=2021-01-01" \
  --query "value[?contains(locations[0],'$DISPLAY_REGION')] | length(@)" -o tsv 2>/dev/null)
if [[ "$count" -gt 0 ]] 2>/dev/null; then
  check "Analytics" "Power BI Embedded" "✅ Available" "$count SKUs"
else
  check "Analytics" "Power BI Embedded" "❌ NOT Available" "No SKUs in region"
fi

# Synapse Analytics: list via REST
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Synapse?api-version=2021-04-01" \
  --query "resourceTypes[?resourceType=='workspaces'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Analytics" "Synapse Analytics" "✅ Available" "Region listed"
else
  check "Analytics" "Synapse Analytics" "❌ NOT Available" "Region not listed"
fi

# Databricks: check via REST provider
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Databricks?api-version=2021-04-01-preview" \
  --query "resourceTypes[?resourceType=='workspaces'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Analytics" "Databricks" "✅ Available" "Region listed"
else
  check "Analytics" "Databricks" "❌ NOT Available" "Region not listed"
fi

# Purview: check via REST provider
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Purview?api-version=2021-07-01" \
  --query "resourceTypes[?resourceType=='accounts'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Analytics" "Purview" "✅ Available" "Region listed"
else
  check "Analytics" "Purview" "❌ NOT Available" "Region not listed"
fi

# --- Compute ---

# Azure Functions / App Service: list available runtimes/SKUs
count=$(az appservice list-locations --sku S1 --query "[?contains(name,'$REGION')] | length(@)" -o tsv 2>/dev/null)
if [[ "$count" -gt 0 ]] 2>/dev/null; then
  check "Compute" "Azure Function (App Service)" "✅ Available" "Region available"
else
  # fallback: check functionapp
  count=$(az functionapp list-runtimes --query "length(linux)" -o tsv 2>/dev/null)
  # This is global, so check via webapp sku availability
  skus=$(az rest --method get \
    --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Web/geoRegions?api-version=2022-03-01&sku=Standard" \
    --query "value[?contains(name,'$REGION')] | length(@)" -o tsv 2>/dev/null)
  if [[ "$skus" -gt 0 ]] 2>/dev/null; then
    check "Compute" "Azure Function (App Service)" "✅ Available" "GeoRegion listed"
  else
    check "Compute" "Azure Function (App Service)" "❌ NOT Available" "No GeoRegion match"
  fi
fi

# AKS: list available Kubernetes versions
versions=$(az aks get-versions --location "$REGION" --query "values[].version" -o tsv 2>/dev/null | head -3)
if [[ -n "$versions" ]]; then
  latest=$(echo "$versions" | head -1)
  check "Compute" "Azure Kubernetes Services" "✅ Available" "Latest: $latest"
else
  check "Compute" "Azure Kubernetes Services" "❌ NOT Available" "No k8s versions"
fi

# --- Databases ---

# Cosmos DB: check via REST capabilities endpoint
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.DocumentDB/locations/$REGION?api-version=2024-05-15" \
  --query "properties.status" -o tsv 2>/dev/null)
if [[ "$result" == "Online" ]]; then
  check "Databases" "Azure Cosmos DB" "✅ Available" "Status: Online"
else
  result2=$(az rest --method get \
    --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.DocumentDB?api-version=2024-05-15" \
    --query "resourceTypes[?resourceType=='databaseAccounts'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
  if [[ -n "$result2" ]]; then
    check "Databases" "Azure Cosmos DB" "✅ Available" "Region listed"
  else
    check "Databases" "Azure Cosmos DB" "❌ NOT Available" "Region not listed"
  fi
fi

# Data Factory
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.DataFactory?api-version=2018-06-01" \
  --query "resourceTypes[?resourceType=='factories'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Databases" "Azure Data Factory" "✅ Available" "Region listed"
else
  check "Databases" "Azure Data Factory" "❌ NOT Available" "Region not listed"
fi

# Redis Cache: list SKUs
count=$(az redis list-cache-capacity --location "$REGION" --query "length(@)" -o tsv 2>/dev/null)
if [[ "$count" -gt 0 ]] 2>/dev/null; then
  check "Databases" "Azure Cache for Redis" "✅ Available" "$count capacities"
else
  # Fallback: REST provider check
  result=$(az rest --method get \
    --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Cache?api-version=2023-08-01" \
    --query "resourceTypes[?resourceType=='redis'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
  if [[ -n "$result" ]]; then
    check "Databases" "Azure Cache for Redis" "✅ Available" "Region listed (REST)"
  else
    check "Databases" "Azure Cache for Redis" "❌ NOT Available" "No data"
  fi
fi

# PostgreSQL Flexible Server: list SKUs
count=$(az postgres flexible-server list-skus --location "$REGION" --query "length(@)" -o tsv 2>/dev/null)
if [[ "$count" -gt 0 ]] 2>/dev/null; then
  check "Databases" "Azure DB for PostgreSQL" "✅ Available" "$count SKU families"
else
  check "Databases" "Azure DB for PostgreSQL" "❌ NOT Available" "No SKUs"
fi

# --- Integration ---

# Event Hub: check namespaces SKU availability via REST
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.EventHub?api-version=2024-01-01" \
  --query "resourceTypes[?resourceType=='namespaces'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Integration" "Azure Event Hub" "✅ Available" "Region listed"
else
  check "Integration" "Azure Event Hub" "❌ NOT Available" "Region not listed"
fi

# API Management: check SKU availability
count=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.ApiManagement/locations/$REGION/platformVersion?api-version=2022-08-01" \
  --query "length(platformVersions)" -o tsv 2>/dev/null)
# Fallback to provider list
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.ApiManagement?api-version=2022-08-01" \
  --query "resourceTypes[?resourceType=='service'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Integration" "Azure API Management" "✅ Available" "Region listed"
else
  check "Integration" "Azure API Management" "❌ NOT Available" "Region not listed"
fi

# Event Grid
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.EventGrid?api-version=2024-06-01-preview" \
  --query "resourceTypes[?resourceType=='topics'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Integration" "Azure Event Grid" "✅ Available" "Region listed"
else
  check "Integration" "Azure Event Grid" "❌ NOT Available" "Region not listed"
fi

# Logic App
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Logic?api-version=2019-05-01" \
  --query "resourceTypes[?resourceType=='workflows'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Integration" "Azure Logic App" "✅ Available" "Region listed"
else
  check "Integration" "Azure Logic App" "❌ NOT Available" "Region not listed"
fi

# Service Bus
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.ServiceBus?api-version=2022-10-01-preview" \
  --query "resourceTypes[?resourceType=='namespaces'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Integration" "Azure Service Bus" "✅ Available" "Region listed"
else
  check "Integration" "Azure Service Bus" "❌ NOT Available" "Region not listed"
fi

# --- Management & Governance ---

# Log Analytics
result=$(az monitor log-analytics workspace list-available-service-tiers --location "$REGION" 2>/dev/null | head -5)
# Fallback to REST
result2=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.OperationalInsights?api-version=2022-10-01" \
  --query "resourceTypes[?resourceType=='workspaces'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result2" ]]; then
  check "Mgmt & Governance" "Azure Log Analytics" "✅ Available" "Region listed"
else
  check "Mgmt & Governance" "Azure Log Analytics" "❌ NOT Available" "Region not listed"
fi

# Application Insights
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Insights?api-version=2020-02-02" \
  --query "resourceTypes[?resourceType=='components'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Mgmt & Governance" "Application Insights" "✅ Available" "Region listed"
else
  check "Mgmt & Governance" "Application Insights" "❌ NOT Available" "Region not listed"
fi

# Automation
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Automation?api-version=2023-11-01" \
  --query "resourceTypes[?resourceType=='automationAccounts'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Mgmt & Governance" "Azure Automation" "✅ Available" "Region listed"
else
  check "Mgmt & Governance" "Azure Automation" "❌ NOT Available" "Region not listed"
fi

# Azure Arc (HybridCompute)
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.HybridCompute?api-version=2024-05-20-preview" \
  --query "resourceTypes[?resourceType=='machines'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Mgmt & Governance" "Azure Arc" "✅ Available" "Region listed"
else
  check "Mgmt & Governance" "Azure Arc" "❌ NOT Available" "Region not listed"
fi

# --- Networking ---

# Application Gateway
count=$(az network application-gateway list-available-server-variable 2>/dev/null | wc -l)
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Network?api-version=2023-11-01" \
  --query "resourceTypes[?resourceType=='applicationGateways'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Networking" "Application Gateway" "✅ Available" "Region listed"
else
  check "Networking" "Application Gateway" "❌ NOT Available" "Region not listed"
fi

# VNet Gateway
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Network?api-version=2023-11-01" \
  --query "resourceTypes[?resourceType=='virtualNetworkGateways'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Networking" "Azure VNet Gateway" "✅ Available" "Region listed"
else
  check "Networking" "Azure VNet Gateway" "❌ NOT Available" "Region not listed"
fi

# Bastion
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Network?api-version=2023-11-01" \
  --query "resourceTypes[?resourceType=='bastionHosts'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Networking" "Azure Bastion" "✅ Available" "Region listed"
else
  check "Networking" "Azure Bastion" "❌ NOT Available" "Region not listed"
fi

# Load Balancer
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Network?api-version=2023-11-01" \
  --query "resourceTypes[?resourceType=='loadBalancers'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Networking" "Azure Load Balancer" "✅ Available" "Region listed"
else
  check "Networking" "Azure Load Balancer" "❌ NOT Available" "Region not listed"
fi

# Private DNS Zones (global service check)
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Network?api-version=2023-11-01" \
  --query "resourceTypes[?resourceType=='privateDnsZones'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Networking" "Private DNS Zones" "✅ Available" "Region listed"
else
  # Private DNS is often 'Global' — check for that
  globalCheck=$(az rest --method get \
    --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Network?api-version=2023-11-01" \
    --query "resourceTypes[?resourceType=='privateDnsZones'].locations[]" -o tsv 2>/dev/null)
  if echo "$globalCheck" | grep -qi "global"; then
    check "Networking" "Private DNS Zones" "✅ Available" "Global service"
  else
    check "Networking" "Private DNS Zones" "❌ NOT Available" "Region not listed"
  fi
fi

# Private Link / Private Endpoints
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Network?api-version=2023-11-01" \
  --query "resourceTypes[?resourceType=='privateEndpoints'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Networking" "Azure Private Link" "✅ Available" "Region listed"
else
  check "Networking" "Azure Private Link" "❌ NOT Available" "Region not listed"
fi

# Route Server
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Network?api-version=2023-11-01" \
  --query "resourceTypes[?resourceType=='virtualHubs'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Networking" "Azure Route Server" "✅ Available" "Region listed"
else
  check "Networking" "Azure Route Server" "❌ NOT Available" "Region not listed"
fi

# --- Security ---

# Microsoft Defender (global)
check "Security" "Microsoft Defender" "✅ Available" "Global service (not region-bound)"

# Sentinel (depends on Log Analytics workspace)
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.SecurityInsights?api-version=2024-03-01" \
  --query "resourceTypes[?resourceType=='alertRules'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Security" "Azure Sentinel" "✅ Available" "Region listed"
else
  check "Security" "Azure Sentinel" "❌ NOT Available" "Region not listed"
fi

# Dedicated HSM
result=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.HardwareSecurityModules?api-version=2021-11-30" \
  --query "resourceTypes[?resourceType=='dedicatedHSMs'].locations[] | [?contains(@,'$DISPLAY_REGION')]" -o tsv 2>/dev/null)
if [[ -n "$result" ]]; then
  check "Security" "Azure Dedicated HSM" "✅ Available" "Region listed"
else
  check "Security" "Azure Dedicated HSM" "❌ NOT Available" "Region not listed"
fi

# --- Storage ---

# Storage Accounts: list SKUs in region
count=$(az storage account show-usage --location "$REGION" --query "currentValue" -o tsv 2>/dev/null)
if [[ $? -eq 0 ]]; then
  check "Storage" "Azure Storage" "✅ Available" "Current usage: $count accounts"
else
  result=$(az rest --method get \
    --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Storage/skus?api-version=2023-05-01" \
    --query "value[?contains(locations[0],'$REGION')] | length(@)" -o tsv 2>/dev/null)
  if [[ "$result" -gt 0 ]] 2>/dev/null; then
    check "Storage" "Azure Storage" "✅ Available" "$result SKUs"
  else
    check "Storage" "Azure Storage" "❌ NOT Available" "No SKUs in region"
  fi
fi

echo ""
echo "============================================================================"
echo " SUMMARY (Method 2: REST / SKU / Capability APIs)"
echo "   Available:     $AVAILABLE"
echo "   Not Available: $NOT_AVAILABLE"
echo "   Errors:        $ERROR"
echo "   Total:         $((AVAILABLE + NOT_AVAILABLE + ERROR))"
echo "============================================================================"
