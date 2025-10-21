import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter + PHP + MySQL',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const UsuariosPage(),
    );
  }
}

class Usuario {
  final int id;
  final String nome;
  final String telefone;
  final String email;
  Usuario({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.email,
  });

  factory Usuario.fromMap(Map<String, dynamic> m) => Usuario(
    id: int.tryParse("${m['id']}") ?? 0,
    nome: "${m['nome'] ?? ''}",
    telefone: "${m['telefone'] ?? ''}",
    email: "${m['email'] ?? ''}",
  );
}

class Api {
  static const String base = "http://localhost/api_flutter";

  static Future<List<Usuario>> listar() async {
    final res = await http.get(Uri.parse("$base/usuarios_listar.php"));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      return data.map((e) => Usuario.fromMap(e)).toList();
    }
    throw Exception("Erro ao listar: ${res.statusCode}");
  }

  static Future<int> inserir(String nome, String telefone, String email) async {
    final res = await http.post(
      Uri.parse("$base/usuarios_inserir.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"nome": nome, "telefone": telefone, "email": email}),
    );
    if (res.statusCode == 201) {
      final obj = jsonDecode(res.body);
      return obj["id"] ?? 0;
    }
    throw Exception("Erro ao inserir: ${res.body}");
  }

  static Future<void> atualizar(
    int id,
    String nome,
    String telefone,
    String email,
  ) async {
    final res = await http.post(
      Uri.parse("$base/usuarios_atualizar.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "id": id,
        "nome": nome,
        "telefone": telefone,
        "email": email,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception("Erro ao atualizar: ${res.body}");
    }
  }

  static Future<void> excluir(int id) async {
    final res = await http.post(Uri.parse("$base/usuarios_excluir.php?id=$id"));
    if (res.statusCode != 200) {
      throw Exception("Erro ao excluir: ${res.body}");
    }
  }
}

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});
  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  late Future<List<Usuario>> future;
  @override
  void initState() {
    super.initState();
    future = Api.listar();
  }

  Future<void> refresh() async {
    setState(() {
      future = Api.listar();
    });
  }

  Future<void> abrirForm([Usuario? u]) async {
    final nomeCtrl = TextEditingController(text: u?.nome ?? "");
    final telCtrl = TextEditingController(text: u?.telefone ?? "");
    final emailCtrl = TextEditingController(text: u?.email ?? "");

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(u == null ? "Novo usuário" : "Editar usuário #${u.id}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: "Nome"),
              ),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(labelText: "Telefone"),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: "Email"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Salvar"),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (u == null) {
        await Api.inserir(nomeCtrl.text, telCtrl.text, emailCtrl.text);
      } else {
        await Api.atualizar(u.id, nomeCtrl.text, telCtrl.text, emailCtrl.text);
      }
      await refresh();
    }
  }

  Future<void> confirmarExcluir(Usuario u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmar exclusão"),
        content: Text("Excluir o usuário \"${u.nome}\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Api.excluir(u.id);
      await refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Usuários (MySQL via PHP)")),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<Usuario>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text("Erro: ${snap.error}"));
            }
            final lista = snap.data ?? [];
            if (lista.isEmpty) {
              return const Center(child: Text("Nenhum usuário cadastrado."));
            }
            return ListView.separated(
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = lista[i];
                return ListTile(
                  title: Text(u.nome),
                  subtitle: Text("${u.email}  •  ${u.telefone}"),
                  onTap: () => abrirForm(u),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => confirmarExcluir(u),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirForm(),
        icon: const Icon(Icons.add),
        label: const Text("Adicionar"),
      ),
    );
  }
}
