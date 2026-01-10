import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/prayer_service.dart';

class CreatePrayerScreen extends StatefulWidget {
  final VoidCallback? onPrayerCreated;
  
  const CreatePrayerScreen({super.key, this.onPrayerCreated});

  @override
  State<CreatePrayerScreen> createState() => _CreatePrayerScreenState();
}

class _CreatePrayerScreenState extends State<CreatePrayerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  
  bool _loading = false;
  bool _hasUnsavedChanges = false;
  
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
    
    // Date: Default to today
    _selectedDate = now;
    
    // Start Time: Next rounded hour
    final nextHour = now.hour + 1;
    _startTime = TimeOfDay(hour: nextHour > 23 ? 0 : nextHour, minute: 0);
    
    // End Time: Start time + 1 hour
    final endHour = _startTime!.hour + 1;
    _endTime = TimeOfDay(hour: endHour > 23 ? 0 : endHour, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day); // Today at midnight
    final DateTime lastDate = now.add(const Duration(days: 365));
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today, // Only allow today or future dates
      lastDate: lastDate,
      helpText: "Select Prayer Date",
      cancelText: "Cancel",
      confirmText: "Select",
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _hasUnsavedChanges = true;
        // If date changed to past, ensure validation shows error
      });
      // Re-validate after date change to show inline errors
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
      // Validate form after time change to show inline errors
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
      // Validate form after time change to show inline errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _formKey.currentState?.validate();
        }
      });
    }
  }

  /// Truncate DateTime to minute precision (YYYY-MM-DD HH:MM)
  DateTime _truncateToMinute(DateTime dateTime) {
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    );
  }

  String? _validateDate() {
    if (_selectedDate == null) {
      return "Please select a date";
    }
    
    final now = DateTime.now();
    final nowTruncated = _truncateToMinute(now);
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    
    // Check if date is in the past (before today)
    if (selectedDateOnly.isBefore(today)) {
      return "You can't schedule a prayer in the past";
    }
    
    // If date is today or in the past, check timestamps up to HH:MM precision
    if (_startTime != null) {
      final startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );
      final startTruncated = _truncateToMinute(startDateTime);
      
      // Check if start time has already passed (including current moment, compare up to HH:MM precision)
      if (startTruncated.compareTo(nowTruncated) <= 0) {
        return "You can't schedule a prayer in the past";
      }
    }
    
    // Also check end time if available
    if (_endTime != null) {
      final endDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );
      final endTruncated = _truncateToMinute(endDateTime);
      
      // Check if end time has already passed (including current moment)
      if (endTruncated.compareTo(nowTruncated) <= 0) {
        return "The end time has already passed";
      }
    }
    
    return null;
  }

  String? _validateEndTime(TimeOfDay? endTime) {
    if (endTime == null) {
      return "Please select an end time";
    }
    if (_startTime == null) {
      return null;
    }
    
    // First check: end time must be after start time
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    
    if (endMinutes <= startMinutes) {
      return "End time should be after start time";
    }
    
    // Second check: Compare full timestamp (date + time) up to HH:MM precision
    if (_selectedDate != null) {
      final now = DateTime.now();
      final nowTruncated = _truncateToMinute(now);
      
      final endDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        endTime.hour,
        endTime.minute,
      );
      final endTruncated = _truncateToMinute(endDateTime);
      
      // Check if end time is in the past or at current moment
      if (endTruncated.compareTo(nowTruncated) <= 0) {
        return "The end time has already passed";
      }
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
        title: const Text("Discard Prayer?"),
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

  Future<void> _createPrayer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null || _startTime == null || _endTime == null) {
      return; // Form validation should catch this
    }

    // Final validation: Check if date is in the past
    final dateError = _validateDate();
    if (dateError != null) {
      // Trigger validation to show inline error
      setState(() {
        _formKey.currentState?.validate();
      });
      return;
    }

    // Final validation: end time must be after start time and not in past
    final endTimeError = _validateEndTime(_endTime);
    if (endTimeError != null) {
      // Error is already shown inline via form field validation
      return;
    }

    setState(() => _loading = true);

    try {
      // Combine date and time for start/end
      final startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      final endDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );

      // Final safety check: Compare timestamps up to HH:MM precision (race condition protection)
      final now = DateTime.now();
      final nowTruncated = _truncateToMinute(now);
      final startTruncated = _truncateToMinute(startDateTime);
      final endTruncated = _truncateToMinute(endDateTime);
      
      // Check if start time is in the past or at current moment (compare up to HH:MM precision)
      if (startTruncated.compareTo(nowTruncated) <= 0) {
        setState(() => _loading = false);
        // Trigger validation to show inline error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _formKey.currentState?.validate();
            });
          }
        });
        return;
      }
      
      // Check if end time is in the past or at current moment (compare up to HH:MM precision)
      if (endTruncated.compareTo(nowTruncated) <= 0) {
        setState(() => _loading = false);
        // Trigger validation to show inline error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _formKey.currentState?.validate();
            });
          }
        });
        return;
      }

      final result = await PrayerService.createPrayer(
        title: _titleController.text.trim(),
        prayerDate: _selectedDate!,
        startTime: startDateTime,
        endTime: endDateTime,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      if (result != null) {
        // Success - show confirmation with actions
        _showSuccessConfirmation();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to create prayer. Please try again."),
            backgroundColor: Colors.red,
          ),
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

  void _showSuccessConfirmation() {
    if (!mounted) return;
    
    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Prayer created successfully"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Show dialog with next actions
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text("Prayer Created")),
          ],
        ),
        content: const Text("Your prayer has been scheduled successfully."),
        actions: [
          TextButton(
            onPressed: () {
              if (!mounted) return;
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Close create prayer screen
              // Navigate to Events tab (index 1)
              widget.onPrayerCreated?.call();
            },
            child: const Text("View Schedule"),
          ),
          ElevatedButton(
            onPressed: () {
              if (!mounted) return;
              Navigator.pop(dialogContext); // Close dialog
              // Reset form for another prayer
              setState(() {
                _titleController.clear();
                _hasUnsavedChanges = false;
              });
              _initializeDefaults();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: const Text("Create Another"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        // If pop was prevented (didPop = false), show confirmation dialog
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
          title: const Text("Create Prayer"),
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
                    "Schedule a new prayer session",
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
                    labelText: "Prayer Title *",
                    hintText: "e.g., Morning Prayer, Evening Fellowship",
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter a prayer title";
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),

                // Date Picker with validation
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "Date *",
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: const OutlineInputBorder(),
                      errorText: _validateDate(),
                      errorMaxLines: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate != null
                              ? DateFormat('EEEE, MMMM d, y').format(_selectedDate!)
                              : "Select date",
                          style: TextStyle(
                            color: _selectedDate != null ? Colors.black87 : Colors.grey,
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

                // End Time Picker with validation
                InkWell(
                  onTap: _selectEndTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "End Time *",
                      prefixIcon: const Icon(Icons.access_time),
                      border: const OutlineInputBorder(),
                      errorText: _endTime != null ? _validateEndTime(_endTime) : null,
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

                // Create Button (Primary CTA)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _createPrayer,
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
                      _loading ? "Creating..." : "Create Prayer",
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

