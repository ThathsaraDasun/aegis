import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/hazard_report_model.dart';
import '../../services/route_safety_service.dart';
import '../../theme/aegis_theme.dart';

class ReportHazardScreen extends StatefulWidget {
  const ReportHazardScreen({super.key});

  @override
  State<ReportHazardScreen> createState() => _ReportHazardScreenState();
}

class _ReportHazardScreenState extends State<ReportHazardScreen> {
  String _selectedCategory = "Broken Light";
  final _descriptionController = TextEditingController(text: "Streetlight #4 flickering out completely near 5th Ave intersection.");
  bool _isSubmitting = false;
  final RouteSafetyService _routeSafetyService = RouteSafetyService();

  Future<void> _submitHazard() async {
    setState(() => _isSubmitting = true);

    try {
      final report = HazardReportModel(
        id: '',
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        lat: 37.7749, // Default verified pin location
        lng: -122.4194,
        severity: 'Medium',
        confirmCount: 1,
        reportedAt: DateTime.now(),
      );

      await _routeSafetyService.reportHazard(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hazard broadcasted to Aegis mesh network!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error reporting hazard: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(
        title: Text("Report Safety Hazard", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AegisSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AegisSpacing.md),
              decoration: BoxDecoration(color: AegisColors.surfaceContainerHigh, borderRadius: AegisRadius.mdAll),
              child: Row(
                children: [
                  const Icon(Icons.my_location, color: AegisColors.tertiary),
                  const SizedBox(width: AegisSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Near 5th Ave & Pine St", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
                      Text("±2m GPS Lock Verified", style: GoogleFonts.outfit(fontSize: 11, color: AegisColors.tertiary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AegisSpacing.xxl),
            Text("Select Hazard Type", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
            const SizedBox(height: AegisSpacing.md),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildCategoryCard("Broken Light", Icons.lightbulb_outline, "Unlit dark stretch", AegisColors.primary),
                _buildCategoryCard("Suspicious Act", Icons.warning, "Loitering or menace", AegisColors.secondary),
                _buildCategoryCard("Blocked Path", Icons.construction, "Construction barrier", AegisColors.primary),
                _buildCategoryCard("Animal Threat", Icons.pets, "Aggressive unleashed animal", AegisColors.secondary),
              ],
            ),
            const SizedBox(height: AegisSpacing.xxl),
            Text("Description & Details", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
            const SizedBox(height: AegisSpacing.sm),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: GoogleFonts.outfit(color: AegisColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AegisColors.surfaceContainerHigh,
                hintText: "Describe details e.g. dark alley, loitering group...",
                hintStyle: const TextStyle(color: AegisColors.textSecondary),
                border: OutlineInputBorder(borderRadius: AegisRadius.mdAll, borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: AegisSpacing.xxl),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AegisColors.primaryContainer),
                onPressed: _isSubmitting ? null : _submitHazard,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                label: Text("BROADCAST LIVE WARNING", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, String subtitle, Color iconColor) {
    bool isSelected = _selectedCategory == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = title),
      child: Container(
        padding: const EdgeInsets.all(AegisSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AegisColors.primaryContainer : AegisColors.surfaceContainerHigh,
          borderRadius: AegisRadius.mdAll,
          border: isSelected ? Border.all(color: AegisColors.tertiary, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: isSelected ? Colors.white : iconColor, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AegisColors.textPrimary)),
                Text(subtitle, style: GoogleFonts.outfit(fontSize: 10, color: isSelected ? Colors.white70 : AegisColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
