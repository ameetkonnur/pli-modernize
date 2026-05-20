#!/bin/bash
# ============================================================================
# Azure Service Availability Check — Belgium Central
# Technical verification using Azure Resource Manager Provider API
# ============================================================================

REGION="belgiumcentral"
DISPLAY_REGION="Belgium Central"

echo "============================================================================"
echo " Azure Service Availability Check — $DISPLAY_REGION"
echo " Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo " Subscription: $(az account show --query name -o tsv)"
echo "============================================================================"
echo ""

# Define services: "Category|Service Name|Provider Namespace|Resource Type (primary)"
SERVICES=(
  "AI + Machine Learning|Azure OpenAI|Microsoft.CognitiveServices|accounts"
  "AI + Machine Learning|Azure Machine Learning|Microsoft.MachineLearningServices|workspaces"
  "Analytics|Azure Power BI Embedded|Microsoft.PowerBIDedicated|capacities"
  "Analytics|Azure Synapse Analytics|Microsoft.Synapse|workspaces"
  "Analytics|Azure Databricks|Microsoft.Databricks|workspaces"
  "Analytics|Purview|Microsoft.Purview|accounts"
  "Compute|Azure Function (App Service)|Microsoft.Web|sites"
  "Compute|Azure Kubernetes Services|Microsoft.ContainerService|managedClusters"
  "Databases|Azure Cosmos DB|Microsoft.DocumentDB|databaseAccounts"
  "Databases|Azure Data Factory|Microsoft.DataFactory|factories"
  "Databases|Azure Cache for Redis|Microsoft.Cache|Redis"
  "Databases|Azure Database for PostgreSQL|Microsoft.DBforPostgreSQL|flexibleServers"
  "Databases|Azure DocumentDB (MongoDB compat)|Microsoft.DocumentDB|databaseAccounts"
  "Integration|Azure Event Hub|Microsoft.EventHub|namespaces"
  "Integration|Azure API Management|Microsoft.ApiManagement|service"
  "Integration|Azure Event Grid|Microsoft.EventGrid|topics"
  "Integration|Azure Logic App|Microsoft.Logic|workflows"
  "Integration|Azure Service Bus|Microsoft.ServiceBus|namespaces"
  "Mgmt & Governance|Azure Log Analytics|Microsoft.OperationalInsights|workspaces"
  "Mgmt & Governance|Azure Application Insights|microsoft.insights|components"
  "Mgmt & Governance|Azure Automation|Microsoft.Automation|automationAccounts"
  "Mgmt & Governance|Azure Arc|Microsoft.HybridCompute|machines"
  "Networking|Azure Application Gateway|Microsoft.Network|applicationGateways"
  "Networking|Azure VNet Gateway|Microsoft.Network|virtualNetworkGateways"
  "Networking|Azure Bastion|Microsoft.Network|bastionHosts"
  "Networking|Azure Load Balancer|Microsoft.Network|loadBalancers"
  "Networking|Azure Private DNS Zones|Microsoft.Network|privateDnsZones"
  "Networking|Azure Private Link|Microsoft.Network|privateEndpoints"
  "Networking|Azure Route Server|Microsoft.Network|virtualHubs"
  "Security|Microsoft Defender|Microsoft.Security|pricings"  # Global service
  "Security|Azure Sentinel|Microsoft.SecurityInsights|alertRules"
  "Security|Azure Dedicated HSM|Microsoft.HardwareSecurityModules|cloudHsmClusters"
  "Storage|Azure Storage|Microsoft.Storage|storageAccounts"
)

AVAILABLE=0
NOT_AVAILABLE=0
UNKNOWN=0

printf "%-25s %-35s %-15s\n" "CATEGORY" "SERVICE" "STATUS"
printf "%-25s %-35s %-15s\n" "$(printf '%0.s-' {1..25})" "$(printf '%0.s-' {1..35})" "$(printf '%0.s-' {1..15})"

for entry in "${SERVICES[@]}"; do
  IFS='|' read -r category service provider resource_type <<< "$entry"

  # Strip inline comments from resource_type
  resource_type=$(echo "$resource_type" | sed 's/#.*//' | xargs)

  # Query Azure RM for the provider's supported locations for this resource type
  locations=$(az provider show -n "$provider" \
    --query "resourceTypes[?resourceType=='$resource_type'].locations[]" \
    -o tsv 2>/dev/null)

  if [ -z "$locations" ]; then
    # Global services (e.g. Defender) have no regional locations
    if [[ "$provider" == "Microsoft.Security" ]]; then
      status="✅ Available (Global)"
      ((AVAILABLE++))
    else
      status="⚠ UNKNOWN"
      ((UNKNOWN++))
    fi
  elif echo "$locations" | grep -qi "$DISPLAY_REGION"; then
    status="✅ Available"
    ((AVAILABLE++))
  else
    status="❌ NOT Available"
    ((NOT_AVAILABLE++))
  fi

  printf "%-25s %-35s %-15s\n" "$category" "$service" "$status"
done

echo ""
echo "============================================================================"
echo " SUMMARY"
echo "   Available:     $AVAILABLE"
echo "   Not Available: $NOT_AVAILABLE"
echo "   Unknown:       $UNKNOWN"
echo "   Total Checked: ${#SERVICES[@]}"
echo "============================================================================"
