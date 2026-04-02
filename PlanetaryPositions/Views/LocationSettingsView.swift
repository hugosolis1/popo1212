import SwiftUI

struct LocationSettingsView: View {
    @ObservedObject var vm: AstroViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var latText: String = ""
    @State private var lonText: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Zona Horaria UTC")) {
                    Picker("UTC Offset", selection: $vm.utcOffset) {
                        ForEach(AstroViewModel.commonUTCOffsets, id: \.1) { offset in
                            Text(offset.0).tag(offset.1)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("Actual: \(vm.utcOffsetString)")
                        .font(.caption)
                        .foregroundColor(.cyan)
                }
                
                Section(header: Text("Ubicación Geográfica")) {
                    HStack {
                        Text("Latitud")
                        Spacer()
                        TextField("ej. 51.4778", text: $latText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Longitud")
                        Spacer()
                        TextField("ej. 0.0", text: $lonText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Ciudades de Referencia")) {
                    cityButton("Greenwich, Londres", lat: 51.4778, lon: 0.0, utc: 0.0)
                    cityButton("Ciudad de México", lat: 19.4326, lon: -99.1332, utc: -6.0)
                    cityButton("Madrid", lat: 40.4168, lon: -3.7038, utc: 1.0)
                    cityButton("Buenos Aires", lat: -34.6037, lon: -58.3816, utc: -3.0)
                    cityButton("Nueva York", lat: 40.7128, lon: -74.0060, utc: -5.0)
                    cityButton("Los Angeles", lat: 34.0522, lon: -118.2437, utc: -8.0)
                    cityButton("Tokio", lat: 35.6762, lon: 139.6503, utc: 9.0)
                    cityButton("Sydney", lat: -33.8688, lon: 151.2093, utc: 10.0)
                }
                
                Section {
                    Button("Aplicar Cambios") {
                        if let lat = Double(latText), let lon = Double(lonText) {
                            vm.latitude = lat
                            vm.longitude = lon
                            vm.compute()
                        }
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear {
                latText = String(format: "%.4f", vm.latitude)
                lonText = String(format: "%.4f", vm.longitude)
            }
        }
    }
    
    func cityButton(_ name: String, lat: Double, lon: Double, utc: Double) -> some View {
        Button(action: {
            vm.latitude = lat
            vm.longitude = lon
            vm.utcOffset = utc
            latText = String(format: "%.4f", lat)
            lonText = String(format: "%.4f", lon)
            vm.compute()
            dismiss()
        }) {
            HStack {
                Text(name)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(String(format: "%.2f", lat))°, \(String(format: "%.2f", lon))°")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("UTC\(utc >= 0 ? "+" : "")\(Int(utc))")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                }
            }
        }
        .foregroundColor(.primary)
    }
}
