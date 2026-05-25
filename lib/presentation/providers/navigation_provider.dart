import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/models/building.dart';
import '../../data/models/nav_node.dart';
import '../../data/models/route_step.dart';
import '../../data/models/position.dart';
import '../../domain/algorithms/astar.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';

enum NavigationState { idle, routing, navigating, arrived }

class NavigationProvider extends ChangeNotifier {
  final TtsService _tts;
  final SttService _stt;
  final AStarPathfinder _pathfinder = AStarPathfinder();

  Building? _building;
  NavigationRoute? _route;
  int _currentStepIndex = 0;
  NavigationState _state = NavigationState.idle;
  String? _statusMessage;
  bool _isListening = false;

  NavigationProvider(this._tts, this._stt);

  NavigationRoute? get route => _route;
  NavigationState get state => _state;
  int get currentStepIndex => _currentStepIndex;
  String? get statusMessage => _statusMessage;
  bool get isListening => _isListening;

  RouteStep? get currentStep =>
      (_route != null && _currentStepIndex < _route!.steps.length)
          ? _route!.steps[_currentStepIndex]
          : null;

  void setBuilding(Building building) {
    _building = building;
    _route = null;
    _state = NavigationState.idle;
    notifyListeners();
  }

  // ── Voice command entry point ─────────────────────────────────────────────

  Future<void> startVoiceCommand() async {
    await _stt.init();
    _isListening = true;
    _statusMessage = 'Ouvindo...';
    notifyListeners();

    final spoken = await _stt.listenOnce();
    _isListening = false;

    if (spoken == null || spoken.isEmpty) {
      _statusMessage = 'Não entendi. Tente novamente.';
      notifyListeners();
      return;
    }

    await _tts.speak('Processando: $spoken');
    await _processVoiceCommand(spoken);
  }

  Future<void> _processVoiceCommand(String text) async {
    final b = _building;
    if (b == null) {
      _statusMessage = 'Nenhum prédio selecionado.';
      notifyListeners();
      return;
    }

    NavNode? originNode;
    NavNode? destNode;

    final lowerText = text.toLowerCase();

    // 1. NLP Entity Extraction: Encontra todos os nós mencionados na frase
    List<NavNode> mentionedNodes = [];
    
    // Ordena do maior nome pro menor para evitar falsos positivos (ex: "Banheiro Masculino" antes de "Banheiro")
    final sortedNodes = b.nodes.toList()..sort((a, b) => b.label.length.compareTo(a.label.length));

    for (final node in sortedNodes) {
      if (node.label.trim().isEmpty) continue;
      final nodeLabel = node.label.toLowerCase().trim();
      
      // Busca exata completa
      if (lowerText.contains(nodeLabel)) {
        mentionedNodes.add(node);
      } else {
        // Busca Fuzzy (Correspondência parcial). Ex: Acha "Banheiro Masculino" se falar só "banheiro"
        final words = nodeLabel.split(' ').where((w) => w.length > 3).toList();
        if (words.isNotEmpty && words.any((w) => lowerText.contains(w))) {
          // Evita adicionar duas variações do mesmo local (ex: Banheiro Fem e Masc) se a palavra for ambígua
          if (!mentionedNodes.any((n) => n.label.toLowerCase().contains(words.first))) {
            mentionedNodes.add(node);
          }
        }
      }
    }

    if (mentionedNodes.length >= 2) {
      // Ordena pela ordem em que apareceram na frase (quem foi falado primeiro é a origem)
      mentionedNodes.sort((a, b) => lowerText.indexOf(a.label.toLowerCase().trim()).compareTo(lowerText.indexOf(b.label.toLowerCase().trim())));
      originNode = mentionedNodes.first;
      destNode = mentionedNodes.last;
    } else if (mentionedNodes.length == 1) {
      // Se falou apenas um local, assume que é o destino (origem será resolvida via Wi-Fi)
      destNode = mentionedNodes.first;
    } else {
      // Fallback para o Regex Gramatical (caso a extração direta não encontre)
      final parsed = _stt.parseCommand(text);
      if (parsed.origin != null) originNode = _findNode(b, parsed.origin!);
      if (parsed.destination != null) destNode = _findNode(b, parsed.destination!);
    }

    if (destNode == null) {
      _statusMessage = 'Destino não encontrado na planta.';
      await _tts.speak('Não encontrei o destino no mapa deste prédio.');
      notifyListeners();
      return;
    }

    await navigateTo(
      destinationId: destNode.id,
      originId: originNode?.id,
    );
  }

  // ── Route calculation ─────────────────────────────────────────────────────

