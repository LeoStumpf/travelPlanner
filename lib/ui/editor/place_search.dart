import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/geocoding.dart';
import '../common/l10n.dart';

final _geocoder = Geocoder();

/// Full-screen place search (OpenStreetMap / Photon). Returns the chosen place.
Future<PlaceResult?> searchPlace(BuildContext context, {String initial = ''}) =>
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PlaceSearchPage(initial: initial),
    ));

class _PlaceSearchPage extends StatefulWidget {
  final String initial;
  const _PlaceSearchPage({required this.initial});

  @override
  State<_PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<_PlaceSearchPage> {
  late final _ctrl = TextEditingController(text: widget.initial);
  Timer? _debounce;
  List<PlaceResult> _results = const [];
  String? _error;
  bool _loading = false;
  int _req = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initial.isNotEmpty) _search(widget.initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    final req = ++_req;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _geocoder.search(q, lang: context.l10n.localeName);
      if (req == _req && mounted) setState(() => _results = r);
    } catch (e) {
      if (req == _req && mounted) setState(() => _error = context.l10n.placeSearchFailed);
    } finally {
      if (req == _req && mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.placeSearchHint, border: InputBorder.none),
          onChanged: _onChanged,
          onSubmitted: _search,
        ),
        bottom: _loading
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : ListView(
              children: [
                for (final r in _results)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(r.name),
                    subtitle: r.detail.isEmpty ? null : Text(r.detail),
                    onTap: () => Navigator.pop(context, r),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.l10n.osmAttribution, style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
    );
  }
}
