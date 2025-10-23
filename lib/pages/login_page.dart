import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'map_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  String _friendlyError(Object e) {
    if (e is AuthApiException) {
      final code = e.code?.toLowerCase();
      if (code == 'invalid_credentials') {
        return 'Credenciales inválidas o correo no verificado. Revisa tu correo y contraseña.';
      }
      if (code == 'email_not_confirmed') {
        return 'Correo no verificado. Revisa tu bandeja de entrada y verifica tu cuenta.';
      }
      return e.message ?? 'Error de autenticación';
    }
    if (e is AuthException) {
      return e.message;
    }
    return e.toString();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = SupabaseService();
      if (!svc.isConfigured) {
        throw Exception('Supabase no está configurado. Revisa tu archivo .env');
      }
      final email = _emailController.text.trim();
      final pass = _passwordController.text.trim();
      if (email.isEmpty || pass.isEmpty) {
        throw Exception('Ingresa correo y contraseña');
      }
      final res = await svc.signIn(email, pass);
      if (res.user != null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MapPage(supabaseConfigured: true)),
        );
      } else {
        setState(() {
          _error = 'Inicio de sesión fallido. ¿Verificaste tu correo?';
        });
      }
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = SupabaseService();
      if (!svc.isConfigured) {
        throw Exception('Supabase no está configurado. Revisa tu archivo .env');
      }
      final email = _emailController.text.trim();
      final pass = _passwordController.text.trim();
      if (email.isEmpty || pass.isEmpty) {
        throw Exception('Ingresa correo y contraseña');
      }
      final res = await svc.signUp(email, pass);
      // En muchos proyectos, el correo debe confirmarse antes de poder iniciar sesión
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada. Revisa tu correo para verificarla y luego inicia sesión.')),
      );
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = SupabaseService();
    final notConfiguredBanner = !svc.isConfigured
        ? Container(
            width: double.infinity,
            color: Colors.orange.shade100,
            padding: const EdgeInsets.all(8),
            child: const Text(
              'Supabase no configurado. Completa .env con SUPABASE_URL y SUPABASE_ANON_KEY para poder iniciar sesión.',
              textAlign: TextAlign.center,
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            notConfiguredBanner,
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.withOpacity(0.1),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading || !svc.isConfigured ? null : _signIn,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Entrar'),
            ),
            TextButton(
              onPressed: _loading || !svc.isConfigured ? null : _signUp,
              child: const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}