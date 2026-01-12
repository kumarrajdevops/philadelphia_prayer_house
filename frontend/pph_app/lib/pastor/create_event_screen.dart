import 'dart:async' show Timer;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/event_service.dart';

class CreateEventScreen extends StatefulWidget {
  final VoidCallback? onEventCreated;
  
  const CreateEventScreen({super.key, this.onEventCreated});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  String _recurrenceType = 'none'; // 'none', 'daily', 'weekly', 'monthly'
  List<int> _selectedWeekdays = []; // 0=Mon, 6=Sun
  DateTime? _recurrenceEndDate;
  int? _recurrenceCount;
  String _recurrenceEndCondition = 'date'; // 'date' or 'count'
  
  bool _loading = false;
  bool _hasUnsavedChanges = false;
  bool _showPreview = false;
  List<Map<String, dynamic>> _previewOccurrences = [];
  bool _loadingPreview = false;
  
  @override
  void initState() {
    super.initState();
    _initializeDefaults();
    _titleController.addListener(() {
      _hasUnsavedChanges = true;
    });
  }

  void _initializeDefaults() {
    final now = DateTime.now();
    
    // Start: Default to today, next hour
    _startDate = now;
    final nextHour = now.hour + 1;
    _startTime = TimeOfDay(hour: nextHour > 23 ? 0 : nextHour, minute: 0);
    
    // End: Same day, start time + 2 hours
    _endDate = now;
    final endHour = _startTime!.hour + 2;
    _endTime = TimeOfDay(hour: endHour > 23 ? 0 : endHour, minute: 0);
    
    // Default to same weekday as start for weekly recurrence
    if (_startDate != null) {
      _selectedWeekdays = [_startDate!.weekday - 1]; // Convert to 0-based (Mon=0)
    }
  }

