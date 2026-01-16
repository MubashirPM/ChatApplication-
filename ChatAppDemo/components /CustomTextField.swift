//
//  CustomTextField.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 16/01/26.
//

import SwiftUI

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
            }
            
            TextField("", text: $text)
        }
    }
}

#Preview {
    CustomTextField(placeholder: "Enter text here", text: .constant(""))
        .padding()
}
