import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageHelper {
  static Future<String?> pickAndUploadImage({
    required BuildContext context,
    required String bucket,
    required String folder,
    required String userId,
  }) async {
    try {
      // Request permission and pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return null;

      // Read file bytes
      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$folder/$userId/$fileName';

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from(bucket)
          .uploadBinary(filePath, bytes);

      // Get public URL
      return Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(filePath);
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: SelectableText('Failed to pick/upload image: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return null;
    }
  }
}
