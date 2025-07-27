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
  final List<ChatMessage> _messages = [];
  final GeminiService _geminiService = GeminiService();
  final KnowledgeBaseService _knowledgeBaseService;
  // pega a lista de caminhos para os pdfs
  List<String> pdfFileNames = [];
  List<String> pdfPaths = [];

  List<ChatMessage> get messages => _messages;

  ChatModel(this._knowledgeBaseService) {
    _loadHistory();
    _updatePdfList();
  }
  Future<void> saveMessagesToJson(String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = jsonEncode(_messages.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonString);
      print('Mensagens salvas em: $filePath');
    } catch (e) {
      print('Erro ao salvar mensagens: $e');
      notifyListeners();
    }
  }

  Future<void> loadMessagesFromJson(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('Arquivo JSON não encontrado: $filePath');
        notifyListeners();
        return;
      }
      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _messages.clear();
      _messages.addAll(jsonList.map((e) => ChatMessage.fromJson(e)).toList());
      print('Mensagens carregadas de: $filePath');
      notifyListeners();
    } catch (e) {
      print('Erro ao carregar mensagens: $e');
    }
  }
  Future<String> get localPath async {
    final directory = await getApplicationCacheDirectory();
    return directory.path;
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
  Future<bool> addPdfToKnowledgeBase() async{
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      File file = File(result.files.first.path!);
      final fileAdded = await _knowledgeBaseService.addPdfToKnowledgeBase(file);
      _updatePdfList();
      print('PDF adicionado com sucesso!');
      return fileAdded;
    } else {
      print('Nenhum PDF selecionado.');
      return false;
    }
  }

  Future<void> removePdf(String pdfPath) async {
    await _knowledgeBaseService.removePdfFromKnowledgeBase(pdfPath);
    _updatePdfList();
  }

  void _updatePdfList() {
    final pdfs = _knowledgeBaseService.getPdfFromKnowledgeBase();
    pdfFileNames.clear();
    pdfPaths.clear();
    pdfFileNames.addAll(pdfs.map((e) => e.split('/').last).toList());
    pdfPaths.addAll(pdfs.toList());
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
    notifyListeners();
  }

  Future<void> clearHistory() async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history');
    notifyListeners();
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

  void showPdfList(BuildContext context){
    final chat = context.read<ChatModel>();
    if(chat.pdfFileNames.isNotEmpty){
      setState(() {
        _showPdfList = true;
      });
    }
  }

  void addPdfToChat(BuildContext context) async {
    final chat = context.read<ChatModel>();
    final fileAdded = await chat.addPdfToKnowledgeBase();
    if (fileAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O arquivo já está na base de dados'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      showPdfList(context);
    }
  }

  void removePdfFromChat(BuildContext context, String pdfPath) async {
    final chat = context.read<ChatModel>();
    await chat.removePdf(pdfPath);
    if(chat.pdfFileNames.isEmpty){
      setState(() {
        _showPdfList = false;
      });
    }
  }

  void togglePdfList() {
    setState(() {
      _showPdfList = !_showPdfList;
    });
  }
  //Metodo para salvar mensagens
  void _saveMessages(BuildContext context) async {
    final chat = context.read<ChatModel>();
    String localPath = await chat.localPath;
    String filePath = '$localPath/chat_history.jason';
    await chat.saveMessagesToJson(filePath);
    //Mostrar mensagens ao usuário
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mensagens salvas em $filePath')),
    );
  }
  //metodo para carregar mensagens
  void _loadMessages(BuildContext context) async {
    final chat = context.read<ChatModel>();
    String localPath = await chat.localPath;
    String filePath = '$localPath/chat_history.json';
    await chat.loadMessagesFromJson(filePath);
    if (chat.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nenhuma mensagem encontrada em $filePath')),
      );
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mensagens carregadas de $filePath')),
      );
    }
  }
  //metodo para editar mensagens
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
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Image.asset('assets/corvo_icon.png'),
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: Text('Corvo AI Chatbot'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: togglePdfList,
            icon: Icon(_showPdfList ? Icons.close : Icons.picture_as_pdf,
            color: Colors.white),
          ),
          IconButton(
            onPressed: _scrollToBottom, // adicionado um novo botão para rolar a tela
            icon: Icon(Icons.arrow_downward, color: Colors.white),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Color(0xFF2E0057),
                ),
                child: Center(
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.chat_bubble_outline, color: Colors.white),
                title: Text('Limpar Chat', style: TextStyle(color: Colors.white)),
                onTap: () {
                  context.read<ChatModel>().clearMessages();
                  context.read<ChatModel>().clearHistory();
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.save, color: Colors.white),
                title: Text('Salvar', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _saveMessages(context);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.download, color: Colors.white),
                title: Text('Carregar', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _loadMessages(context);
                  Navigator.of(context).pop();
                }
              ),
            ],
        ),
      ),
      body: Column(
        children: [
          if (_showPdfList)
            Expanded(
              child: ListView.builder(
                itemCount: chat.pdfFileNames.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(chat.pdfFileNames[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          removePdfFromChat(context, chat.pdfPaths[index]),
                    ),
                  );
                },
              ),
            ),
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
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}