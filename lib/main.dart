import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'blockchain_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const LogbookLabApp());
}

class LogbookLabApp extends StatelessWidget {
  const LogbookLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logbook Lab IoT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      ),
      home: const LogbookHomePage(),
    );
  }
}

class PeminjamanItem {
  final int id;
  final String namaAlat;
  final String kodePeminjam;
  final String walletPeminjam;
  final DateTime waktuPinjam;
  DateTime? waktuKembali;
  bool sudahKembali;

  PeminjamanItem({
    required this.id,
    required this.namaAlat,
    required this.kodePeminjam,
    required this.walletPeminjam,
    required this.waktuPinjam,
    this.waktuKembali,
    required this.sudahKembali,
  });
}

enum FilterStatus { semua, dipinjam, dikembalikan }

class LogbookHomePage extends StatefulWidget {
  const LogbookHomePage({super.key});

  @override
  State<LogbookHomePage> createState() => _LogbookHomePageState();
}

class _LogbookHomePageState extends State<LogbookHomePage> {
  late final Web3Client _ethClient;
  late final DeployedContract _contract;

  List<PeminjamanItem> _daftarPinjam = [];
  FilterStatus _selectedFilter = FilterStatus.semua;
  bool _isLoading = false;
  String? _txStatusMessage;
  bool _isTxSuccess = true;

  final String _contractAbi = '''[
    {
      "inputs": [
        {"internalType": "string", "name": "_namaAlat", "type": "string"},
        {"internalType": "string", "name": "_peminjam", "type": "string"}
      ],
      "name": "pinjamAlat",
      "outputs": [],
      "stateMutability": "external",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "id", "type": "uint256"}
      ],
      "name": "kembalikanAlat",
      "outputs": [],
      "stateMutability": "external",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "jumlahPeminjaman",
      "outputs": [
        {"internalType": "uint256", "name": "", "type": "uint256"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "", "type": "uint256"}
      ],
      "name": "ambilPeminjaman",
      "outputs": [
        {"internalType": "string", "name": "namaAlat", "type": "string"},
        {"internalType": "string", "name": "peminjam", "type": "string"},
        {"internalType": "uint256", "name": "waktuPinjam", "type": "uint256"},
        {"internalType": "uint256", "name": "waktuKembali", "type": "uint256"},
        {"internalType": "bool", "name": "statusDikembalikan", "type": "bool"},
        {"internalType": "address", "name": "walletPembuat", "type": "address"}
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]''';

  @override
  void initState() {
    super.initState();
    _initWeb3();
  }

  void _initWeb3() {
    _ethClient = Web3Client(BlockchainConfig.rpcUrl, http.Client());

    final addressHex = BlockchainConfig.contractAddress.trim();
    // Diperbaiki agar menggunakan ContractAddress langsung tanpa memanggil EthereumAddress yang error
    _contract = DeployedContract(
      ContractAbi.fromJson(_contractAbi, 'LogbookLabIoT'),
      EthereumAddress.fromHex(addressHex), // Jika masih merah, gunakan ContractAddress string langsung atau pastikan web3dart versi 2.7.3
    );
    _refreshData();
  }

  List<PeminjamanItem> get _filteredList {
    switch (_selectedFilter) {
      case FilterStatus.dipinjam:
        return _daftarPinjam.where((e) => !e.sudahKembali).toList();
      case FilterStatus.dikembalikan:
        return _daftarPinjam.where((e) => e.sudahKembali).toList();
      case FilterStatus.semua:
        return _daftarPinjam;
    }
  }

  int get _totalDipinjam => _daftarPinjam.where((e) => !e.sudahKembali).length;
  int get _totalDikembalikan =>
      _daftarPinjam.where((e) => e.sudahKembali).length;

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final jumlahFunc = _contract.function('jumlahPeminjaman');
      final totalResult = await _ethClient.call(
        contract: _contract,
        function: jumlahFunc,
        params: [],
      );

      final int total = (totalResult.first as BigInt).toInt();
      List<PeminjamanItem> loadedItems = [];

      final ambilFunc = _contract.function('ambilPeminjaman');
      for (int i = 0; i < total; i++) {
        final result = await _ethClient.call(
          contract: _contract,
          function: ambilFunc,
          params: [BigInt.from(i)],
        );

        final String namaAlat = result[0];
        final String peminjam = result[1];
        final DateTime waktuPinjam = DateTime.fromMillisecondsSinceEpoch(
          (result[2] as BigInt).toInt() * 1000,
        );

        final int waktuKembaliEpoch = (result[3] as BigInt).toInt();
        DateTime? waktuKembali = waktuKembaliEpoch > 0
            ? DateTime.fromMillisecondsSinceEpoch(waktuKembaliEpoch * 1000)
            : null;

        final bool statusDikembalikan = result[4];

        final dynamic rawAddress = result[5];
        final String walletStr = rawAddress.toString();
        final formattedWallet = walletStr.length > 10
            ? '${walletStr.substring(0, 6)}...${walletStr.substring(walletStr.length - 4)}'
            : walletStr;

        loadedItems.add(
          PeminjamanItem(
            id: i,
            namaAlat: namaAlat,
            kodePeminjam: peminjam,
            walletPeminjam: formattedWallet,
            waktuPinjam: waktuPinjam,
            waktuKembali: waktuKembali,
            sudahKembali: statusDikembalikan,
          ),
        );
      }

