import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; 

class MinigameOverlay extends StatefulWidget {
  final double progress; // 0.0 a 1.0

  const MinigameOverlay({super.key, required this.progress});

  @override
  State<MinigameOverlay> createState() => _MinigameOverlayState();
}

class _MinigameOverlayState extends State<MinigameOverlay> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  
  // Game State
  double _playerY = 0; // 0 = suelo, 1 = altura máxima salto
  double _playerVelocity = 0;
  bool _isJumping = false;
  
  // Obstacles
  List<double> _obstaclesX = []; // Posición X (1.0 = derecha, -1.0 = izquierda)
  double _gameSpeed = 0.015;
  
  int _score = 0;
  bool _gameOver = false;
  
  // Physics constants
  final double _gravity = -0.0025;
  final double _jumpForce = 0.065;

  @override
  void initState() {
    super.initState();
    _spawnObstacle();
    
    _ticker = createTicker((elapsed) {
      if (!_gameOver) {
        _updateGame();
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _spawnObstacle() {
    _obstaclesX.add(1.5); // Empieza fuera de pantalla
  }

  void _updateGame() {
    setState(() {
      // Physics Player
      if (_isJumping || _playerY > 0) {
        _playerY += _playerVelocity;
        _playerVelocity += _gravity;
        
        if (_playerY <= 0) {
          _playerY = 0;
          _playerVelocity = 0;
          _isJumping = false;
        }
      }

      // Physics Obstacles
      for (int i = 0; i < _obstaclesX.length; i++) {
        _obstaclesX[i] -= _gameSpeed;
      }

      // Clean up & Spawn
      if (_obstaclesX.isNotEmpty && _obstaclesX[0] < -1.2) {
        _obstaclesX.removeAt(0);
        _score++;
        _gameSpeed += 0.0005; // Make it harder
      }

      if (_obstaclesX.isEmpty || _obstaclesX.last < 0.5) {
        if (Random().nextInt(50) == 0) _spawnObstacle();
      }

      // Collision Detection (Hitbox muy simple)
      // Player X está fijo en -0.7 aprox
      // Player Y > 0.1 salva el obstáculo
      for (var ox in _obstaclesX) {
        if (ox > -0.8 && ox < -0.6) { // X overlap
           if (_playerY < 0.15) { // Y overlap (no saltó suficiente)
             _gameOver = true;
           }
        }
      }
    });
  }

  void _jump() {
    if (_playerY <= 0.05 && !_gameOver) {
      _playerVelocity = _jumpForce;
      _isJumping = true;
    }
    if (_gameOver) {
      // Reiniciar
      setState(() {
        _gameOver = false;
        _score = 0;
        _obstaclesX.clear();
        _spawnObstacle();
        _gameSpeed = 0.015;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _jump,
      child: Container(
        color: const Color(0xFF0A0E14).withOpacity(0.95),
        child: Stack(
          children: [
            // 1. Progress Background (Giant text)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(widget.progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Text(
                    "ACTUALIZANDO...",
                    style: TextStyle(
                      fontSize: 20,
                      letterSpacing: 5,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  )
                ],
              ),
            ),

            // 2. Game World
            Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    alignment: Alignment(0, 0.5),
                    child: _gameOver 
                      ? const Text("GAME OVER\nTap to restart", textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontSize: 30, fontWeight: FontWeight.bold))
                      : Text("SCORE: $_score", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      // Floor
                      const Align(
                        alignment: Alignment(0, 0.5),
                        child: Divider(color: Colors.white, thickness: 2),
                      ),
                      
                      // Player (LOGO)
                      Align(
                        alignment: Alignment(-0.7, 0.5 - _playerY * 1.5), 
                        child: Image.asset(
                          'assets/icon/app_logo.png',
                          width: 48,
                          height: 48,
                        ),
                      ),
                      
                      // Obstacles
                      ..._obstaclesX.map((ox) => Align(
                        alignment: Alignment(ox, 0.5), // Suelo
                        child: const Icon(
                          Icons.bug_report,
                          color: Colors.redAccent,
                          size: 32,
                        ),
                      )),
                    ],
                  ),
                ),
                const Expanded(flex: 1, child: SizedBox()),
              ],
            ),
            
            // 3. Hints
            const Positioned(
              bottom: 50,
              left: 0, 
              right: 0,
              child: Text(
                "Toca para saltar los bugs mientras esperas",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          ],
        ),
      ),
    );
  }
}
