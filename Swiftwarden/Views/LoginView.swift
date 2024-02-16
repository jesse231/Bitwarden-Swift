import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @Binding var loginSuccess: Bool
    @State var email: String = (ProcessInfo.processInfo.environment["Username"] ?? "")
    @State var password: String = (ProcessInfo.processInfo.environment["Password"] ?? "")
    @State var server: String = (ProcessInfo.processInfo.environment["Server"] ?? "")

    @State var storedEmail: String? = UserDefaults.standard.string(forKey: "email")
    @State var storedServer: String? = UserDefaults.standard.string(forKey: "server")

    @State var attempt = false
    @State var errorMessage = "Your username or password is incorrect or your account does not exist."
    @State var isLoading = false
    let context = LAContext()

    @EnvironmentObject var account: Account
    
    func unlock() {
        Task {
            do {
                isLoading = true
                try await loginSuccess = login(storedEmail: storedEmail, storedServer: storedServer)
                context.invalidate()
            } catch let error as AuthError {
                attempt = true
                errorMessage = error.message
                isLoading = false
            } catch {
                print(error)
                attempt = true
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func validateAndLogin(storedEmail: String? = nil, storedPassword: String? = nil, storedServer: String? = nil) {
        Task {
            attempt = false
            isLoading = true
            do {
                let checkEmail = try Regex("[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
                guard email != "" && password != "" else {
                    errorMessage = "Please enter a valid email address and password."
                    attempt = true
                    isLoading = false
                    return
                }
                
                guard email.contains(checkEmail) else {
                    errorMessage = "Please enter a valid email address."
                    isLoading = false
                    attempt = true
                    return
                }
                
                try await loginSuccess = login()
            } catch let error as AuthError {
                print(error)
                attempt = true
                errorMessage = error.message
                isLoading = false
            } catch {
                attempt = true
                print(error)
                errorMessage = error.localizedDescription
                isLoading = false
            }
            isLoading = false
        }
    }
    
    
    func login (storedEmail: String? = nil, storedPassword: String? = nil, storedServer: String? = nil) async throws -> Bool {

        let username = storedEmail ?? email
        let pass = storedPassword ?? password
        var serv = storedServer ?? server

        let base = URL(string: serv)
        if let base, base.host == nil {
            serv = "https://" + serv
        }

        let api = try await Api(username: username, password: pass, base: URL(string: serv), identityPath: nil, apiPath: nil, iconPath: nil)

        let sync = try await api.sync()
        let privateKey = sync.profile?.privateKey
        var privateKeyDec = try Encryption.decrypt(str: privateKey!).toBase64()

        // Turn the private key into PEM formatted key
        privateKeyDec = "-----BEGIN PRIVATE KEY-----\n" + privateKeyDec + "\n-----END PRIVATE KEY-----"

        let pk = try SwKeyConvert.PrivateKey.pemToPKCS1DER(privateKeyDec)
        Encryption.privateKey = SecKeyCreateWithData(pk as CFData, [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPrivate] as CFDictionary, nil)

        account.user = User(sync: sync, api: api, email: username)

        if storedPassword == nil {
            KeyChain.saveUser(account: email, password: password)
        }

        if storedEmail == nil {
            let defaults = UserDefaults.standard
            defaults.set(email, forKey: "email")
        }
        if storedServer == nil {
            let defaults = UserDefaults.standard
            defaults.set(server, forKey: "server")
        }

        return true
    }

    var body: some View {
        if let storedEmail, let storedServer {
            let storedPassword = KeyChain.getUser(account: storedEmail)
            VStack {
                HStack {
                    GroupBox {
                        SecureField("Master Password", text: $password)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                unlock()
                            }
                    }
                    .textContentType(.oneTimeCode) // Hacky solution to disable password autofill prompt
                    .accessibilityIdentifier("Master Password")
                    .padding()
                    Button {
                        authenticate(context: context) { _ in
                            Task {
                                do {
                                    isLoading = true
                                    try await loginSuccess = self.login(storedEmail: storedEmail, storedPassword: storedPassword, storedServer: storedServer)
                                    loginSuccess = true
                                } catch let error as AuthError {
                                    attempt = true
                                    errorMessage = error.message
                                    isLoading = false
                                } catch {
                                    attempt = true
                                    errorMessage = error.localizedDescription
                                    isLoading = false
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "touchid")
                    }
                }
                if attempt == true {
                    Text(errorMessage)
                        .fixedSize(horizontal: false, vertical: false)
                        .containerShape(Rectangle())
                        .padding(20)
                        .foregroundColor(.primary)
                        .background(.pink.opacity(0.4))
                        .cornerRadius(5)
                }
                HStack {
                    Button(action: {
                        UserDefaults.standard.set(nil, forKey: "email")
                        UserDefaults.standard.set(nil, forKey: "server")
                        KeyChain.deleteUser(account: storedEmail)
                        self.storedEmail = nil
                        self.storedServer = nil
                        self.attempt = false
                        self.password = ""
                    }) {
                        Text("Log out")
                            .padding(22)
                            .frame(width: 111, height: 22)
                            .background(Color.gray)
                            .foregroundColor(Color.white)
                    }
                    .disabled(isLoading)
                    .buttonStyle(.plain)
                    .padding(22)
                    .frame(width: 122, height: 25)
                    .background(Color.gray)
                    .foregroundColor(Color.white)
                    .cornerRadius(5)
                    Button {
                        unlock()
                    } label: {
                        HStack {
                            if (isLoading) {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Unlock")
                                    .background(Color.blue)
                                    .foregroundColor(Color.white)
                            }
                        }
                        .frame(width: 111, height: 22)
                        .padding(22)

                    }
                    .buttonStyle(.plain)
                    .padding(22)
                    .frame(width: 122, height: 25)
                    .background(Color.blue)
                    .foregroundColor(Color.white)
                    .cornerRadius(5)
                }.padding().frame(maxWidth: 300)
            }.padding().frame(maxWidth: 300)
        } else {
            VStack {
                Text("Log in").font(.title).bold()
                Divider().padding(.bottom, 5)
                GroupBox {
                    TextField("Email Address", text: $email)
                        .onSubmit {
                            validateAndLogin()
                        }
                        .textFieldStyle(.plain)
                        .padding(4)
                }.padding(4)
                GroupBox {
                    SecureField("Password", text: $password)
                        .onSubmit {
                            validateAndLogin()
                        }
                        .textFieldStyle(.plain)
                        .padding(4)
                        .disableAutocorrection(true)
                        .textContentType(.oneTimeCode) // Hacky solution to disable password autofill prompt
                }.padding(4)
                Section(header: Text("Server URL")) {
                    GroupBox {
                        TextField("https://bitwarden.com/", text: $server)
                            .textFieldStyle(.plain)
                            .padding(4)
                            .onSubmit {
                                validateAndLogin()
                            }
                    }.padding(4)
                }
                if attempt == true {
                    Text(errorMessage)
                        .fixedSize(horizontal: false, vertical: false)
                        .containerShape(Rectangle())
                        .padding(20)
                        .foregroundColor(.primary)
                        .background(.pink.opacity(0.4))
                        .cornerRadius(5)
                }
                Button {
                        validateAndLogin()
                } label: {
                    if isLoading {
                        ProgressView() // Show loading animation
                            .controlSize(.small)
                    } else {
                        Text("Log In")
                            .padding(22)
                            .frame(width: 111, height: 22)
                            .background(Color.blue)
                            .foregroundColor(Color.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(22)
                .frame(width: 111, height: 22)
                .background(Color.blue)
                .foregroundColor(Color.white)
                .cornerRadius(5)
            }.padding()
                .frame(maxWidth: 300)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(loginSuccess: .constant(false))
            .environmentObject(Account())
    }

}
