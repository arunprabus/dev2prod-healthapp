# 📦 Database Snapshot Restore Guide

## 🎯 **Restore from healthapidb-snapshot**

### **Quick Setup**
```bash
# 1. Edit configuration
vim infra/environments/lower.tfvars

# 2. Uncomment snapshot restore
snapshot_identifier = "healthapidb-snapshot"

# 3. Deploy with existing data
Actions → Core Infrastructure → environment: "lower"
```

## ✅ **What You Get**

### **Instant Data Availability**
- ✅ All existing users and data
- ✅ Complete database schema
- ✅ No manual data migration needed
- ✅ Applications work immediately

### **Network Benefits**
- **Lower Network**: Dev + Test share same restored data
- **Higher Network**: Prod gets dedicated copy of data
- **Consistent Testing**: Real data across environments

## 🔄 **Restore Options**

### **Option 1: Fresh Database (Default)**
```bash
# In lower.tfvars and higher.tfvars
# snapshot_identifier = "healthapidb-snapshot"  # COMMENTED OUT
```
**Result**: Empty database, applications start fresh

### **Option 2: Restore from Snapshot**
```bash
# In lower.tfvars and higher.tfvars
snapshot_identifier = "healthapidb-snapshot"  # UNCOMMENTED
```
**Result**: Database with all existing data

## 💰 **Cost Impact**

| Scenario | Lower Network | Higher Network | Total Cost |
|----------|---------------|----------------|------------|
| **Fresh DB** | $0 | $0 | **$0/month** |
| **Restored DB** | $0 | $0 | **$0/month** |

**Snapshot restore is FREE!** ✨

## 🚀 **Usage Examples**

### **Development with Real Data**
```bash
# Lower network with restored data
snapshot_identifier = "healthapidb-snapshot"
# Dev and Test environments get production-like data
```

### **Production Migration**
```bash
# Higher network with restored data  
snapshot_identifier = "healthapidb-snapshot"
# Prod environment gets exact copy of existing data
```

### **Mixed Approach**
```bash
# Lower: Fresh for testing
# Higher: Restored for production continuity
```

## 🔧 **Technical Details**

### **Automatic Configuration**
- Database credentials auto-configured in K8s secrets
- Connection strings updated automatically
- Applications connect without code changes

### **Data Integrity**
- Snapshot point-in-time consistency
- All foreign key relationships preserved
- Indexes and constraints maintained

---

**🎉 Result: New architecture with all your existing data in minutes!**