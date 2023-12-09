//
//  WidgetCustomizationView.swift
//
//
//  Created by lemin on 10/13/23.
//

import Foundation
import SwiftUI

// MARK: Widget Customization View
struct WidgetCustomizationView: View {
    @StateObject var widgetManager: WidgetManager = .init()
    
    var body: some View {
        NavigationView {
            VStack {
                // List of Widget Sets
                List {
                    ForEach($widgetManager.widgetSets) { widgetSet in
                        NavigationLink(destination: EditWidgetSetView(widgetManager: widgetManager, widgetSet: widgetSet.wrappedValue)) {
                            Text(widgetSet.title.wrappedValue)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { i in
                            UIApplication.shared.confirmAlert(title: "Delete \(widgetManager.widgetSets[i].title)", body: "Are you sure you want to delete the widget set \"\(widgetManager.widgetSets[i].title)\"?", onOK: {
                                widgetManager.removeWidgetSet(widgetSet: widgetManager.widgetSets[i])
                            }, noCancel: false)
                        }
                    }
                }
                .toolbar {
                    HStack {
                        // create a new widget set
                        Button(action: {
                            UIApplication.shared.inputAlert(title: "Enter Name", body: "Choose a name for the widget set.", confirmTitle: "Confirm", placeholder: "Name", onOK: { title in
                                // make selection for anchor
                                UIApplication.shared.optionsAlert(title: "Choose Side", body: "Choose a side for the widget set to anchor to. This can be changed later.", options: ["Left", "Center", "Right"]) { anchorSide in
                                    var anchor: Int
                                    switch (anchorSide) {
                                    case "Left":
                                        anchor = 0
                                        break
                                    case "Center":
                                        anchor = 1
                                        break
                                    case "Right":
                                        anchor = 2
                                        break
                                    default:
                                        anchor = 0
                                        break
                                    }
                                    widgetManager.createWidgetSet(title: title == "" ? "Untitled" : title, anchor: anchor)
                                }
                            }, noCancel: false)
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .navigationTitle("Customize")
        }
    }
}

// MARK: Widget Modify View
//struct WidgetModifyView: View {
//    @StateObject var widgetManager: WidgetManager
//    @Binding var widgetIndex: Int
//    
//    var dismiss: () -> Void
//    
//    var body: some View {
//        return VStack {
//            if widgetIndex >= 0 && widgetIndex < widgetManager.widgetStructs.count {
//                // Widget Preferences
//                WidgetPreferencesView(widgetStruct: $widgetManager.widgetStructs[widgetIndex])
//                VStack {
//                    Spacer()
//                    // Save Button
//                    Button("Save") {
//                        widgetManager.saveWidgetStructs()
//                        dismiss()
//                    }
//                    .buttonStyle(TintedButton(color: .blue, fullWidth: true))
//                    .padding(.horizontal, 7)
//                    // Delete Button
//                    Button("Delete") {
//                        widgetManager.removeWidget(id: widgetIndex)
//                        dismiss()
//                    }
//                    .buttonStyle(TintedButton(color: .red, fullWidth: true))
//                    .padding(.horizontal, 7)
//                }
//                .padding(10)
//            }
//        }
//    }
//}

// MARK: Widget Add View
struct WidgetAddView: View {
    @StateObject var widgetManager: WidgetManager
    @State var widgetSet: WidgetSetStruct
    @Binding var isOpen: Bool
    
    var onChoice: (WidgetIDStruct) -> ()
    
    var body: some View {
        List {
            ForEach(WidgetModule.allCases, id: \.self) { id in
                Button(action: {
                    let newWidget = widgetManager.addWidget(widgetSet: widgetSet, module: id)
                    isOpen = false
                    onChoice(newWidget)
                }) {
                    WidgetChoiceView(widgetName: WidgetDetails.getWidgetName(id), exampleText: WidgetDetails.getWidgetExample(id))
                }
            }
        }
    }
}

// MARK: Widget Choice View
struct WidgetChoiceView: View {
    var widgetName: String
    var exampleText: String

    var body: some View {
        HStack {
            ZStack {
                Image(uiImage: UIImage(named: "wallpaper")!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.5)
                    .frame(width: 125, height: 50)
                    .cornerRadius(12)
                    .clipped()
                ZStack {
                    Text(exampleText)
                        .padding(.vertical, 5)
                        .foregroundColor(.white)
                }
                .frame(width: 125, height: 50)
            }
            .padding(.trailing, 5)
            Text(widgetName)
                .foregroundColor(.primary)
                .bold()
        }
    }
}

//struct WidgetCustomizationView_Previews: PreviewProvider {
//    static var previews: some View {
//        WidgetCustomizationView()
//    }
//}
