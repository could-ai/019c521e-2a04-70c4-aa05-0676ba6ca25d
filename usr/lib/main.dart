import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:couldai_user_app/integrations/supabase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase using the generated configuration
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const SpreadsheetApp());
}

class SpreadsheetApp extends StatelessWidget {
  const SpreadsheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tariff  Tree Entry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SpreadsheetPage(),
      },
    );
  }
}

class SubRowData {
  final int? id;
  final int? parentRowId;
  final List<TextEditingController> controllers;

  SubRowData({
    this.id,
    this.parentRowId,
    required this.controllers,
  });

  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
  }
}

class RowData {
  final int? id;
  final List<TextEditingController> controllers;
  final List<SubRowData> subRows;
  bool isExpanded;

  RowData({
    this.id,
    required this.controllers,
    List<SubRowData>? subRows,
    this.isExpanded = false,
  }) : subRows = subRows ?? [];

  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    for (var subRow in subRows) {
      subRow.dispose();
    }
  }
}

class SpreadsheetPage extends StatefulWidget {
  const SpreadsheetPage({super.key});

  @override
  State<SpreadsheetPage> createState() => _SpreadsheetPageState();
}

class _SpreadsheetPageState extends State<SpreadsheetPage> {
  final _supabase = Supabase.instance.client;
  
  // Define the number of columns for our grid
  final int _columnCount = 4;
  final int _subRowColumnCount = 3;
  
