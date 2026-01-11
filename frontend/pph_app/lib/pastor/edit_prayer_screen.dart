import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/prayer_service.dart';

class EditPrayerScreen extends StatefulWidget {
  final Map<String, dynamic> prayer;
  final VoidCallback? onPrayerUpdated;
  
  const EditPrayerScreen({
    super.key,
    required this.prayer,
    this.onPrayerUpdated,
  });

  @override
  State<EditPrayerScreen> createState() => _EditPrayerScreenState();
}

class _EditPrayerScreenState extends State<EditPrayerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _joinInfoController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  
  String _prayerType = 'offline'; // 'offline' or 'online'
  
  bool _loading = false;
  bool _hasUnsavedChanges = false;
  int? _prayerId;

  @override
  void initState() {
    super.initState();
    _prayerId = widget.prayer['id'] as int?;
    _titleController = TextEditingController(text: widget.prayer['title'] as String? ?? '');
    _initializeFromPrayer();
    _titleController.addListener(() {
      _hasUnsavedChanges = true;
    });
  }

  void _initializeFromPrayer() {
    // Parse date from "YYYY-MM-DD" format
    final prayerDateStr = widget.prayer['prayer_date'] as String?;
    if (prayerDateStr != null) {
      try {
        final parts = prayerDateStr.split('-');
        if (parts.length >= 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          _selectedDate = DateTime(year, month, day);
        }
      } catch (e) {
        print("Error parsing date: $e");
      }
    }
    
    // Parse start time from "HH:MM:SS" format
    final startTimeStr = widget.prayer['start_time'] as String?;
    if (startTimeStr != null) {
      try {
        final parts = startTimeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          _startTime = TimeOfDay(hour: hour, minute: minute);
        }
      } catch (e) {
        print("Error parsing start time: $e");
      }
    }
    
    // Parse end time from "HH:MM:SS" format
    final endTimeStr = widget.prayer['end_time'] as String?;
    if (endTimeStr != null) {
      try {
        final parts = endTimeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          _endTime = TimeOfDay(hour: hour, minute: minute);
        }
      } catch (e) {
        print("Error parsing end time: $e");
      }
    }
    
    _hasUnsavedChanges = false; // Reset after initializing
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _joinInfoController.dispose();
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

  Future<void> _updatePrayer() async {
    if (_prayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid prayer ID")),
      );
      return;
    }
    
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

      final result = await PrayerService.updatePrayer(
        prayerId: _prayerId!,
        title: _titleController.text.trim(),
        prayerDate: _selectedDate!,
        startTime: startDateTime,
        endTime: endDateTime,
        prayerType: _prayerType,
        location: _prayerType == 'offline' ? _locationController.text.trim() : null,
        joinInfo: _prayerType == 'online' ? _joinInfoController.text.trim() : null,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      if (result != null) {
        // Success - show confirmation
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Prayer updated successfully"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Call callback and pop
        widget.onPrayerUpdated?.call();
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update prayer. Please try again."),
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
          title: const Text("Edit Prayer"),
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
                    "Update prayer details",
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

                // Prayer Type Toggle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Prayer Type *",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _prayerType = 'offline';
                                  _hasUnsavedChanges = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _prayerType == 'offline' ? Colors.blue[700] : Colors.transparent,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Offline',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _prayerType == 'offline' ? Colors.white : Colors.grey[700],
                                    fontWeight: _prayerType == 'offline' ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _prayerType = 'online';
                                  _hasUnsavedChanges = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _prayerType == 'online' ? Colors.blue[700] : Colors.transparent,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Online',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _prayerType == 'online' ? Colors.white : Colors.grey[700],
                                    fontWeight: _prayerType == 'online' ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Location Field (for offline prayers)
                if (_prayerType == 'offline')
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: "Location *",
                      hintText: "e.g., Main Prayer Hall, Church Building",
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (_prayerType == 'offline' && (value == null || value.trim().isEmpty)) {
                        return "Please enter a location for offline prayers";
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),

                // Join Info Field (for online prayers)
                if (_prayerType == 'online')
                  TextFormField(
                    controller: _joinInfoController,
                    decoration: const InputDecoration(
                      labelText: "WhatsApp Join Info *",
                      hintText: "e.g., WhatsApp link or join instructions",
                      prefixIcon: Icon(Icons.chat),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (_prayerType == 'online' && (value == null || value.trim().isEmpty)) {
                        return "Please enter WhatsApp join information for online prayers";
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

                // Update Button (Primary CTA)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _updatePrayer,
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
                      _loading ? "Updating..." : "Update Prayer",
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

