import 'package:flutter/material.dart';
import 'package:neero_ttl_etag_cache/neero_ttl_etag_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NeeroTtlEtagCache.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JSONPlaceholder Todo Cache',
      home: Scaffold(
        appBar: AppBar(title: const Text('Todos Cache + ETag')),
        body: const TodoList(),
      ),
    );
  }
}

// Modèle Todo
class Todo {
  final int id;
  final String title;
  final bool completed;
  Todo({required this.id, required this.title, required this.completed});

  factory Todo.fromJson(Map<String, dynamic> json) =>
      Todo(id: json['id'], title: json['title'], completed: json['completed']);
}

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  late final CachedTtlEtagRepository<List<Todo>> _repository;

  @override
  void initState() {
    super.initState();
    _repository = CachedTtlEtagRepository<List<Todo>>(
      url: 'https://jsonplaceholder.typicode.com/todos',
      fromJson: (json) {
        final list = json as List;
        return list.map((e) => Todo.fromJson(e)).toList();
      },
      defaultTtl: Duration(minutes: 5),
    );
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Zone des boutons
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            children: [
              ElevatedButton(
                onPressed: () async {
                  // Invalidate le cache local
                  await _repository.invalidate();
                },
                child: const Text('Clear Local Cache'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  // Force refetch depuis le serveur
                  await _repository.fetch();
                },
                child: const Text('Refetch'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Force refetch depuis le serveur
                  _repository.refresh();
                },
                child: const Text('Force Server'),
              ),
            ],
          ),
        ),

        // Zone liste avec cache réactif
        Expanded(
          child: StreamBuilder<CacheTtlEtagState<List<Todo>>>(
            stream: _repository.stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var cache = snapshot.data!;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Stale: ${cache.isStale} | TTL: ${cache.ttlSeconds ?? 0}s |  Timestamp: ${cache.timestamp?.toLocal().toString() ?? '-'} | Error: ${cache.error}',
                      style: TextStyle(
                        color: cache.isStale ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: snapshot.data!.data?.length ?? 0,
                      itemBuilder: (context, index) {
                        final todo = snapshot.data!.data![index];
                        return ListTile(
                          title: Text(todo.title),
                          subtitle: Text('Completed: ${todo.completed}'),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
