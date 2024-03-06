//
//  WidgetPreferencesView.swift
//  Helium UI
//
//  Created by lemin on 10/18/23.
//

import Foundation
import SwiftUI

struct WidgetPreferencesView: View {
    @StateObject var widgetManager: WidgetManager
    @State var widgetSet: WidgetSetStruct
    @Binding var widgetID: WidgetIDStruct
    
    @State var text: String = ""
    @State var weatherFormat: String = ""
    @State var weatherProvider: Int = 0
    @State var intSelection: Int = 0
    @State var intSelection2: Int = 0
    @State var intSelection3: Int = 1
    @State var boolSelection: Bool = false
    
    @State var modified: Bool = false
    @State private var isPresented = false
    
    let timeFormats: [String] = [
        "hh:mm",
        "hh:mm a",
        "hh:mm:ss",
        "hh",
        
        "HH:mm",
        "HH:mm:ss",
        "HH",
        
        "mm",
        "ss"
    ]
    
    let dateFormatter = DateFormatter()
    let currentDate = Date()
    
    var body: some View {
        VStack {
            // MARK: Preview
            WidgetPreviewsView(widget: $widgetID, previewColor: .white)
            
            switch (widgetID.module) {
            case .dateWidget:
                // MARK: Date Format Textbox
                HStack {
                    Text(NSLocalizedString("Date Format", comment:""))
                        .foregroundColor(.primary)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField(NSLocalizedString("E MMM dd", comment:""), text: $text)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onAppear {
                            if let format = widgetID.config["dateFormat"] as? String {
                                text = format
                            } else {
                                text = NSLocalizedString("E MMM dd", comment:"")
                            }
                        }
                }
            case .network:
                // MARK: Network Type Choice
                VStack {
                    HStack {
                        Text(NSLocalizedString("Network Type", comment:""))
                            .foregroundColor(.primary)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        DropdownPicker(selection: $intSelection) {
                            return [
                                DropdownItem(NSLocalizedString("Download", comment:""), tag: 0),
                                DropdownItem(NSLocalizedString("Upload", comment:""), tag: 1)
                            ]
                        }
                        .onAppear {
                            if let netUp = widgetID.config["isUp"] as? Bool {
                                intSelection = netUp ? 1 : 0
                            } else {
                                intSelection = 0
                            }
                        }
                    }
                    // MARK: Speed Icon Choice
                    HStack {
                        Text(NSLocalizedString("Speed Icon", comment:""))
                            .foregroundColor(.primary)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        DropdownPicker(selection: $intSelection2) {
                            return [
                                DropdownItem(intSelection == 0 ? "▼" : "▲", tag: 0),
                                DropdownItem(intSelection == 0 ? "↓" : "↑", tag: 1)
                            ]
                        }
                        .onAppear {
                            if let speedIcon = widgetID.config["speedIcon"] as? Int {
                                intSelection2 = speedIcon
                            } else {
                                intSelection2 = 0
                            }
                        }
                    }
                    // MARK: Minimum Unit Choice
                    HStack {
                        Text(NSLocalizedString("Minimum Unit", comment:""))
                            .foregroundColor(.primary)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        DropdownPicker(selection: $intSelection3) {
                            return [
                                DropdownItem("b", tag: 0),
                                DropdownItem("Kb", tag: 1),
                                DropdownItem("Mb", tag: 2),
                                DropdownItem("Gb", tag: 3)
                            ]
                        }
                        .onAppear {
                            if let minUnit = widgetID.config["minUnit"] as? Int {
                                intSelection3 = minUnit
                            } else {
                                intSelection3 = 1
                            }
                        }
                    }
                    // MARK: Hide Speed When Zero
                    Toggle(isOn: $boolSelection) {
                        Text(NSLocalizedString("Hide Speed When 0", comment:""))
                            .foregroundColor(.primary)
                            .bold()
                    }
                    .onAppear {
                        boolSelection = widgetID.config["hideSpeedWhenZero"] as? Bool ?? false
                    }
                }
            case .temperature:
                // MARK: Battery Temperature Value
                HStack {
                    Text(NSLocalizedString("Temperature Unit", comment:""))
                        .foregroundColor(.primary)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DropdownPicker(selection: $intSelection) {
                        return [
                            DropdownItem(NSLocalizedString("Celcius", comment:""), tag: 0),
                            DropdownItem(NSLocalizedString("Fahrenheit", comment:""), tag: 1)
                        ]
                    }
                    .onAppear {
                        if widgetID.config["useFahrenheit"] as? Bool ?? false == true {
                            intSelection = 1
                        } else {
                            intSelection = 0
                        }
                    }
                }
            case .battery:
                // MARK: Battery Value Type
                HStack {
                    Text(NSLocalizedString("Battery Option", comment:""))
                        .foregroundColor(.primary)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DropdownPicker(selection: $intSelection) {
                        return [
                            DropdownItem(NSLocalizedString("Watts", comment:""), tag: 0),
                            DropdownItem(NSLocalizedString("Charging Current", comment:""), tag: 1),
                            DropdownItem(NSLocalizedString("Amperage", comment:""), tag: 2),
                            DropdownItem(NSLocalizedString("Charge Cycles", comment:""), tag: 3)
                        ]
                    }
                    .onAppear {
                        if let batteryType = widgetID.config["batteryValueType"] as? Int {
                            intSelection = batteryType
                        } else {
                            intSelection = 0
                        }
                    }
                }
            case .timeWidget:
                // MARK: Time Format Selector
                HStack {
                    Text(NSLocalizedString("Time Format", comment:""))
                        .foregroundColor(.primary)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DropdownPicker(selection: $intSelection) {
                        return timeFormats.indices.map { index in
                            DropdownItem("\(getFormattedDate(timeFormats[index]))\n(\(timeFormats[index]))", tag: index)
                        }
                    }
                    .onAppear {
                        if let timeFormat = widgetID.config["dateFormat"] as? String {
                            intSelection = timeFormats.firstIndex(of: timeFormat) ?? 0
                        } else {
                            intSelection = 0
                        }
                    }
                }
            case .textWidget:
                // MARK: Custom Text Label Textbox
                HStack {
                    Text(NSLocalizedString("Label Text", comment:""))
                        .foregroundColor(.primary)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField(NSLocalizedString("Example", comment:""), text: $text)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onAppear {
                            if let format = widgetID.config["text"] as? String {
                                text = format
                            } else {
                                text = NSLocalizedString("Example", comment:"")
                            }
                        }
                }
            case .currentCapacity:
                // MARK: Current Capacity Choice
                HStack {
                    Toggle(isOn: $boolSelection) {
                        Text(NSLocalizedString("Show Percent (%) Symbol", comment:""))
                            .foregroundColor(.primary)
                            .bold()
                    }
                    .onAppear {
                        boolSelection = widgetID.config["showPercentage"] as? Bool ?? true
                    }
                }
            case .chargeSymbol:
                // MARK: Charge Symbol Fill Option
                HStack {
                    Toggle(isOn: $boolSelection) {
                        Text(NSLocalizedString("Fill Symbol", comment:""))
                            .foregroundColor(.primary)
                            .bold()
                    }
                    .onAppear {
                        boolSelection = widgetID.config["filled"] as? Bool ?? true
                    }
                }
            case .weather:
                ScrollView(.vertical, showsIndicators: false) {
                    VStack {
                        HStack {
                            Text(NSLocalizedString("Format", comment:""))
                                .foregroundColor(.primary)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            TextField("{i}{n}{lt}°~{ht}°({t}°,{bt}°)💧{h}%", text: $weatherFormat)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onAppear {
                                    if let format = widgetID.config["format"] as? String {
                                        weatherFormat = format
                                    } else {
                                        weatherFormat = "{i}{n}{lt}°~{ht}°({t}°,{bt}°)💧{h}%"
                                    }
                                }
                        }

                        HStack {
                            Text(NSLocalizedString("Measurement System", comment:""))
                                .foregroundColor(.primary)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            DropdownPicker(selection: $intSelection2) {
                                return [
                                    DropdownItem(NSLocalizedString("Metric", comment:""), tag: 0),
                                    DropdownItem(NSLocalizedString("US", comment:""), tag: 1)
                                ]
                            }
                            .onAppear {
                                if let useMetric = widgetID.config["useMetric"] as? Bool {
                                    intSelection2 = useMetric ? 1 : 0
                                } else {
                                    intSelection2 = 0
                                }
                            }
                        }
                        
                        HStack {
                            Text(NSLocalizedString("Temperature Unit", comment:""))
                                .foregroundColor(.primary)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            DropdownPicker(selection: $intSelection) {
                                return [
                                    DropdownItem(NSLocalizedString("Celcius", comment:""), tag: 0),
                                    DropdownItem(NSLocalizedString("Fahrenheit", comment:""), tag: 1)
                                ]
                            }
                            .onAppear {
                                if widgetID.config["useFahrenheit"] as? Bool ?? false == true {
                                    intSelection = 1
                                } else {
                                    intSelection = 0
                                }
                            }
                        }

                        if weatherProvider == 0 {
                            HStack {
                                Text(NSLocalizedString("Weather Format System", comment:""))
                                    .multilineTextAlignment(.leading)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        } else if weatherProvider != 0 {
                            HStack {
                                Text(NSLocalizedString("Location", comment:""))
                                    .foregroundColor(.primary)
                                    .bold()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                TextField(NSLocalizedString("Input", comment:""), text: $text)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onAppear {
                                        if let format = widgetID.config["location"] as? String {
                                            text = format
                                        } else {
                                            text = "101010100"
                                        }
                                    }
                                Button(NSLocalizedString("Get", comment:"")) {
                                    isPresented = true
                                }
                                .sheet(isPresented: $isPresented) {
                                    WeatherLocationView(locationID: self.$text)
                                }
                            }

                            HStack {
                                Text(NSLocalizedString("Weather Format QWeather", comment:""))
                                    .multilineTextAlignment(.leading)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
            case .lyrics:
                // MARK: Battery Value Type
                VStack {
                    Toggle(isOn: $boolSelection) {
                        Text(NSLocalizedString("Unsupported Apps Are Displayed", comment:""))
                            .foregroundColor(.primary)
                            .bold()
                    }

                    HStack {
                        Text(NSLocalizedString("Lyrics Option", comment:""))
                            .foregroundColor(.primary)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        DropdownPicker(selection: $intSelection) {
                            return [
                                DropdownItem(NSLocalizedString("Auto Detection", comment:""), tag: 0),
                                DropdownItem(NSLocalizedString("Title", comment:""), tag: 1),
                                DropdownItem(NSLocalizedString("Artist", comment:""), tag: 2),
                                DropdownItem(NSLocalizedString("Album", comment:""), tag: 3)
                            ]
                        }
                    }

                    if boolSelection || intSelection != 0 {
                        HStack{
                            Text(NSLocalizedString("Bluetooth Headset Option", comment:""))
                                .foregroundColor(.primary)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            DropdownPicker(selection: $intSelection2) {
                                return [
                                    DropdownItem(NSLocalizedString("Title", comment:""), tag: 1),
                                    DropdownItem(NSLocalizedString("Artist", comment:""), tag: 2),
                                    DropdownItem(NSLocalizedString("Album", comment:""), tag: 3)
                                ]
                            }
                        }

                        HStack{
                            Text(NSLocalizedString("Wired Headset Option", comment:""))
                                .foregroundColor(.primary)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            DropdownPicker(selection: $intSelection3) {
                                return [
                                    DropdownItem(NSLocalizedString("Title", comment:""), tag: 1),
                                    DropdownItem(NSLocalizedString("Artist", comment:""), tag: 2),
                                    DropdownItem(NSLocalizedString("Album", comment:""), tag: 3)
                                ]
                            }
                        }
                    }
                }
                .onAppear {
                    boolSelection = widgetID.config["unsupported"] as? Bool ?? false
                    if let lyricsType = widgetID.config["lyricsType"] as? Int {
                        intSelection = lyricsType
                    } else {
                        intSelection = boolSelection ? 1 : 0
                    }
                    if let bluetoothType = widgetID.config["bluetoothType"] as? Int {
                        intSelection2 = bluetoothType
                    } else {
                        intSelection2 = 1
                    }
                    if let wiredType = widgetID.config["wiredType"] as? Int {
                        intSelection3 = wiredType
                    } else {
                        intSelection3 = 1
                    }
                }
            default:
                Text(NSLocalizedString("No Configurable Aspects", comment:""))
            }
        }
        .padding(.horizontal, 15)
        .toolbar {
            HStack {
                // MARK: Save Button
                // only shows up if something is changed
                if (modified) {
                    Button(action: {
                        saveChanges()
                    }) {
                        Image(systemName: "checkmark.circle")
                    }
                }
            }
        }
        .onAppear {
            weatherProvider = UserDefaults.standard.integer(forKey: "weatherProvider", forPath: USER_DEFAULTS_PATH)
        }
        .onDisappear {
            if modified {
                UIApplication.shared.confirmAlert(title: NSLocalizedString("Save Changes", comment:""), body: NSLocalizedString("Would you like to save changes to the widget?", comment:""), onOK: {
                    saveChanges()
                }, noCancel: false)
            }
        }
        .onChange(of: text) { _ in
            modified = true
        }
        .onChange(of: weatherFormat) { _ in
            modified = true
        }
        .onChange(of: intSelection) { _ in
            modified = true
        }
        .onChange(of: intSelection2) { _ in
            modified = true
        }
        .onChange(of: intSelection3) { _ in
            modified = true
        }
        .onChange(of: boolSelection) { _ in
            modified = true
        }
    }
    
    func getFormattedDate(_ format: String) -> String {
        let locale = UserDefaults.standard.string(forKey: "dateLocale", forPath: USER_DEFAULTS_PATH) ?? "en"
        dateFormatter.locale = Locale(identifier: locale)
        dateFormatter.dateFormat = format
        // dateFormatter.locale = Locale(identifier: NSLocalizedString("en_US", comment:""))
        return dateFormatter.string(from: currentDate)
    }
    
    func saveChanges() {
        var widgetStruct: WidgetIDStruct = .init(module: widgetID.module, config: widgetID.config)
        
        switch(widgetStruct.module) {
        // MARK: Changing Text
        case .dateWidget:
            // MARK: Date Format Handling
            if text == "" {
                widgetStruct.config["dateFormat"] = nil
            } else {
                widgetStruct.config["dateFormat"] = text
            }
        case .textWidget:
            // MARK: Custom Text Handling
            if text == "" {
                widgetStruct.config["text"] = nil
            } else {
                widgetStruct.config["text"] = text
            }
        
        // MARK: Changing Integer
        case .network:
            // MARK: Network Choices Handling
            widgetStruct.config["isUp"] = intSelection == 1 ? true : false
            widgetStruct.config["speedIcon"] = intSelection2
            widgetStruct.config["minUnit"] = intSelection3
            widgetStruct.config["hideSpeedWhenZero"] = boolSelection
        case .temperature:
            // MARK: Temperature Unit Handling
            widgetStruct.config["useFahrenheit"] = intSelection == 1 ? true : false
        case .battery:
            // MARK: Battery Value Type Handling
            widgetStruct.config["batteryValueType"] = intSelection
        case .timeWidget:
            // MARK: Time Format Handling
            widgetStruct.config["dateFormat"] = timeFormats[intSelection]
        // MARK: Changing Boolean
        case .currentCapacity:
            // MARK: Current Capacity Handling
            widgetStruct.config["showPercentage"] = boolSelection
        case .chargeSymbol:
            // MARK: Charge Symbol Fill Handling
            widgetStruct.config["filled"] = boolSelection
        case .weather:
            // MARK: Weather Handling
            widgetStruct.config["useFahrenheit"] = intSelection == 1 ? true : false
            widgetStruct.config["useMetric"] = intSelection2 == 0 ? true : false
            if weatherFormat == "" {
                widgetStruct.config["format"] = nil
            } else {
                widgetStruct.config["format"] = weatherFormat
            }
            if text == "" {
                widgetStruct.config["location"] = nil
            } else {
                widgetStruct.config["location"] = text
            }
        case .lyrics:
            // MARK: Weather Handling
            widgetStruct.config["unsupported"] = boolSelection
            widgetStruct.config["lyricsType"] = (boolSelection && intSelection == 0) ? 1 : intSelection
            widgetStruct.config["bluetoothType"] = intSelection2
            widgetStruct.config["wiredType"] = intSelection3
        default:
            return;
        }
        
        widgetManager.updateWidgetConfig(widgetSet: widgetSet, id: widgetID, newID: widgetStruct)
        widgetID.config = widgetStruct.config
        modified = false
    }
}

struct Location: Identifiable {
    var id: String
    var name: String
    var country: String
    var adm1: String
    var adm2: String
    var lat: String
    var lon: String
}

struct WeatherLocationView: View {
    @State var searchString = ""
    @Binding var locationID: String
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @State var locations: [Location] = []
    
    var body: some View {
        NavigationView{
            VStack {
                HStack {
                    if #available(iOS 15.0, *) {
                        TextField("", text: $searchString)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                search()
                            }
                    } else {
                        TextField("", text: $searchString, onCommit: {
                            search()
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Button(NSLocalizedString("Search", comment:"")) {
                        search()
                    }
                }
                .padding()
                Spacer()
                List(locations) {location in
                    ListCell(item: location)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            locationID = location.id
                            presentationMode.wrappedValue.dismiss()
                        }
                }
                .listStyle(PlainListStyle())
                .padding(.vertical, 0)
                .navigationBarTitle(Text(NSLocalizedString("Get Location ID", comment:"")))
            }
        }
    }

    func search() {
        if !searchString.isEmpty {
            let qweather = QWeather.sharedInstance()
            qweather!.locale = UserDefaults.standard.string(forKey: "dateLocale", forPath: USER_DEFAULTS_PATH) ?? "en"
            qweather!.apiKey = UserDefaults.standard.string(forKey: "weatherApiKey", forPath: USER_DEFAULTS_PATH) ?? ""
            let data = qweather!.fetchLocationID(forName:searchString)
            let json = try! JSONSerialization.jsonObject(with: data!, options: []) as! Dictionary<String, Any>
            if json["code"] as? String == "200" {
                let array = json["location"] as! [Dictionary<String, Any>]
                for item in array {
                    let name = item["name"] as! String
                    let id = item["id"] as! String
                    let country = item["country"] as! String
                    let adm1 = item["adm1"] as! String
                    let adm2 = item["adm2"] as! String
                    let lat = item["lat"] as! String
                    let lon = item["lon"] as! String
                    locations.append(Location(id: id, name: name, country: country, adm1: adm1, adm2: adm2, lat: lat, lon: lon))
                }
            }
        }
    }
}

struct ListCell: View {
    var item: Location
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(item.id),\(item.name)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            HStack {
                Text("\(item.adm1),\(item.adm2)")
                    .lineLimit(1)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}