
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';

class CloudinaryService {
  static final cloudinary = CloudinaryPublic(
    'YOUR_CLOUD_NAME',  // Replace with your Cloudinary cloud name
    'YOUR_UPLOAD_PRESET',  // Replace with your upload preset
    cache: false,
  );

  static Future<String> uploadImage(File imageFile) async {
    try {
      // Upload image to Cloudinary
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      
      // Return the secure URL of the uploaded image
      return response.secureUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image');
    }
  }
}

// Alternatively, for PostImage API implementation:
class PostImageService {
  static Future<String> uploadImage(File imageFile) async {
    try {
      // Create multipart request
      final uri = Uri.parse('https://postimages.org/json/rr');
      final request = http.MultipartRequest('POST', uri);
      
      // Add file to request
      final file = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      );
      request.files.add(file);
      
      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);
      
      // Return direct image URL
      return jsonData['url'];
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image');
    }
  }
}

// For Imgur API implementation:
class ImgurService {
  static const String clientId = 'YOUR_IMGUR_CLIENT_ID';  // Replace with your Imgur client ID
  
  static Future<String> uploadImage(File imageFile) async {
    try {
      // Convert image to base64
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      
      // Prepare request
      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {
          'Authorization': 'Client-ID $clientId',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image': base64Image,
          'type': 'base64',
        }),
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['data']['link'];
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image');
    }
  }
}