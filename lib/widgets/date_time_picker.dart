import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DateTimePicker extends StatelessWidget {
  final DateTime selectedDate;
  final TimeOfDay? selectedTime;
  final Function(DateTime) onDateSelected;
  final Function(TimeOfDay) onTimeSelected;
  final Function()? onTimeClear;
  final Color accentColor;
  final bool showTimeError;
  final String? timeErrorText;

  const DateTimePicker({
    Key? key,
    required this.selectedDate,
    this.selectedTime,
    required this.onDateSelected,
    required this.onTimeSelected,
    this.onTimeClear,
    required this.accentColor,
    this.showTimeError = false,
    this.timeErrorText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        // Date Selection
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Due Date',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildDateOption(
                      context,
                      'Today',
                      selectedDate.year == today.year &&
                          selectedDate.month == today.month &&
                          selectedDate.day == today.day,
                      () => onDateSelected(today),
                    ),
                    _buildDateOption(
                      context,
                      'Tomorrow',
                      selectedDate.year == today.add(Duration(days: 1)).year &&
                          selectedDate.month == today.add(Duration(days: 1)).month &&
                          selectedDate.day == today.add(Duration(days: 1)).day,
                      () => onDateSelected(today.add(Duration(days: 1))),
                    ),
                    _buildCustomDatePicker(context),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 20, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Time Selection
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: showTimeError ? Colors.red : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: Icon(
                  Icons.access_time,
                  color: showTimeError ? Colors.red : null,
                ),
                title: Text(
                  selectedTime != null
                      ? '${selectedTime!.format(context)}'
                      : 'Set time (Optional)',
                  style: GoogleFonts.inter(
                    color: showTimeError ? Colors.red : null,
                  ),
                ),
                trailing: selectedTime != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onTimeClear,
                      )
                    : null,
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) {
                    onTimeSelected(picked);
                  }
                },
              ),
              if (showTimeError && timeErrorText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Text(
                    timeErrorText!,
                    style: GoogleFonts.inter(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateOption(
      BuildContext context, String text, bool isSelected, VoidCallback onTap) {
    return Container(
      width: 100,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? accentColor : Colors.grey[300]!,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDatePicker(BuildContext context) {
    return Container(
      width: 100,
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final currentDate = DateTime(now.year, now.month, now.day);

          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate.isBefore(currentDate)
                ? currentDate
                : selectedDate,
            firstDate: currentDate,
            lastDate: DateTime(currentDate.year + 2, 12, 31),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: accentColor,
                      ),
                ),
                child: child!,
              );
            },
          );

          if (picked != null) {
            onDateSelected(picked);
          }
        },
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Pick',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}