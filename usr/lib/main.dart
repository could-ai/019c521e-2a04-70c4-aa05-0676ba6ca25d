import 'package:flutter/material.dart';

void main() {
  runApp(const SpreadsheetApp());
}

class SpreadsheetApp extends StatelessWidget {
  const SpreadsheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spreadsheet Entry',
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

class RowData {
  final List<TextEditingController> controllers;
  final List<List<TextEditingController>> subRows;
  bool isExpanded;

  RowData({
    required this.controllers,
    List<List<TextEditingController>>? subRows,
    this.isExpanded = false,
  }) : subRows = subRows ?? [];

  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    for (var subRow in subRows) {
      for (var controller in subRow) {
        controller.dispose();
      }
    }
  }
}

class SpreadsheetPage extends StatefulWidget {
  const SpreadsheetPage({super.key});

  @override
  State<SpreadsheetPage> createState() => _SpreadsheetPageState();
}

class _SpreadsheetPageState extends State<SpreadsheetPage> {
  // Define the number of columns for our grid
  final int _columnCount = 4;
  final int _subRowColumnCount = 3;
  
  // Store row data objects
  final List<RowData> _rows = [];

  @override
  void initState() {
    super.initState();
    // Start with one initial line as requested
    _addNewRow();
  }

  @override
  void dispose() {
    // Clean up all controllers when the widget is disposed
    for (var row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addNewRow() {
    setState(() {
      // Create a new list of controllers for the new row
      List<TextEditingController> newRowControllers = List.generate(
        _columnCount,
        (index) => TextEditingController(),
      );
      _rows.add(RowData(controllers: newRowControllers));
    });
  }

  void _removeRow(int index) {
    // Dispose controllers for the row being removed
    _rows[index].dispose();
    
    setState(() {
      _rows.removeAt(index);
    });
  }

  void _addSubRow(int rowIndex) {
    setState(() {
      List<TextEditingController> newSubRowControllers = List.generate(
        _subRowColumnCount,
        (index) => TextEditingController(),
      );
      _rows[rowIndex].subRows.add(newSubRowControllers);
    });
  }

  void _removeSubRow(int rowIndex, int subRowIndex) {
    for (var controller in _rows[rowIndex].subRows[subRowIndex]) {
      controller.dispose();
    }
    setState(() {
      _rows[rowIndex].subRows.removeAt(subRowIndex);
    });
  }

  void _toggleExpansion(int index) {
    setState(() {
      _rows[index].isExpanded = !_rows[index].isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Entry Grid'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
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
                                              controller: rowData.subRows[subIndex][fieldIndex],
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
        onPressed: _addNewRow,
        tooltip: 'Add Row',
        child: const Icon(Icons.add),
      ),
    );
  }
}
