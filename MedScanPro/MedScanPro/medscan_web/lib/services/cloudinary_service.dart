import 'dart:convert';
import 'package:http/http.dart' as http;


class CloudinaryService {
  // Hardcoded for direct upload to Cloudinary.
  // The cloudName and uploadPreset should ideally come from environment variables.
  // We use placeholder values here to indicate configuration is needed.
  final String cloudName = 'REPLACE_WITH_CLOUD_NAME';
  final String uploadPreset = 'REPLACE_WITH_UPLOAD_PRESET';

  Future<Map<String, dynamic>> uploadImage(List<int> fileBytes, String fileName) async {
    if (cloudName == 'REPLACE_WITH_CLOUD_NAME' || uploadPreset == 'REPLACE_WITH_UPLOAD_PRESET') {
      throw Exception('Cloudinary is not configured. Please update CloudinaryService.');
    }
    
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri);
    
    request.fields['upload_preset'] = uploadPreset;
    
    if (fileBytes.isNotEmpty) {
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    } else {
      throw Exception('File bytes are null');
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    
    if (response.statusCode == 200) {
      return json.decode(responseBody);
    } else {
      throw Exception('Failed to upload image: $responseBody');
    }
  }
}
