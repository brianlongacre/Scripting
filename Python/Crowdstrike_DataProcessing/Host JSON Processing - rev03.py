import os
import json
import pandas as pd
from pathlib import Path
import sys

# Prompt user for a date in YYYYmmDD format
if len(sys.argv) > 1 :
    date_str = sys.argv[1].strip()
else:
    date_str = input("Enter the date for the data folder (YYYYmmDD): ").strip()

# CID to Customer Name mapping
cid_to_customer = {
    "850b517a9a8e448689dc6ff8aabc7932": "Russel Metals Inc.",
    "554dcfe9bf3045618c7c0bf7f6261e4e": "Sanborn"
}

# Paths
import_folder = Path(f"D:/Overflow - One Drive Filling up - Temporary/Projects/Cyber Security/Crowdstrike/Data Prep/{date_str}")
Export_Folder_path = Path("C:/Users/blongacr/OneDrive - Russel Metals/Documents/Projects/Cyber Security/Crowdstrike/Source Data")
Export_Folder_path_SQL = Path(f"D:/Overflow - One Drive Filling up - Temporary/Projects/Cyber Security/Crowdstrike/Data Prep/{date_str}")
output_path = Export_Folder_path / f"Daily Host Export - All - {date_str} - prepped.csv"
json_filename = f"Daily Host Export - All - {date_str}.json"
json_path = import_folder / json_filename
#File Path Variables - Streamlined dataset - Prepped for SQL Import
File_Ouptput_Prefix_SQL = "Daily_Host_Export_ALL_SQL_"
File_Output_Suffix_SQL = ".csv"
File_Output_Name_SQL = f"{File_Ouptput_Prefix_SQL}{date_str}{File_Output_Suffix_SQL}"


if not json_path.exists():
    raise FileNotFoundError(f"Could not find file: {json_path}")

# Load JSON records
with open(json_path, 'r', encoding='utf-8') as f:
    records = json.load(f)

# Define fixed output schema for SQL file
sql_fields = [
    "SnapshotDate",
    "Customer_ID",
    "Host_ID",
    "Hostname",
    "First_Seen",
    "Last_Seen",
    "Platform",
    "OS_Version",
    "OS_Build",
    "OS_Product_Name",
    "Kernel_Version",
    "Model",
    "Manufacturer",
    "Type",
    "OU",
    "Site",
    "Status",
    "Serial_Number",
    "Last_Logged_In_User_Account",
    "Last_User_Account_Login",
    "Last_Logged_in_User_SID"
]


# Helper to join array fields
join = lambda x: "; ".join(x) if isinstance(x, list) else x

