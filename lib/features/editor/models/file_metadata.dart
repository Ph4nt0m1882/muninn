import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';

enum NoteStatus {
  draft,
  inProgress,
  review,
  completed,
  archived,
  system
}

extension NoteStatusExtension on NoteStatus {
  String get name {
    switch (this) {
      case NoteStatus.draft: return 'draft';
      case NoteStatus.inProgress: return 'in_progress';
      case NoteStatus.review: return 'review';
      case NoteStatus.completed: return 'completed';
      case NoteStatus.archived: return 'archived';
      case NoteStatus.system: return 'system';
    }
  }

  static NoteStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'in_progress':
      case 'inprogress':
        return NoteStatus.inProgress;
      case 'review':
        return NoteStatus.review;
      case 'completed':
        return NoteStatus.completed;
      case 'archived':
        return NoteStatus.archived;
      case 'system':
        return NoteStatus.system;
      case 'draft':
      default:
        return NoteStatus.draft;
    }
  }
}

class FileMetadata {
  String title;
  DateTime created;
  List<String> tags;
  NoteStatus status;
  String? description;

  FileMetadata({
    required this.title,
    required this.created,
    required this.tags,
    required this.status,
    this.description,
  });

  factory FileMetadata.defaultMeta(String title) {
    return FileMetadata(
      title: title,
      created: DateTime.now(),
      tags: [],
      status: NoteStatus.draft,
    );
  }

  factory FileMetadata.fromYaml(String yamlString, {String defaultTitle = ''}) {
    if (yamlString.trim().isEmpty) {
      return FileMetadata.defaultMeta(defaultTitle);
    }
    
    try {
      final doc = loadYaml(yamlString) as YamlMap;
      
      final title = doc['title']?.toString() ?? defaultTitle;
      
      DateTime created;
      if (doc['created'] != null) {
        created = DateTime.tryParse(doc['created'].toString()) ?? DateTime.now();
      } else {
        created = DateTime.now();
      }
      
      List<String> tags = [];
      if (doc['tags'] is YamlList) {
        tags = (doc['tags'] as YamlList).map((e) => e.toString()).toList();
      } else if (doc['tags'] is List) {
        tags = (doc['tags'] as List).map((e) => e.toString()).toList();
      }
      
      final statusStr = doc['status']?.toString() ?? 'draft';
      final status = NoteStatusExtension.fromString(statusStr);
      
      final description = doc['description']?.toString();

      return FileMetadata(
        title: title,
        created: created,
        tags: tags,
        status: status,
        description: description,
      );
    } catch (e) {
      return FileMetadata.defaultMeta(defaultTitle);
    }
  }

  String toYamlString() {
    final writer = YamlWriter();
    final map = {
      'title': title,
      'created': created.toIso8601String().split('T').first,
      'tags': tags,
      'status': status.name,
    };
    if (description != null && description!.isNotEmpty) {
      map['description'] = description!;
    }
    return writer.write(map).trim();
  }
}
