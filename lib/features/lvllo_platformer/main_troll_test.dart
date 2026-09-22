import 'package:flutter/material.dart';
import 'troll_game.dart';

void main() {
  runApp(const TrollTestApp());
}

class TrollTestApp extends StatelessWidget {
  const TrollTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Troll Platformer C1',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07080A),
      ),
      home: const GameLauncher(),
    );
  }
}

class GameLauncher extends StatefulWidget {
  const GameLauncher({super.key});

  @override
  State<GameLauncher> createState() => _GameLauncherState();
}

class _GameLauncherState extends State<GameLauncher> {
  bool _isPlaying = false;
  int _selectedRound = 1;

  void _startGame(int round) {
    setState(() {
      _selectedRound = round;
      _isPlaying = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlaying) {
      return Stack(
        children: [
          TrollGame(
            startRound: _selectedRound,
            onWin: (int score) => setState(() => _isPlaying = false),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white.withOpacity(0.1),
              elevation: 0,
              child: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() => _isPlaying = false),
            ),
          )
        ],
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('TROLL PLATFORMER', style: TextStyle(
              color: Color(0xFF00FFCC), 
              fontSize: 40, 
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            )),
            const SizedBox(height: 10),
            Text('CHOOSE A STAGE', style: TextStyle(
              color: Colors.white.withOpacity(0.5), 
              fontSize: 16, 
              letterSpacing: 4,
            )),
            const SizedBox(height: 60),
            
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 15,
              runSpacing: 15,
              children: [
                _buildChapterButton("C1", 1),
                _buildChapterButton("C2", 4),
                _buildChapterButton("C3", 7),
                _buildChapterButton("C4", 10),
                _buildChapterButton("C5", 13),
                _buildChapterButton("C6", 16),
                _buildChapterButton("C7", 19),
                _buildChapterButton("C8", 22),
                _buildChapterButton("C9", 25),
                _buildChapterButton("C10", 28),
                _buildChapterButton("C11", 31),
                _buildChapterButton("C12", 34),
                _buildChapterButton("C13", 37),
                _buildChapterButton("C14", 40),
                _buildChapterButton("C15", 43),
                _buildChapterButton("C16", 46),
                _buildChapterButton("C17", 49),
                _buildChapterButton("C18", 52),
                _buildChapterButton("C19", 55),
                _buildChapterButton("C20", 58),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterButton(String label, int round) {
    return InkWell(
      onTap: () => _startGame(round),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF00FFCC).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00FFCC), width: 2),
          boxShadow: [
            BoxShadow(color: const Color(0xFF00FFCC).withOpacity(0.1), blurRadius: 10)
          ]
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