  Future<void> navigateTo({
    required String destinationId,
    String? originId,
    IndoorPosition? currentPosition,
  }) async {
    final b = _building;
    if (b == null) return;

    String startId = originId ?? _resolveOriginFromPosition(b, currentPosition);

    _state = NavigationState.routing;
    notifyListeners();

    final route = _pathfinder.findRoute(
      startId: startId,
      goalId: destinationId,
      nodes: b.nodes,
      edges: b.edges,
    );

    if (route == null || route.isEmpty) {
      _statusMessage = 'Rota não encontrada.';
      _state = NavigationState.idle;
      await _tts.speak('Não foi possível calcular uma rota.');
      notifyListeners();
      return;
    }

    _route = route;
    _currentStepIndex = 0;
    _state = NavigationState.navigating;
    _statusMessage = 'Navegando...';
    notifyListeners();

    final dest = b.nodes.firstWhere((n) => n.id == destinationId);
    await _tts.speak(
      'Rota calculada. ${route.totalDistanceMeters.toStringAsFixed(0)} metros até ${dest.label}. '
      '${route.steps.first.instruction}',
    );
  }

  DateTime? _lastRerouteTime;

  /// Called every time the user's position updates. Advances route steps or triggers rerouting.
  Future<void> onPositionUpdate(IndoorPosition position) async {
    if (_state != NavigationState.navigating) return;
    final route = _route;
    if (route == null) return;

    final step = currentStep;
    if (step == null) return;

    // 1. Check if user is out of route (more than 6.0 meters away from current segment)
    final fromNode = step.fromNode;
    final toNode = step.toNode;
    final devDist = _distanceToSegment(position.x, position.y, fromNode.x, fromNode.y, toNode.x, toNode.y);
    if (devDist > 6.0) {
      await _handleReroute(position);
      return;
    }

    // 2. Check proximity to next node (within 3 m)
    final dx = position.x - toNode.x;
    final dy = position.y - toNode.y;
    final dist = (dx * dx + dy * dy);

    if (dist < 9.0) {
      // 3m²
      await _advanceStep();
    }
  }

  double _distanceToSegment(double px, double py, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1));
    
    double t = ((px - x1) * dx + (py - y1) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    
    final projX = x1 + t * dx;
    final projY = y1 + t * dy;
    final pX = px - projX;
    final pY = py - projY;
    return sqrt(pX * pX + pY * pY);
  }

  Future<void> _handleReroute(IndoorPosition position) async {
    // Debounce to avoid spamming the user's screen or TTS
    final now = DateTime.now();
    if (_lastRerouteTime != null && now.difference(_lastRerouteTime!) < const Duration(seconds: 10)) {
      return;
    }
    _lastRerouteTime = now;

    await _tts.speak('Você está saindo da rota certa. Recalculando.');

    final b = _building;
    final route = _route;
    if (b == null || route == null) return;

    final goalId = route.nodes.last.id;
    final startId = position.nearestNodeId ?? _resolveOriginFromPosition(b, position);

    final newRoute = _pathfinder.findRoute(
      startId: startId,
      goalId: goalId,
      nodes: b.nodes,
      edges: b.edges,
    );

    if (newRoute == null || newRoute.isEmpty) {
      await _tts.speak('Desvio detectado, mas não encontrei um novo caminho.');
      return;
    }

    _route = newRoute;
    _currentStepIndex = 0;
    notifyListeners();

    await _tts.speak('Nova rota calculada. ${newRoute.steps.first.instruction}');
  }

  Future<void> _advanceStep() async {
    final route = _route!;
    _currentStepIndex++;
    if (_currentStepIndex >= route.steps.length) {
      _state = NavigationState.arrived;
      _statusMessage = 'Você chegou!';
      notifyListeners();
      await _tts.speak('Você chegou ao destino.');
      return;
    }
    notifyListeners();
    await _tts.speak(route.steps[_currentStepIndex].instruction);
  }

  void cancelNavigation() {
    _route = null;
    _state = NavigationState.idle;
    _statusMessage = null;
    _tts.stop();
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  NavNode? _findNode(Building b, String query) {
    if (b.nodes.isEmpty) return null;
    final q = query.toLowerCase().trim();
    for (final node in b.nodes) {
      if (node.label.toLowerCase().trim() == q) return node;
    }
    for (final node in b.nodes) {
      if (node.label.toLowerCase().contains(q)) return node;
    }
    return null;
  }

  String _resolveOriginFromPosition(Building b, IndoorPosition? pos) {
    if (pos?.nearestNodeId != null) return pos!.nearestNodeId!;
    // Default to first entrance
    final entrance = b.nodes.firstWhere(
      (n) => n.nodeTypeStr == 'entrance',
      orElse: () => b.nodes.first,
    );
    return entrance.id;
  }
}
