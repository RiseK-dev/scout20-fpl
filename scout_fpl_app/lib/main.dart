import 'package:flutter/material.dart';
import 'models/player_model.dart';
import 'services/fpl_api_service.dart';
import 'widgets/player_card.dart';
import 'widgets/player_detail_sheet.dart';

void main() {
  runApp(const ScoutFplApp());
}

class ScoutFplApp extends StatelessWidget {
  const ScoutFplApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPL Best Buys Scout',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38003C),
          primary: const Color(0xFF38003C),
          secondary: const Color(0xFF00FF87),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF38003C),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late FplApiService _apiService;
  late TextEditingController _hostController;

  GameweekOverview? _overview;
  List<PlayerRecommendation> _recommendations = [];
  List<PlayerRecommendation> _topKeepers = [];
  List<PlayerRecommendation> _jokers = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Navigation Tab State (0 = Topp 20, 1 = Keepere, 2 = Joker)
  int _currentTabIndex = 0;

  // Filter States for Main Tab
  String _selectedPosition = 'ALL';
  double _maxPrice = 15.0;
  int _nextGameweeks = 3;
  String _sortBy = 'expected_points';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiService = FplApiService();
    _hostController = TextEditingController(text: _apiService.baseUrl);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hostController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final overviewFuture = _apiService.fetchOverview();
      
      // 1. Fetch Main List (20 players)
      final buysFuture = _apiService.fetchBestBuys(
        position: _selectedPosition,
        maxPrice: _maxPrice,
        nextGameweeks: _nextGameweeks,
        limit: 20,
        sortBy: _sortBy,
      );

      // 2. Fetch Top 3 Keepers
      final keepersFuture = _apiService.fetchBestBuys(
        position: 'GKP',
        nextGameweeks: _nextGameweeks,
        limit: 3,
        sortBy: 'expected_points',
      );

      // 3. Fetch Joker Picks
      final jokersFuture = _apiService.fetchJokers(
        nextGameweeks: _nextGameweeks,
        limit: 1,
      );

      final results = await Future.wait([overviewFuture, buysFuture, keepersFuture, jokersFuture]);

      setState(() {
        _overview = results[0] as GameweekOverview;
        _recommendations = results[1] as List<PlayerRecommendation>;
        _topKeepers = results[2] as List<PlayerRecommendation>;
        _jokers = results[3] as List<PlayerRecommendation>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the URL for the Python FastAPI backend server:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                border: OutlineInputBorder(),
                hintText: 'e.g. http://10.0.2.2:8000',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '• Android Emulator: http://10.0.2.2:8000\n'
              '• Web / Localhost: http://localhost:8000\n'
              '• Physical Device: http://<Your-PC-IP>:8000',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _apiService = FplApiService(
                  customBaseUrl: _hostController.text.trim(),
                );
              });
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  void _showDetailModal(PlayerRecommendation player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PlayerDetailSheet(player: player),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF87),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: Color(0xFF38003C),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'FPL Best Buys',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOverviewBanner(),
          Expanded(
            child: _buildActiveTabContent(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        selectedItemColor: const Color(0xFF38003C),
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.format_list_numbered),
            activeIcon: Icon(Icons.format_list_numbered_rtl, color: Color(0xFF38003C)),
            label: 'Top 20',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            activeIcon: Icon(Icons.security, color: Color(0xFF38003C)),
            label: 'Keepers (3)',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            activeIcon: Icon(Icons.auto_awesome, color: Color(0xFF38003C)),
            label: 'Joker',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewBanner() {
    final gwName = _overview?.gameweekName ?? 'GW Overview';
    final playersCount = _overview?.totalFplPlayers ?? 0;

    return Container(
      width: double.infinity,
      color: const Color(0xFF38003C),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month, color: Color(0xFF00FF87), size: 18),
                const SizedBox(width: 6),
                Text(
                  gwName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Text(
              playersCount > 0 ? 'Analyzing $playersCount players' : 'Connecting...',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_currentTabIndex) {
      case 0:
        return _buildMainTab();
      case 1:
        return _buildKeepersTab();
      case 2:
        return _buildJokerTab();
      default:
        return _buildMainTab();
    }
  }

  // FANE 1: Hovedfane (Topp 20 spillere med bakgrunnsbilde)
  Widget _buildMainTab() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/top20_bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          _buildFilterBar(),
          _buildListHeader(),
          Expanded(child: _buildPlayerList(_recommendations)),
        ],
      ),
    );
  }

  // FANE 2: Keepere (Topp 3 keepere med bakgrunnsbilde)
  Widget _buildKeepersTab() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/keepers_bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.white.withValues(alpha: 0.92),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.security, color: Colors.amber.shade900, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top 3 Recommended Keepers',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Sorted by expected points for upcoming gameweeks',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade200.withValues(alpha: 0.90),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered, size: 16, color: Color(0xFF38003C)),
                const SizedBox(width: 6),
                Text(
                  'Showing ${_topKeepers.length} best keepers',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF38003C),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildPlayerList(_topKeepers)),
        ],
      ),
    );
  }

  // FANE 3: Joker (med bakgrunnsbilde)
  Widget _buildJokerTab() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/joker_bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.white.withValues(alpha: 0.92),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF87).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF38003C), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🃏 Joker Candidate',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Affordable player with low ownership and highest projected points per million!',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade200.withValues(alpha: 0.90),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, size: 16, color: Color(0xFF38003C)),
                const SizedBox(width: 6),
                Text(
                  'Showing ${_jokers.length} recommended joker pick',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF38003C),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildPlayerList(_jokers)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white.withValues(alpha: 0.92),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Nedtrekksmeny for posisjon
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF38003C).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF38003C).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 20, color: Color(0xFF38003C)),
                const SizedBox(width: 8),
                const Text(
                  'Select position:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF38003C),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPosition,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38003C)),
                      style: const TextStyle(
                        color: Color(0xFF38003C),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text('All 20 players (Default)'),
                        ),
                        DropdownMenuItem(
                          value: 'DEF',
                          child: Text('Defenders only'),
                        ),
                        DropdownMenuItem(
                          value: 'MID',
                          child: Text('Midfielders only'),
                        ),
                        DropdownMenuItem(
                          value: 'FWD',
                          child: Text('Forwards only'),
                        ),
                        DropdownMenuItem(
                          value: 'GKP',
                          child: Text('Goalkeepers only'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedPosition = val;
                          });
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Maks pris & Gameweek horisont
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Max: £${_maxPrice == 15.0 ? "Unlimited" : "${_maxPrice.toStringAsFixed(1)}m"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _maxPrice,
                          min: 4.0,
                          max: 15.0,
                          divisions: 22,
                          label: '£${_maxPrice.toStringAsFixed(1)}m',
                          activeColor: const Color(0xFF38003C),
                          onChanged: (val) {
                            setState(() {
                              _maxPrice = val;
                            });
                          },
                          onChangeEnd: (_) => _loadData(),
                        ),
                      ),
                    ],
                  ),
                ),

                DropdownButton<int>(
                  value: _nextGameweeks,
                  underline: const SizedBox(),
                  style: const TextStyle(
                    color: Color(0xFF38003C),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  items: const [
                    DropdownMenuItem(value: 3, child: Text('Next 3 GWs')),
                    DropdownMenuItem(value: 5, child: Text('Next 5 GWs')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _nextGameweeks = val;
                      });
                      _loadData();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    String posText = 'players';
    if (_selectedPosition == 'DEF') posText = 'defenders';
    if (_selectedPosition == 'MID') posText = 'midfielders';
    if (_selectedPosition == 'FWD') posText = 'forwards';
    if (_selectedPosition == 'GKP') posText = 'goalkeepers';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade200.withValues(alpha: 0.90),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_numbered, size: 16, color: Color(0xFF38003C)),
              const SizedBox(width: 6),
              Text(
                'Showing ${_recommendations.length} $posText',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF38003C),
                ),
              ),
            ],
          ),
          
          InkWell(
            onTap: () {
              setState(() {
                _sortBy = (_sortBy == 'expected_points') ? 'best_buy_score' : 'expected_points';
              });
              _loadData();
            },
            child: Row(
              children: [
                Text(
                  _sortBy == 'expected_points' ? 'Sorted: Projected Pts' : 'Sorted: Scout Score',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007A33),
                  ),
                ),
                const Icon(Icons.swap_vert, size: 16, color: Color(0xFF007A33)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerList(List<PlayerRecommendation> list) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF38003C)),
            SizedBox(height: 16),
            Text(
              'Fetching FPL data and calculating projected points...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 50, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text(
                'Could not connect to Python backend',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38003C),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _showSettingsDialog,
                child: const Text('Configure Backend URL'),
              ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return const Center(
        child: Text('No players matched your filter criteria.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF38003C),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: list.length,
        itemBuilder: (ctx, index) {
          final player = list[index];
          return PlayerCard(
            player: player,
            rank: index + 1,
            onTap: () => _showDetailModal(player),
          );
        },
      ),
    );
  }
}
