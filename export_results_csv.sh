#!/bin/bash
REGION="belgiumcentral"
DISPLAY_REGION="Belgium Central"
SUB_ID=$(az account show --query id -o tsv)
SUB_NAME=$(az account show --query name -o tsv)
OUTFILE="belgium_central_availability.csv"

# Fetch all providers in one call
ALL_PROVIDERS=$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB_ID/providers?api-version=2021-04-01&\$expand=resourceTypes" \
  -o json 2>/dev/null)

check() {
  local category="$1" service="$2" namespace="$3" resource_type="$4"
  local locations status
  locations=$(echo "$ALL_PROVIDERS" | jq -r --arg ns "$namespace" --arg rt "$resource_type" \
    '.value[] | select(.namespace | ascii_downcase == ($ns | ascii_downcase)) | .resourceTypes[] | select(.resourceType == $rt) | .locations[]' 2>/dev/null)
  if [ -z "$locations" ]; then
    if [[ "$namespace" == "Microsoft.Security" ]]; then
      status="Available (Global)"
    else
      status="Not Available"
    fi
  elif echo "$locations" | grep -qi "$DISPLAY_REGION"; then
    status="Available"
  else
    status="Not Available"
  fi
  echo "\"$category\",\"$service\",\"$namespace\",\"$resource_type\",\"$status\",\"$DISPLAY_REGION\""
}

# Write CSV header
echo "\"Category\",\"Service\",\"Provider Namespace\",\"Resource Type\",\"Status\",\"Region\"" > "$OUTFILE"

# Write rows
check "AI + Machine Learning" "Azure OpenAI" "Microsoft.CognitiveServices" "accounts" >> "$OUTFILE"
check "AI + Machine Learning" "Azure Machine Learning" "Microsoft.MachineLearningServices" "workspaces" >> "$OUTFILE"
check "Analytics" "Azure Power BI Embedded" "Microsoft.PowerBIDedicated" "capacities" >> "$OUTFILE"
check "Analytics" "Azure Synapse Analytics" "Microsoft.Synapse" "workspaces" >> "$OUTFILE"
check "Analytics" "Azure Databricks" "Microsoft.Databricks" "workspaces" >> "$OUTFILE"
check "Analytics" "Purview" "Microsoft.Purview" "accounts" >> "$OUTFILE"
check "Compute" "Azure Function (App Service)" "Microsoft.Web" "sites" >> "$OUTFILE"
check "Compute" "Azure Kubernetes Services" "Microsoft.ContainerService" "managedClusters" >> "$OUTFILE"
check "Databases" "Azure Cosmos DB" "Microsoft.DocumentDB" "databaseAccounts" >> "$OUTFILE"
check "Databases" "Azure Data Factory" "Microsoft.DataFactory" "factories" >> "$OUTFILE"
check "Databases" "Azure Cache for Redis" "Microsoft.Cache" "Redis" >> "$OUTFILE"
check "Databases" "Azure Database for PostgreSQL" "Microsoft.DBforPostgreSQL" "flexibleServers" >> "$OUTFILE"
check "Databases" "Azure DocumentDB (MongoDB compat)" "Microsoft.DocumentDB" "databaseAccounts" >> "$OUTFILE"
check "Integration" "Azure Event Hub" "Microsoft.EventHub" "namespaces" >> "$OUTFILE"
check "Integration" "Azure API Management" "Microsoft.ApiManagement" "service" >> "$OUTFILE"
check "Integration" "Azure Event Grid" "Microsoft.EventGrid" "topics" >> "$OUTFILE"
check "Integration" "Azure Logic App" "Microsoft.Logic" "workflows" >> "$OUTFILE"
check "Integration" "Azure Service Bus" "Microsoft.ServiceBus" "namespaces" >> "$OUTFILE"
check "Management & Governance" "Azure Log Analytics" "Microsoft.OperationalInsights" "workspaces" >> "$OUTFILE"
check "Management & Governance" "Azure Application Insights" "microsoft.insights" "components" >> "$OUTFILE"
check "Management & Governance" "Azure Automation" "Microsoft.Automation" "automationAccounts" >> "$OUTFILE"
check "Management & Governance" "Azure Arc" "Microsoft.HybridCompute" "machines" >> "$OUTFILE"
check "Networking" "Azure Application Gateway" "Microsoft.Network" "applicationGateways" >> "$OUTFILE"
check "Networking" "Azure VNet Gateway" "Microsoft.Network" "virtualNetworkGateways" >> "$OUTFILE"
check "Networking" "Azure Bastion" "Microsoft.Network" "bastionHosts" >> "$OUTFILE"
check "Networking" "Azure Load Balancer" "Microsoft.Network" "loadBalancers" >> "$OUTFILE"
check "Networking" "Azure Private DNS Zones" "Microsoft.Network" "privateDnsZones" >> "$OUTFILE"
check "Networking" "Azure Private Link" "Microsoft.Network" "privateEndpoints" >> "$OUTFILE"
check "Networking" "Azure Route Server" "Microsoft.Network" "virtualHubs" >> "$OUTFILE"
check "Security" "Microsoft Defender" "Microsoft.Security" "pricings" >> "$OUTFILE"
check "Security" "Azure Sentinel" "Microsoft.SecurityInsights" "alertRules" >> "$OUTFILE"
check "Security" "Azure Dedicated HSM" "Microsoft.HardwareSecurityModules" "cloudHsmClusters" >> "$OUTFILE"
check "Storage" "Azure Storage" "Microsoft.Storage" "storageAccounts" >> "$OUTFILE"

echo "Exported $(wc -l < "$OUTFILE") lines (including header) to $OUTFILE"
echo ""
cat "$OUTFILE"
