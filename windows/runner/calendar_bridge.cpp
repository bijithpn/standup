#include "calendar_bridge.h"
#include <windows.h>
#include <shellapi.h>
#include <winrt/base.h>
#include <winrt/Windows.ApplicationModel.Appointments.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.UI.h>
#include <chrono>
#include <iostream>
#include <algorithm>

using namespace winrt::Windows::ApplicationModel::Appointments;
using namespace winrt::Windows::Foundation;

CalendarBridge::CalendarBridge() {}

CalendarBridge::~CalendarBridge() {}

std::string CalendarBridge::GetCalendarPermissionStatus() {
  try {
    // Access modern WinRT store through COM. RequestStoreAsync requests a specific access level from the OS.
    auto store_op = AppointmentManager::RequestStoreAsync(AppointmentStoreAccessType::AllCalendarsReadOnly);
    // .get() synchronously blocks until the WinRT async operation yields a store.
    // NOTE: This blocking call is safe and does not impact the Flutter UI/event loop
    // because all platform channel invocations to CalendarBridge are offloaded to
    // asynchronous background worker threads (detached std::threads) inside flutter_window.cpp.
    auto store = store_op.get();
    return "granted";
  } catch (const winrt::hresult_error& ex) {
    std::wcerr << L"[BreakMate][Calendar] Windows GetCalendarPermissionStatus failed: " 
              << ex.message().c_str() << L" (code: " << std::hex << ex.code() << L")" << std::endl;
    return "denied";
  } catch (...) {
    std::cerr << "[BreakMate][Calendar] Windows GetCalendarPermissionStatus failed with unknown exception" << std::endl;
    return "denied";
  }
}

bool CalendarBridge::RequestCalendarPermissions() {
  try {
    auto store_op = AppointmentManager::RequestStoreAsync(AppointmentStoreAccessType::AllCalendarsReadOnly);
    auto store = store_op.get();
    return true;
  } catch (const winrt::hresult_error& ex) {
    std::wcerr << L"[BreakMate][Calendar] Windows RequestCalendarPermissions failed: " 
              << ex.message().c_str() << std::endl;
    return false;
  } catch (...) {
    return false;
  }
}

void CalendarBridge::OpenCalendarSettings() {
  ShellExecute(NULL, L"open", L"ms-settings:privacy-calendar", NULL, NULL, SW_SHOWNORMAL);
}

std::vector<flutter::EncodableValue> CalendarBridge::GetCalendars() {
  std::vector<flutter::EncodableValue> result_list;
  try {
    auto store_op = AppointmentManager::RequestStoreAsync(AppointmentStoreAccessType::AllCalendarsReadOnly);
    auto store = store_op.get();
    
    auto calendars_op = store.FindAppointmentCalendarsAsync();
    auto calendars = calendars_op.get();
    
    for (const auto& calendar : calendars) {
      flutter::EncodableMap map;
      map[flutter::EncodableValue("id")] = flutter::EncodableValue(winrt::to_string(calendar.LocalId()));
      map[flutter::EncodableValue("name")] = flutter::EncodableValue(winrt::to_string(calendar.DisplayName()));
      
      auto color = calendar.DisplayColor();
      char hex_color[10];
      snprintf(hex_color, sizeof(hex_color), "#%02X%02X%02X", color.R, color.G, color.B);
      map[flutter::EncodableValue("color")] = flutter::EncodableValue(hex_color);
      map[flutter::EncodableValue("isReadOnly")] = flutter::EncodableValue(calendar.CanCreateOrUpdateAppointments() ? false : true);
      
      result_list.push_back(flutter::EncodableValue(map));
    }
  } catch (const winrt::hresult_error& ex) {
    std::wcerr << L"[BreakMate][Calendar] Windows GetCalendars failed: " << ex.message().c_str() << std::endl;
  } catch (...) {
    std::cerr << "[BreakMate][Calendar] Windows GetCalendars failed with unknown exception" << std::endl;
  }
  return result_list;
}

std::vector<flutter::EncodableValue> CalendarBridge::GetEvents(int64_t start_ms, int64_t end_ms, const std::vector<std::string>& calendar_ids) {
  std::vector<flutter::EncodableValue> result_list;
  try {
    auto store_op = AppointmentManager::RequestStoreAsync(AppointmentStoreAccessType::AllCalendarsReadOnly);
    auto store = store_op.get();
    
    auto epoch = std::chrono::system_clock::time_point(std::chrono::milliseconds(start_ms));
    winrt::Windows::Foundation::DateTime start_time = winrt::clock::from_sys(epoch);
    auto duration = std::chrono::milliseconds(end_ms - start_ms);
    
    FindAppointmentsOptions options;
    options.MaxCount(500);
    
    auto appointments_op = store.FindAppointmentsAsync(start_time, duration, options);
    auto appointments = appointments_op.get();
    
    for (const auto& appointment : appointments) {
      std::string cal_id = winrt::to_string(appointment.CalendarId());
      if (!calendar_ids.empty()) {
        if (std::find(calendar_ids.begin(), calendar_ids.end(), cal_id) == calendar_ids.end()) {
          continue;
        }
      }
      
      flutter::EncodableMap map;
      map[flutter::EncodableValue("id")] = flutter::EncodableValue(winrt::to_string(appointment.LocalId()));
      map[flutter::EncodableValue("calendarId")] = flutter::EncodableValue(cal_id);
      map[flutter::EncodableValue("title")] = flutter::EncodableValue(winrt::to_string(appointment.Subject()));
      map[flutter::EncodableValue("notes")] = flutter::EncodableValue(winrt::to_string(appointment.Details()));
      
      auto start_tp = winrt::clock::to_sys(appointment.StartTime());
      auto start_epoch = std::chrono::duration_cast<std::chrono::milliseconds>(start_tp.time_since_epoch()).count();
      map[flutter::EncodableValue("start")] = flutter::EncodableValue(static_cast<int64_t>(start_epoch));
      
      auto end_tp = start_tp + appointment.Duration();
      auto end_epoch = std::chrono::duration_cast<std::chrono::milliseconds>(end_tp.time_since_epoch()).count();
      map[flutter::EncodableValue("end")] = flutter::EncodableValue(static_cast<int64_t>(end_epoch));
      map[flutter::EncodableValue("allDay")] = flutter::EncodableValue(appointment.AllDay());
      
      result_list.push_back(flutter::EncodableValue(map));
    }
  } catch (const winrt::hresult_error& ex) {
    std::wcerr << L"[BreakMate][Calendar] Windows GetEvents failed: " << ex.message().c_str() << std::endl;
  } catch (...) {
    std::cerr << "[BreakMate][Calendar] Windows GetEvents failed with unknown exception" << std::endl;
  }
  return result_list;
}

std::vector<flutter::EncodableValue> CalendarBridge::GetUpcomingCalendarEvents(int window_minutes) {
  auto now_tp = std::chrono::system_clock::now();
  auto now_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now_tp.time_since_epoch()).count();
  auto end_ms = now_ms + (static_cast<int64_t>(window_minutes) * 60 * 1000);
  return GetEvents(now_ms, end_ms, {});
}
