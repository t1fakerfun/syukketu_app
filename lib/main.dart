import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syukketu_app/screens/mount-page.dart';
import 'package:syukketu_app/screens/register-page.dart';
import 'package:syukketu_app/screens/check-and-analyze-page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '今日休んだら出席回数オーバー?不安に怯える朝を終わらせるアプリ',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BottomNavigation(),
    );
  }
}

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    MountPage(),
    RegisterPage(),
    CheckAndAnalyzePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _pages.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '時間割',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: '教科登録'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: '分析'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
