import 'package:flutter/material.dart';
import '../../services/destination_search_service.dart';

class DestinationSearchSheet extends StatefulWidget {
  const DestinationSearchSheet({super.key});
  @override
  State<DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<DestinationSearchSheet> {
  final _query = TextEditingController();
  List<DestinationPlace> _results = [];
  String? _message;
  bool _busy = false;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
      _results = [];
    });
    try {
      final results = await DestinationSearchService.instance.search(
        _query.text,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty)
          _message =
              'No matches. Include the town or try selecting the place on the map.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _message = e is FormatException
            ? e.message
            : 'Could not search. Check your internet connection and retry.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Search destination',
                  style: TextStyle(fontSize: 20),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          TextField(
            controller: _query,
            enabled: !_busy,
            maxLength: 200,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: const InputDecoration(
              labelText: 'Place name and town',
              hintText: 'School, shop or address',
            ),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _search,
            icon: const Icon(Icons.search),
            label: Text(_busy ? 'Searching…' : 'Search'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(_message!)),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final place = _results[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(place.name),
                  onTap: () => Navigator.pop(context, place),
                );
              },
            ),
          ),
          const Text(
            'Search: Nominatim · © OpenStreetMap contributors\nSearch text is sent to the search provider. Check the selected pin before starting.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
