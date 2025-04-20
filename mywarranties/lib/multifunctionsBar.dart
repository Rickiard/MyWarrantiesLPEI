import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isBottomBarCollapsed = true;

  void _toggleBottomBar() {
    setState(() {
      _isBottomBarCollapsed = !_isBottomBarCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFADD8E6), // Cor de fundo azul claro
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search products...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {},
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Conteúdo principal
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    "Main Content",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          // Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: _isBottomBarCollapsed ? 50 : 100,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: _isBottomBarCollapsed
                  ? Center(
                      child: GestureDetector(
                        onTap: _toggleBottomBar,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Icon(
                            Icons.arrow_drop_up,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : BottomBar(
                      isCollapsed: _isBottomBarCollapsed,
                      onToggle: _toggleBottomBar,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class BottomBar extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  BottomBar({required this.isCollapsed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(Icons.home),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.bar_chart),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.add_circle),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.filter_list),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.person),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.arrow_drop_down),
          onPressed: onToggle,
        ),
      ],
    );
  }
}