  // Store row data objects
  final List<RowData> _rows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Clean up all controllers when the widget is disposed
    for (var row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch rows ordered by created_at (or id)
      final rowsResponse = await _supabase
          .from('spreadsheet_rows')
          .select()
          .order('created_at', ascending: true);

      final List<RowData> loadedRows = [];

      for (var rowMap in rowsResponse) {
        final rowId = rowMap['id'] as int;
        
        // Create controllers for main row
        List<TextEditingController> controllers = [
          TextEditingController(text: rowMap['col_a'] ?? ''),
          TextEditingController(text: rowMap['col_b'] ?? ''),
          TextEditingController(text: rowMap['col_c'] ?? ''),
          TextEditingController(text: rowMap['col_d'] ?? ''),
        ];

        // Fetch sub-rows for this row
        final subRowsResponse = await _supabase
            .from('spreadsheet_sub_rows')
            .select()
            .eq('row_id', rowId)
            .order('created_at', ascending: true);

        List<SubRowData> subRows = [];
        for (var subRowMap in subRowsResponse) {
          List<TextEditingController> subControllers = [
            TextEditingController(text: subRowMap['col_1'] ?? ''),
            TextEditingController(text: subRowMap['col_2'] ?? ''),
            TextEditingController(text: subRowMap['col_3'] ?? ''),
          ];
          subRows.add(SubRowData(
            id: subRowMap['id'] as int,
            parentRowId: rowId,
            controllers: subControllers,
          ));
        }

        loadedRows.add(RowData(
          id: rowId,
          controllers: controllers,
          subRows: subRows,
        ));
      }

      setState(() {
        _rows.clear();
        _rows.addAll(loadedRows);
        _isLoading = false;
      });
      
      // If empty, add one initial row locally (and save it)
      if (_rows.isEmpty) {
        _addNewRow();
      }

    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
      // Fallback to local empty state if load fails (e.g. bad config)
      if (_rows.isEmpty) {
        _addNewRow(localOnly: true);
      }
    }
  }

  Future<void> _addNewRow({bool localOnly = false}) async {
    // Create controllers first
    List<TextEditingController> newRowControllers = List.generate(
      _columnCount,
      (index) => TextEditingController(),
    );

    if (localOnly) {
      setState(() {
        _rows.add(RowData(controllers: newRowControllers));
      });
      return;
    }

    try {
      // Insert into Supabase
      final response = await _supabase
          .from('spreadsheet_rows')
          .insert({
            'col_a': '',
            'col_b': '',
            'col_c': '',
            'col_d': '',
          })
          .select()
          .single();

      setState(() {
        _rows.add(RowData(
          id: response['id'] as int,
          controllers: newRowControllers,
        ));
      });
    } catch (e) {
      debugPrint('Error adding row: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding row: $e')),
      );
    }
  }

  Future<void> _removeRow(int index) async {
    final row = _rows[index];
    final rowId = row.id;

    // Remove from UI immediately for responsiveness
    // We keep a reference to dispose later if needed, but for now just remove from list
    setState(() {
      _rows.removeAt(index);
    });

    if (rowId != null) {
      try {
        await _supabase.from('spreadsheet_rows').delete().eq('id', rowId);
      } catch (e) {
        debugPrint('Error deleting row: $e');
        // Optionally restore the row if delete fails
      }
    }
    
    row.dispose();
  }

  Future<void> _addSubRow(int rowIndex) async {
    final parentRow = _rows[rowIndex];
    final parentId = parentRow.id;

    if (parentId == null) return;

    List<TextEditingController> newSubRowControllers = List.generate(
      _subRowColumnCount,
      (index) => TextEditingController(),
    );

    try {
      final response = await _supabase
          .from('spreadsheet_sub_rows')
          .insert({
            'row_id': parentId,
            'col_1': '',
            'col_2': '',
            'col_3': '',
          })
          .select()
          .single();

      setState(() {
        parentRow.subRows.add(SubRowData(
          id: response['id'] as int,
          parentRowId: parentId,
          controllers: newSubRowControllers,
        ));
      });
    } catch (e) {
      debugPrint('Error adding sub-row: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding sub-row: $e')),
      );
    }
  }

  Future<void> _removeSubRow(int rowIndex, int subRowIndex) async {
    final subRow = _rows[rowIndex].subRows[subRowIndex];
    final subRowId = subRow.id;

    setState(() {
      _rows[rowIndex].subRows.removeAt(subRowIndex);
    });

    if (subRowId != null) {
      try {
        await _supabase.from('spreadsheet_sub_rows').delete().eq('id', subRowId);
      } catch (e) {
        debugPrint('Error deleting sub-row: $e');
      }
    }
    
    subRow.dispose();
  }

  void _toggleExpansion(int index) {
    setState(() {
      _rows[index].isExpanded = !_rows[index].isExpanded;
    });
  }

  Future<void> _saveAllData() async {
    // Save all current values to Supabase
    // This is a simple implementation that updates every row. 
    // In a production app, you'd track dirty states.
    
    bool hasError = false;

    for (var row in _rows) {
      if (row.id != null) {
        try {
          await _supabase.from('spreadsheet_rows').update({
            'col_a': row.controllers[0].text,
            'col_b': row.controllers[1].text,
            'col_c': row.controllers[2].text,
            'col_d': row.controllers[3].text,
          }).eq('id', row.id!);

          for (var subRow in row.subRows) {
            if (subRow.id != null) {
              await _supabase.from('spreadsheet_sub_rows').update({
                'col_1': subRow.controllers[0].text,
                'col_2': subRow.controllers[1].text,
                'col_3': subRow.controllers[2].text,
              }).eq('id', subRow.id!);
            }
          }
        } catch (e) {
          hasError = true;
          debugPrint('Error saving row ${row.id}: $e');
        }
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hasError ? 'Saved with some errors' : 'All data saved successfully'),
        backgroundColor: hasError ? Colors.orange : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Entry Grid'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save All Changes',
            onPressed: _saveAllData,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          // Header Row
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                const SizedBox(width: 40), // Space for expand icon
                // Row Number Header
                const SizedBox(
                  width: 40,
                  child: Text(
                    '#',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Data Column Headers
                ...List.generate(_columnCount, (index) {
                  return Expanded(
                    child: Text(
                      'Column ${String.fromCharCode(65 + index)}', // A, B, C, D...
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Scrollable Grid Area
          Expanded(
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (context, rowIndex) {
                // Use the list object itself as a unique key for the Dismissible
                // This ensures the correct row is dismissed even if the list changes
                final rowData = _rows[rowIndex];
                
                return Dismissible(
                  key: ObjectKey(rowData),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _removeRow(rowIndex);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Row ${rowIndex + 1} deleted'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      // Main Row
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Expand/Collapse Icon
                            SizedBox(
                              width: 40,
                              child: IconButton(
                                icon: Icon(rowData.isExpanded 
                                  ? Icons.keyboard_arrow_up 
                                  : Icons.keyboard_arrow_down
                                ),
                                onPressed: () => _toggleExpansion(rowIndex),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                            // Row Number
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${rowIndex + 1}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Vertical Divider
                            Container(width: 1, height: 50, color: Colors.grey.shade300),
                            
                            // Editable Cells
                            ...List.generate(_columnCount, (colIndex) {
                              return Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: Colors.grey.shade300,
                                        width: colIndex == _columnCount - 1 ? 0 : 1,
                                      ),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: rowData.controllers[colIndex],
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(8.0),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.text,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      
                      // Sub-rows Section
                      if (rowData.isExpanded)
                        Container(
                          color: Colors.grey.shade50,
                          padding: const EdgeInsets.only(left: 40, right: 10, bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Existing Sub-rows
                              ...List.generate(rowData.subRows.length, (subIndex) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      // 3 Data Entry Fields
                                      ...List.generate(_subRowColumnCount, (fieldIndex) {
                                        return Expanded(
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: TextField(
                                              controller: rowData.subRows[subIndex].controllers[fieldIndex],
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                hintText: 'Sub ${fieldIndex + 1}',
                                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                isDense: true,
                                              ),
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        );
                                      }),
                                      // Delete Sub-row Button
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                        onPressed: () => _removeSubRow(rowIndex, subIndex),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              
                              // Add Sub-row Button
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, left: 24),
                                child: TextButton.icon(
                                  onPressed: () => _addSubRow(rowIndex),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Sub-row'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewRow(),
        tooltip: 'Add Row',
        child: const Icon(Icons.add),
      ),
    );
  }
}