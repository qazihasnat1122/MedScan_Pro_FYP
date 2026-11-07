import os
import re

def fix_const_app_colors(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace "const AppColors" with "AppColors"
    content = content.replace("const AppColors.", "AppColors.")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Fixed consts in {filepath}")

features_dir = r"c:\Users\Nouman\Downloads\MedScanPro\MedScanPro\medscan_web\lib\features\manufacturer"
for filename in os.listdir(features_dir):
    if filename.endswith(".dart"):
        fix_const_app_colors(os.path.join(features_dir, filename))