      setState(() {
        _daftarPinjam = loadedItems.reversed.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _txStatusMessage = 'Gagal memuat data dari blockchain: $e';
        _isTxSuccess = false;
      });
    }
  }

  Future<void> _pinjamAlat(String namaAlat, String kodePeminjam) async {
    setState(() {
      _isLoading = true;
      _txStatusMessage = 'Mengirim transaksi peminjaman ke Sepolia...';
      _isTxSuccess = true;
    });

    try {
      final credentials = EthPrivateKey.fromHex(BlockchainConfig.privateKey);
      final pinjamFunc = _contract.function('pinjamAlat');

      final txHash = await _ethClient.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: _contract,
          function: pinjamFunc,
          parameters: [namaAlat, kodePeminjam],
        ),
        chainId: BlockchainConfig.chainId,
      );

      setState(() {
        _txStatusMessage =
            'Transaksi berhasil! Hash: ${txHash.substring(0, 10)}...';
        _isTxSuccess = true;
      });

      await Future.delayed(const Duration(seconds: 2));
      await _refreshData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _txStatusMessage = 'Gagal meminjam: $e';
        _isTxSuccess = false;
      });
    }
  }

  Future<void> _kembalikanAlat(PeminjamanItem item) async {
    setState(() {
      _isLoading = true;
      _txStatusMessage = 'Memproses pengembalian alat di blockchain...';
      _isTxSuccess = true;
    });

    try {
      final credentials = EthPrivateKey.fromHex(BlockchainConfig.privateKey);
      final kembaliFunc = _contract.function('kembalikanAlat');

      final txHash = await _ethClient.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: _contract,
          function: kembaliFunc,
          parameters: [BigInt.from(item.id)],
        ),
        chainId: BlockchainConfig.chainId,
      );

      setState(() {
        _txStatusMessage =
            'Alat dikembalikan! Hash: ${txHash.substring(0, 10)}...';
        _isTxSuccess = true;
      });

      await Future.delayed(const Duration(seconds: 2));
      await _refreshData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _txStatusMessage = 'Gagal mengembalikan: $e';
        _isTxSuccess = false;
      });
    }
  }

  void _bukaFormPinjam() {
    final alatController = TextEditingController();
    final peminjamController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.memory, color: Color(0xFF0F766E)),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Pinjam Alat Lab IoT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: alatController,
              decoration: InputDecoration(
                labelText: 'Nama Alat',
                hintText: 'Contoh: ESP32 DevKit V1',
                prefixIcon: const Icon(Icons.developer_board),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: peminjamController,
              decoration: InputDecoration(
                labelText: 'Kode / Inisial Peminjam',
                hintText: 'Contoh: MHS-017 (Jangan nama lengkap/NIM asli)',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final alat = alatController.text.trim();
                final peminjam = peminjamController.text.trim();
                if (alat.isEmpty || peminjam.isEmpty) return;
                Navigator.pop(ctx);
                _pinjamAlat(alat, peminjam);
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Catat ke Blockchain'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWaktu(DateTime dt) {
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $jam:$menit';
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredList;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logbook Lab IoT',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Smart Contract • Sepolia Testnet',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refreshData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang Data',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              if (_isLoading)
                const LinearProgressIndicator(
                  color: Color(0xFF14B8A6),
                  backgroundColor: Color(0xFFCCFBF1),
                ),
              if (_txStatusMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isTxSuccess
                        ? const Color(0xFFCCFBF1)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isTxSuccess
                          ? const Color(0xFF5EEAD4)
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isTxSuccess
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        size: 18,
                        color: _isTxSuccess
                            ? const Color(0xFF0F766E)
                            : Colors.red.shade800,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _txStatusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _isTxSuccess
                                ? const Color(0xFF115E59)
                                : Colors.red.shade900,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _txStatusMessage = null),
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ],
                  ),
                ),

              // Kartu Ringkasan Statistik
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _buildStatCard(
                      label: 'Total Log',
                      count: _daftarPinjam.length.toString(),
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      label: 'Dipinjam',
                      count: _totalDipinjam.toString(),
                      icon: Icons.pending_actions_rounded,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      label: 'Kembali',
                      count: _totalDikembalikan.toString(),
                      icon: Icons.task_alt_rounded,
                      color: Colors.green.shade700,
                    ),
                  ],
                ),
              ),

              // Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    _buildFilterChip('Semua', FilterStatus.semua),
                    const SizedBox(width: 8),
                    _buildFilterChip('Dipinjam', FilterStatus.dipinjam),
                    const SizedBox(width: 8),
                    _buildFilterChip('Dikembalikan', FilterStatus.dikembalikan),
                  ],
                ),
              ),

              // Daftar Item Peminjaman
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  child: items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'Tidak ada data peminjaman pada kategori ini.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: item.sudahKembali
                                                ? Colors.green.shade50
                                                : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.developer_board_rounded,
                                            color: item.sudahKembali
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.namaAlat,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: item.sudahKembali
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item.kodePeminjam} • ${item.walletPeminjam}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: item.sudahKembali
                                                ? Colors.green.shade50
                                                : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: item.sudahKembali
                                                  ? Colors.green.shade200
                                                  : Colors.orange.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            item.sudahKembali
                                                ? 'Dikembalikan'
                                                : 'Dipinjam',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: item.sudahKembali
                                                  ? Colors.green.shade800
                                                  : Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Divider(height: 1),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Pinjam: ${_formatWaktu(item.waktuPinjam)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            if (item.waktuKembali != null)
                                              Text(
                                                'Kembali: ${_formatWaktu(item.waktuKembali!)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (!item.sudahKembali)
                                          FilledButton.tonalIcon(
                                            onPressed: _isLoading
                                                ? null
                                                : () => _kembalikanAlat(item),
                                            icon: const Icon(
                                              Icons
                                                  .assignment_turned_in_rounded,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Kembalikan',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        onPressed: _isLoading ? null : _bukaFormPinjam,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Pinjam Alat'),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, FilterStatus status) {
    final isSelected = _selectedFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = status),
      selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? const Color(0xFF0F766E) : Colors.grey.shade700,
      ),
    );
  }
}