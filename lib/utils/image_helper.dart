import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageHelper {
  static Future<String?> pickAndUploadImage({
    required BuildContext context,
    required String bucket,
    required String folder,
    required String userId,
  }) async {
    try {
      // Configure allowed file types
      final XTypeGroup imageTypeGroup = XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );

      // Open file picker
      final XFile? file = await openFile(
        acceptedTypeGroups: [imageTypeGroup],
      );

      if (file == null) return null;

      // Read file bytes
      final bytes = await file.readAsBytes();
      final fileExt = file.name.split('.').last.toLowerCase();
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
