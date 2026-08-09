import 'package:flutter/material.dart';
import 'package:muninn/features/editor/models/opened_file.dart';
import 'package:muninn/features/editor/models/file_metadata.dart';
import 'package:muninn/features/editor/services/editor_manager.dart';

class MetadataDialog extends StatefulWidget {
  final OpenedFile file;

  const MetadataDialog({super.key, required this.file});

  @override
  State<MetadataDialog> createState() => _MetadataDialogState();
}

class _MetadataDialogState extends State<MetadataDialog> {
  late TextEditingController _titleController;
  late TextEditingController _tagController;
  late List<String> _tags;
  late NoteStatus _status;

  @override
  void initState() {
    super.initState();
    final meta = widget.file.metadata ?? FileMetadata.defaultMeta(widget.file.name);
    _titleController = TextEditingController(text: meta.title);
    _tagController = TextEditingController();
    _tags = List.from(meta.tags);
    _status = meta.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _save() {
    // Si l'utilisateur a écrit un tag mais n'a pas cliqué sur le "+", on l'ajoute automatiquement
    final pendingTag = _tagController.text.trim();
    if (pendingTag.isNotEmpty && !_tags.contains(pendingTag)) {
      _tags.add(pendingTag);
    }

    if (widget.file.metadata == null) {
      widget.file.metadata = FileMetadata.defaultMeta(_titleController.text);
    } else {
      widget.file.metadata!.title = _titleController.text;
    }
    widget.file.metadata!.tags = _tags;
    widget.file.metadata!.status = _status;
    widget.file.isDirty = true;
    
    // Notify UI
    EditorManager.instance.notifyListeners();
    // Save to disk
    EditorManager.instance.saveActiveFile();
    Navigator.of(context).pop();
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('Métadonnées du fichier'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      labelText: 'Ajouter un tag',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTag(_tagController.text),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _tags.map((t) => Chip(
                label: Text(t),
                onDeleted: () => _removeTag(t),
              )).toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NoteStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Statut',
                border: OutlineInputBorder(),
              ),
              items: NoteStatus.values.map((s) => DropdownMenuItem(
                value: s,
                child: Text(s.name.toUpperCase()),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _status = val);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Créé le : ${widget.file.metadata?.created.toLocal().toString().split('.').first ?? DateTime.now().toString().split('.').first}',
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Sauvegarder'),
        ),
      ],
    );
  }
}
