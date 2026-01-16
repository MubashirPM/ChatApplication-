//
//  AutheticationView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 15/01/26.
//

import SwiftUI

struct AutheticationView: View {
    @State var mail = ""
    var body: some View {
        ZStack {
            VStack {
                Image(systemName: "message")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64,height: 64)
                    .foregroundStyle(.white)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.peach))
                Text("Welcome")
                    .font(.largeTitle)
                    .bold()
                TextField("Enter your mail ", text: $mail)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    debugPrint("Continue Button Tapped")
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.gray)
                        .background(Color.peach)
                }
                Divider()
                
                VStack{
                    Button {
                        
                    } label: {
                         HStack {
                             Image(systemName: "g.circle")
                                 .foregroundStyle(.black)
                                 
                             Text("Continue With Google")
                                 .font(.subheadline)
                                 .foregroundStyle(.gray)
                         }
                    }
                }
            }
            .padding()
            
            
        }
    }
}

#Preview {
    AutheticationView()
}
