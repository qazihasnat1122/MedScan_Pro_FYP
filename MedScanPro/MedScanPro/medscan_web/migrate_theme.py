import os
import re

def migrate_theme(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Add import if missing
    if "import '../../core/theme/app_colors.dart';" not in content:
        content = content.replace(
            "import 'package:flutter/material.dart';", 
            "import 'package:flutter/material.dart';\nimport '../../core/theme/app_colors.dart';"
        )

    # Replace hardcoded light theme colors with AppColors equivalents
    content = content.replace("color: Colors.white,", "color: AppColors.card,")
    content = content.replace("backgroundColor: Colors.white,", "backgroundColor: AppColors.surface,")
    content = content.replace("Color(0xFF0F172A)", "AppColors.textPrimary")
    content = content.replace("Color(0xFF64748B)", "AppColors.textSecondary")
    content = content.replace("Color(0xFFE2E8F0)", "AppColors.border")
    content = content.replace("Color(0xFFF8FAFC)", "AppColors.elevated")
    content = content.replace("Color(0xFFF1F5F9)", "AppColors.border")
    content = content.replace("Color(0xFF475569)", "AppColors.textSecondary")
    content = content.replace("Color(0xFF334155)", "AppColors.textPrimary")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Migrated theme for {filepath}")

admin_dir = r"c:\Users\Nouman\Downloads\MedScanPro\MedScanPro\medscan_web\lib\features\admin"
for filename in os.listdir(admin_dir):
    if filename.endswith(".dart"):
        migrate_theme(os.path.join(admin_dir, filename))
