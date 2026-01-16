//
//  ProfileView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 15/01/26.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        ZStack {
            ScrollView(){
                VStack(alignment: .leading) {
                    Text("Profile")
                    HStack {
                       Image("Image")
                            .resizable()
                            .frame(width: 50,height: 50)
                            .clipShape(.circle)
                        VStack {
                            Text("Mubashir")
                                .font(.headline)
                            Text("Pm")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
