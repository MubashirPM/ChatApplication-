//
//  AutheticationView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 15/01/26.
//

import SwiftUI

struct AutheticationView: View {
    @EnvironmentObject var viewModel: AuthenticationViewModel
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Image(systemName: "message")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.white)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.peach))
                
                Text("Welcome")
                    .font(.largeTitle)
                    .bold()
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                
                Divider()
                
                // Google Sign-In Button
                Button {
                    Task {
                        await viewModel.signInWithGoogle()
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        } else {
                            Image(systemName: "g.circle.fill")
                                .foregroundStyle(.black)
                        }
                        
                        Text(viewModel.isLoading ? "Signing in..." : "Continue With Google")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.peach.opacity(0.3))
                    .cornerRadius(8)
                }
                .disabled(viewModel.isLoading)
                
                // Facebook Sign-In Button
                Button {
                    Task {
                        await viewModel.signInWithFacebook()
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "f.circle.fill")
                                .foregroundStyle(.white)
                        }
                        
                        Text(viewModel.isLoading ? "Signing in..." : "Continue With Facebook")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.26, green: 0.40, blue: 0.70)) // Facebook blue
                    .cornerRadius(8)
                }
                .disabled(viewModel.isLoading)
            }
            .padding()
        }
    }
}

#Preview {
    AutheticationView()
        .environmentObject(AuthenticationViewModel())
}
