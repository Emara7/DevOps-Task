#!/bin/bash

echo "🎯 Grafana Access Guide - View Loki Data"
echo "========================================"
echo ""

echo "📊 Current Status:"
kubectl get pods -n observability
echo ""

echo "🌐 Access Grafana:"
echo "URL: http://192.168.49.2:32000"
echo "Username: admin"
echo "Password: admin"
echo ""

echo "📋 Sample LogQL Queries to try in Grafana:"
echo "1. {job=\"containerlogs\"} - All container logs"
echo "2. {container_name=\"nginx\"} - Nginx logs only"
echo "3. {job=\"containerlogs\"} |= \"GET\" - HTTP GET requests"
echo "4. {job=\"containerlogs\"} |= \"error\" - Error logs"
echo ""

echo "🚀 Steps to view data:"
echo "1. Open http://192.168.49.2:32000 in your browser"
echo "2. Login with admin/admin"
echo "3. Click 'Explore' in the left sidebar"
echo "4. Select 'Loki' datasource"
echo "5. Enter query: {job=\"containerlogs\"}"
echo "6. Click 'Run Query'"
echo ""

echo "📈 Generate more logs:"
echo "Running sample requests to generate more log data..."
for i in {1..5}; do
    curl -s http://192.168.49.2:30081 > /dev/null
    echo "Generated request $i"
    sleep 1
done
echo ""

echo "✅ Ready to explore logs in Grafana!"
echo "Your observability stack is fully operational."
