import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List> fetchAllCycles() async {
    try {
      final response = await _supabase.from('cycles').select().order('id', ascending: false);
      return List.from(response);
    } catch (e) {
      debugPrint("Gagal mengambil data dari Supabase: $e");
      return [];
    }
  }

  Future<void> insertCycle(Map<String, dynamic> row) async {
    try {
      await _supabase.from('cycles').insert({
        'startdate': row['startDate'],
        'enddate': (row['endDate'] == null || row['endDate'] == '') ? null : row['endDate'],
        'status': row['status'],
        'issynced': 1,
      });
    } catch (e) {
      debugPrint("Gagal insert ke Supabase: $e");
    }
  }

  Future<void> updateCycle(Map<String, dynamic> row) async {
    try {
      await _supabase.from('cycles').update({
        'startdate': row['startDate'],
        'enddate': (row['endDate'] == null || row['endDate'] == '') ? null : row['endDate'],
        'status': row['status'],
      }).eq('id', row['id']);
    } catch (e) {
      debugPrint("Gagal update ke Supabase: $e");
    }
  }

  Future<void> deleteCycle(dynamic id) async {
    try {
      await _supabase.from('cycles').delete().eq('id', id);
      debugPrint("Berhasil menghapus data dengan ID: $id");
    } catch (e) {
      debugPrint("Gagal hapus dari Supabase: $e");
    }
  }
}