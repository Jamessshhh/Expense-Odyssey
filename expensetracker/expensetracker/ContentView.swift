//
//  ContentView.swift
//  expensetracker
//
//  Created by Ritesh Mahara on 20/02/25.
//

import SwiftUI
import Charts

// MARK: - Expense Model
struct Expense: Identifiable, Codable, Equatable {
    var id = UUID()
    var amount: Double
    var category: String
    var date: Date
    var note: String
}

// MARK: - Expense ViewModel
class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = [] {
        didSet { saveExpenses() }
    }
    
    @Published var selectedCategory: String = "All"
    
    private let storageKey = "expenses"
    let categories = ["All", "Food", "Transport", "Entertainment", "Shopping", "Bills", "Other"]
    
    init() {
        loadExpenses()
    }
    
    // Add a new expense
    func addExpense(amount: Double, category: String, date: Date, note: String) {
        let newExpense = Expense(amount: amount, category: category, date: date, note: note)
        expenses.append(newExpense)
    }
    
    // Update an existing expense
    func updateExpense(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
        }
    }
    
    // Delete an expense
    func deleteExpense(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
    }
    
    // Calculate total expenses for filtered expenses
    func totalExpenses() -> Double {
        filteredExpenses().reduce(0) { $0 + $1.amount }
    }
    
    // Group expenses by category (filtered)
    func expensesByCategory() -> [String: Double] {
        Dictionary(grouping: filteredExpenses(), by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }
    
    // Get filtered expenses based on selected category
    func filteredExpenses() -> [Expense] {
        if selectedCategory == "All" {
            return expenses
        } else {
            return expenses.filter { $0.category == selectedCategory }
        }
    }
    
    // MARK: - Data Persistence (UserDefaults)
    private func saveExpenses() {
        if let encoded = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadExpenses() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Expense].self, from: savedData) {
            expenses = decoded
        }
    }
}

// MARK: - Expense Card View
struct ExpenseCardView: View {
    let expense: Expense
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(expense.category)
                    .font(.headline)
                Spacer()
                Text("$\(expense.amount, specifier: "%.2f")")
                    .font(.headline)
            }
            Text(expense.note)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(expense.date, style: .date)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(LinearGradient(gradient: Gradient(colors: [Color.pink.opacity(0.7), Color.orange.opacity(0.7)]),
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(radius: 5)
    }
}

// MARK: - Expense List View (with Filter & Edit)
struct ExpenseListView: View {
    @ObservedObject var viewModel: ExpenseViewModel
    @State private var showingAddExpense = false
    @State private var selectedExpense: Expense? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background adapting to Dark/Light mode
                LinearGradient(gradient: Gradient(colors: [Color("BGStart"), Color("BGEnd")]),
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack {
                    // Category Filter
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(viewModel.categories, id: \.self) { category in
                            Text(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if viewModel.filteredExpenses().isEmpty {
                        Spacer()
                        Text("No expenses added yet!")
                            .font(.title3)
                            .foregroundColor(.white)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.filteredExpenses()) { expense in
                                    Button(action: {
                                        selectedExpense = expense
                                    }) {
                                        ExpenseCardView(expense: expense)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .onDelete { offsets in
                                    viewModel.deleteExpense(at: offsets)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    
                    HStack {
                        Text("Total: ")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("$\(viewModel.totalExpenses(), specifier: "%.2f")")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                    }
                    .padding()
                }
            }
            .navigationTitle("My Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddExpense.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView(viewModel: viewModel)
            }
            .sheet(item: $selectedExpense) { expense in
                // Pass the selected expense for editing
                EditExpenseView(viewModel: viewModel, expense: expense)
            }
        }
    }
}

// MARK: - Add Expense View
struct AddExpenseView: View {
    @ObservedObject var viewModel: ExpenseViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var amount: String = ""
    @State private var category: String = "Food"
    @State private var date = Date()
    @State private var note: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Amount").foregroundColor(.accentColor)) {
                    TextField("Enter amount", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Category").foregroundColor(.accentColor)) {
                    Picker("Select Category", selection: $category) {
                        ForEach(viewModel.categories.filter { $0 != "All" }, id: \.self) { cat in
                            Text(cat)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Date").foregroundColor(.accentColor)) {
                    DatePicker("Select Date", selection: $date, displayedComponents: .date)
                }
                
                Section(header: Text("Note").foregroundColor(.accentColor)) {
                    TextField("Enter note", text: $note)
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                Button("Save") {
                    if let expenseAmount = Double(amount) {
                        viewModel.addExpense(amount: expenseAmount, category: category, date: date, note: note)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Expense View
struct EditExpenseView: View {
    @ObservedObject var viewModel: ExpenseViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State var expense: Expense
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Amount").foregroundColor(.accentColor)) {
                    TextField("Enter amount", value: $expense.amount, formatter: NumberFormatter.currency)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Category").foregroundColor(.accentColor)) {
                    Picker("Select Category", selection: $expense.category) {
                        ForEach(viewModel.categories.filter { $0 != "All" }, id: \.self) { cat in
                            Text(cat)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Date").foregroundColor(.accentColor)) {
                    DatePicker("Select Date", selection: $expense.date, displayedComponents: .date)
                }
                
                Section(header: Text("Note").foregroundColor(.accentColor)) {
                    TextField("Enter note", text: $expense.note)
                }
            }
            .navigationTitle("Edit Expense")
            .toolbar {
                Button("Update") {
                    viewModel.updateExpense(expense)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// Formatter for editing expense amount
extension NumberFormatter {
    static var currency: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }
}

// MARK: - Expense Chart View
struct ExpenseChartView: View {
    @ObservedObject var viewModel: ExpenseViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color("BGStart"), Color("BGEnd")]),
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack {
                    if viewModel.filteredExpenses().isEmpty {
                        Spacer()
                        Text("No data to display!")
                            .font(.title3)
                            .foregroundColor(.white)
                        Spacer()
                    } else {
                        Text("Expenses by Category")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                        
                        Chart {
                            ForEach(viewModel.expensesByCategory().sorted(by: { $0.key < $1.key }), id: \.key) { category, total in
                                BarMark(
                                    x: .value("Category", category),
                                    y: .value("Total Spent", total)
                                )
                                .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.green, Color.blue]),
                                                                startPoint: .top, endPoint: .bottom))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic) { _ in
                                AxisGridLine().foregroundStyle(.white.opacity(0.3))
                                AxisTick().foregroundStyle(.white)
                                AxisValueLabel().foregroundStyle(.white)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Reports")
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @StateObject var viewModel = ExpenseViewModel()
    
    var body: some View {
        TabView {
            ExpenseListView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Expenses")
                }
            
            ExpenseChartView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Reports")
                }
        }
    }
}

// MARK: - App Entry Point
@main
struct ExpenseTrackerApp: App {
    init() {
        // Customize UINavigationBar appearance for a unified look
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemIndigo
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                // Automatically supports light/dark mode; you can force a mode with:
                //.preferredColorScheme(.dark)
        }
    }
}
