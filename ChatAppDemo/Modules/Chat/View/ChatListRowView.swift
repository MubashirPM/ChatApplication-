//
//  ChatListRowView.swift
//  ChatAppDemo
//
//  Created by Antigravity on 21/01/26.
//

import SwiftUI

struct ChatListRowView: View {
    let user: UserModel
    
    var body: some View {
        HStack(spacing: 12) {
            // User Avatar
            AsyncImage(url: URL(string: user.photoURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}
