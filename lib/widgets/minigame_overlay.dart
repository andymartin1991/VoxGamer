import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Para FontFeature
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; 
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'package:shared_preferences/shared_preferences.dart';

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
  int _jumpsLeft = 2; 
  
  // Rotation State
  double _rotation = 0.0;
  double _rotationVelocity = 0.0;
  
  // Obstacles
  List<double> _obstaclesX = []; 
  double _gameSpeed = 0.015;
  
  int _score = 0;
  int _highScore = 0; // Puntuación máxima persistente
  bool _gameOver = false;
  bool _newRecord = false; // Flag para efectos visuales cuando se rompe el récord
  
  // Physics constants
  final double _gravity = -0.0018; 
  final double _jumpForce = 0.032; 

  // CONFIGURACIÓN VISUAL
  final double _floorAlignmentY = 0.5;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _spawnObstacle();
    
    _ticker = createTicker((elapsed) {
      if (!_gameOver) {
        _updateGame();
      }
    });
    _ticker.start();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _highScore = prefs.getInt('minigame_highscore') ?? 0;
      });
    }
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('minigame_highscore', _highScore);
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
        
        // Aplicar rotación si hay velocidad
        _rotation += _rotationVelocity;
        
        if (_playerY <= 0) {
          _playerY = 0;
          _playerVelocity = 0;
          _isJumping = false;
          _jumpsLeft = 2; // Reset saltos
          
          // Reset rotación al tocar suelo
          _rotation = 0.0;
          _rotationVelocity = 0.0;
          
          if (_playerVelocity < -0.02) HapticFeedback.selectionClick(); 
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
        
        // Lógica High Score
        if (_score > _highScore) {
          if (!_newRecord) {
             _newRecord = true;
             HapticFeedback.heavyImpact(); // Celebración táctil
          }
          _highScore = _score;
          // Guardamos el récord en tiempo real (o podrías hacerlo al perder)
          _saveHighScore(); 
        }

        if (_score % 10 == 0) HapticFeedback.mediumImpact(); 
        _gameSpeed += 0.0005; 
      }

      if (_obstaclesX.isEmpty || _obstaclesX.last < 0.5) {
        if (Random().nextInt(50) == 0) _spawnObstacle();
      }

      // Collision Detection
      for (var ox in _obstaclesX) {
        if (ox > -0.76 && ox < -0.64) { 
           if (_playerY < 0.06) { 
             _gameOver = true;
             HapticFeedback.heavyImpact(); 
           }
        }
      }
    });
  }

  void _jump() {
    if (_gameOver) {
      // Reiniciar
      setState(() {
        _gameOver = false;
        _score = 0;
        _newRecord = false;
        _obstaclesX.clear();
        _spawnObstacle();
        _gameSpeed = 0.015;
        _jumpsLeft = 2;
        _playerY = 0;
        _rotation = 0.0;
        _rotationVelocity = 0.0;
      });
      HapticFeedback.mediumImpact();
      return;
    }

    if (_jumpsLeft > 0) {
      setState(() {
        _playerVelocity = _jumpForce;
        _isJumping = true;
        _jumpsLeft--;
        
        if (_jumpsLeft == 0) {
           _rotationVelocity = 0.15; 
        } else {
           _rotationVelocity = 0.0; 
           _rotation = 0.0;
        }
      });
      
      if (_jumpsLeft == 1) {
         HapticFeedback.lightImpact(); 
      } else {
         HapticFeedback.mediumImpact(); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _jump,
        child: Container(
          color: const Color(0xFF0A0E14).withOpacity(0.96),
          child: Stack(
            children: [
              // 1. Progress Background
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(widget.progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 120,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    Text(
                      "ACTUALIZANDO...",
                      style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 5,
                        color: Colors.white.withOpacity(0.2),
                      ),
                    )
                  ],
                ),
              ),

              // 2. Game Floor
              Align(
                alignment: Alignment(0, _floorAlignmentY), 
                child: Container(
                  height: 1,
                  width: double.infinity,
                  color: Colors.white24,
                ),
              ),

              // 3. Player (con Rotación)
               Align(
                  alignment: Alignment(-0.7, _floorAlignmentY - _playerY * 1.5), 
                  child: Transform.rotate(
                    angle: _rotation,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.6), 
                            blurRadius: 15,
                            spreadRadius: 2
                          )
                        ]
                      ),
                      child: Image.asset(
                        'assets/icon/app_logo.png',
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                ),
              
              // 4. Obstacles
              ..._obstaclesX.map((ox) => Align(
                alignment: Alignment(ox, _floorAlignmentY),
                child: const Icon(
                  Icons.bug_report,
                  color: Colors.redAccent,
                  size: 32,
                ),
              )),

              // 5. HUD (Score & High Score)
              Positioned(
                top: MediaQuery.of(context).padding.top + 40,
                left: 0, 
                right: 0,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _gameOver 
                    ? Container(
                        key: const ValueKey('gameover'),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)]
                        ),
                        child: const Text(
                          "GAME OVER\nToca para reiniciar",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      )
                    : Container(
                        key: const ValueKey('score'),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // SCORE ACTUAL
                            const Icon(Icons.sports_score, size: 18, color: Color(0xFF7C4DFF)),
                            const SizedBox(width: 8),
                            Text(
                              "$_score",
                              style: const TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            
                            // SEPARADOR
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              width: 1,
                              height: 16,
                              color: Colors.white24,
                            ),

                            // HIGH SCORE (Color Oro si es nuevo record)
                            Icon(Icons.emoji_events, size: 18, color: _newRecord ? Colors.amberAccent : Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              "BEST: $_highScore",
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold, 
                                color: _newRecord ? Colors.amberAccent : Colors.grey.shade400,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ),
                ),
              ),

              // 6. Hints
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Text(
                  "Toca para saltar (¡Doble salto con giro!)",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
