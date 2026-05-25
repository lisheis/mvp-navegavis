# NavegaVis — Sistema de Navegação Indoor

> GPS interno para prédios: localização por Wi-Fi passivo, filtro de Kalman, grafo indoor com A\* e navegação guiada por voz em português brasileiro.

---

## Sumário

1. [Sobre o Projeto](#1-sobre-o-projeto)
2. [O Problema que Resolve](#2-o-problema-que-resolve)
3. [Funcionalidades](#3-funcionalidades)
4. [Arquitetura do Sistema](#4-arquitetura-do-sistema)
5. [Estrutura de Arquivos](#5-estrutura-de-arquivos)
6. [Modelos de Dados](#6-modelos-de-dados)
7. [Sistema de Localização Wi-Fi](#7-sistema-de-localização-wi-fi)
8. [Algoritmos](#8-algoritmos)
9. [Grafo Indoor e Roteamento A\*](#9-grafo-indoor-e-roteamento-a)
10. [Navegação por Voz](#10-navegação-por-voz)
11. [Gerenciamento de Estado](#11-gerenciamento-de-estado)
12. [Backend — API REST](#12-backend--api-rest)
13. [Banco de Dados](#13-banco-de-dados)
14. [Cache Offline](#14-cache-offline)
15. [Configuração e Instalação](#15-configuração-e-instalação)
16. [Estratégia de Treinamento Indoor](#16-estratégia-de-treinamento-indoor)
17. [Telas do App](#17-telas-do-app)
18. [Parâmetros Ajustáveis](#18-parâmetros-ajustáveis)
19. [Tecnologias Utilizadas](#19-tecnologias-utilizadas)
20. [Decisões de Arquitetura](#20-decisões-de-arquitetura)
21. [Limitações e Próximos Passos](#21-limitações-e-próximos-passos)

---

## 1. Sobre o Projeto

**NavegaVis** é um sistema completo de navegação indoor (dentro de prédios) que funciona **sem GPS e sem internet**. Ele usa os sinais Wi-Fi do ambiente como sensor passivo para estimar a posição do usuário dentro de um edifício, calcula a melhor rota usando o algoritmo A\* sobre um grafo de caminhos, e guia o usuário por voz em português.

O sistema é composto por:

- **App Flutter** — captura Wi-Fi, processa posição, renderiza mapa, executa rota e voz
- **Backend Node.js** — armazena prédios, grafos e fingerprints; sincroniza entre dispositivos
- **Algoritmos próprios** — Kalman filter, kNN fingerprinting, A\*, map matching

---

## 2. O Problema que Resolve

GPS não funciona dentro de prédios. Em ambientes como hospitais, centros culturais, museus, aeroportos ou shoppings, usuários — especialmente pessoas com deficiência visual — ficam sem referência espacial.

O NavegaVis resolve isso usando os roteadores Wi-Fi já existentes no local como **infraestrutura de localização passiva**: nenhum hardware adicional é necessário, nenhuma conexão é feita com eles. O app apenas lê a intensidade do sinal (RSSI) de cada roteador próximo e usa isso para estimar onde o usuário está.

---

## 3. Funcionalidades

| Funcionalidade | Detalhes |
|---|---|
| Localização indoor | Via Wi-Fi passivo (RSSI fingerprinting), sem GPS, sem internet |
| Filtro de Kalman | Suavização de sinal por BSSID + suavização de posição (x,y) |
| Filtro de média móvel | Segunda camada de suavização; evita flutuações bruscas |
| Map matching | Snap da posição estimada para o grafo de caminhos válidos |
| Editor de mapa | Criação de nós e arestas por toque diretamente no app |
| Roteamento A\* | Cálculo de menor caminho com heurística Euclidiana |
| Navegação por voz | Comando de voz + instruções em pt-BR guiadas por TTS |
| NLP de comandos | Interpreta frases naturais como "quero ir até o banheiro" |
| Offline-first | Mapa e posicionamento funcionam 100% sem internet |
| Multi-andar | Suporte a prédios com múltiplos andares |
| Multi-prédio | Gerencia vários ambientes diferentes |
| Treinamento no app | Coleta de fingerprints Wi-Fi por nó diretamente no celular |
| Sincronização | Backend sincroniza mapas e fingerprints entre dispositivos |
| Acessibilidade | Flag `accessible` em arestas para rotas sem escadas |

---

## 4. Arquitetura do Sistema

```
╔══════════════════════════════════════════════════════════════════════╗
║                         DISPOSITIVO MÓVEL                            ║
║                                                                      ║
║  ┌─────────────┐  RSSI   ┌────────────────────────────────────────┐ ║
║  │  Wi-Fi HW   │────────▶│  WifiScanService                       │ ║
║  │  (sensor)   │         │  • Scan periódico a cada 2s            │ ║
║  └─────────────┘         │  • Emite Stream<List<ApReading>>       │ ║
║                          └──────────────────┬───────────────────── ┘ ║
║                                             │ List<ApReading>        ║
║                          ┌──────────────────▼──────────────────────┐ ║
║                          │  WifiPositioningEngine                   │ ║
║                          │                                          │ ║
║                          │  [1] RssiKalmanBank                      │ ║
║                          │      Kalman 1D por BSSID (Q=0.008,R=4)  │ ║
║                          │          │                               │ ║
║                          │  [2] RssiMovingAverageBank               │ ║
║                          │      Janela deslizante de 4 amostras     │ ║
║                          │          │                               │ ║
║                          │  [3] kNN Fingerprint Match (k=3)         │ ║
║                          │      Distância Euclidiana no espaço RSSI │ ║
║                          │      Centróide por peso 1/(dist+ε)       │ ║
║                          │          │ (x_raw, y_raw)               │ ║
║                          │  [4] KalmanFilter2D                      │ ║
║                          │      Suaviza coordenadas x,y             │ ║
║                          │          │                               │ ║
║                          │  [5] PositionSmoother                    │ ║
║                          │      EWMA α=0.30 (anti-teleport)         │ ║
║                          └──────────────────┬───────────────────────┘ ║
║                                             │ IndoorPosition           ║
║                          ┌──────────────────▼───────────────────────┐ ║
║                          │  MapMatcher                               │ ║
║                          │  • Projeta posição nos segmentos do grafo │ ║
║                          │  • Snap ao nó/aresta mais próximo (≤5m)  │ ║
║                          └──────────────────┬───────────────────────┘ ║
║                                             │                          ║
║  ┌──────────────────────┐     ┌─────────────▼─────────────────────┐  ║
║  │  VoiceCommandFab     │     │  PositioningProvider               │  ║
║  │  STT (pt-BR)         │     │  Notifica NavigationProvider        │  ║
║  │  NLP parseCommand()  │     └──────────────────────────────────  ┘  ║
║  └──────────┬───────────┘                                             ║
║             │ {origin?, destination}                                   ║
║  ┌──────────▼───────────────────────────────────────────────────────┐ ║
║  │  NavigationProvider                                               │ ║
║  │  • Resolve nós por label                                         │ ║
║  │  • AStarPathfinder.findRoute()                                   │ ║
║  │  • Avança steps por proximidade (dist² < 9m)                     │ ║
║  │  • Chama TtsService para cada instrução                          │ ║
║  └──────────────────────────────────────────────────────────────────┘ ║
║                                                                        ║
║  ┌──────────────────────────────────────────────────────────────────┐ ║
║  │  IndoorMapView (CustomPainter)                                    │ ║
║  │  • Grid + arestas (cinza / azul na rota)                         │ ║
║  │  • Nós por tipo (cor + label)                                    │ ║
║  │  • Ponto azul do usuário + anel de confiança                     │ ║
║  │  • Destino atual com anel verde pulsante                         │ ║
║  └──────────────────────────────────────────────────────────────────┘ ║
║                                                                        ║
║  ┌──────────────────────┐   ┌──────────────────────────────────────┐ ║
║  │  TtsService (pt-BR)  │   │  CacheService (Hive JSON)            │ ║
║  │  flutter_tts         │   │  Buildings + Nodes + Edges + FPs     │ ║
║  └──────────────────────┘   └──────────────────────────────────────┘ ║
╚══════════════════════════════════════════════════════════════════════╝
                │  sync HTTP (best-effort, offline-tolerant)
                ▼
╔══════════════════════════════════════════════════════╗
║  Node.js Backend                                     ║
║                                                      ║
║  Express 4 + helmet + cors + morgan                  ║
║                                                      ║
║  ┌──────────────────────────────────────────────┐   ║
║  │  SQLite (better-sqlite3, WAL mode)           │   ║
║  │  • buildings                                 │   ║
║  │  • floor_plans                               │   ║
║  │  • nav_nodes                                 │   ║
║  │  • nav_edges                                 │   ║
║  │  • wifi_fingerprints                         │   ║
║  └──────────────────────────────────────────────┘   ║
║                                                      ║
║  /api/buildings      — CRUD de prédios + grafo       ║
║  /api/fingerprints   — upload/lista/estimativa       ║
║  /api/health         — health check                  ║
╚══════════════════════════════════════════════════════╝
```

### Princípios da Arquitetura

| Princípio | Como é aplicado |
|---|---|
| **Offline-first** | Toda navegação roda localmente; backend é opcional e assíncrono |
| **Wi-Fi como sensor** | Nenhuma conexão é feita com APs; só leitura de RSSI |
| **Sem GPS** | Posicionamento 100% baseado em fingerprint Wi-Fi |
| **Sem Google Maps** | Mapa é um CustomPainter próprio sobre grafo indoor |
| **Tolerante a ruído** | Kalman + moving average + map matching protegem contra spikes de sinal |
| **Separação de responsabilidades** | Algoritmos em `domain/`, UI em `presentation/`, dados em `data/`, I/O em `services/` |

---

## 5. Estrutura de Arquivos

```
navegavis2/
│
├── pubspec.yaml                            # Dependências Flutter
├── README.md                               # Esta documentação
│
├── lib/
│   ├── main.dart                           # Entry point — inicializa app
│   ├── app.dart                            # Root widget: MultiProvider + MaterialApp.router
│   │
│   ├── core/
│   │   ├── theme/
│   │   │   └── app_theme.dart             # Tema dark/light (Material 3)
│   │   └── router/
│   │       └── app_router.dart            # GoRouter — 4 rotas declarativas
│   │
│   ├── data/
│   │   └── models/
│   │       ├── building.dart              # Building + FloorPlan
│   │       ├── nav_node.dart              # NavNode + enum NodeType
│   │       ├── nav_edge.dart              # NavEdge + enum EdgeType
│   │       ├── wifi_fingerprint.dart      # ApReading + WifiFingerprint
│   │       ├── route_step.dart            # RouteStep + NavigationRoute + enum Direction
│   │       └── position.dart             # IndoorPosition (x, y, floor, confidence)
│   │
│   ├── domain/
│   │   └── algorithms/
│   │       ├── kalman_filter.dart         # KalmanFilter1D, KalmanFilter2D, RssiKalmanBank
│   │       ├── moving_average.dart        # MovingAverage, RssiMovingAverageBank, PositionSmoother
│   │       ├── wifi_positioning.dart      # WifiPositioningEngine (pipeline completo)
│   │       ├── astar.dart                 # AStarPathfinder + geração de instruções pt-BR
│   │       └── map_matching.dart          # MapMatcher (snap ao grafo)
│   │
│   ├── services/
│   │   ├── wifi_service.dart              # WifiScanService — stream de APs
│   │   ├── tts_service.dart               # TtsService — flutter_tts pt-BR
│   │   ├── stt_service.dart               # SttService — STT + NLP de comandos
│   │   ├── cache_service.dart             # CacheService — Hive JSON offline
│   │   └── api_service.dart               # ApiService — Dio REST client
│   │
│   └── presentation/
│       ├── providers/
│       │   ├── building_provider.dart     # CRUD de prédios + sync backend
│       │   ├── positioning_provider.dart  # Loop de posicionamento Wi-Fi
│       │   └── navigation_provider.dart   # Rota + voz + avanço de steps
│       │
│       ├── screens/
│       │   ├── home/
│       │   │   └── home_screen.dart       # Lista de prédios cadastrados
│       │   ├── map/
│       │   │   └── map_screen.dart        # Editor de grafo (nós + arestas)
│       │   ├── navigation/
│       │   │   └── navigation_screen.dart # Mapa em tempo real + barra de status
│       │   └── training/
│       │       └── training_screen.dart   # Coleta de fingerprints por nó
│       │
│       └── widgets/
│           ├── indoor_map_painter.dart    # CustomPainter — mapa + rota + usuário
│           └── voice_command_widget.dart  # FAB animado + chip de status de voz
│
└── backend/
    ├── server.js                          # Express app + rotas montadas
    ├── package.json                       # Dependências Node.js
    └── src/
        ├── db/
        │   └── database.js               # Conexão SQLite + criação de tabelas
        ├── routes/
        │   ├── buildings.js              # Rotas /api/buildings
        │   └── fingerprints.js          # Rotas /api/fingerprints
        └── controllers/
            ├── buildingController.js    # Lógica CRUD de prédios + grafo
            └── fingerprintController.js # Lógica CRUD de fingerprints + estimativa
```

---

## 6. Modelos de Dados

### NavNode — Ponto no Grafo

Representa um ponto físico dentro do prédio (entrada, sala, corredor, banheiro etc.).

```dart
class NavNode {
  final String id;           // UUID
  final String label;        // Nome exibido ("Banheiro Masculino")
  final double x;            // Posição em metros no eixo X do andar
  final double y;            // Posição em metros no eixo Y do andar
  final int floor;           // Número do andar (0 = térreo)
  final String nodeTypeStr;  // 'entrance' | 'corridor' | 'room' | 'bathroom'
                             // 'elevator' | 'stairs' | 'exit' | 'poi'
  final String buildingId;
  final Map<String, dynamic>? metadata; // dados extras livres
}
```

**Tipos de nó e suas cores no mapa:**

| NodeType | Cor | Uso |
|---|---|---|
| `entrance` | Verde | Entrada principal do prédio |
| `exit` | Vermelho | Saída de emergência |
| `corridor` | Cinza escuro | Corredor de passagem |
| `room` | Índigo | Sala, auditório, escritório |
| `bathroom` | Teal | Banheiro |
| `elevator` | Roxo | Elevador (conecta andares) |
| `stairs` | Laranja | Escada (conecta andares) |
| `poi` | Rosa | Ponto de interesse livre |

---

### NavEdge — Caminho entre Nós

Representa um trecho físico caminhável entre dois nós.

```dart
class NavEdge {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final double weight;        // Distância em metros (peso do A*)
  final bool bidirectional;   // true = caminho em ambas direções
  final String edgeTypeStr;   // 'walk' | 'stairs' | 'elevator' | 'ramp'
  final bool accessible;      // false = não acessível a cadeirantes
}
```

---

### WifiFingerprint — Amostra de Posição

Conjunto de leituras de APs Wi-Fi coletadas em um nó específico.

```dart
class ApReading {
  final String bssid;    // Endereço MAC do roteador (identificador único)
  final String ssid;     // Nome da rede (informativo)
  final int rssi;        // Força do sinal em dBm (ex: -62)
  final int frequency;   // Frequência em MHz (ex: 2412 = canal 1 a 2.4 GHz)
}

class WifiFingerprint {
  final String id;
  final String nodeId;       // Nó ao qual esta amostra pertence
  final String buildingId;
  final int floor;
  final List<ApReading> readings;  // Todas as leituras desta coleta
  final DateTime collectedAt;
}
```

**Por que BSSID e não SSID?**
BSSID é o endereço MAC do rádio — único por antena. SSID é o nome visível que pode se repetir em vários APs. Para fingerprinting, BSSID é obrigatório.

---

### IndoorPosition — Posição Estimada

Resultado final do pipeline de posicionamento.

```dart
class IndoorPosition {
  final double x;              // Metros no eixo X
  final double y;              // Metros no eixo Y
  final int floor;             // Andar estimado
  final double confidence;     // 0.0 a 1.0 — qualidade da estimativa
  final String? nearestNodeId; // ID do nó mais próximo após map matching
}
```

---

### NavigationRoute — Rota Calculada

```dart
class NavigationRoute {
  final List<NavNode> nodes;      // Sequência de nós da rota
  final List<RouteStep> steps;    // Instruções passo a passo
  final double totalDistanceMeters;
  final int estimatedSeconds;     // Baseado em 1.2 m/s (velocidade de caminhada)
}

class RouteStep {
  final NavNode fromNode;
  final NavNode toNode;
  final double distanceMeters;
  final Direction direction;   // straight | left | right | slightLeft | ...
  final String instruction;    // Frase em português para TTS
}
```

---

### Building — Prédio Completo

```dart
class Building {
  final String id;
  final String name;
  final String address;
  final List<FloorPlan> floorPlans;      // Um por andar
  final List<NavNode> nodes;
  final List<NavEdge> edges;
  final List<WifiFingerprint> fingerprints;
  final DateTime lastSynced;
}

class FloorPlan {
  final int floor;
  final String? imageUrl;      // Imagem da planta baixa (opcional)
  final double widthMeters;    // Largura real em metros
  final double heightMeters;   // Altura real em metros
}
```

**Exemplo real (JSON):**

```json
{
  "id": "bld-001",
  "name": "Caixa Cultural Brasília",
  "address": "SCS Quadra 4, Bloco A, Brasília – DF",
  "floorPlans": [
    { "floor": 0, "widthMeters": 80, "heightMeters": 60 },
    { "floor": 1, "widthMeters": 80, "heightMeters": 60 }
  ],
  "nodes": [
    { "id": "n1", "label": "Entrada Principal", "x": 5.0,  "y": 30.0, "floor": 0, "nodeType": "entrance" },
    { "id": "n2", "label": "Recepção",          "x": 15.0, "y": 30.0, "floor": 0, "nodeType": "room"     },
    { "id": "n3", "label": "Corredor Central",  "x": 40.0, "y": 30.0, "floor": 0, "nodeType": "corridor" },
    { "id": "n4", "label": "Banheiro",          "x": 70.0, "y": 10.0, "floor": 0, "nodeType": "bathroom" },
    { "id": "n5", "label": "Elevador",          "x": 40.0, "y": 55.0, "floor": 0, "nodeType": "elevator" },
    { "id": "n6", "label": "Galeria Principal", "x": 40.0, "y": 30.0, "floor": 1, "nodeType": "room"     }
  ],
  "edges": [
    { "id": "e1", "fromNodeId": "n1", "toNodeId": "n2", "weight": 10.0, "bidirectional": true, "edgeType": "walk",     "accessible": true },
    { "id": "e2", "fromNodeId": "n2", "toNodeId": "n3", "weight": 25.0, "bidirectional": true, "edgeType": "walk",     "accessible": true },
    { "id": "e3", "fromNodeId": "n3", "toNodeId": "n4", "weight": 32.0, "bidirectional": true, "edgeType": "walk",     "accessible": true },
    { "id": "e4", "fromNodeId": "n3", "toNodeId": "n5", "weight": 25.0, "bidirectional": true, "edgeType": "elevator", "accessible": true },
    { "id": "e5", "fromNodeId": "n5", "toNodeId": "n6", "weight": 1.0,  "bidirectional": true, "edgeType": "elevator", "accessible": true }
  ]
}
```

---

## 7. Sistema de Localização Wi-Fi

### Conceito: Fingerprinting

Fingerprinting Wi-Fi é uma técnica de posicionamento indoor baseada na observação de que **cada local físico dentro de um prédio tem uma "assinatura" única de sinais Wi-Fi** — uma combinação de quais roteadores são visíveis e com qual intensidade.

Durante o **treinamento**, o app coleta essa assinatura em cada ponto conhecido (nó do grafo). Durante a **navegação**, compara a leitura atual com as assinaturas armazenadas e estima onde o usuário está.

```
Fase de treinamento:
  Usuário vai até a "Recepção" → coleta Wi-Fi → salva fingerprint do nó "Recepção"
  Usuário vai até o "Banheiro"  → coleta Wi-Fi → salva fingerprint do nó "Banheiro"
  ...repete para todos os nós...

Fase de navegação:
  App lê Wi-Fi atual → compara com fingerprints salvos → "você está mais perto da Recepção"
```

### Por que não usa GPS?

GPS requer linha de visão com satélites — impossível dentro de prédios. Sinais GPS penetram paredes com atenuação de 20–30 dB, tornando a precisão inútil para navegação indoor.

### Por que não usa Bluetooth / beacons?

Beacons exigem hardware adicional instalado no prédio. O NavegaVis usa a infraestrutura Wi-Fi **já existente** — zero custo de hardware adicional.

### Pipeline de Localização (7 estágios)

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  ENTRADA: Map<String bssid, double rssiDdBm>                 │
│  Ex: { "AA:BB:CC": -62.0, "11:22:33": -78.0, ... }          │
│                                                              │
│  ──────────────────────────────────────────────────────────  │
│                                                              │
│  [1] KALMAN 1D POR BSSID (RssiKalmanBank)                    │
│      Para cada BSSID, aplica filtro de Kalman independente   │
│      • Reduz ruído de medição (multipath, interferência)     │
│      • Q = 0.008 (processo varia lentamente)                 │
│      • R = 4.0   (sensor tem ruído de ~4 dBm)               │
│      • Estado persiste entre ciclos de scan                  │
│                                                              │
│  [2] MÉDIA MÓVEL POR BSSID (RssiMovingAverageBank)           │
│      Janela deslizante de 4 amostras após o Kalman           │
│      • Segunda camada de suavização para picos residuais     │
│      • Opera sobre o sinal já filtrado pelo Kalman           │
│                                                              │
│  [3] kNN FINGERPRINT MATCHING                                │
│      k = 3 vizinhos mais próximos                            │
│      Métrica: distância Euclidiana no espaço RSSI            │
│                                                              │
│      d(live, stored) = √(Σ(live_bssid - stored_bssid)²)     │
│                                                              │
│      AP ausente no scan ao vivo = tratado como -100 dBm      │
│      AP ausente no fingerprint  = tratado como -100 dBm      │
│                                                              │
│  [4] CENTRÓIDE PONDERADO (IDW)                               │
│      Combina os k vizinhos por peso inverso à distância      │
│      weight_i = 1 / (dist_i + ε)                            │
│      x_raw = Σ(node_i.x × weight_i) / Σweight_i             │
│      y_raw = Σ(node_i.y × weight_i) / Σweight_i             │
│                                                              │
│  [5] KALMAN 2D EM (x, y) (KalmanFilter2D)                   │
│      Dois filtros Kalman 1D independentes para x e y         │
│      • processNoise   = 0.01                                 │
│      • measurementNoise = 1.5                                │
│      • Trata posição como estado persistente entre scans     │
│                                                              │
│  [6] ANTI-TELEPORT (PositionSmoother)                        │
│      EWMA: x_smooth = α × x_new + (1-α) × x_prev            │
│      α = 0.30 — favorece posição anterior (30% nova)         │
│      Impede o ponto do usuário de "pular" no mapa            │
│                                                              │
│  [7] MAP MATCHING (MapMatcher)                               │
│      Projeta posição no segmento de reta mais próximo        │
│      do grafo indoor (projeção ortogonal sobre aresta)       │
│      maxSnapDistance = 5m                                    │
│      Garante que usuário apareça em caminhos válidos         │
│                                                              │
│  SAÍDA: IndoorPosition(x, y, floor, confidence, nodeId)      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Confiança da Estimativa

```dart
confidence = (1.0 - bestDist / 200.0).clamp(0.0, 1.0)
```

- `bestDist = 0` → confiança = 100% (scan idêntico ao fingerprint)
- `bestDist = 100` → confiança = 50%
- `bestDist ≥ 200` → confiança = 0% (nenhuma correspondência útil)

---

## 8. Algoritmos

### 8.1 Filtro de Kalman 1D

O filtro de Kalman é um algoritmo recursivo que estima o estado de um sistema ruidoso. Para RSSI, trata o sinal como estado oculto e cada leitura como observação barulhenta.

**Equações:**

```
// Predição
P_pred = P + Q

// Ganho de Kalman
K = P_pred / (P_pred + R)

// Atualização
x = x + K × (medição - x)
P = (1 - K) × P_pred
```

**Parâmetros:**
- `Q = 0.008` — variância do processo (o RSSI real muda lentamente)
- `R = 4.0` — variância da medição (ruído típico do Wi-Fi em dBm²)
- `P_inicial = 1.0` — incerteza inicial da estimativa

**Por que é obrigatório?**
Sem Kalman, um único spike de sinal causaria um salto brusco na posição estimada. O filtro amortece variações bruscas mantendo o sistema responsivo a mudanças reais.

---

### 8.2 kNN (k-Nearest Neighbors)

Encontra os `k` fingerprints mais similares ao scan atual no banco de dados.

```
Para cada fingerprint armazenado:
  Calcular: d = √(Σ(rssi_live[bssid] - rssi_stored[bssid])²)
  
Ordenar por distância crescente
Tomar os k=3 menores

Calcular centróide com pesos inversamente proporcionais à distância:
  w_i = 1 / (d_i + 1e-6)
  x = Σ(nó_i.x × w_i) / Σw_i
  y = Σ(nó_i.y × w_i) / Σw_i
```

**Por que k=3?**
Com k=1, qualquer fingerprint ruidoso domina. Com k=5+, a posição tende ao centróide global. k=3 oferece robustez sem perder precisão local.

---

### 8.3 Map Matching

Evita que a posição estimada apareça em paredes ou áreas inacessíveis.

**Algoritmo (projeção ortogonal em segmento):**

```
Para cada aresta (A → B) do grafo no andar atual:
  Calcular vetor AB
  t = ((P - A) · AB) / |AB|²   // parâmetro de projeção
  Se 0 ≤ t ≤ 1:
    proj = A + t × AB           // ponto projetado no segmento
    d = |P - proj|              // distância do usuário ao segmento

Também verificar cada nó diretamente.

Escolher ponto com menor distância.
Se dist ≤ 5m: retornar posição projetada.
Caso contrário: retornar posição original (fora do alcance de snap).
```

---

## 9. Grafo Indoor e Roteamento A\*

### Por que um grafo?

O espaço físico de um prédio não é livre — há paredes, portas, obstáculos. Representar caminhos possíveis como arestas de um grafo garante que a rota calculada respeite a geometria real do ambiente.

### Estrutura do Grafo

```
NavNode = vértice (ponto físico)
NavEdge = aresta (caminho entre dois pontos)
  └── weight = distância em metros (usada como custo pelo A*)
```

### Algoritmo A\*

```
Heurística: h(n) = distância Euclidiana até o destino
             + penalidade de andar: |andar_n - andar_dest| × 10

Para cada nó na fila aberta (ordenada por f = g + h):
  Se é o destino: reconstruir caminho e retornar
  Para cada vizinho:
    g_novo = g_atual + peso_da_aresta
    Se g_novo < g_existente do vizinho:
      Atualizar vizinho
      Adicionar à fila aberta
```

A penalidade de andar incentiva o algoritmo a completar o deslocamento no andar atual antes de usar elevadores/escadas.

### Geração de Instruções em Português

Para cada passo, o algoritmo calcula o ângulo de deflexão entre o segmento anterior e o próximo:

```dart
ângulo = atan2(v2y, v2x) - atan2(v1y, v1x)  // normalizado para [-π, π]

Se |ângulo| < 0.26 rad (15°)  → "Siga em frente"
Se ângulo > 1.30 rad (75°)    → "Vire à esquerda"
Se ângulo < -1.30 rad         → "Vire à direita"
Se ângulo > 0                 → "Vire levemente à esquerda"
Caso contrário                → "Vire levemente à direita"
```

**Exemplo de instrução gerada:**
```
"Vire à esquerda e siga por 15 metros até o Banheiro."
"Siga em frente por poucos metros até a Recepção."
"Você chegou ao destino: Galeria Principal."
```

---

## 10. Navegação por Voz

### Fluxo Completo

```
Usuário fala: "estou na entrada do Caixa Cultural e quero ir até o banheiro"
                              │
                  ┌───────────▼──────────────┐
                  │  SpeechToText (pt-BR)     │
                  │  speech_to_text package   │
                  └───────────┬──────────────┘
                              │ texto transcrito
                  ┌───────────▼──────────────┐
                  │  SttService.parseCommand()│  NLP via regex
                  │                          │
                  │  Padrão 1 (completo):    │
                  │  "estou em/na/no <orig>  │
                  │   ... ir até <dest>"     │
                  │                          │
                  │  Padrão 2 (só destino):  │
                  │  "ir para/até <dest>"    │
                  │                          │
                  │  Padrão 3 (fallback):    │
                  │  texto inteiro = destino │
                  └───────────┬──────────────┘
                              │ { origin?, destination }
                  ┌───────────▼──────────────┐
                  │  NavigationProvider      │
                  │  findNode(label)         │
                  │  → busca por substring   │
                  │    case-insensitive      │
                  └───────────┬──────────────┘
                              │ NavNode origem + destino
                  ┌───────────▼──────────────┐
                  │  AStarPathfinder         │
                  │  findRoute(from, to)     │
                  └───────────┬──────────────┘
                              │ NavigationRoute
                  ┌───────────▼──────────────┐
                  │  TtsService.speak()       │
                  │  "Rota calculada.        │
                  │   45 metros até o        │
                  │   banheiro. Siga em      │
                  │   frente por 20 metros   │
                  │   até a Recepção."       │
                  └───────────┬──────────────┘
                              │
                  ┌───────────▼──────────────┐
                  │  Loop a cada scan (~2s)  │
                  │  onPositionUpdate()      │
                  │                          │
                  │  Se dist² < 9 (= 3m):   │
                  │    avança step           │
                  │    fala próxima instrução│
                  └──────────────────────────┘
```

### Exemplos de Comandos Aceitos

| Comando do usuário | Origem detectada | Destino detectado |
|---|---|---|
| "estou na entrada e quero ir até o banheiro" | entrada | banheiro |
| "quero ir para a recepção" | — (usa posição atual) | recepção |
| "ir até o elevador" | — | elevador |
| "navegar até a galeria principal" | — | galeria principal |
| "banheiro" | — | banheiro |

### TTS — Voz

Configuração padrão:
- Idioma: `pt-BR`
- Taxa de fala: 0.48 (ligeiramente mais lento que o normal para clareza)
- Volume: 1.0
- Tom: 1.0

---

## 11. Gerenciamento de Estado

O app usa **Provider** com três providers independentes:

### BuildingProvider
Responsável pelo ciclo de vida dos prédios.
- `init()` — carrega cache local, tenta sync com backend
- `createBuilding()` — cria prédio e persiste no Hive
- `addNode()` / `addEdge()` — adiciona elemento ao grafo e salva
- `addFingerprint()` — persiste fingerprint + tenta upload ao backend

### PositioningProvider
Loop principal de posicionamento.
- `startPositioning()` — inicia scan Wi-Fi periódico
- `_onScan()` — processa cada batch de APs → chama `WifiPositioningEngine` → chama `MapMatcher` → notifica listeners
- `stopPositioning()` — cancela timer e stream

### NavigationProvider
Controla a rota e a voz.
- `startVoiceCommand()` — ativa STT, aguarda, processa comando
- `navigateTo()` — chama A\*, inicia rota, fala instrução inicial
- `onPositionUpdate()` — verifica proximidade ao próximo nó, avança step se necessário
- `cancelNavigation()` — limpa estado, para TTS

**Diagrama de dependência entre providers:**
```
CacheService ──┐
ApiService  ──┤──▶ BuildingProvider
               │
WifiScanService ──▶ PositioningProvider
               │
TtsService  ──┐│
SttService  ──┤──▶ NavigationProvider
               │
               └── (NavigationProvider observa PositioningProvider via onPositionUpdate)
```

---

## 12. Backend — API REST

O backend é **opcional** — o app funciona 100% offline. Ele serve para:
1. Sincronizar mapas entre múltiplos dispositivos ou usuários
2. Fazer backup dos grafos e fingerprints
3. Debug e validação de fingerprints via estimativa server-side

### Endpoints — Prédios

| Método | Endpoint | Body | Retorno | Descrição |
|---|---|---|---|---|
| `GET` | `/api/buildings` | — | `Building[]` | Lista todos os prédios |
| `POST` | `/api/buildings` | `{ name, address?, floorPlans? }` | `Building` | Cria novo prédio |
| `GET` | `/api/buildings/:id` | — | `Building` | Dados completos com grafo e fingerprints |
| `PUT` | `/api/buildings/:id` | `{ name?, address?, nodes?, edges? }` | `Building` | Atualiza dados |
| `DELETE` | `/api/buildings/:id` | — | `204` | Remove prédio e todos os dados relacionados |
| `PUT` | `/api/buildings/:id/graph` | `{ nodes[], edges[] }` | `{ ok: true }` | Substitui grafo indoor completo |

### Endpoints — Fingerprints Wi-Fi

| Método | Endpoint | Query/Body | Retorno | Descrição |
|---|---|---|---|---|
| `GET` | `/api/fingerprints` | `?buildingId=X&floor=0&nodeId=Y` | `Fingerprint[]` | Lista amostras com filtros |
| `POST` | `/api/fingerprints` | `{ nodeId, buildingId, floor, readings[], collectedAt }` | `{ id }` | Upload de amostra |
| `DELETE` | `/api/fingerprints/:id` | — | `204` | Remove amostra |
| `DELETE` | `/api/fingerprints/building/:buildingId` | — | `204` | Limpa todas as amostras de um prédio |
| `POST` | `/api/fingerprints/estimate` | `{ buildingId, floor, scan: [{bssid, rssi}] }` | `{ nodeId, confidence, dist }` | Estimativa kNN server-side (debug) |

### Health Check

```
GET /api/health
→ { "status": "ok", "ts": "2025-01-01T12:00:00.000Z" }
```

### Exemplos de Chamadas

**Criar prédio:**
```bash
curl -X POST http://localhost:3000/api/buildings \
  -H "Content-Type: application/json" \
  -d '{ "name": "Caixa Cultural Brasília", "address": "SCS Quadra 4" }'
```

**Upload de fingerprint:**
```bash
curl -X POST http://localhost:3000/api/fingerprints \
  -H "Content-Type: application/json" \
  -d '{
    "nodeId": "n1",
    "buildingId": "bld-001",
    "floor": 0,
    "readings": [
      { "bssid": "AA:BB:CC:DD:EE:FF", "ssid": "Rede-X", "rssi": -62, "frequency": 2412 }
    ],
    "collectedAt": "2025-01-01T12:00:00Z"
  }'
```

**Estimativa server-side (debug):**
```bash
curl -X POST http://localhost:3000/api/fingerprints/estimate \
  -H "Content-Type: application/json" \
  -d '{
    "buildingId": "bld-001",
    "floor": 0,
    "scan": [
      { "bssid": "AA:BB:CC:DD:EE:FF", "rssi": -64 },
      { "bssid": "11:22:33:44:55:66", "rssi": -80 }
    ]
  }'
```

---

## 13. Banco de Dados

O backend usa **SQLite via better-sqlite3** com **WAL mode** (Write-Ahead Logging) para melhor desempenho em leituras concorrentes.

### Schema

```sql
-- Prédios
CREATE TABLE buildings (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  address    TEXT DEFAULT '',
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Plantas baixas por andar
CREATE TABLE floor_plans (
  id            TEXT PRIMARY KEY,
  building_id   TEXT NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
  floor         INTEGER NOT NULL,
  image_url     TEXT,
  width_meters  REAL NOT NULL DEFAULT 50,
  height_meters REAL NOT NULL DEFAULT 30
);

-- Nós do grafo indoor
CREATE TABLE nav_nodes (
  id          TEXT PRIMARY KEY,
  building_id TEXT NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
  label       TEXT NOT NULL,
  x           REAL NOT NULL,
  y           REAL NOT NULL,
  floor       INTEGER NOT NULL DEFAULT 0,
  node_type   TEXT NOT NULL DEFAULT 'corridor',
  metadata    TEXT DEFAULT '{}'
);

-- Arestas (caminhos)
CREATE TABLE nav_edges (
  id            TEXT PRIMARY KEY,
  building_id   TEXT NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
  from_node_id  TEXT NOT NULL REFERENCES nav_nodes(id) ON DELETE CASCADE,
  to_node_id    TEXT NOT NULL REFERENCES nav_nodes(id) ON DELETE CASCADE,
  weight        REAL NOT NULL,
  bidirectional INTEGER NOT NULL DEFAULT 1,
  edge_type     TEXT NOT NULL DEFAULT 'walk',
  accessible    INTEGER NOT NULL DEFAULT 1
);

-- Fingerprints Wi-Fi
CREATE TABLE wifi_fingerprints (
  id          TEXT PRIMARY KEY,
  building_id TEXT NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
  node_id     TEXT NOT NULL REFERENCES nav_nodes(id) ON DELETE CASCADE,
  floor       INTEGER NOT NULL,
  readings    TEXT NOT NULL,   -- JSON array de ApReading
  collected_at TEXT NOT NULL
);
```

**Chaves estrangeiras com `ON DELETE CASCADE`**: deletar um prédio remove automaticamente todos os andares, nós, arestas e fingerprints relacionados.

---

## 14. Cache Offline

O app usa **Hive** (banco chave-valor em Dart) para armazenar os dados dos prédios localmente como JSON.

### CacheService

```dart
// Salvar prédio completo
await cache.saveBuilding(building);  // key = building.id

// Recuperar (sem internet)
final building = cache.getBuilding('bld-001');

// Listar todos os prédios em cache
final buildings = cache.getAllBuildings();
```

### Estratégia de Sincronização

```
App inicia
  │
  ├─▶ Carrega cache local imediatamente (UI disponível offline)
  │
  └─▶ Tenta sync com backend (em background, sem bloquear UI)
        │
        ├─ Sucesso: atualiza cache + notifica listeners
        └─ Falha (sem internet): continua com cache local silenciosamente
```

O usuário **nunca espera pela rede**. Se não há internet, o app funciona normalmente com os dados já em cache.

---

## 15. Configuração e Instalação

### Pré-requisitos

| Ferramenta | Versão mínima |
|---|---|
| Flutter SDK | 3.0.0 |
| Dart | 3.0.0 |
| Node.js | 18.0.0 |
| npm | 9.0.0 |
| Android SDK | API 21 (Android 5.0) |
| Dispositivo físico Android | Obrigatório para Wi-Fi real |

> **iOS:** requer entitlements adicionais de Wi-Fi scanning (Network Extension). Funciona mas precisa de configuração extra no Xcode.

---

### Passo 1 — Clonar e instalar dependências

```bash
# Flutter
cd navegavis2
flutter pub get

# Backend
cd backend
npm install
```

---

### Passo 2 — Permissões Android

Adicionar em `android/app/src/main/AndroidManifest.xml` dentro de `<manifest>`:

```xml
<!-- Wi-Fi scanning (localização indoor) -->
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

<!-- Voz -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>

<!-- Sync com backend (opcional) -->
<uses-permission android:name="android.permission.INTERNET"/>
```

> **Android 9+:** a partir do Android 9 (API 28), scanning de Wi-Fi em background requer `ACCESS_FINE_LOCATION`. O app solicita essa permissão automaticamente via `permission_handler`.

> **Android 10+:** o sistema limita scans a 4 por 2 minutos em algumas condições. O app usa intervalo de 2s que funciona em modo foreground.

---

### Passo 3 — Configurar URL do backend

O `ApiService` aceita um `baseUrl` via parâmetro no construtor ou por variável de build. Por padrão em desenvolvimento o serviço aponta para `http://10.0.2.2:3000/api` (compatível com o emulador Android).

Opções de configuração:

- Passar diretamente no construtor (útil para testes no código):

```dart
ApiService(baseUrl: 'http://192.168.x.y:3000/api')
```

- Usar `--dart-define` ao rodar/buildar (recomendado para builds/CI):

```bash
# Emulador Android (aponta para o host localhost)
flutter run --dart-define=API_BASE_URL="http://10.0.2.2:3000/api"

# Dispositivo real — use o IP da máquina na rede local
flutter run --dart-define=API_BASE_URL="http://192.168.x.y:3000/api"

# Build release apontando para backend remoto
flutter build apk --release --dart-define=API_BASE_URL="https://api.seu-servidor.com/api"
```

Observação: para deploy em dispositivos reais, use o IP ou hostname público do servidor backend (com HTTPS em produção).

---

### Passo 4 — Iniciar backend

```bash
cd backend
npm start
# ou em modo desenvolvimento com hot reload:
npm run dev
```

Saída esperada:
```
{
  "status": "ok",
  "ts": "..."
}
```

---

### Passo 5 — Build remoto do APK via GitHub Actions

Se você não quer ou não pode gerar o APK no seu PC, use o workflow remoto do GitHub.

1. Adicione e commite o arquivo `.github/workflows/build-apk.yml` ao repositório.
2. Faça push para o GitHub.
3. Vá em `Actions` no repositório e abra o workflow `Build APK`.
4. Execute o workflow manualmente com `Run workflow`.
5. Quando o job terminar com sucesso, baixe o APK em `Artifacts` → `navegavis-apk`.

Esse build gera um APK com `API_BASE_URL=http://0.0.0.0:0/api`, ou seja, modo offline. Se quiser depois gerar um APK apontando para um backend real, posso ajustar o workflow para usar sua URL pública.

---

### Passo 6 — Instalar o APK no Android

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Ou instale o arquivo direto no seu dispositivo via USB ou compartilhamento.

---

### Passo 7 — Testar offline

1. Abra o app.
2. Crie um prédio e adicione nós/arestas.
3. Colete fingerprints em cada nó.
4. Inicie a navegação local.

NavegaVis backend running on http://localhost:3000
```

---

### Passo 5 — Rodar o app

```bash
# Listar dispositivos disponíveis
flutter devices

# Rodar no dispositivo físico
flutter run -d <device-id>

# Build APK para distribuição
flutter build apk --release
```

---

### Passo 6 — Hive (nota importante)

Os modelos com `@HiveType` precisam de geração de código para os arquivos `.g.dart`:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Alternativa sem build_runner:** o `CacheService` serializa/deserializa usando `.toJson()` / `.fromJson()` nativos. Para usar sem o Hive generator, substitua `Box<String>` com `SharedPreferences` ou simplesmente remova as anotações `@HiveType` — o cache JSON puro já funciona.

---

## 16. Estratégia de Treinamento Indoor

### O que é o treinamento?

Treinamento é a fase de **coleta de fingerprints**: o app aprende como é o sinal Wi-Fi em cada ponto do prédio. Sem essa fase, o sistema não sabe distinguir onde o usuário está.

### Passo a Passo

```
1. Criar o prédio
   App → Home → "Novo prédio" → informar nome e endereço

2. Criar o grafo no Editor de Mapa
   App → Mapa → modo "Nó" → tocar no mapa para criar pontos físicos
   App → Mapa → modo "Aresta" → tocar dois nós para conectá-los
   
   Boas práticas:
   • Criar nós a cada 5–10 metros em corredores longos
   • Cobrir todas as bifurcações, salas, banheiros, elevadores
   • Arestas devem refletir caminhos físicos reais (sem atravessar paredes)

3. Coletar fingerprints (Tela de Treinamento)
   Para cada nó:
   a) Andar fisicamente até o ponto no prédio
   b) Selecionar o nó correspondente na lista do app
   c) Tocar "Coletar amostra Wi-Fi"
   d) O app faz 3 varreduras automáticas (~6s no total)
   e) Repetir no mínimo 5 vezes em momentos diferentes do dia

4. Validar
   Ir para a tela de Navegação e caminhar pelo prédio
   O ponto azul deve seguir sua posição aproximada
   Se estiver impreciso: coletar mais amostras nos pontos problemáticos
```

### Quantidade Recomendada de Amostras

| Tamanho do ambiente | Amostras por nó | Total estimado |
|---|---|---|
| Pequeno (< 500 m²) | 5 | 50–100 |
| Médio (500–2000 m²) | 8 | 150–300 |
| Grande (> 2000 m²) | 10 | 300–600 |

### Dicas de Qualidade

| Prática | Motivo |
|---|---|
| Coletar em dias/horários diferentes | Ocupação do prédio altera propagação de sinal |
| Posicionar o celular sempre na mesma altura (~1m) | Orientação do dispositivo afeta RSSI |
| Verificar que ≥ 4 APs são visíveis por nó | Menos APs = fingerprint menos discriminativo |
| Separar nós por ≥ 3 metros | Fingerprints muito próximos confundem o kNN |
| Reativar treinamento após rearranjo de móveis | Móveis alteram a propagação do sinal |
| Coletar amostras com o prédio em uso normal | Pessoas absorvem sinal — o treino deve refletir isso |

### Por que múltiplas amostras por nó?

O sinal Wi-Fi flutua naturalmente ±3–5 dBm. Múltiplas amostras são armazenadas individualmente no banco — o kNN as trata como referências independentes. Isso é equivalente a um "banco de exemplos" que captura a variabilidade natural do sinal naquele ponto.

---

## 17. Telas do App

### Home — Lista de Prédios

Exibe todos os prédios cadastrados no cache local. Permite criar novo prédio via dialog. Cada item do prédio tem menu com acesso às três funções: editar mapa, treinar Wi-Fi e navegar.

### Editor de Mapa

Interface de criação do grafo indoor:

| Modo | Ação |
|---|---|
| **Nó** | Toca no mapa → dialog pede nome → cria NavNode naquela posição |
| **Aresta** | Toca no primeiro nó → toca no segundo → cria NavEdge com distância calculada |
| **Apagar** | (MVP — reservado para versão futura) |

Seletor de tipo de nó (NodeType) no topo permite escolher entre: entrance, corridor, room, elevator, stairs, bathroom, exit, poi.

### Tela de Navegação

Tela principal de uso em tempo real:

- Mapa ao centro com posição do usuário (ponto azul) atualizado a cada ~2s
- Barra de status no topo com instrução atual e dados de confiança
- Seletor de andar na base
- FAB de comando de voz que anima quando ouvindo
- Cancela rota com botão no AppBar

### Treinamento Wi-Fi

Lista todos os nós do prédio. Usuário seleciona um nó, caminha até o ponto físico correspondente e toca "Coletar amostra". O app faz 3 varreduras e salva o fingerprint.

---

## 18. Parâmetros Ajustáveis

Todos os parâmetros críticos estão em constantes facilmente localizáveis:

### Localização

| Parâmetro | Arquivo | Padrão | Aumentar | Diminuir |
|---|---|---|---|---|
| `k` (kNN) | `wifi_positioning.dart:13` | `3` | Posição mais suave, menos precisa | Posição mais precisa, mais instável |
| `Q` Kalman RSSI | `kalman_filter.dart:40` | `0.008` | Segue variações reais mais rápido | Mais suavização, mais lento |
| `R` Kalman RSSI | `kalman_filter.dart:41` | `4.0` | Mais suavização | Mais responsivo ao sinal |
| Janela MA | `moving_average.dart:44` | `4` | Mais suavização | Mais responsivo |
| `alpha` smoother | `moving_average.dart:64` | `0.30` | Mais responsivo | Menos teleporte |
| `processNoise` Kalman 2D | `wifi_positioning.dart` | `0.01` | Posição muda mais rápido | Posição mais estável |
| `measurementNoise` Kalman 2D | `wifi_positioning.dart` | `1.5` | Mais suavização | Mais fiel ao kNN |
| `maxSnapDistance` | `positioning_provider.dart:52` | `5.0 m` | Snap mais agressivo | Snap só em proximidade |

### Scan e Performance

| Parâmetro | Arquivo | Padrão | Nota |
|---|---|---|---|
| Intervalo de scan | `positioning_provider.dart:37` | `2000 ms` | Menor = mais responsivo, mais bateria |
| Amostras por coleta | `training_screen.dart` | `3` | Mais = fingerprint mais robusto |
| Delay entre amostras | `training_screen.dart` | `500 ms` | |

### Navegação

| Parâmetro | Arquivo | Padrão | Nota |
|---|---|---|---|
| Raio de chegada ao nó | `navigation_provider.dart` | `9 m²` (= 3m) | Distância² para avançar step |
| Velocidade de caminhada | `astar.dart` | `1.2 m/s` | Usada para estimar tempo da rota |
| Penalidade de andar (A\*) | `astar.dart` | `10 m/andar` | Incentiva completar andar antes de trocar |

### Voz

| Parâmetro | Arquivo | Padrão | Nota |
|---|---|---|---|
| Taxa de fala TTS | `tts_service.dart` | `0.48` | 0.0 = lento, 1.0 = rápido |
| Timeout STT | `stt_service.dart` | `8 s` | Tempo máximo ouvindo |
| Pause STT | `stt_service.dart` | `3 s` | Silêncio para encerrar escuta |

---

## 19. Tecnologias Utilizadas

### Frontend (Flutter)

| Pacote | Versão | Uso |
|---|---|---|
| `flutter` SDK | ≥ 3.0.0 | Framework base |
| `provider` | ^6.1.1 | Gerenciamento de estado |
| `go_router` | ^12.1.3 | Roteamento declarativo |
| `wifi_scan` | ^0.4.1 | Leitura de APs Wi-Fi (RSSI) |
| `flutter_tts` | ^3.8.5 | Text-to-speech pt-BR |
| `speech_to_text` | ^6.6.0 | Speech-to-text pt-BR |
| `hive_flutter` | ^1.1.0 | Cache offline local |
| `dio` | ^5.4.0 | HTTP client (sync com backend) |
| `connectivity_plus` | ^5.0.2 | Detecção de conectividade |
| `permission_handler` | ^11.1.0 | Permissões Android/iOS |
| `uuid` | ^4.2.2 | Geração de IDs únicos |
| `vector_math` | ^2.1.4 | Cálculos vetoriais |

### Backend (Node.js)

| Pacote | Versão | Uso |
|---|---|---|
| `express` | ^4.18.2 | Framework HTTP |
| `better-sqlite3` | ^9.4.3 | SQLite síncrono de alta performance |
| `cors` | ^2.8.5 | Headers CORS |
| `helmet` | ^7.1.0 | Headers de segurança HTTP |
| `morgan` | ^1.10.0 | Logging de requisições |
| `uuid` | ^9.0.0 | UUIDs para IDs |
| `nodemon` | ^3.0.3 | Hot reload em desenvolvimento |

### Algoritmos (implementados do zero)

| Algoritmo | Arquivo | Descrição |
|---|---|---|
| Kalman 1D | `kalman_filter.dart` | Suavização de sinal RSSI por BSSID |
| Kalman 2D | `kalman_filter.dart` | Suavização de posição (x, y) |
| kNN + IDW | `wifi_positioning.dart` | Fingerprint matching + centróide ponderado |
| EWMA | `moving_average.dart` | Suavizador anti-teleport exponencial |
| A\* | `astar.dart` | Caminho mínimo no grafo indoor |
| Map Matching | `map_matching.dart` | Projeção ortogonal em segmentos do grafo |

---

## 20. Decisões de Arquitetura

### Por que Flutter?
- Código único para Android e iOS
- CustomPainter permite mapa indoor totalmente customizado sem dependências de mapas externos
- Pacotes de Wi-Fi, TTS e STT com suporte ativo

### Por que Wi-Fi e não BLE/UWB?
- Wi-Fi já existe em praticamente todos os prédios públicos
- Sem custo de hardware (zero beacons para instalar)
- RSSI Wi-Fi tem alcance de 30–50m — adequado para fingerprinting indoor
- BLE seria mais preciso mas requer infraestrutura dedicada

### Por que Kalman + MA em vez de só um?
- Kalman é ótimo para ruído Gaussiano mas tem lag em mudanças bruscas
- Moving average complementa capturando padrões de janela
- A combinação dos dois reduz tanto spikes quanto o lag isolado de cada um

### Por que SQLite no backend e não PostgreSQL/MongoDB?
- Zero configuração para desenvolvimento e deploy simples
- better-sqlite3 é síncrono — ideal para Node.js com Express sem async complexo
- Dados indoor são relativamente pequenos (10k nós = ~5MB)
- Pode ser substituído por PostgreSQL em produção com alterações mínimas

### Por que Provider e não Riverpod/BLoC?
- Provider é mais simples para um MVP — menos boilerplate
- A separação de concerns já está feita pelos três providers independentes
- Migração para Riverpod é possível sem alterar a lógica de domínio

### Por que offline-first?
- Dentro de prédios, conectividade é frequentemente ruim (paredes atenuam sinal)
- Usuários com deficiência visual não podem depender de reconectar manualmente
- O sistema de localização Wi-Fi é intrinsecamente local — sem necessidade de cloud

---

## 21. Limitações e Próximos Passos

### Limitações Conhecidas

| Limitação | Impacto | Solução futura |
|---|---|---|
| Android 9+ limita scans em background | Posição para em segundo plano | Foreground Service permanente |
| iOS requer Network Extension | Wi-Fi scanning não disponível por padrão | Entitlement + CoreLocation |
| Fingerprint degrada com o tempo | Precisão cai após mudanças no prédio | Re-treinamento periódico ou incremental |
| kNN não distingue andares por RSSI | Sinal pode confundir andares semelhantes | Barômetro como sensor adicional de andar |
| NLP de voz é baseado em regex | Comandos muito livres falham | Integração com LLM local ou API |
| Sem PDR (Pedestrian Dead Reckoning) | Falha total se Wi-Fi sumir | Fusão com acelerômetro/giroscópio |

### Roadmap

**Curto prazo (MVP+):**
- [ ] Foreground Service Android para scan contínuo em segundo plano
- [ ] Suporte a imagem de planta baixa como fundo do mapa
- [ ] Re-treinamento incremental sem apagar fingerprints anteriores
- [ ] Exportar/importar mapa como arquivo JSON

**Médio prazo:**
- [ ] PDR (acelerômetro + giroscópio) como fallback quando Wi-Fi é fraco
- [ ] Barômetro para detecção precisa de andar
- [ ] Interface web para editar grafo em computador e exportar para o app
- [ ] Múltiplos usuários simultâneos (heatmap de presença)

**Longo prazo:**
- [ ] Machine learning (LSTM) no lugar de kNN para posicionamento temporal
- [ ] Suporte a UWB (Ultra-Wideband) para precisão centimétrica em hardware compatível
- [ ] Mapeamento colaborativo: vários celulares treinam o modelo ao mesmo tempo
- [ ] API pública para integração com sistemas de acessibilidade de hospitais/museus

---

## Licença

Este projeto é de uso educacional e de pesquisa. Adapte livremente para suas necessidades.

---

*NavegaVis — Um GPS para quem não pode depender do céu.*
