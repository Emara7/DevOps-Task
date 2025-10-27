# 🎯 Grafana Access Guide - View Loki Data

## 🌐 Access Grafana Dashboard

1. **Open Grafana**: http://192.168.49.2:32000
2. **Login Credentials**:
   - Username: `admin`
   - Password: `admin`

## 📊 View Loki Data in Grafana

### Step 1: Access Explore
1. Click on **"Explore"** in the left sidebar (compass icon)
2. You should see Loki datasource already configured

### Step 2: Query Logs
Use these LogQL queries to see data:

#### Basic Queries:
```
{job="containerlogs"}
```
This shows all container logs collected by Promtail.

#### Filter by Container:
```
{container_name="nginx"}
```
This shows logs from your Nginx application.

#### Search for Specific Text:
```
{job="containerlogs"} |= "GET"
```
This shows logs containing "GET" (HTTP requests).

#### Error Logs:
```
{job="containerlogs"} |= "error"
```
This shows error logs.

#### Rate of Logs:
```
rate({job="containerlogs"}[5m])
```
This shows the rate of log entries per second.

### Step 3: Create a Dashboard
1. Go to **"Dashboards"** → **"New"** → **"New Dashboard"**
2. Add a **"Logs"** panel
3. Set the datasource to **"Loki"**
4. Use query: `{job="containerlogs"}`
5. Save the dashboard

## 🔍 Sample LogQL Queries to Try

| Query | Description |
|-------|-------------|
| `{job="containerlogs"}` | All container logs |
| `{container_name="nginx"}` | Nginx logs only |
| `{job="containerlogs"} |= "GET"` | HTTP GET requests |
| `{job="containerlogs"} |= "error"` | Error logs |
| `{job="containerlogs"} |~ "404"` | 404 errors |
| `rate({job="containerlogs"}[5m])` | Log rate over 5 minutes |

## 📈 Create Visualizations

### 1. Log Volume Over Time
- Panel Type: **Time Series**
- Query: `rate({job="containerlogs"}[1m])`
- Shows: Number of log entries per minute

### 2. Top Log Sources
- Panel Type: **Stat**
- Query: `count by (container_name) ({job="containerlogs"})`
- Shows: Count of logs by container

### 3. Error Rate
- Panel Type: **Time Series**
- Query: `rate({job="containerlogs"} |= "error" [5m])`
- Shows: Error rate over time

## 🚀 Quick Start Commands

```bash
# Check if services are running
kubectl get pods -n observability

# Check Loki labels
curl -s "http://localhost:3100/loki/api/v1/labels"

# Check available jobs
curl -s "http://localhost:3100/loki/api/v1/label/job/values"
```

## 🎯 Your Services Status

- ✅ **Grafana**: http://192.168.49.2:32000 (admin/admin)
- ✅ **Loki**: Collecting logs from all containers
- ✅ **Promtail**: Running on all nodes
- ✅ **Nginx App**: http://192.168.49.2:30081 (generating logs)

## 📝 Next Steps

1. **Access Grafana** and explore the logs
2. **Create dashboards** for your applications
3. **Set up alerts** for error conditions
4. **Monitor log patterns** and trends

Your observability stack is ready for log analysis! 🎉
