import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TimePicker extends StatefulWidget {
  final Function(TimeOfDay) onTimeSelected;
  final Color accentColor;

  const TimePicker({
    Key? key,
    required this.onTimeSelected,
    this.accentColor = Colors.blue,
  }) : super(key: key);

  @override
  _TimePickerState createState() => _TimePickerState();
}

class _TimePickerState extends State<TimePicker> {
  late int selectedHour;
  late int selectedMinute;
  late bool isAM;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _amPmController;

  @override
  void initState() {
    super.initState();
    // Set current time as initial
    final now = TimeOfDay.now();
    selectedHour = now.hourOfPeriod; // 0 for 12, 1-11 for others
    selectedMinute = now.minute;
    isAM = now.period == DayPeriod.am;

    // Initialize controllers with current time values.
    _hourController = FixedExtentScrollController(initialItem: selectedHour);
    _minuteController =
        FixedExtentScrollController(initialItem: selectedMinute);
    _amPmController = FixedExtentScrollController(initialItem: isAM ? 0 : 1);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _amPmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Set Reminder',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Time picker wheels
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hours wheel (12-hour format)
                SizedBox(
                  width: 70,
                  child: ListWheelScrollView.useDelegate(
                    controller: _hourController,
                    itemExtent: 50,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: FixedExtentScrollPhysics(),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 12,
                      builder: (context, index) {
                        // Display "12" for index 0 and then 1-11.
                        final hour = index == 0 ? "12" : index.toString();
                        return _buildTimeItem(
                          hour.padLeft(2, '0'),
                          selectedHour == index,
                        );
                      },
                    ),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        selectedHour = index;
                        _updateSelectedTime();
                      });
                    },
                  ),
                ),

                Text(
                  ':',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                // Minutes wheel
                SizedBox(
                  width: 70,
                  child: ListWheelScrollView.useDelegate(
                    controller: _minuteController,
                    itemExtent: 50,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: FixedExtentScrollPhysics(),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 60,
                      builder: (context, index) {
                        return _buildTimeItem(
                          index.toString().padLeft(2, '0'),
                          selectedMinute == index,
                        );
                      },
                    ),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        selectedMinute = index;
                        _updateSelectedTime();
                      });
                    },
                  ),
                ),

                // AM/PM selector
                SizedBox(
                  width: 70,
                  child: ListWheelScrollView.useDelegate(
                    controller: _amPmController,
                    itemExtent: 50,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: FixedExtentScrollPhysics(),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 2,
                      builder: (context, index) {
                        return _buildTimeItem(
                          index == 0 ? 'AM' : 'PM',
                          (index == 0) == isAM,
                        );
                      },
                    ),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        isAM = index == 0;
                        _updateSelectedTime();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Buttons
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final selectedTime = _getSelectedTimeOfDay();
                      Navigator.pop(context, selectedTime);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeItem(String text, bool isSelected) {
    return Container(
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected
            ? widget.accentColor.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 24,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? widget.accentColor : Colors.grey[600],
        ),
      ),
    );
  }

  void _updateSelectedTime() {
    widget.onTimeSelected(_getSelectedTimeOfDay());
  }

  TimeOfDay _getSelectedTimeOfDay() {
    int hour = selectedHour;
    // Convert 0 to 12 to display as "12"
    if (hour == 0) hour = 12;

    // Convert to 24-hour format based on AM/PM selection.
    if (!isAM) {
      if (hour != 12) hour += 12;
    } else {
      if (hour == 12) hour = 0;
    }

    return TimeOfDay(hour: hour, minute: selectedMinute);
  }
}

class CustomDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Function(DateTime)? onDateSelected;
  final Color accentColor;

  const CustomDatePicker({
    Key? key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.onDateSelected,
    this.accentColor = Colors.blue,
  }) : super(key: key);

  @override
  _CustomDatePickerState createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    // Set the initial selected date.
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Adjust the height as needed.
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar.
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Select Date',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Calendar Date Picker with past dates disabled.
          Expanded(
            child: CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              selectableDayPredicate: (DateTime date) {
                final now = DateTime.now();
                // Normalize today’s date (remove time portion).
                final currentDate = DateTime(now.year, now.month, now.day);
                return !date.isBefore(currentDate);
              },
              onDateChanged: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
            ),
          ),
          // Action Buttons.
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Cancel Button.
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                // Done Button.
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (widget.onDateSelected != null) {
                        widget.onDateSelected!(_selectedDate);
                      }
                      Navigator.pop(context, _selectedDate);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
