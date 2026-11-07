import '../models/medicine_model.dart';
import '../models/batch_model.dart';
import '../models/packaging_model.dart';
import '../services/operational_database_service.dart';

class ManufacturerRepository {
  final OperationalDatabaseService _db = OperationalDatabaseService.instance;

  // Add a new medicine attached strictly to the authenticated company's manufacturerId
  Future<void> addMedicine(MedicineModel medicine) async {
    await _db.addMedicine(medicine);
  }

  // Strict tenant isolation: only retrieve medicines created by this manufacturer
  Stream<List<MedicineModel>> getMedicines(String manufacturerId) {
    return _db.watchMedicines(manufacturerId);
  }

  // Public Consumer Catalog: retrieve medicines from all approved companies for consumer lookup
  Stream<List<MedicineModel>> getAllPublicMedicines() {
    return _db.watchAllPublicMedicines();
  }

  Future<void> updateMedicine(MedicineModel medicine) async {
    await _db.addMedicine(medicine);
  }

  Future<void> deleteMedicine(String medicineId) async {
    await _db.deleteMedicine(medicineId);
  }

  // Strict tenant isolation: only retrieve batches created by this manufacturer
  Future<void> addBatch(BatchModel batch) async {
    await _db.addBatch(batch);
  }

  Stream<List<BatchModel>> getBatches(String manufacturerId) {
    return _db.watchBatches(manufacturerId);
  }

  // Public verification lookup for consumers across all batches
  Stream<List<BatchModel>> getAllPublicBatches() {
    return _db.watchAllPublicBatches();
  }

  // Strict tenant isolation: packaging reference standards
  Future<void> addPackagingReference(PackagingModel ref) async {
    await _db.addPackaging(ref);
  }

  Stream<List<PackagingModel>> getPackagingReferences(String manufacturerId) {
    return _db.watchPackaging(manufacturerId);
  }
}
