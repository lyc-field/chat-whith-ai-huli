import 'package:flutter/material.dart';
import 'admin_panel_page.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _autoLogging = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final savedAccount = await DatabaseService.getSetting('saved_admin_account');
    final savedPw = await DatabaseService.getSetting('saved_admin_password');
    final autoLogin = savedAccount != null && savedAccount.isNotEmpty &&
        savedPw != null && savedPw.isNotEmpty;
    if (autoLogin) {
      _accountController.text = savedAccount;
      _passwordController.text = savedPw;
      _rememberMe = true;
      // Auto-login: verify and navigate directly
      final ok = await AuthService.verifyAdmin(savedAccount, savedPw);
      if (mounted) {
        if (ok) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminPanelPage()),
          );
          return;
        } else {
          // Saved credentials are no longer valid, clear them
          await DatabaseService.saveSetting('saved_admin_account', '');
          await DatabaseService.saveSetting('saved_admin_password', '');
          _rememberMe = false;
        }
      }
    }
    if (mounted) setState(() => _autoLogging = false);
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final account = _accountController.text.trim();
    final password = _passwordController.text;
    if (account.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入账号和密码');
      return;
    }
    final ok = await AuthService.verifyAdmin(account, password);
    if (!mounted) return;
    if (ok) {
      if (_rememberMe) {
        await DatabaseService.saveSetting('saved_admin_account', account);
        await DatabaseService.saveSetting('saved_admin_password', password);
      } else {
        await DatabaseService.saveSetting('saved_admin_account', '');
        await DatabaseService.saveSetting('saved_admin_password', '');
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminPanelPage()),
      );
    } else {
      setState(() => _error = '账号或密码错误');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_autoLogging) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('管理员登录'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, size: 56, color: Colors.grey),
              const SizedBox(height: 24),
              TextField(
                controller: _accountController,
                decoration: const InputDecoration(
                  labelText: '账号',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                ),
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: const Text('记住登录'),
                ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _login,
                  child: const Text('登录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
