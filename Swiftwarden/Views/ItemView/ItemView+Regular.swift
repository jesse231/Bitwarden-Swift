import Foundation
import NukeUI
import SwiftUI

extension ItemView {
    func delete() async throws{
        if let cipher{
            do {
                try await account.user.deleteCipher(cipher:cipher, api: account.api)
                account.selectedCipher = Cipher()
                self.cipher = nil
            } catch {
                print(error)
            }
        }
    }
    func deletePermanently() async throws{
        if let cipher{
            do {
                try await account.user.deleteCipherPermanently(cipher:cipher, api: account.api)
                account.selectedCipher = Cipher()
                self.cipher = nil
            } catch {
                print(error)
            }
        }
    }
    
    func extractHost(uri: Uris) -> String {
        if let noScheme = uri.uri.split(separator:"//").dropFirst().first, let host = noScheme.split(separator:"/").first {
                return String(host)
            } else {
                return uri.uri
        }
    }
    
    var RegularView: some View {
        return AnyView (
            Group{
                    HStack{
                        if cipher?.deletedDate == nil {
                        Button {
                            Task {
                                try await delete()
                            }
                        } label: {
                            Text("Delete")
                        }
                        Spacer()
                        Button {
                            editing = true
                        } label: {
                            Text("Edit")
                        }
                        } else {
                            Spacer()
                            Button {
                                Task {
                                    try await deletePermanently()
                                }
                            } label: {
                                Text("Delete Permanently")
                            }
                        }
                }
                    
                ScrollView{
                    VStack{
                        HStack{
                            Icon(hostname: hostname, account: account)
                            VStack{
                                Text(name)
                                    .font(.system(size: 15))
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                Text(verbatim: "Login")
                                    .font(.system(size: 10))
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                
                            }
                            Button (action: {
                                favourite = !favourite
                                
                                let index = account.user.getCiphers(deleted: true).firstIndex(of: account.selectedCipher)
                                
                                
                                account.selectedCipher.favorite = favourite
                                Task {
                                    do{
                                        try await account.user.updateCipher(cipher: account.selectedCipher, api: account.api, index: index)
                                    } catch {
                                        print(error)
                                    }
                                    
                                }
                                
                            } ){
                                if (favourite) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                } else {
                                    Image(systemName: "star")
                                }
                            }.buttonStyle(.plain)
                            
                            
                        }
                        Divider()
                        if cipher?.login?.username != nil {
                            Field(
                                title: "Username",
                                content: username,
                                buttons: {
                                    Copy(content: username)
                                })
                        }
                        if cipher?.login?.password != nil {
                            Field(
                                title: "Password",
                                content: (showPassword ? password : String(repeating: "•", count: password.count)),
                                buttons: {
                                    Hide(toggle: $showPassword)
                                    Copy(content: password)
                                })
                        }
                        if let uris = cipher?.login?.uris{
                            ForEach(uris, id: \.self.id) { uri in
                                if (uri.uri != "") {
                                    Field(
                                        title: "Website",
                                        content: extractHost(uri: uri),
                                        buttons: {
                                            Open(link: uri.uri)
                                            Copy(content: uri.uri)
                                        })
                                }
                            }
                        }
                        
                    }
                    Spacer()
                }
                
            }
            )
            
        }
}
