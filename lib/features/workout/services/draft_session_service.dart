import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/draft_session_model.dart';

class DraftSessionService {
  static const String _draftKey = 'draft_workout_session';

  Future<void> saveDraft(DraftSessionModel draft) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(draft.toJson());
    await prefs.setString(_draftKey, jsonString);
  }

  Future<DraftSessionModel?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_draftKey);
    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString);
        return DraftSessionModel.fromJson(json);
      } catch (e) {
        // If parsing fails (e.g. data schema changed), discard the draft
        await clearDraft();
        return null;
      }
    }
    return null;
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }
}
