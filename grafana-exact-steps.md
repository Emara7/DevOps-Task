# 🎯 Exact Steps to Query Loki in Grafana

## 📍 **Where to Put the Query**

### **Step 1: Access Grafana**
1. Open your browser
2. Go to: **http://192.168.49.2:32000**
3. Login with: **admin** / **admin**

### **Step 2: Navigate to Explore**
1. Look at the **left sidebar** in Grafana
2. Find the **compass icon** (⧉) - this is "Explore"
3. **Click on "Explore"**

### **Step 3: Select Loki Datasource**
1. At the top of the Explore page, you'll see a dropdown that says "Data source"
2. **Click on the dropdown**
3. **Select "Loki"** from the list

### **Step 4: Set Time Range**
1. Look at the **top-right corner** of Grafana
2. You'll see a time picker (might show "Last 6 hours" or similar)
3. **Click on the time picker**
4. **Select "Last 5 minutes"** or **"Last 1 hour"**

### **Step 5: Enter the Query**
1. In the Explore page, you'll see a **query input box**
2. It might have a label like "Query" or "LogQL"
3. **Type this exactly**: `{job="containerlogs"}`
4. **Press Enter** or click the **"Run Query"** button (▶️)

## 🎯 **Visual Guide**

```
Grafana Interface:
┌─────────────────────────────────────┐
│ [☰] Dashboard  [⧉] Explore  [⚙] Config │
├─────────────────────────────────────┤
│ Data source: [Loki ▼]               │
│                                     │
│ Query: [ {job="containerlogs"} ]    │
│                                     │
│ Time: [Last 5 minutes ▼]            │
│                                     │
│ [▶️ Run Query]                       │
└─────────────────────────────────────┘
```

## 🔍 **Alternative Queries to Try**

If `{job="containerlogs"}` doesn't work, try these in the same query box:

1. `{job="containerlogs"} |= "."`
2. `{container_name="nginx"}`
3. `{job="containerlogs"} |= "GET"`

## 📊 **What You Should See**

After clicking "Run Query", you should see:
- A list of log entries
- Timestamps on the left
- Log content on the right
- Real-time streaming of new logs

## 🚨 **If Still No Results**

1. **Check time range**: Make sure it's "Last 5 minutes"
2. **Check datasource**: Should show "Loki" in the dropdown
3. **Try broader query**: Use `{job="containerlogs"} |= "."`
4. **Refresh page**: Press Ctrl+R

## ✅ **Current Status**
- Loki has 2 log streams with fresh data
- Grafana is configured with Loki datasource
- Data is available from the last few minutes

**The query goes in the main query input box in the Explore section!** 🎯
