#ifndef RUNNER_CALENDAR_BRIDGE_H_
#define RUNNER_CALENDAR_BRIDGE_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <string>
#include <vector>

class CalendarBridge {
 public:
  CalendarBridge();
  virtual ~CalendarBridge();

  std::string GetCalendarPermissionStatus();
  bool RequestCalendarPermissions();
  void OpenCalendarSettings();
  std::vector<flutter::EncodableValue> GetCalendars();
  std::vector<flutter::EncodableValue> GetEvents(int64_t start_ms, int64_t end_ms, const std::vector<std::string>& calendar_ids);
  std::vector<flutter::EncodableValue> GetUpcomingCalendarEvents(int window_minutes);
};

#endif  // RUNNER_CALENDAR_BRIDGE_H_
