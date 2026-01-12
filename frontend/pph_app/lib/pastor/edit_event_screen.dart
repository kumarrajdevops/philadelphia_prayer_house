import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/event_service.dart';

class EditEventScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onEventUpdated;

  const EditEventScreen({
    super.key,
    required this.event,
    this.onEventUpdated,
  });

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  
  bool _loading = false;
  bool _hasUnsavedChanges = false;
  int? _eventId;
  bool _isRecurring = false;
  bool _applyToFuture = false;

  @override
  void initState() {
    super.initState();
    _eventId = widget.event['id'] as int?;
    _titleController = TextEditingController(text: widget.event['title'] as String? ?? '');
    _initializeFromEvent();
    _titleController.addListener(() {
      _hasUnsavedChanges = true;
    });
  }

  void _initializeFromEvent() {
    // Parse start datetime
    final startStr = widget.event['start_datetime'] as String?;
    if (startStr != null) {
      try {
        final start = DateTime.parse(startStr).toLocal();
        _startDate = DateTime(start.year, start.month, start.day);
        _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
      } catch (e) {
        print("Error parsing start datetime: $e");
      }
    }
    
    // Parse end datetime
    final endStr = widget.event['end_datetime'] as String?;
    if (endStr != null) {
      try {
        final end = DateTime.parse(endStr).toLocal();
        _endDate = DateTime(end.year, end.month, end.day);
        _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
      } catch (e) {
        print("Error parsing end datetime: $e");
      }
    }
    
    // Parse description
    final description = widget.event['description'] as String?;
    if (description != null && description.isNotEmpty) {
      _descriptionController.text = description;
    }
    
    // Parse location
    final location = widget.event['location'] as String?;
    if (location != null && location.isNotEmpty) {
      _locationController.text = location;
    }
    
    // Check if this is part of a recurring series
    final recurrenceType = widget.event['recurrence_type'] as String?;
    _isRecurring = recurrenceType != null && recurrenceType.isNotEmpty && recurrenceType.toLowerCase() != 'none';
    
    _hasUnsavedChanges = false; // Reset after initializing
  }

  @override
  void dispose() {
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
      cancelText: "Cancel",
      confirmText: "Select",
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _hasUnsavedChanges = true;
        // If end date is before start date, adjust it to start date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
      // Re-validate after date change
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _formKey.currentState?.validate();
        }
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: "Select Start Time",
      cancelText: "Cancel",
      confirmText: "Select",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Auto-adjust end time if it's before or equal to start time
        if (_endTime == null || 
            _endTime!.hour < picked.hour || 
            (_endTime!.hour == picked.hour && _endTime!.minute <= picked.minute)) {
          final endHour = picked.hour + 1;
          _endTime = TimeOfDay(hour: endHour > 23 ? 0 : endHour, minute: picked.minute);
        }
        _hasUnsavedChanges = true;
      });
      // Validate form after time change
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _formKey.currentState?.validate();
        }
      });
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
      cancelText: "Cancel",
      confirmText: "Select",
    );
    
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _hasUnsavedChanges = true;
      });
      // Re-validate after date change
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _formKey.currentState?.validate();
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? (_startTime != null 
          ? TimeOfDay(hour: _startTime!.hour + 1, minute: _startTime!.minute)
          : const TimeOfDay(hour: 10, minute: 0)),
      helpText: "Select End Time",
      cancelText: "Cancel",
      confirmText: "Select",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _hasUnsavedChanges = true;
      });
      // Validate form after time change
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _formKey.currentState?.validate();
        }
      });
    }
  }

  /// Truncate DateTime to minute precision
  DateTime _truncateToMinute(DateTime dateTime) {
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    );
  }

  String? _validateStartDateTime() {
    if (_startDate == null || _startTime == null) {
      return "Please select start date and time";
    }
    
    final now = DateTime.now();
    final nowTruncated = _truncateToMinute(now);
    
    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    final startTruncated = _truncateToMinute(startDateTime);
    
    // Check if start time is in the past
    if (startTruncated.compareTo(nowTruncated) <= 0) {
      return "You can't edit an event that has already started";
    }
    
    return null;
  }

  String? _validateEndDateTime() {
    if (_endDate == null || _endTime == null) {
      return "Please select end date and time";
    }
    
    if (_startDate == null || _startTime == null) {
      return null;
    }
    
    // First check: end must be after start
    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    
    final endDateTime = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );
    
    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      return "End date/time must be after start date/time";
    }
    
    // Second check: end time must not be in the past
    final now = DateTime.now();
    final nowTruncated = _truncateToMinute(now);
    final endTruncated = _truncateToMinute(endDateTime);
    
    if (endTruncated.compareTo(nowTruncated) <= 0) {
      return "End date/time cannot be in the past";
    }
    
    return null;
  }

  Future<bool> _handleWillPop() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Discard Changes?"),
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

  Future<void> _updateEvent() async {
    if (_eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid event ID")),
      );
      return;
    }
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _startTime == null || _endDate == null || _endTime == null) {
      return; // Form validation should catch this
    }

    // Final validation: Check if start datetime is in the past
    final startError = _validateStartDateTime();
    if (startError != null) {
      setState(() {
        _formKey.currentState?.validate();
      });
      return;
    }

    // Final validation: Check end datetime
    final endError = _validateEndDateTime();
    if (endError != null) {
      setState(() {
        _formKey.currentState?.validate();
      });
      return;
    }

    // Show confirmation dialog for recurring events
    if (_isRecurring) {
      final applyToFuture = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Apply Changes To"),
          content: const Text("This is a recurring event. Do you want to apply changes to this occurrence only, or this and all future occurrences?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("This Occurrence Only"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("This and Future"),
            ),
          ],
        ),
      );
      
      if (applyToFuture == null) {
        return; // User cancelled
      }
      
      _applyToFuture = applyToFuture;
    }

    setState(() => _loading = true);

    try {
      // Combine date and time for start/end
      final startDateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      final endDateTime = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );

      // Final safety check: Compare timestamps up to minute precision
      final now = DateTime.now();
      final nowTruncated = _truncateToMinute(now);
      final startTruncated = _truncateToMinute(startDateTime);
      final endTruncated = _truncateToMinute(endDateTime);
      
      // Check if start time is in the past
      if (startTruncated.compareTo(nowTruncated) <= 0) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _formKey.currentState?.validate();
            });
          }
        });
        return;
      }
      
      // Check if end time is in the past
      if (endTruncated.compareTo(nowTruncated) <= 0) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _formKey.currentState?.validate();
            });
          }
        });
        return;
      }

      final result = await EventService.updateEventOccurrence(
        occurrenceId: _eventId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        eventType: 'offline', // Events are offline only
        location: _locationController.text.trim(),
        joinInfo: null, // Events are offline only
        startDatetime: startDateTime,
        endDatetime: endDateTime,
        applyToFuture: _applyToFuture,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      if (result != null) {
        // Success - show confirmation
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Event updated successfully"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Call callback and pop
        widget.onEventUpdated?.call();
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update event. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      
      String errorMessage = "Failed to update event";
      if (e.toString().contains("already started")) {
        errorMessage = "This event has already started and can't be edited.";
      } else if (e.toString().isNotEmpty) {
        errorMessage = e.toString().replaceFirst("Exception: ", "");
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
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
          title: const Text("Edit Event"),
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
          actions: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subtext
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    "Update event details",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: "Event Title *",
                    hintText: "e.g., Sunday Service, Bible Study",
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
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),

                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Description (Optional)",
                    hintText: "Add event details...",
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),

                // Location Field
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: "Location *",
                    hintText: "e.g., Main Hall, Church Building",
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter a location";
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),

                // Start Date Picker with validation
                InkWell(
                  onTap: _selectStartDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "Start Date *",
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: const OutlineInputBorder(),
                      errorText: _startDate != null && _startTime != null ? _validateStartDateTime() : null,
                      errorMaxLines: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _startDate != null
                              ? DateFormat('EEEE, MMMM d, y').format(_startDate!)
                              : "Select start date",
                          style: TextStyle(
                            color: _startDate != null ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Start Time Picker
                InkWell(
                  onTap: _selectStartTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Start Time *",
                      prefixIcon: Icon(Icons.access_time),
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _startTime != null
                              ? _startTime!.format(context)
                              : "Select start time",
                          style: TextStyle(
                            color: _startTime != null ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // End Date Picker
                InkWell(
                  onTap: _selectEndDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "End Date *",
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _endDate != null
                              ? DateFormat('EEEE, MMMM d, y').format(_endDate!)
                              : "Select end date",
                          style: TextStyle(
                            color: _endDate != null ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // End Time Picker with validation
                InkWell(
                  onTap: _selectEndTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "End Time *",
                      prefixIcon: const Icon(Icons.access_time),
                      border: const OutlineInputBorder(),
                      errorText: _endDate != null && _endTime != null ? _validateEndDateTime() : null,
                      errorMaxLines: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _endTime != null
                              ? _endTime!.format(context)
                              : "Select end time",
                          style: TextStyle(
                            color: _endTime != null ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Update Button (Primary CTA)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _updateEvent,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 24),
                    label: Text(
                      _loading ? "Updating..." : "Update Event",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
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
