import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_shopping_list/data/categories.dart';
import 'package:flutter_shopping_list/models/grocery_item.dart';
import 'package:flutter_shopping_list/widgets/new_item.dart';
import 'package:http/http.dart' as http;

class GroceryList extends StatefulWidget {
  const GroceryList({super.key});

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  List<GroceryItem> _groceryItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() async {
    final url = Uri.https(
      dotenv.env['FIREBASE_URL'] ?? "null",
      'shopping-list.json',
    );
    final response = await http.get(url);
    final data = json.decode(response.body);
    if (response.statusCode >= 400) {
      setState(() {
        _isLoading = false;
        _error = data['error'];
      });
      return;
    }
    if (data == null) {
      setState(() {
        _groceryItems = [];
        _isLoading = false;
      });
      return;
    }
    final Map<String, dynamic> listData = data;
    final List<GroceryItem> listOfGroceryItems = [];
    for (final item in listData.entries) {
      final category = categories.entries
          .firstWhere(
            (element) => element.value.title == item.value['category'],
          )
          .value;
      listOfGroceryItems.add(
        GroceryItem(
          id: item.key,
          name: item.value['name'],
          quantity: item.value['quantity'],
          category: category,
        ),
      );
    }
    setState(() {
      _groceryItems = listOfGroceryItems;
      _isLoading = false;
    });
  }

  void _addItem() async {
    final item = await Navigator.of(context).push<GroceryItem>(
      MaterialPageRoute(
        builder: (ctx) => const NewItem(),
      ),
    );
    if (item == null) return;
    setState(() {
      _groceryItems.add(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent = Center(
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Text(_error != null ? _error! : 'No items added yet!'),
      ),
    );

    if (_groceryItems.isNotEmpty) {
      bodyContent = ListView.builder(
        itemCount: _groceryItems.length,
        itemBuilder: (ctx, index) => Dismissible(
          key: ValueKey(_groceryItems[index].id),
          onDismissed: (direction) async {
            final item = _groceryItems[index];
            setState(() {
              _groceryItems.remove(item);
            });
            final url = Uri.https(
              dotenv.env['FIREBASE_URL'] ?? "null",
              'shopping-list/${item.id}.json',
            );
            final response = await http.delete(url);
            if (response.statusCode >= 400) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to delete!'),
                  ),
                );
              }

              setState(() {
                _groceryItems.insert(index, item);
              });
            }
          },
          child: ListTile(
            title: Text(_groceryItems[index].name),
            leading: Container(
              width: 24,
              height: 24,
              color: _groceryItems[index].category.color,
            ),
            trailing: Text(
              _groceryItems[index].quantity.toString(),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Groceries'),
        actions: [
          IconButton(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
          )
        ],
      ),
      body: bodyContent,
    );
  }
}
