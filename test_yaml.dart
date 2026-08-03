import 'dart:io';
import 'package:munnin/features/editor/models/file_metadata.dart';

void main() {
  final meta = FileMetadata.defaultMeta('Test');
  meta.tags = ['tag1', 'tag2'];
  final str = meta.toYamlString();
  print("YAML:\n\$str");
  print("PARSED:");
  final parsed = FileMetadata.fromYaml(str);
  print(parsed.tags);
}
