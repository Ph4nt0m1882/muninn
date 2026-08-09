import 'package:muninn/src/rust/api/models.dart';
import 'package:muninn/features/editor/models/file_metadata.dart';

enum EditorMode { markdown, render, settings }

enum TabOpenAnimation { normal, raven, none }

class OpenedFile {
  final String path;
  String content;
  bool isDirty;
  EditorMode mode;
  TeleportTarget? teleportTarget;
  TabOpenAnimation openAnimation;
  FileMetadata? metadata;

  // Nom du fichier pour l'affichage dans l'onglet
  String get name {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    if (fileName.toLowerCase().endsWith('.md')) {
      return fileName.substring(0, fileName.length - 3);
    }
    return fileName;
  }

  OpenedFile({
    required this.path,
    required this.content,
    this.metadata,
    this.isDirty = false,
    this.mode = EditorMode.markdown,
    this.teleportTarget,
    this.openAnimation = TabOpenAnimation.none,
  });
}

class TeleportTarget {
  final int startOffset;
  final int endOffset;

  TeleportTarget(this.startOffset, this.endOffset);
}
