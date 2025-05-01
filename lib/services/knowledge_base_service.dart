import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class KnowledgeBaseService {
  List<String> knowledgeBase = [];
  List<String> _pdfPaths = [];
  List<String> getPdfFileNames() {
    return _pdfPaths.map((path) => path.split('/').last).toList();
  }
  // tipo do paramentro que vamos receber no construtor
  Future<Directory> Function() getApplicationDocumentsDirectoryCallback;

  // o construtor vai receber a funcao como paramentro
  KnowledgeBaseService(this.getApplicationDocumentsDirectoryCallback) {
    // Quando a classe for criada vai carregar os pdfs que estão salvos
    _loadPdfPaths().then((paths) {
      _pdfPaths = paths;
    });
  }

  Future<void> addPdfToKnowledgeBase(File pdfFile) async {
    try {
      print('KnowledgeBaseService.addPdfToKnowledgeBase: Iniciando...');
      print('KnowledgeBaseService.addPdfToKnowledgeBase: Caminho do arquivo recebido: ${pdfFile.path}');
      // Pega o diretório de documentos do aplicativo
      final directory = await getApplicationDocumentsDirectoryCallback();
      //Define o nome do arquivo para o novo PDF (você pode precisar de um metodo melhor para gerar nomes de arquivos únicos)
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.pdf';
      // Cria um novo caminho de arquivo para o novo PDF
      final newFilePath = '${directory.path}/$fileName';
      // Copia o arquivo PDF para o diretório de documentos do app
      final newPdfFile = await pdfFile.copy(newFilePath);
      if (!await newPdfFile.exists()) {
        throw Exception('Falha ao copiar o arquivo.');
      }
      // Extrair o texto do PDF
      final extractedText = await _extractTextFromPdf(newPdfFile);
      knowledgeBase.add(extractedText); // Adicione o texto extraído à knowledgeBase
      // Armazena o novo caminho de arquivo
      await _savePdfPath(newFilePath);
      print('PDF adicionado com sucesso! Novo caminho: $newFilePath');
    } catch (e) {
      print('Erro ao adicionar PDF: $e');
    }
  }
  // Extrair o texto do PDF
  Future<String> _extractTextFromPdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    // Load an existing PDF document.
    PdfDocument document = PdfDocument(inputBytes: bytes);
    //Create a new instance of the PdfTextExtractor.
    PdfTextExtractor extractor = PdfTextExtractor(document);
    //Extract all the text from the document.
    String text = extractor.extractText();
    //Dispose the document.
    document.dispose();
    return text;
  }

  List<String> findRelevantParts(String query) {
    // 1. Dividir a consulta em palavras-chave
    final queryWords = query.toLowerCase().split(RegExp(r'\s+'));
    // 2. e 3. Iterar e verificar relevância
    final Map<String, int> relevanceScores = {};
    for (final text in knowledgeBase) {
      int score = 0;
      final textLower = text.toLowerCase();
      for (final word in queryWords) {
        if (textLower.contains(word)) {
          score++;
        }
        print('KnowledgeBaseService.addPdfToKnowledgeBase: Texto extraído com sucesso!');
        print('KnowledgeBaseService.addPdfToKnowledgeBase: Tamanho do texto extraído: ${text.length} caracteres');
      }
      if (score > 0) {
        relevanceScores[text] = score;
      }
    }
    // 4. Ordenar e retornar
    final sortedTexts = relevanceScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Ordena por score

    return sortedTexts.map((entry) => entry.key).toList();
  }
  Future<void> _savePdfPath(String pdfPath) async {
    final prefs = await SharedPreferences.getInstance();
    // Busca os caminhos salvos
    List<String> pdfPaths = prefs.getStringList('pdf_paths') ?? [];
    // Adiciona o novo caminho
    pdfPaths.add(pdfPath);
    // Salva a lista atualizada
    await prefs.setStringList('pdf_paths', pdfPaths);
  }

  Future<List<String>> _loadPdfPaths() async {
    final prefs = await SharedPreferences.getInstance();
    // Busca os caminhos salvos ou retorna uma lista vazia
    return prefs.getStringList('pdf_paths') ?? [];
  }
  // pega a lista de caminhos para os pdfs
  List<String> get newPdfFile => _pdfPaths;

  Future<void> removePdfFromKnowledgeBase(String pdfPath) async {
    try {
      print('KnowledgeBaseService.removePdfFromKnowledgeBase: Iniciando...');
      print('KnowledgeBaseService.removePdfFromKnowledgeBase: Caminho do arquivo recebido: $pdfPath');
      final file = File(pdfPath);
      if (await file.exists()) {
        await file.delete(); // Remove o arquivo do sistema de arquivos
        print('Arquivo removido do sistema de arquivos: $pdfPath');
        await _removePdfPath(pdfPath); // Remove o caminho do arquivo das preferências compartilhadas
        print('Caminho removido das preferências compartilhadas: $pdfPath');
        knowledgeBase.removeWhere((element) => element.contains(pdfPath));
        print('Removendo pdf da knowledgeBase: $pdfPath');
      } else {
        print('Arquivo não encontrado no sistema de arquivos: $pdfPath');
      }
      print('KnowledgeBaseService.removePdfFromKnowledgeBase: Finalizado.');
    } catch (e) {
      print('Erro ao remover PDF: $e');
    }
  }
  Future<void> _removePdfPath(String pdfPath) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pdfPaths = prefs.getStringList('pdf_paths') ?? [];
    pdfPaths.remove(pdfPath); // Remove o caminho do arquivo da lista
    _pdfPaths = pdfPaths;
    await prefs.setStringList('pdf_paths', pdfPaths);
  }
}