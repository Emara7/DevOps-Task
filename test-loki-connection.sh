#!/bin/bash

echo "🔍 Testing Loki Connection and Data"
echo "=================================="

echo "📊 Checking Loki status..."
curl -s http://localhost:3100/ready && echo " ✅ Loki is ready"

echo ""
echo "📋 Checking available labels..."
curl -s "http://localhost:3100/loki/api/v1/labels" | jq '.data'

echo ""
echo "📝 Checking log data..."
LOG_COUNT=$(curl -s "http://localhost:3100/loki/api/v1/query?query=%7Bjob%3D%22containerlogs%22%7D&limit=5" | jq '.data.result | length')
echo "Found $LOG_COUNT log streams"

echo ""
echo "🔍 Sample log entry:"
curl -s "http://localhost:3100/loki/api/v1/query?query=%7Bjob%3D%22containerlogs%22%7D&limit=1" | jq -r '.data.result[0].values[0][1]' | head -1

echo ""
echo "🌐 Grafana Access:"
echo "URL: http://192.168.49.2:32000"
echo "Username: admin"
echo "Password: admin"
echo ""
echo "📋 Try these queries in Grafana Explore:"
echo "1. {job=\"containerlogs\"}"
echo "2. {container_name=\"nginx\"}"
echo "3. {job=\"containerlogs\"} |= \"GET\""
echo ""
echo "✅ Loki has data! The issue might be with Grafana datasource configuration."
