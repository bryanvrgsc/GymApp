//
//  AttendanceCalendarView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// User attendance calendar view
struct AttendanceCalendarView: View {
    @ObservedObject private var authState = AuthState.shared
    
    @State private var currentMonth = Date()
    @State private var checkins: [Checkin] = []
    @State private var groupedAttendance: [String: [Checkin]] = [:]
    @State private var selectedDate: Date?
    @State private var isLoading = true
    @State private var stats = AttendanceStats.empty
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["L", "M", "M", "J", "V", "S", "D"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Month navigation
                    monthHeader
                    
                    // Calendar grid
                    calendarGrid
                    
                    // Selected day detail
                    if let date = selectedDate {
                        selectedDayDetail(date: date)
                    }
                    
                    // Stats section
                    statsSection
                }
                .padding()
            }
            .navigationTitle("Asistencias")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadCheckins() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadCheckins()
            }
        }
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation { previousMonth() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            
            Spacer()
            
            Text(monthYearString)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button {
                withAnimation { nextMonth() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
        }
        .padding(.horizontal)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth).capitalized
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Day headers
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days grid
            let days = generateDaysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        dayCell(date: date)
                    } else {
                        Text("")
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func dayCell(date: Date) -> some View {
        let dateKey = dateKeyFor(date)
        let hasAttendance = groupedAttendance[dateKey] != nil
        let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
        let isToday = calendar.isDateInToday(date)
        
        return Button {
            withAnimation { selectedDate = date }
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isSelected ? .white : (isToday ? .accentColor : .primary))
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if hasAttendance {
                            Circle().fill(Color.green.opacity(0.3))
                        }
                        
                        if isToday && !isSelected {
                            Circle().stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
                )
        }
    }
    
    // MARK: - Selected Day Detail
    
    private func selectedDayDetail(date: Date) -> some View {
        let dateKey = dateKeyFor(date)
        let dayCheckins = groupedAttendance[dateKey] ?? []
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(formattedDate(date))
                .font(.headline)
            
            if dayCheckins.isEmpty {
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                    Text("Sin asistencia este día")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    // Check-in time
                    if let checkIn = dayCheckins.first(where: { $0.type == .checkin }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.green)
                            Text("Entrada")
                            Spacer()
                            Text(formatTime(checkIn.timestamp))
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // Check-out time
                    if let checkOut = dayCheckins.first(where: { $0.type == .checkout }) {
                        HStack {
                            Image(systemName: "arrow.left.circle.fill")
                                .foregroundColor(.orange)
                            Text("Salida")
                            Spacer()
                            Text(formatTime(checkOut.timestamp))
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // Duration
                    if let checkIn = dayCheckins.first(where: { $0.type == .checkin }),
                       let checkOut = dayCheckins.first(where: { $0.type == .checkout }) {
                        Divider()
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.accentColor)
                            Text("Duración")
                            Spacer()
                            Text(formatDuration(from: checkIn.timestamp, to: checkOut.timestamp))
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estadísticas")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatBox(title: "Total visitas", value: "\(stats.totalVisits)", icon: "figure.walk")
                StatBox(title: "Esta semana", value: "\(stats.visitsThisWeek)", icon: "calendar")
                StatBox(title: "Tiempo total", value: stats.totalDurationString, icon: "clock.fill")
                StatBox(title: "Promedio", value: stats.averageDurationString, icon: "chart.bar.fill")
            }
            
            if let day = stats.mostFrequentDay {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Día más frecuente: \(day)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadCheckins() async {
        isLoading = true
        
        guard let userId = authState.gymUser?.id else {
            isLoading = false
            return
        }
        
        // Get month range
        let (startOfMonth, endOfMonth) = getMonthRange(for: currentMonth)
        
        do {
            // Fetch checkins for current month
            let monthCheckins = try await FirebaseService.shared.getUserCheckins(
                userId: userId,
                startDate: startOfMonth,
                endDate: endOfMonth
            )
            
            // Group by date
            var grouped: [String: [Checkin]] = [:]
            for checkin in monthCheckins {
                let key = checkin.dateKey
                if grouped[key] == nil {
                    grouped[key] = []
                }
                grouped[key]?.append(checkin)
            }
            
            // Fetch all for stats
            let allCheckins = try await FirebaseService.shared.getAllUserCheckins(userId: userId)
            let calculatedStats = calculateStats(from: allCheckins)
            
            await MainActor.run {
                self.checkins = monthCheckins
                self.groupedAttendance = grouped
                self.stats = calculatedStats
            }
        } catch {
            print("[AttendanceCalendarView] Error loading checkins: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Stats Calculation
    
    private func calculateStats(from checkins: [Checkin]) -> AttendanceStats {
        // Group by date
        var byDate: [String: [Checkin]] = [:]
        for c in checkins {
            let key = c.dateKey
            if byDate[key] == nil { byDate[key] = [] }
            byDate[key]?.append(c)
        }
        
        let visitDays = byDate.keys.count
        
        // Calculate durations
        var totalDuration: TimeInterval = 0
        var durationCount = 0
        
        for (_, dayCheckins) in byDate {
            if let checkIn = dayCheckins.first(where: { $0.type == .checkin }),
               let checkOut = dayCheckins.first(where: { $0.type == .checkout }) {
                totalDuration += checkOut.timestamp.timeIntervalSince(checkIn.timestamp)
                durationCount += 1
            }
        }
        
        let avgDuration = durationCount > 0 ? totalDuration / Double(durationCount) : 0
        
        // Most frequent day of week
        var dayOfWeekCounts: [Int: Int] = [:]
        for date in byDate.keys {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let d = formatter.date(from: date) {
                let weekday = calendar.component(.weekday, from: d)
                dayOfWeekCounts[weekday, default: 0] += 1
            }
        }
        let mostFrequent = dayOfWeekCounts.max(by: { $0.value < $1.value })
        
        // Map weekday to name
        let dayNames = ["", "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
        let frequentDay = mostFrequent != nil ? dayNames[mostFrequent!.key] : nil
        
        // This week/month counts
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        let thisWeek = byDate.keys.filter { key in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let d = formatter.date(from: key) {
                return d >= weekStart
            }
            return false
        }.count
        
        let thisMonth = byDate.keys.filter { key in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let d = formatter.date(from: key) {
                return d >= monthStart
            }
            return false
        }.count
        
        return AttendanceStats(
            totalVisits: visitDays,
            totalDuration: totalDuration,
            averageDuration: avgDuration,
            mostFrequentDay: frequentDay,
            visitsThisWeek: thisWeek,
            visitsThisMonth: thisMonth
        )
    }
    
    // MARK: - Helpers
    
    private func generateDaysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        // Adjust for Monday start (1 = Sunday, 2 = Monday, ...)
        let offset = (firstWeekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func getMonthRange(for date: Date) -> (Date, Date) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        return (start, calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end)!)
    }
    
    private func dateKeyFor(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateStyle = .full
        return formatter.string(from: date).capitalized
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
    
    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
            Task { await loadCheckins() }
        }
    }
    
    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
            Task { await loadCheckins() }
        }
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    AttendanceCalendarView()
}
