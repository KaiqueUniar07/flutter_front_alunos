import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Função principal que inicializa o aplicativo Flutter
void main() => runApp(const MaterialApp(home: CadastroAluno()));


class CadastroAluno extends StatefulWidget {
  const CadastroAluno({super.key});

  @override
  State<CadastroAluno> createState() => _CadastroAlunoState();
}

class _CadastroAlunoState extends State<CadastroAluno> {

  final _formKey = GlobalKey<FormState>();

  // Controladores de texto para os campos do formulário
  final _nome = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();
  final _endereco = TextEditingController();
  final _cep = TextEditingController();

  final _buscaController = TextEditingController(); // Campo de busca por nome

  // Estado do app
  String mensagem = ''; 
  bool enviando = false; 
  List<dynamic> alunos = []; 
  List<dynamic> alunosFiltrados = []; 

  String? editingId; 

  final String apiUrl = 'http://localhost:8080/projeto/api/v1/aluno'; // URL da API

  // Consulta externa API 
  Future<void> apiExterna(String cep) async {
    try {
      final url = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final resposta = await http.get(url);
      final dados = jsonDecode(resposta.body);

      if (resposta.statusCode == 200 && !dados.containsKey('erro')) {
        setState(() {
          _endereco.text =
              '${dados['logradouro']}, ${dados['bairro']}, ${dados['localidade']}';
        });
        return;
      }
    } catch (_) {}

    setState(() {
      mensagem = 'Cep inválido';
    });
  }

  // Função para cadastrar novo aluno ou atualizar 
  Future<void> cadastrarAtual() async {
    if (!_formKey.currentState!.validate()) return; 

    setState(() {
      enviando = true;
      mensagem = '';
    });

    late http.Response resposta;

    // cadastrar
    if (editingId == null) {
      resposta = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': _nome.text,
          'telefone': _telefone.text,
          'email': _email.text,
          'endereco': _endereco.text,
        }),
      );
    } else {
      // atualizar
      resposta = await http.put(
        Uri.parse('$apiUrl/$editingId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': _nome.text,
          'telefone': _telefone.text,
          'email': _email.text,
          'endereco': _endereco.text,
        }),
      );
    }

    setState(() {
      enviando = false;
      if (resposta.statusCode == 201 || resposta.statusCode == 200) {
        // Limpa campos e atualiza lista
        _nome.clear();
        _telefone.clear();
        _email.clear();
        _cep.clear();
        _endereco.clear();
        mensagem = editingId == null
            ? 'Aluno cadastrado com sucesso!'
            : 'Aluno atualizado com sucesso!';
        editingId = null;
        buscarAlunos();
      } else {
        mensagem = 'Erro ao salvar aluno.';
      }
    });
  }

  // Consulta todos os alunos da API
  Future<void> buscarAlunos() async {
    final resposta = await http.get(Uri.parse(apiUrl));
    if (resposta.statusCode == 200) {
      setState(() {
        alunos = jsonDecode(resposta.body);
        alunosFiltrados = alunos;
      });
    } else {
      setState(() {
        mensagem = 'Erro ao carregar alunos.';
      });
    }
  }

  // Deleta um aluno pelo ID
  Future<void> deletarAluno(String id) async {
    final resposta = await http.delete(Uri.parse('$apiUrl/$id'));
    if (resposta.statusCode == 204) {
      setState(() {
        mensagem = 'Aluno deletado com sucesso!';
        if (editingId == id) {
          editingId = null;
          _nome.clear();
          _telefone.clear();
          _email.clear();
          _cep.clear();
          _endereco.clear();
        }
        buscarAlunos();
      });
    } else {
      setState(() {
        mensagem = 'Erro ao deletar aluno.';
      });
    }
  }

  // Preenche os campos com os dados do aluno para edição
  void iniciarEdicao(dynamic aluno) {
    setState(() {
      editingId = aluno['id'];
      _nome.text = aluno['nome'];
      _telefone.text = aluno['telefone'];
      _email.text = aluno['email'];
      _endereco.text = aluno['endereco'];
      mensagem = '';
    });
  }

  // Filtra alunos por nome
  void filtrarAlunos(String textoBusca) {
    final filtro = textoBusca.toLowerCase();
    setState(() {
      alunosFiltrados = alunos.where((aluno) {
        final nome = (aluno['nome'] ?? '').toLowerCase();
        return nome.contains(filtro);
      }).toList();
    });
  }

  // campo de formulário reaproveitável
  Widget campo(String label, TextEditingController c,
      {Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        validator: (valor) =>
            valor!.isEmpty ? 'Preencha o campo "$label"' : null,
        onChanged: onChanged,
      ),
    );
  }

  
  @override
  void initState() {
    super.initState();
    buscarAlunos();
    _buscaController.addListener(() {
      filtrarAlunos(_buscaController.text);
    });
  }

  @override
  void dispose() {
    _buscaController.dispose(); 
    super.dispose();
  }

  //interface do app
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sistema de controle de Alunos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Formulário de cadastro
          Form(
            key: _formKey,
            child: Column(children: [
              campo('Nome', _nome),
              campo('Telefone', _telefone),
              campo('Email', _email),
              campo('CEP', _cep, onChanged: (valor) {
                if (valor.length == 8) {
                  apiExterna(valor); 
                }
              }),
              campo('Endereço', _endereco),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: enviando ? null : cadastrarAtual,
                child:
                    Text(editingId == null ? 'Cadastrar Aluno' : 'Atualizar Aluno'),
              ),
              if (mensagem.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    mensagem,
                    style: TextStyle(
                      color: mensagem.contains('sucesso')
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
            ]),
          ),
          const Divider(height: 40),
          // Campo de busca
          TextFormField(
            controller: _buscaController,
            decoration: const InputDecoration(
              labelText: 'Buscar',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Alunos Cadastrados:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // Lista de alunos
          for (var aluno in alunosFiltrados)
            ListTile(
              title: Text(aluno['nome']),
              subtitle: Text(
                  'Telefone: ${aluno['telefone']}\nEmail: ${aluno['email']}\nEndereço: ${aluno['endereco']}'),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => iniciarEdicao(aluno),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => deletarAluno(aluno['id']),
                  ),
                ],
              ),
            )
        ]),
      ),
    );
  }
}
