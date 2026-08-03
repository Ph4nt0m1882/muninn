import 'dart:io';
import 'package:munnin/src/rust/api/rag.dart' as rust_rag;
import 'package:munnin/src/rust/frb_generated.dart';

void main() async {
  await RustLib.init();
  try {
    print("Initialisation embedder...");
    await rust_rag.initEmbedder();
    
    print("Recherche RAG...");
    final results = await rust_rag.searchSimilar(
      wikiRoot: r'C:\Users\barre\Workspace\munnin\testMunnin',
      query: 'test',
      limit: BigInt.from(5)
    );
    
    print("Résultats: ${results.length}");
    for (var r in results) {
      print("${r.filePath}: ${r.distance}");
    }
  } catch (e) {
    print("Erreur: $e");
  }
  exit(0);
}
