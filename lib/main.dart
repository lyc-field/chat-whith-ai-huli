import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/chat_provider.dart';
import 'services/auth_service.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProxyProvider<ConversationProvider, ChatProvider>(
          create: (ctx) => ChatProvider(ctx.read<ConversationProvider>()),
          update: (ctx, convProvider, previous) =>
              previous!..updateConvProvider(convProvider),
        ),
      ],
      child: MaterialApp(
        title: '小狐爱说话',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const AppStarter(),
      ),
    );
  }
}

/// Triggers initial data load on first frame.
class AppStarter extends StatefulWidget {
  const AppStarter({super.key});

  @override
  State<AppStarter> createState() => _AppStarterState();
}

class _AppStarterState extends State<AppStarter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().loadConversations();
      context.read<ChatProvider>().loadSavedApiKey();
      AuthService.initializeDefaults();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}
