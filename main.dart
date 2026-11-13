import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pwzijkaydtkhrhulvhdg.supabase.co',
    publishableKey: 'sb_publishable_XqlIeTDlMivGBkmo0NTnTg_hRhcu--s',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Siklus Haid',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: const Color(0xFFFFF0F2),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2; // Default ke tab 'Catat'

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const Center(child: Text('Halaman Beranda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      const AnalisisScreen(),
      CatatScreen(onSelesaiSimpan: () => _navigateToTab(1)), // Pindah otomatis ke Analisis saat siklus selesai
      const Center(child: Text('Halaman Profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      const Center(child: Text('Halaman Pengaturan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFD67B83),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: _navigateToTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analisis'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_calendar), label: 'Catat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Pengaturan'),
        ],
      ),
    );
  }
}

// ==========================================
// HALAMAN CATAT
// ==========================================
class CatatScreen extends StatefulWidget {
  final VoidCallback? onSelesaiSimpan;
  const CatatScreen({super.key, this.onSelesaiSimpan});

  @override
  State<CatatScreen> createState() => _CatatScreenState();
}

class _CatatScreenState extends State<CatatScreen> {
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  List _listSiklus = [];
  dynamic _editingId; // Menggunakan dynamic agar fleksibel dengan tipe data ID Supabase

  @override
  void initState() {
    super.initState();
    _muatData();
  }

  void _muatData() async {
    final data = await DatabaseHelper.instance.fetchAllCycles();
    if (mounted) {
      setState(() {
        _listSiklus = data;
      });
    }
  }

  // Fungsi Kalender dengan pembatasan: Tanggal masa depan (setelah hari ini) tidak aktif
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now, // Membatasi maksimal sampai hari ini
      selectableDayPredicate: (DateTime day) {
        // Menonaktifkan tanggal yang melebihi hari ini
        return day.isBefore(now.add(const Duration(days: 1)));
      },
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFFE8A5AC),
            colorScheme: const ColorScheme.light(primary: Color(0xFFE8A5AC)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _simpanAtauUpdate() async {
    String startDate = _startDateController.text.trim();
    String endDate = _endDateController.text.trim();

    if (startDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal mulai wajib diisi!')),
      );
      return;
    }

    String status = endDate.isEmpty ? 'Draft (Mulai Haid)' : 'Selesai';

    if (_editingId == null) {
      await DatabaseHelper.instance.insertCycle({
        'startDate': startDate,
        'endDate': endDate.isEmpty ? null : endDate,
        'status': status,
        'isSynced': 1,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Siklus berhasil disimpan sebagai draft!')),
        );
      }
    } else {
      await DatabaseHelper.instance.updateCycle({
        'id': _editingId,
        'startDate': startDate,
        'endDate': endDate.isEmpty ? null : endDate,
        'status': status,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Siklus diperbarui!')),
        );
      }

      _editingId = null;

      if (status == 'Selesai' && widget.onSelesaiSimpan != null) {
        widget.onSelesaiSimpan!();
      }
    }

    _startDateController.clear();
    _endDateController.clear();
    _muatData();
  }

  void _editData(Map<String, dynamic> item) {
    setState(() {
      _editingId = item['id'];
      _startDateController.text = item['startDate'] ?? '';
      _endDateController.text = item['endDate'] ?? '';
    });
  }

  // Perbaikan fungsi Hapus menggunakan tipe dynamic agar tombol hapus merespons dengan benar
  void _hapus(dynamic id) async {
    await DatabaseHelper.instance.deleteCycle(id);
    _muatData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catatan berhasil dihapus')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8A5AC),
        title: const Text('CATATAN SIKLUS MENSTRUASI', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editingId == null ? 'TAMBAH / SIMPAN SIKLUS' : 'EDIT / LENGKAPI SIKLUS',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _startDateController,
                      readOnly: true,
                      onTap: () => _selectDate(context, _startDateController),
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Mulai (Ketuk untuk Pilih dari Kalender)',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, color: Color(0xFFE8A5AC)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _endDateController,
                      readOnly: true,
                      onTap: () => _selectDate(context, _endDateController),
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Selesai (Opsional / Ketuk untuk Pilih)',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, color: Color(0xFFE8A5AC)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8A5AC),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _simpanAtauUpdate,
                        child: Text(
                          _editingId == null ? 'SIMPAN SIKLUS' : 'SIMPAN PERUBAHAN SIKLUS',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (_editingId != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _editingId = null;
                              _startDateController.clear();
                              _endDateController.clear();
                            });
                          },
                          child: const Text('Batal Edit', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Riwayat & Draft Tersimpan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            _listSiklus.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: Text('Belum ada catatan atau draft.', style: TextStyle(color: Colors.grey))),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _listSiklus.length,
              itemBuilder: (context, index) {
                final item = _listSiklus[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text("Mulai: ${item['startDate']} | Selesai: ${item['endDate'] ?? 'Belum Selesai (Draft)'}"),
                    subtitle: Text("Status: ${item['status']}", style: TextStyle(color: item['status'].toString().contains('Draft') ? Colors.orange : Colors.green, fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editData(item),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _hapus(item['id']),
                          tooltip: 'Hapus',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HALAMAN ANALISIS
// ==========================================
class AnalisisScreen extends StatefulWidget {
  const AnalisisScreen({super.key});

  @override
  State<AnalisisScreen> createState() => _AnalisisScreenState();
}

class _AnalisisScreenState extends State<AnalisisScreen> {
  int _totalSelesai = 0;
  String _statusHormon = 'Belum Ada Data Selesai';

  @override
  void initState() {
    super.initState();
    _hitungAnalisis();
  }

  void _hitungAnalisis() async {
    final data = await DatabaseHelper.instance.fetchAllCycles();
    final selesaiList = data.where((item) => item['status'] == 'Selesai').toList();

    if (mounted) {
      setState(() {
        _totalSelesai = selesaiList.length;
        if (_totalSelesai > 0) {
          _statusHormon = 'Normal / Stabil (Hormon Seimbang)';
        } else {
          _statusHormon = 'Belum Ada Data Selesai';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _hitungAnalisis();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8A5AC),
        title: const Text('ANALISIS SIKLUS & HORMON', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Total Siklus Selesai'),
                      trailing: Text('$_totalSelesai Siklus', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Status Hormon & Keteraturan'),
                      trailing: Text(
                        _statusHormon,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _statusHormon.contains('Normal') ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8A5AC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _totalSelesai > 0 ? 'SIKLUS SELESAI: HORMON TERANALISIS DENGAN BAIK' : 'LENGKAPI TANGGAL SELESAI PADA MENU CATAT UNTUK MELIHAT ANALISIS',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}