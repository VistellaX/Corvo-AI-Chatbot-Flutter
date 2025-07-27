import 'package:corvo_ai_chatbot_db/services/knowledge_base_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final knowledgeBaseService = KnowledgeBaseService(getApplicationDocumentsDirectory);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatModel(knowledgeBaseService),
      child: const CorvoApp(),
    ),
  );
}

class CorvoApp extends StatelessWidget {
  const CorvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('CorvoApp: build() chamado.');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Corvo AI Chatbot',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(color: Color(0xFF2E0057)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2E0057)),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