# Flatten relevant fields
flattened = []
for entry in records:
    cid = entry.get('cid')
    flattened.append({
        'Hostname': entry.get('hostname'),
        'CID': cid,
        'Customer Name': cid_to_customer.get(cid, ''),
        'Last Seen': entry.get('last_seen'),
        'First Seen': entry.get('first_seen'),
        'Platform': entry.get('platform_name'),
        'OS Version': entry.get('os_version'),
        'OS Build': entry.get('os_build'),
        'OS Product Name': entry.get('os_product_name'),
        'Kernel Version': entry.get('kernel_version'),
        'Model': entry.get('system_product_name'),
        'Manufacturer': entry.get('system_manufacturer'),
        'Type': entry.get('product_type_desc'),
        'Chassis': entry.get('chassis_type_desc'),
        'Last Reboot': entry.get('last_reboot'),
        'OU': join(entry.get('ou',[])),
        'Site': entry.get('site_name'),
        'Prevention Policy': ' ', # entry.get('prevention.policy_id'), #This will need to be a lookup value, as the prevention.policy_id field is a GUID only, human readable is not passed in the JSON
        'Response Policy': ' ', #entry.get('remote-response.policy_id'), #This will need to be a lookup value, as the remote-response.policy_id field is a GUID only, human readable is not passed in the JSON
        'Sensor Update Policy': ' ', #entry.get('sensor_update.policy_id'), #This will need to be a lookup value, as the sensor_update.policy_id field is a GUID only, human readable is not passed in the JSON
        'Host Retention Policy': ' ', #entry.get('host-retention.policy_id'), #This will need to be a lookup value, as the host-retention.policy_id field is a GUID only, human readable is not passed in the JSON
        'USB Device Policy': ' ', #entry.get(''), #This will require further investigation, as I'm unsure what the correlation to the Usb Device Policy .policy_id field  field would be.  I suspect that it is a GUID only, human readable is not passed in the JSON
        'Kubernetes Admission Control Policy': ' ', #entry.get(''), #This will require further investigation, as I'm unsure what the correlation to the Kubernetes Admission Control Policy .policy_id field  field would be.  I suspect that it is a GUID only, human readable is not passed in the JSON
        'Host ID': entry.get('device_id'),
        'Local IP': entry.get('local_ip'),
        'Connection IP': entry.get('connection_ip'),
        'Default Gateway IP': entry.get('default_gateway_ip'),
        'External IP': entry.get('external_ip'),
        'Domain': entry.get('machine_domain'),
        'MAC Address': entry.get('mac_address'),
        'Connection MAC Address': entry.get('connection_mac_address'),
        'Detections Disabled': ' ', #This will require further investigation, as I'm unsure what the correlation to the Detections Disabled field would be
        'Status': entry.get('status'),
        'Filesystem Containment Status': entry.get('filesystem_containment_status'),
        'CPUID': entry.get('cpu_signature'),
        'Serial Number': entry.get('serial_number'),
        'Sensor Version': entry.get('agent_version'),
        'Sensor Tags': ' ', #This will require further investigation, as I'm unsure what the correlation to the Sensor Tags
        'Cloud Service Provider': ' ', #Not populated yet in our environment
        'Cloud Service Account ID': ' ', #Not populated yet in our environment
        'Cloud Service Instance ID': ' ', #Not populated yet in our environment
        'Cloud Service Zone/Group': ' ', #Not populated yet in our environment
        'Kubernetes Cluster ID': ' ', #Not populated yet in our environment
        'Kubernetes Server Git Version': ' ', #Not populated yet in our environment
        'Kubernetes Server Version': ' ', #Not populated yet in our environment
        'RFM': entry.get('reduced_functionality_mode'),
        'Linux Sensor Mode': ' ', #This will require further investigation, as I'm unsure what the correlation to the Linx Sensor Mode field would be
        'Deployment Type': ' ', #This will require further investigation, as I'm unsure what the correlation to the Deployment Type field would be
        'Email': ' ', #This will require further investigation, as I'm unsure what the correlation to the Email field would be
        'Pod ID': ' ', #Not populated yet in our environment
        'Pod Name': ' ', #Not populated yet in our environment
        'Pod Namespace': ' ', #Not populated yet in our environment
        'Pod Labels': ' ', #Not populated yet in our environment
        'Pod Annotations': ' ', #Not populated yet in our environment
        'Pod IP4': ' ', #Not populated yet in our environment
        'Pod IP6': ' ', #Not populated yet in our environment
        'Pod Hostname': ' ', #Not populated yet in our environment
        'Pod Host IP4': ' ', #Not populated yet in our environment
        'Pod Host IP6': ' ', #Not populated yet in our environment
        'Pod Service Account Name': ' ', #Not populated yet in our environment
        'Host Groups': "; ".join(entry.get('groups',[])),
        'Last Logged In User Account': entry.get('last_login_user'),
        'Last User Account Login': entry.get('last_login_timestamp'),
        'Last Logged In UID': ' ', #This will require further investigation, as I'm unsure what the correlation to the Last Logged In UID field would be
        'Last Logged In User SID': entry.get('last_login_user_sid'),
    })

# Convert to DataFrame
df = pd.DataFrame(flattened)

# Deduplicate: keep only the most recent 'Last Seen' per Hostname
df['Last Seen'] = pd.to_datetime(df['Last Seen'])
df = df.sort_values(by='Last Seen', ascending=False)
df_deduped = df.drop_duplicates(subset='Hostname', keep='first')
df_deduped["SnapshotDate"] = date_str

#Define column renam mapping Old name : New Name
rename_map = {
    "CID": "Customer_ID",
    "Host ID": "Host_ID",
    "First Seen": "First_Seen",
    "Last Seen": "Last_Seen",
    "OS Version": "OS_Version",
    "OS Build": "OS_Build",
    "OS Product Name": "OS_Product_Name",
    "Kernel Version": "Kernel_Version",
    "Serial Number": "Serial_Number",
    "Last Logged In User Account": "Last_Logged_In_User_Account",
    "Last User Account Login": "Last_User_Account_Login",
    "Last Logged In User SID": "Last_Logged_in_User_SID"
}
# Apply the renaming
sql_ready_df = df_deduped.rename(columns=rename_map)
#Normalize, reorder, and fill missing fields
sql_ready_df = sql_ready_df.reindex(columns=sql_fields).fillna("")

#Log Missing and Extra Columns
missing_cols = set(sql_fields) - set(sql_ready_df.columns)
extra_cols = set(sql_ready_df.columns) - set(sql_fields)

if missing_cols:
    print(f"Warning: Missing columns in SQL output: {missing_cols}")
if extra_cols:
    print(f"Note: Extra columns present but unused: {extra_cols}")

#Export for SQL Import
sql_ready_df.to_csv(Export_Folder_path_SQL / File_Output_Name_SQL, sep='\t', index=False)
print(f"\nSQL ready data saved to: {Export_Folder_path_SQL / File_Output_Name_SQL}")

# Export
df_deduped.to_csv(output_path, sep='\t', index=False)
print(f"Deduplicated host data saved to: {output_path}")
print(f"Total input rows: {len(records)}")
print(f"Exported to Power BI: {len(df)}")
print(f"Exported to SQL: {len(sql_ready_df)}")
if len(sql_ready_df.columns) != len(sql_fields):
        print("⚠ Column count mismatch! SQL export may not align.")