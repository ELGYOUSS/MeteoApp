import SwiftUI
import Combine


// MARK: - Data Models
struct WeatherData: Codable {
    var name: String
    var sys: Sys
    var weather: [Weather]
    var main: Main
    var wind: Wind
}

struct Weather: Codable {
    var id: Int
    var main: String
    var description: String
}

struct Main: Codable {
    var temp: Double
    var feels_like: Double
    var pressure: Double
    var humidity: Double
}

struct Wind: Codable {
    var speed: Double
    var deg: Int
}

struct Sys: Codable {
    var country: String
    var sunrise: Int
    var sunset: Int
}

// Forecast
struct ForecastData: Codable {
    var list: [HourlyForecast]
}

struct HourlyForecast: Codable, Identifiable {
    var id: Int { dt }
    var dt: Int
    var main: Main
    var weather: [Weather]
}

// MARK: - Weather Service
class WeatherService {
    let apiKey = Secrets.openWeatherMap

    func getWeather(city: String, completion: @escaping (Result<WeatherData, Error>) -> Void) {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(city)&appid=\(apiKey)&units=metric"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else { return }

            do {
                let weather = try JSONDecoder().decode(WeatherData.self, from: data)
                completion(.success(weather))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func getForecast(city: String, completion: @escaping (Result<ForecastData, Error>) -> Void) {
        let urlString = "https://api.openweathermap.org/data/2.5/forecast?q=\(city)&appid=\(apiKey)&units=metric"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else { return }

            do {
                let forecast = try JSONDecoder().decode(ForecastData.self, from: data)
                completion(.success(forecast))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - ViewModel
class WeatherViewModel: ObservableObject {
    @Published var weatherData: WeatherData?
    @Published var forecastData: ForecastData?
    @Published var city = "Montreal"
    
    let cities = ["Montreal", "Toronto", "Vancouver"]

    private let service = WeatherService()

    func fetchWeather() {
        service.getWeather(city: city) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self?.weatherData = data
                case .failure(let error):
                    print("Weather error:", error)
                }
            }
        }
    }

    func fetchForecast() {
        service.getForecast(city: city) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self?.forecastData = data
                case .failure(let error):
                    print("Forecast error:", error)
                }
            }
        }
    }

    func getWindDirection(degree: Int) -> String {
        let directions = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
        let index = Int((Double(degree) + 11.25)/22.5)
        return directions[index % 16]
    }

    func getWeatherIcon(id: Int) -> String {
        switch id {
        case 200...232: return "cloud.bolt.rain.fill"
        case 300...321: return "cloud.drizzle.fill"
        case 500...531: return "cloud.rain.fill"
        case 600...622: return "cloud.snow.fill"
        case 701...771: return "smoke.fill"
        case 781: return "tornado"
        case 800: return "sun.max.fill"
        case 801: return "cloud.sun.fill"
        case 802...804: return "cloud.fill"
        default: return "questionmark.circle"
        }
    }

    func formatHour(unixTime: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unixTime))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Views
struct MeteoDegreHeure: View {
    var image: String
    var heure: String
    var temperature: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: image)
                .resizable()
                .frame(width: 40, height: 40)
                .symbolRenderingMode(.multicolor)
            Text(heure)
            Text("\(temperature)°C")
        }
        .padding(10)
        .background(Color.gray.opacity(0.6))
        .cornerRadius(8)
    }
}

struct DetailMeteo: View {
    var image: String
    var text: String
    var detail: String
    var body: some View {
        HStack {
            Image(systemName: image)
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)
            Text(text)
            Spacer()
            Text(detail)
        }
        .padding(10)
        .background(Color.gray.opacity(0.6))
        .cornerRadius(8)
    }
}

struct ContentView: View {
    @StateObject var viewModel = WeatherViewModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue, .blue, .white], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                       // City picker
                       Picker("Select a city", selection: $viewModel.city) {
                           ForEach(viewModel.cities, id: \.self) { city in
                               Text(city)
                           }
                       }
                       .pickerStyle(.segmented) // or .wheel
                       .padding()
                       .onChange(of: viewModel.city) { _ in
                           viewModel.fetchWeather()
                           viewModel.fetchForecast()
                       }
                // Weather data
                if let weather = viewModel.weatherData {
                    HStack {
                        Text("\(weather.name), \(weather.sys.country)")
                            .font(.title)
                            .bold()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal)

                    HStack {
                        Image(systemName: viewModel.getWeatherIcon(id: weather.weather.first?.id ?? 800))
                            .resizable()
                            .frame(width: 100, height: 100)
                            .symbolRenderingMode(.multicolor)
                        VStack(alignment: .leading) {
                            Text("\(Int(weather.main.temp))°C")
                                .font(.largeTitle)
                            Text("Feels like: \(Int(weather.main.feels_like))°C")
                            Text(weather.weather.first?.description.capitalized ?? "")
                            Text("Wind: \(viewModel.getWindDirection(degree: weather.wind.deg)) \(Int(weather.wind.speed)) km/h")
                        }
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    
                    // Hourly forecast
                    if let forecast = viewModel.forecastData {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(forecast.list.prefix(12)) { hour in
                                    MeteoDegreHeure(
                                        image: viewModel.getWeatherIcon(id: hour.weather.first?.id ?? 800),
                                        heure: viewModel.formatHour(unixTime: hour.dt),
                                        temperature: "\(Int(hour.main.temp))"
                                    )
                                }
                            }
                            .padding()
                        }
                    }

                    VStack(spacing: 5) {
                        DetailMeteo(image: "sun.and.horizon.fill", text: "Sunrise - Sunset", detail: "06:44 - 17:47")
                        DetailMeteo(image: "humidity", text: "Humidity", detail: "\(Int(weather.main.humidity))%")
                        DetailMeteo(image: "gauge", text: "Pressure", detail: "\(Int(weather.main.pressure)) hPa")
                    }
                    .padding()
                } else {
                    Text("Loading weather...")
                        .foregroundColor(.white)
                        .font(.title2)
                        .padding()
                }

                Spacer()
            }
        }
        .onAppear {
            viewModel.fetchWeather()
            viewModel.fetchForecast()
        }
    }
}



