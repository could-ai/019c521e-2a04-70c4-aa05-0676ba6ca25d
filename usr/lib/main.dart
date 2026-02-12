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

class SpreadsheetPage extends StatefulWidget {
  const SpreadsheetPage({super.key});

  @override
  State<SpreadsheetPage> createState() => _SpreadsheetPageState();
}

class _SpreadsheetPageState extends State<SpreadsheetPage> {
  // Define the number of columns for our grid
  final int _columnCount = 4;
  
  // Store controllers for each cell to manage text input
  final List<List<TextEditingController>> _rows = [];

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
      for (var controller in row) {
        controller.dispose();
      }
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
      _rows.add(newRowControllers);
    });
  }

  void _removeRow(int index) {
    // Dispose controllers for the row being removed
    for (var controller in _rows[index]) {
      controller.dispose();
    }
    
    setState(() {
      _rows.removeAt(index);
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
                final rowControllers = _rows[rowIndex];
                
                return Dismissible(
                  key: ObjectKey(rowControllers),
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
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
                                controller: _rows[rowIndex][colIndex],
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
