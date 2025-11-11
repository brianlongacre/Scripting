import os
import json
import pandas as pd
from datetime import datetime
from pathlib import Path

# Prompt user for a date in YYYYmmDD format
date_str = input("Enter the date for the data folder (YYYYmmDD): ").strip()

# File Path Variables
Import_Folder_path = "D:/Overflow - One Drive Filling up - Temporary/Projects/Cyber Security/Crowdstrike/Data Prep"
#Export_Folder_path = Path("C:/Users/blongacr/OneDrive - Russel Metals/Documents/Projects/Cyber Security/Crowdstrike/Source Data") #Temporarily commented out for initial testing
Import_data_folder = Path(Import_Folder_path + "/" + date_str)
Export_Folder_path = Import_data_folder #Temporary Export Path for initial testing
File_Ouptput_Prefix = "Daily Remediation Export - ALL - "
File_Output_Suffix = ".csv"
File_Output_Name = File_Ouptput_Prefix + date_str + File_Output_Suffix

if not Import_data_folder.exists():
    raise FileNotFoundError(f"Folder '{Import_data_folder}' not found.")

# Prepare to collect all rows
flattened_rows = []

# Define which files to look for based on naming convention
file_prefixes = [
    "Daily Remediation Export - ALL - ",
]

# Helper to join array fields
join_array = lambda x: "; ".join([str(i) for i in x if i is not None]) if isinstance(x, list) else x

# Helper to sanitize fields
def clean_text(value):
    if isinstance(value, str):
        cleaned = value.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').strip()
        cleaned = cleaned.replace('"\r, http', ', http')
        cleaned = cleaned.replace('"\n, http', ', http')
        cleaned = cleaned.replace('"\r\n, http', ', http')
        cleaned = cleaned.replace('" , http', ', http')
        cleaned = cleaned.replace('", http', ', http')
        return cleaned
    return value

# Loop through expected files
for prefix in file_prefixes:
    json_path = Import_data_folder / f"{prefix}{date_str}.json"
    if not json_path.exists():
        print(f"Warning: File not found: {json_path.name}")
        continue

    with open(json_path, 'r', encoding='utf-8') as f:
        try:
            records = json.load(f)
        except json.JSONDecodeError as e:
            print(f"Error parsing {json_path.name}: {e}")
            continue

    for entry in records:
        for product in entry.get('products', []):
            base = {
                'Hostname' : entry.get('hostname'),
                'LocalIP' : entry.get('local_ip'),
                'HostType' : entry.get('host_type'),
                'OSVersion' : entry.get('os_version'),
                'MachineDomain' : entry.get('machine_domain'),
                'OU' : entry.get('ou'),
                'SiteName' : entry.get('site_name'),
                'RecommendedRemediation' : entry.get('recommended_remediation'),
                'RemediationDetail' : entry.get('remediation_detail'),
                'Products' : join_array(entry.get('products',)),
                'Count' : entry.get('count'),
                'Critical' : entry.get('critical'),
                'High' : entry.get('high'),
                'Medium' : entry.get('medium'),
                'Low' : entry.get('low'),
                'Unknown' : entry.get('unknown'),
                'GroupNames' : join_array([g.get('name') for g in entry.get('groups',[])]),
                'Tags' : join_array(entry.get('tags',[])),
                'HostID' : entry.get('host_id'),
                'Exploits' : entry.get('exploits'),
                'Platform' : entry.get('platform'),
                'ExPRT Critical' : entry.get('exprt_critical'),
                'ExPRT High' : entry.get('exprt_high'),
                'ExPRT Medium' : entry.get('exprt_medium'),
                'ExPRT Low' : entry.get('exprt_low'),
                'ExPRT Unknown' : entry.get('exprt_unknown'),
                'AdditionalRemediationAdvisoryUrl' : entry.get('vendor_advisory'),
                'AdditionalRemediationSteps' : clean_text(join_array([g.get('text') for g in entry.get('extra_remediation_steps',[])])),
                'Asset Criticality' : entry.get('asset_criticality'),
                'Asset Roles' : '',
                'Internet exposure' : entry.get('internet_exposure'),
                'Managed By' : entry.get('managed_by'),
                'Data Providers' : join_array(entry.get('data_providers',[])),
                'Third-party Asset IDs' : entry.get('third_party_asset_ids'),
                'CID' : entry.get('cid'),
                'Customer' : entry.get('customer_name'),
                'Recommendation Type' : entry.get('recommendation_type'),
                'Patch Publication Date' : entry.get('patch_publication_date'),
        }
            flattened_rows.append(base)

    #Build DataFrame and export
if flattened_rows:
    df = pd.DataFrame(flattened_rows)    
    output_path = Export_Folder_path / File_Output_Name
    df.to_csv(output_path, sep='\t', index=False)
    print(f"\n{File_Output_Name}: {output_path}")
else:
    print("\nDaily Remediation Export was NOT generated. Please check the input files.")                

