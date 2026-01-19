//
//  CustomizableOTPView.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 19/01/26.
//
import SwiftUI

struct CustomizableOTPView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    let length: Int = 4 // Changed to 4 digits for "1234"
    @State private var otp: [String] = Array(repeating: "", count: 4)
    @FocusState private var focusedIndex: Int?
    @State private var isVerifying = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.white)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.peach))
                    
                    Text("Enter OTP")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Please enter the 4-digit OTP to continue")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Error Message
                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                
                // OTP Input Fields
                HStack(spacing: 16) {
                    ForEach(0..<length, id: \.self) { index in
                        TextField("", text: $otp[index])
                            .frame(width: 60, height: 60)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .font(.title2)
                            .bold()
                            .focused($focusedIndex, equals: index)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusedIndex == index ? Color.peach : Color.gray.opacity(0.3), lineWidth: 2)
                                    )
                            )
                            .onChange(of: otp[index]) { oldValue, newValue in
                                // Only allow numbers
                                let filtered = newValue.filter { $0.isNumber }
                                otp[index] = String(filtered.prefix(1))
                                
                                // Auto-advance to next field
                                if !otp[index].isEmpty && index < length - 1 {
                                    focusedIndex = index + 1
                                }
                                
                                // Auto-verify when all fields are filled
                                if index == length - 1 && !otp[index].isEmpty {
                                    verifyOTP()
                                }
                            }
                    }
                }
                .padding(.horizontal)
                
                // Verify Button
                Button {
                    verifyOTP()
                } label: {
                    HStack {
                        if isVerifying || authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Verify OTP")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isOTPComplete ? Color.peach : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isOTPComplete || isVerifying || authViewModel.isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Focus first field when view appears
            focusedIndex = 0
        }
    }
    
    /// Check if all OTP fields are filled
    private var isOTPComplete: Bool {
        otp.allSatisfy { !$0.isEmpty }
    }
    
    /// Get complete OTP string
    private var otpString: String {
        otp.joined()
    }
    
    /// Verify OTP with AuthenticationViewModel
    private func verifyOTP() {
        guard isOTPComplete else { return }
        
        isVerifying = true
        Task {
            let isValid = await authViewModel.verifyOTP(otpString)
            isVerifying = false
            
            if !isValid {
                // Clear OTP fields on error
                otp = Array(repeating: "", count: length)
                focusedIndex = 0
            }
        }
    }
}

#Preview {
    CustomizableOTPView()
        .environmentObject(AuthenticationViewModel())
}
