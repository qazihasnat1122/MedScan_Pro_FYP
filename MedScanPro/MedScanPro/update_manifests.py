import os

android_manifest_path = r'd:\medscan\MedScanPro\medscan_mobile\android\app\src\main\AndroidManifest.xml'
ios_info_plist_path = r'd:\medscan\MedScanPro\medscan_mobile\ios\Runner\Info.plist'

with open(android_manifest_path, 'r', encoding='utf-8') as f:
    android_content = f.read()

if '<uses-permission android:name="android.permission.CAMERA"/>' not in android_content:
    android_content = android_content.replace(
        '<application',
        '<uses-permission android:name="android.permission.CAMERA"/>\n    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>\n    <application'
    )
    with open(android_manifest_path, 'w', encoding='utf-8') as f:
        f.write(android_content)

with open(ios_info_plist_path, 'r', encoding='utf-8') as f:
    ios_content = f.read()

if 'NSCameraUsageDescription' not in ios_content:
    ios_content = ios_content.replace(
        '<dict>',
        '<dict>\n\t<key>NSCameraUsageDescription</key>\n\t<string>Used to capture medicine packaging and scan barcodes.</string>\n\t<key>NSPhotoLibraryUsageDescription</key>\n\t<string>Used to upload medicine packaging images.</string>'
    )
    with open(ios_info_plist_path, 'w', encoding='utf-8') as f:
        f.write(ios_content)

print('Updated manifests')
