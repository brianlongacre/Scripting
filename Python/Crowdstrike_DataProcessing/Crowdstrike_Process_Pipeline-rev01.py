import subprocess
import time
from datetime import datetime
from pathlib import Path
import zipfile
import os
import logging

# === CONFIGURATION ===
date_str = input("Enter the date for the data folder (YYYYmmDD): ").strip()
working_folder = Path(f"D:/Overflow - One Drive Filling up - Temporary/Projects/Cyber Security/Crowdstrike/Data Prep/{date_str}")
json_folder = working_folder
script_folder = Path("C:/Users/blongacr/OneDrive - Russel Metals/Documents/Projects/Scripting/Python/Crowdstrike_DataProcessing")
scripts = [
    "Vulnerability JSON Processing - rev03.py",
    "Remediation JSON Processing - rev02.py",
    "Host JSON Processing - rev03.py"
]

# === LOGGING SETUP ===
log_file = working_folder / f"pipeline_log_{date_str}.log"
logging.basicConfig(
    filename=log_file,
    filemode='w',
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    level=logging.INFO
)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(message)s')
console.setFormatter(formatter)
logging.getLogger('').addHandler(console)

# === RUN JSON PROCESSING SCRIPTS ===
logging.info("\n--- Starting JSON processing ---")
for script in scripts:
    script_path = script_folder / script
    logging.info(f"Running: {script}")
    result = subprocess.run(["python", str(script_path), date_str], capture_output=True, text=True)
    logging.info(result.stdout.strip())
    if result.returncode != 0:
        logging.error(f"Error running {script}:")
        logging.error(result.stderr.strip())
        logging.error("Aborting pipeline.")
        exit(1)
    time.sleep(1)

# === ZIP AND CLEANUP RAW JSON FILES ===
logging.info("\n--- Archiving raw JSON files ---")
zip_path = working_folder / f"{date_str}_json_export.zip"
with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for json_file in json_folder.glob("*.json"):
        zipf.write(json_file, arcname=json_file.name)
        logging.info(f"  + {json_file.name} added to archive")

# Confirm deletion
#cleanup = input("\nDo you want to delete the raw JSON files now? (y/n): ").strip().lower()     # Commented out 11/10/2025 to enable auto cleanup
cleanup = 'y'                                                                                   # Added 11/10/2025 to enable auto cleanup
if cleanup == 'y':
    for json_file in json_folder.glob("*.json"):
        json_file.unlink()
        logging.info(f"  - {json_file.name} deleted")
else:
    logging.info("  Skipping JSON file deletion.")

logging.info("\n--- Pipeline complete ---")
logging.info(f"Log saved to: {log_file}")