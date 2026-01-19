//
//  CustomizableOTPView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 19/01/26.
//
import SwiftUI

struct CustomizableOTPView: View {
    let length: Int = 6
    @State private var otp: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<length, id: \.self) { index in
                TextField("", text: $otp[index])
                    .frame(width: 50, height: 50)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($focusedIndex, equals: index)
                    .onChange(of: otp[index]) { newValue in
                        if newValue.count > 1 {
                            otp[index] = String(newValue.prefix(1))
                        }
                        if !newValue.isEmpty && index < length - 1 {
                            focusedIndex = index + 1
                        }
                    }
            }
        }
    }
}
#Preview {
    CustomizableOTPView()
}
