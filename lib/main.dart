import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/persona_provider.dart';
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
        ChangeNotifierProvider(create: (_) => PersonaProvider()),
        ChangeNotifierProxyProvider<ConversationProvider, ChatProvider>(
          create: (ctx) => ChatProvider(
            ctx.read<ConversationProvider>(),
            ctx.read<PersonaProvider>(),
          ),
          update: (ctx, convProvider, previous) =>
              previous!..updateConvProvider(convProvider),
        ),
      ],
      child: MaterialApp(
        title: '小狐爱说话',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor:
                const Color(0xFFFA8072), // Elegant soft coral/salmon fox theme
            primary: const Color(0xFFFA8072),
            secondary: const Color(0xFF7CB342),
            background: const Color(0xFFFFF9F5),
            surface: Colors.white,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFFF9F5),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Color(0xFFFFF9F5),
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: Color(0xFF333333),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
            iconTheme: IconThemeData(color: Color(0xFF333333)),
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shadowColor: const Color(0xFFFA8072).withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide:
                  const BorderSide(color: Color(0xFFFA8072), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFA8072),
            primary: const Color(0xFFFA8072),
            secondary: const Color(0xFF7CB342),
            background: const Color(0xFF1A1A1A),
            surface: const Color(0xFF242424),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF1A1A1A),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Color(0xFF1A1A1A),
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
            iconTheme: IconThemeData(color: Colors.white),
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.4),
            color: const Color(0xFF242424),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF2C2C2C),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide:
                  const BorderSide(color: Color(0xFFFA8072), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
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
