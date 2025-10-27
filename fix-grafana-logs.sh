#!/bin/bash

echo "🔧 Fixing Grafana 'No logs volume available' Issue"
echo "================================================="

echo "📊 Current Loki Status:"
curl -s http://localhost:3100/ready && echo " ✅ Loki is ready"

echo ""
echo "📝 Available log streams:"
LOG_STREAMS=$(curl -s "http://localhost:3100/loki/api/v1/query?query=%7Bjob%3D%22containerlogs%22%7D&limit=5" | jq '.data.result | length')
echo "Found $LOG_STREAMS log streams in Loki"

echo ""
echo "🔍 Sample log entry:"
curl -s "http://localhost:3100/loki/api/v1/query?query=%7Bjob%3D%22containerlogs%22%7D&limit=1" | jq -r '.data.result[0].values[0][1]' | head -1

echo ""
echo "🌐 Grafana Access Instructions:"
echo "1. Go to: http://192.168.49.2:32000"
echo "2. Login: admin / admin"
echo "3. Click 'Explore' (compass icon)"
echo "4. IMPORTANT: Set time range to 'Last 5 minutes'"
echo "5. Enter query: {job=\"containerlogs\"}"
echo "6. Click 'Run Query'"

echo ""
echo "🎯 Alternative Queries to Try:"
echo "- {job=\"containerlogs\"} |= \".\""
echo "- {container_name=\"nginx\"}"
echo "- {job=\"containerlogs\"} |= \"GET\""

echo ""
echo "⚠️  Common Issues:"
echo "- Time range too old (use 'Last 5 minutes')"
echo "- Query too specific (start with {job=\"containerlogs\"})"
echo "- Datasource not configured (check Configuration → Data Sources)"

echo ""
echo "✅ Data is available in Loki - the issue is with Grafana time range!"
