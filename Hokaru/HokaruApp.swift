//
//  HokaruApp.swift
//  Hokaru
//
//  Created by Artur Zukauskas on 25.07.2024.
//

import SwiftUI

@main
struct HokaruApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
       
       var body: some Scene {
           WindowGroup {
               ContentView()
                   .environmentObject(delegate) // обязательно
           }
       }
}
