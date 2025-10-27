# 🔧 Grafana Loki Troubleshooting Guide

## 🚨 Issue: "No logs volume available"

This error occurs when Grafana can't find logs for the selected time range or query.

## ✅ **Step-by-Step Fix**

### 1. **Check Time Range in Grafana**
- In Grafana Explore, look at the **time picker** (top right)
- Set it to **"Last 5 minutes"** or **"Last 1 hour"**
- Make sure the time range includes recent logs

### 2. **Try These Queries in Order**

#### Basic Query (Start Here):
```
{job="containerlogs"}
```

#### If that doesn't work, try:
```
{job="containerlogs"} |= "."
```

#### For specific containers:
```
{container_name="nginx"}
```

#### For recent logs only:
```
{job="containerlogs"} |= "2025-10-22"
```

### 3. **Check Datasource Configuration**
1. Go to **Configuration** → **Data Sources**
2. Click on **Loki**
3. Verify URL: `http://loki-service.observability.svc.cluster.local:3100`
4. Click **"Test"** button
5. Should show "Data source is working"

### 4. **Force Refresh**
- Click the **refresh button** (↻) in Grafana
- Or press **Ctrl+R** to reload the page

### 5. **Check Loki Directly**
Run this command to verify data exists:
```bash
curl -s "http://localhost:3100/loki/api/v1/query?query=%7Bjob%3D%22containerlogs%22%7D&limit=1"
```

## 🎯 **Quick Test Queries**

| Query | Purpose |
|-------|---------|
| `{job="containerlogs"}` | All logs |
| `{job="containerlogs"} |= "GET"` | HTTP requests |
| `{job="containerlogs"} |= "nginx"` | Nginx logs |
| `{job="containerlogs"} |= "error"` | Error logs |

## 🔍 **Common Issues & Solutions**

### Issue: Time Range Too Old
**Solution**: Set time range to "Last 5 minutes"

### Issue: Query Too Specific  
**Solution**: Start with `{job="containerlogs"}`

### Issue: Datasource Not Working
**Solution**: Check URL and test connection

### Issue: No Data in Loki
**Solution**: Generate new logs with:
```bash
curl http://192.168.49.2:30081
```

## 📊 **Current Status**
- ✅ Loki: Running with data
- ✅ Promtail: Collecting logs  
- ✅ Grafana: Running with Loki datasource
- ✅ Data: Available (3 log streams)

## 🚀 **Next Steps**
1. Set time range to "Last 5 minutes"
2. Use query: `{job="containerlogs"}`
3. Click "Run Query"
4. You should see logs!

Your observability stack is working - just need to adjust the time range and query! 🎉
