import 'package:flutter/material.dart';
import 'package:munnin/core/modules/munnin_module.dart';
import 'package:munnin/core/modules/module_registry.dart';
import 'package:file_picker/file_picker.dart';

class NewEntityDialog extends StatefulWidget {
  final bool isDirectory;

  const NewEntityDialog({super.key, required this.isDirectory});

  @override
  State<NewEntityDialog> createState() => _NewEntityDialogState();
}

class _NewEntityDialogState extends State<NewEntityDialog> {
  final _nameController = TextEditingController();
  ModuleFolderType? _selectedType;
  final Map<String, TextEditingController> _fieldControllers = {};
  
  final List<ModuleFolderType> _availableTypes = [];

  @override
  void initState() {
    super.initState();
    if (widget.isDirectory) {
      for (var module in ModuleRegistry.instance.modules) {
        _availableTypes.addAll(module.getFolderTypes());
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isDirectory ? 'Nouveau dossier' : 'Nouveau fichier'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: widget.isDirectory ? 'Nom du dossier' : 'Nom du fichier',
              ),
              autofocus: true,
              onSubmitted: (val) {
                if (!widget.isDirectory || _availableTypes.isEmpty) {
                  _submit();
                }
              },
            ),
            if (widget.isDirectory && _availableTypes.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<ModuleFolderType?>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Type de dossier (Optionnel)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Standard')),
                  ..._availableTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  )),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedType = val;
                    _fieldControllers.clear();
                    if (val != null) {
                      for (var field in val.fields) {
                        _fieldControllers[field.key] = TextEditingController();
                      }
                    }
                  });
                },
              ),
              if (_selectedType != null && _selectedType!.fields.isNotEmpty) ...[
                const SizedBox(height: 16),
                ..._selectedType!.fields.map((field) {
                  final controller = _fieldControllers[field.key]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: field.label,
                              hintText: field.hint,
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                        ),
                        if (field.isDirectoryPicker)
                          IconButton(
                            icon: const Icon(Icons.folder_open),
                            onPressed: () async {
                              final String? dirPath = await FilePicker.getDirectoryPath();
                              if (dirPath != null) {
                                controller.text = dirPath;
                              }
                            },
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Créer'),
        ),
      ],
    );
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) return;
    
    Map<String, dynamic>? configData;
    if (_selectedType != null) {
      configData = {};
      _fieldControllers.forEach((key, controller) {
        configData![key] = controller.text;
      });
    }
    
    Navigator.pop(context, {
      'name': _nameController.text,
      'configData': configData,
      'moduleId': _selectedType?.id,
    });
  }
}
