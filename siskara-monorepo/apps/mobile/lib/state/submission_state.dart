import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/submission_model.dart';
import '../models/checklist_template_model.dart';
import '../services/firestore_service.dart';
import 'auth_state.dart';

/// Provides the FirestoreService instance.
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

/// Provides the active checklist template for the current user's transport mode.
final activeTemplateProvider = FutureProvider<ChecklistTemplateModel?>((ref) async {
  final transportMode = ref.watch(transportModeProvider);
  if (transportMode == null || transportMode.isEmpty) return null;

  final service = ref.read(firestoreServiceProvider);
  return await service.getActiveTemplate(transportMode);
});

/// Provides checklist items for the active template.
final templateItemsProvider = FutureProvider<List<ChecklistTemplateItemModel>>((ref) async {
  final template = await ref.watch(activeTemplateProvider.future);
  if (template == null) return [];

  final service = ref.read(firestoreServiceProvider);
  return await service.getTemplateItems(template.id);
});

/// Streams the current user's submissions (for history).
final userSubmissionsProvider = StreamProvider<List<SubmissionModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  final service = ref.read(firestoreServiceProvider);
  return service.streamUserSubmissions(
    user.id,
    reviewedByUser: user.isStaf,
  );
});

/// Streams submissions pending review (for staf_bbkk).
final pendingSubmissionsProvider = StreamProvider<List<SubmissionModel>>((ref) {
  final service = ref.read(firestoreServiceProvider);
  return service.streamPendingSubmissions();
});
