//
//  TitleComponent.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 13/01/26.
//

import SwiftUI

struct TitleComponent: View {
    var imageUrl = URL(string: "https://images.unsplash.com/photo-1570158268183-d296b2892211?q=80&w=3087&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D")
    var name = "Mubashir"
    
    var body: some View {
        HStack{
            AsyncImage(url: imageUrl) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50,height: 50)
                    .cornerRadius(50)
            } placeholder: {
                 ProgressView()
            }
            VStack(alignment: .leading) {
                Text(name)
                    .font(.title).bold()
                Text("Online")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity,alignment: .leading)
            
//            Image(systemName: "phone.fill")
//                .foregroundStyle(.gray)
//                .padding(10)
//                .background(.white)
//                .cornerRadius(50)
        }
        .padding()
    }
}

#Preview {
    TitleComponent()
        .background(Color("peach"))
}