  @override
  void dispose() {
    _previewDebounceTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime lastDate = now.add(const Duration(days: 365));
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? today,
      firstDate: today,
      lastDate: lastDate,
      helpText: "Select Start Date",
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _hasUnsavedChanges = true;
        // Update default weekday for weekly recurrence
        _selectedWeekdays = [picked.weekday - 1];
        // If end date is before start date, adjust it to start date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
      _updatePreview();
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: "Select Start Time",
    );
    
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _hasUnsavedChanges = true;
        // Auto-adjust end time if needed
        if (_endTime == null || 
            _endTime!.hour < picked.hour || 
            (_endTime!.hour == picked.hour && _endTime!.minute <= picked.minute)) {
          final endHour = picked.hour + 2;
          _endTime = TimeOfDay(hour: endHour > 23 ? 0 : endHour, minute: picked.minute);
        }
      });
      _updatePreview();
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime firstDate = _startDate != null && _startDate!.isAfter(today) 
        ? _startDate! 
        : today;
    final DateTime lastDate = now.add(const Duration(days: 365));
    
    // Ensure initialDate is not before firstDate
    DateTime initialDate = _endDate ?? firstDate;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: "Select End Date",
    );
    
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _hasUnsavedChanges = true;
      });
      _updatePreview();
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? (_startTime != null 
          ? TimeOfDay(hour: _startTime!.hour + 2, minute: _startTime!.minute)
          : const TimeOfDay(hour: 11, minute: 0)),
      helpText: "Select End Time",
    );
    
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _hasUnsavedChanges = true;
      });
      _updatePreview();
    }
  }

  Future<void> _selectRecurrenceEndDate() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime firstDate = _startDate != null && _startDate!.isAfter(today) 
        ? _startDate! 
        : today;
    final DateTime lastDate = now.add(const Duration(days: 365));
    
    // Ensure initialDate is not before firstDate
    DateTime initialDate = _recurrenceEndDate ?? firstDate;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: "Recurrence End Date",
    );
    
    if (picked != null) {
      setState(() {
        _recurrenceEndDate = picked;
        _hasUnsavedChanges = true;
      });
      _updatePreview();
    }
  }

  void _toggleWeekday(int day) {
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
      _selectedWeekdays.sort();
      _hasUnsavedChanges = true;
    });
    _updatePreview();
  }

  Timer? _previewDebounceTimer;

  Future<void> _updatePreview() async {
    // Cancel any pending preview update
    _previewDebounceTimer?.cancel();
    
    // Debounce preview updates to avoid too many API calls
    _previewDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      
      if (_recurrenceType == 'none' || !_isFormValidForPreview()) {
        if (mounted) {
          setState(() {
            _showPreview = false;
            _previewOccurrences = [];
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _loadingPreview = true;
        });
      }

      try {
        // Use WidgetsBinding to ensure state is fully updated
        await WidgetsBinding.instance.endOfFrame;
        
        final startDateTime = _getStartDateTime();
        final endDateTime = _getEndDateTime();
        
        if (startDateTime == null || endDateTime == null) {
          if (mounted) {
            setState(() {
              _loadingPreview = false;
              _showPreview = false;
            });
          }
          return;
        }

        final preview = await EventService.previewEventOccurrences(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          eventType: 'offline',
          location: _locationController.text.trim(),
          joinInfo: null,
          startDatetime: startDateTime,
          endDatetime: endDateTime,
          recurrenceType: _recurrenceType,
          recurrenceDays: _recurrenceType == 'weekly' && _selectedWeekdays.isNotEmpty
              ? _selectedWeekdays.join(',')
              : null,
          recurrenceEndDate: _recurrenceEndCondition == 'date' && _recurrenceEndDate != null
              ? _recurrenceEndDate!.toIso8601String().split('T')[0]
              : null,
          recurrenceCount: _recurrenceEndCondition == 'count' ? _recurrenceCount : null,
        );

        if (mounted) {
          setState(() {
            _previewOccurrences = preview;
            _showPreview = preview.isNotEmpty;
            _loadingPreview = false;
          });
        }
      } catch (e) {
        print("Preview error: $e");
        if (mounted) {
          setState(() {
            _loadingPreview = false;
            _showPreview = false;
          });
        }
      }
    });
  }

  bool _isFormValidForPreview() {
    return _titleController.text.trim().isNotEmpty &&
           _startDate != null &&
           _startTime != null &&
           _endDate != null &&
           _endTime != null &&
           _locationController.text.trim().isNotEmpty;
  }

  DateTime? _getStartDateTime() {
    if (_startDate == null || _startTime == null) return null;
    return DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
  }

  DateTime? _getEndDateTime() {
    if (_endDate == null || _endTime == null) return null;
    return DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );
  }

  Future<bool> _handleWillPop() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Discard Event?"),
        content: const Text("Your changes will be lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Discard", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final startDateTime = _getStartDateTime();
    final endDateTime = _getEndDateTime();

    if (startDateTime == null || endDateTime == null) {
      return;
    }

    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End datetime must be after start datetime"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await EventService.createEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        eventType: 'offline',
        location: _locationController.text.trim(),
        joinInfo: null,
        startDatetime: startDateTime,
        endDatetime: endDateTime,
        recurrenceType: _recurrenceType,
        recurrenceDays: _recurrenceType == 'weekly' && _selectedWeekdays.isNotEmpty
            ? _selectedWeekdays.join(',')
            : null,
        recurrenceEndDate: _recurrenceEndCondition == 'date' && _recurrenceEndDate != null
            ? _recurrenceEndDate!.toIso8601String().split('T')[0]
            : null,
        recurrenceCount: _recurrenceEndCondition == 'count' ? _recurrenceCount : null,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event created successfully"), backgroundColor: Colors.green),
        );
        widget.onEventCreated?.call();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to create event. Please try again."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString().replaceFirst("Exception: ", "")}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          if (!mounted) return;
          final shouldPop = await _handleWillPop();
          if (shouldPop && mounted && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Create Event"),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (!mounted) return;
              final shouldPop = await _handleWillPop();
              if (shouldPop && mounted && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: "Event Title *",
                    hintText: "e.g., Church Anniversary, Youth Meet",
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter an event title";
                    }
                    return null;
                  },
                  onChanged: (_) => _updatePreview(),
                ),

                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Description (Optional)",
                    hintText: "Event details...",
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (_) => _updatePreview(),
                ),

                const SizedBox(height: 24),

                // Location
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: "Location *",
                    hintText: "e.g., Main Prayer Hall",
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Location is required";
                    }
                    return null;
                  },
                  onChanged: (_) => _updatePreview(),
                ),

                const SizedBox(height: 24),

                // Start Date & Time
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectStartDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: "Start Date *",
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _startDate != null
                                ? DateFormat('MMM d, y').format(_startDate!)
                                : "Select date",
                            style: TextStyle(color: _startDate != null ? Colors.black87 : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _selectStartTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: "Start Time *",
                            prefixIcon: Icon(Icons.access_time),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _startTime != null
                                ? _startTime!.format(context)
                                : "Select time",
                            style: TextStyle(color: _startTime != null ? Colors.black87 : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // End Date & Time
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectEndDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: "End Date *",
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _endDate != null
                                ? DateFormat('MMM d, y').format(_endDate!)
                                : "Select date",
                            style: TextStyle(color: _endDate != null ? Colors.black87 : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _selectEndTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: "End Time *",
                            prefixIcon: Icon(Icons.access_time),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _endTime != null
                                ? _endTime!.format(context)
                                : "Select time",
                            style: TextStyle(color: _endTime != null ? Colors.black87 : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Recurrence Toggle
                Row(
                  children: [
                    Checkbox(
                      value: _recurrenceType != 'none',
                      onChanged: (value) {
                        setState(() {
                          _recurrenceType = value == true ? 'weekly' : 'none';
                          _hasUnsavedChanges = true;
                        });
                        _updatePreview();
                      },
                    ),
                    const Text("Recurring Event"),
                  ],
                ),

                // Recurrence Options
                if (_recurrenceType != 'none') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _recurrenceType,
                    decoration: const InputDecoration(
                      labelText: "Recurrence Type *",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _recurrenceType = value ?? 'weekly';
                        _hasUnsavedChanges = true;
                      });
                      _updatePreview();
                    },
                  ),

                  if (_recurrenceType == 'weekly') ...[
                    const SizedBox(height: 16),
                    const Text("Select Days:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].asMap().entries.map((entry) {
                        final dayIndex = entry.key;
                        final dayLabel = entry.value;
                        final isSelected = _selectedWeekdays.contains(dayIndex);
                        return FilterChip(
                          label: Text(dayLabel),
                          selected: isSelected,
                          onSelected: (_) => _toggleWeekday(dayIndex),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text("End on date"),
                          value: 'date',
                          groupValue: _recurrenceEndCondition,
                          onChanged: (value) {
                            setState(() {
                              _recurrenceEndCondition = value ?? 'date';
                              _hasUnsavedChanges = true;
                            });
                            _updatePreview();
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text("End after N times"),
                          value: 'count',
                          groupValue: _recurrenceEndCondition,
                          onChanged: (value) {
                            setState(() {
                              _recurrenceEndCondition = value ?? 'count';
                              _hasUnsavedChanges = true;
                            });
                            _updatePreview();
                          },
                        ),
                      ),
                    ],
                  ),

                  if (_recurrenceEndCondition == 'date') ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectRecurrenceEndDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Recurrence End Date",
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _recurrenceEndDate != null
                              ? DateFormat('MMM d, y').format(_recurrenceEndDate!)
                              : "Select end date",
                          style: TextStyle(color: _recurrenceEndDate != null ? Colors.black87 : Colors.grey),
                        ),
                      ),
                    ),
                  ],

                  if (_recurrenceEndCondition == 'count') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: "Number of Occurrences",
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _recurrenceCount = value.isEmpty ? null : int.tryParse(value);
                          _hasUnsavedChanges = true;
                        });
                        _updatePreview();
                      },
                    ),
                  ],
                ],

                // Preview Section
                if (_showPreview && _previewOccurrences.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    "Preview (Next 5 Occurrences):",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingPreview)
                    const Center(child: CircularProgressIndicator())
                  else
                    ..._previewOccurrences.map((occ) {
                      String dateLabel = '';
                      try {
                        final startStr = occ['start_datetime'] as String?;
                        final endStr = occ['end_datetime'] as String?;
                        if (startStr != null && endStr != null) {
                          final start = DateTime.parse(startStr).toLocal();
                          final end = DateTime.parse(endStr).toLocal();
                          if (start.year == end.year && start.month == end.month && start.day == end.day) {
                            // Same day
                            dateLabel = "${DateFormat('MMM d, y').format(start)} · ${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
                          } else {
                            // Multi-day
                            dateLabel = "${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, y').format(end)} · ${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}";
                          }
                        } else {
                          dateLabel = occ['date_label'] ?? '';
                        }
                      } catch (e) {
                        dateLabel = occ['date_label'] ?? '';
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.event, color: Colors.blue),
                          title: Text(dateLabel),
                          dense: true,
                        ),
                      );
                    }).toList(),
                ],

                const SizedBox(height: 32),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _createEvent,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Icon(Icons.check_circle, size: 24),
                    label: Text(
                      _loading ? "Creating..." : "Create Event",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            if (!mounted) return;
                            final shouldPop = await _handleWillPop();
                            if (shouldPop && mounted && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

