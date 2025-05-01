import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/knowledge_base_service.dart';
import '../models/chat_message.dart';
import '../services/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatModel extends ChangeNotifier {
  final KnowledgeBaseService _knowledgeBaseService = KnowledgeBaseService(getApplicationDocumentsDirectory);
  final GeminiService _geminiService = GeminiService();
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  // pega a lista de caminhos para os pdfs
  List<String> get pdfPaths => _knowledgeBaseService.newPdfFile;
  List<String> get pdfFileNames => _knowledgeBaseService.getPdfFileNames();

  ChatModel() {
    print('ChatModel: Iniciando o construtor...');
    _loadHistory();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _addUserMessage(text);
    // Busca palavras chaves na base de conhecimento
    final List<String> relevantParts = _knowledgeBaseService.findRelevantParts(text);
    // constroi o contexto adicional para enviar ao gemini
    final String additionalContext = relevantParts.join('\n');
    // monta as mensagens para enviar ao gemini
    final List<Map<String, dynamic>> msgs = _messages.map((msg) => {
      'role': msg.isUser ? 'user' : 'model',
      'parts': [
        {'text': msg.text}
      ]
    }).toList();
    final botReply = await _geminiService.callGemini(msgs, additionalContext);
    _addBotMessage(botReply);
    await _saveHistory();
  }
  // adiciona PDF na base de conhecimento
  Future<void> addPdfToKnowledgeBase() async{
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      File file = File(result.files.first.path!);
      await _knowledgeBaseService.addPdfToKnowledgeBase(file);
      print('PDF adicionado com sucesso!');
      notifyListeners();
    } else {
      print('Nenhum PDF selecionado.');
    }
  }

  Future<void> removePdf(String pdfPath) async {
    await _knowledgeBaseService.removePdfFromKnowledgeBase(pdfPath);
    notifyListeners();
  }

  void _addUserMessage(String text) {
    final newMessage = ChatMessage(text: text, isUser: true);
    _messages.add(newMessage);
    notifyListeners();
  }

  void _addBotMessage(String text) {
    final newMessage = ChatMessage(text: text, isUser: false);
    _messages.add(newMessage);
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('chat_history') ?? [];
    _messages.clear(); // Limpa a lista de mensagens exibidas
    _messages.addAll(data.map((e) => ChatMessage.fromJson(json.decode(e))).toList());
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _messages.map((e) => json.encode(e.toJson())).toList();
    await prefs.setStringList('chat_history', data);
  }
  void editMessage(int index, String newText) {
    final newMessage = ChatMessage(text: newText, isUser: _messages[index].isUser);
    _messages[index] = newMessage;//altera a mensagem original na lista completa
    _saveHistory();
    notifyListeners();
  }
  void removeMessage(int index) {
    if (index >= 0 && index < _messages.length) {
      _messages.removeAt(index);
      _saveHistory();
      notifyListeners();
    }
  }
  void clearMessages() async {
    _messages.clear();
    notifyListeners();
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showPdfList = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }
  void _togglePdfList() {
    setState(() {
      _showPdfList = !_showPdfList;
    });
  }
  Future<void> _editMessage(int index) async {
    final chat = context.read<ChatModel>();
    final originalMessage = chat.messages[index];
    final controller = TextEditingController(text: originalMessage.text);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Mensagem'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Nova mensagem'),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Salvar'),
            onPressed: () {
              chat.editMessage(index, controller.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }
  @override
  Widget build(BuildContext context) {
    print('ChatScreenState: build() chamado.');
    final chat = context.watch<ChatModel>();
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Image.asset('assets/corvo_icon.png'),
        ),
        title: Text('Corvo AI Chatbot'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => context.read<ChatModel>().clearMessages(),
            icon: Icon(Icons.chat_bubble_outline, color: Colors.white),
          ),
          IconButton(
            onPressed: _togglePdfList,
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
          ),
          IconButton(
            onPressed: _scrollToBottom, // adicionado um novo botão para rolar a tela
            icon: Icon(Icons.arrow_downward, color: Colors.white),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
                reverse: false,
                controller: _scrollController,
                padding: EdgeInsets.all(8),
                itemCount: chat.messages.length, // Usa _displayedMessages.length
                itemBuilder: (context, index) {
                  final msg = chat.messages[index];// Usa _displayedMessages[index]
                  return Column(
                    crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,// Adiciona um Row para conter a mensagem e o botão
                    children: [
                      Align(
                        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: msg.isUser
                                ? Color(0xFF2E0057)
                                : Colors.grey[850],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      Row( // Row para os botões abaixo da mensagem
                        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              chat.removeMessage(index);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () {
                              _editMessage(index);
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                }
            ),
          ),
          //lista de arquivos pdfs carregados
          if (_showPdfList)
          Container(
            height: 50,
            child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: chat.pdfFileNames.length,
                itemBuilder: (context, index) {
                  final fileName = chat.pdfFileNames[index];
                  final filePaths = chat.pdfPaths[index];
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Text(fileName, style: TextStyle(color: Colors.white)),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            context.read<ChatModel>().removePdf(filePaths).then((value) =>setState(() {}));
                          }
                        )
                      ]
                    ),
                  );
                }
            ),
          ),
          Divider(height: 1, color: Colors.grey),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Digite sua mensagem...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF2E0090)),
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      context.read<ChatModel>().sendMessage(_textController.text);
                      _scrollToBottom(); // ao enviar mensagem, rolar a tela para baixo
                      _textController.clear();
                    }
                  }
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Color(0xFF2E0090)),
                  onPressed: () {
                    context.read<ChatModel>().addPdfToKnowledgeBase().then((value) =>setState(() {}));
                  },
                )
              ],
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}