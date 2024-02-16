//
//  ItemView+Editing.swift
//  Swiftwarden
//
//  Created by Jesse Seeligsohn on 2023-05-14.
//

import SwiftUI
import NukeUI

extension ItemView {
    struct SecureNoteEditing: View {
        @Binding var cipher: Cipher?
        @Binding var editing: Bool
        var account: Account
        
        @State private var name: String
        
        @State private var folder: String?
        @State private var favorite: Bool
        @State private var reprompt: RepromptState
        
        @State private var notes = ""
        
        @State private var fields: [CustomField] = []
        
        init(cipher: Binding<Cipher?>, editing: Binding<Bool>, account: Account) {
            _cipher = cipher
            _editing = editing
            self.account = account
            
            _name = State(initialValue: cipher.wrappedValue?.name ?? "")
            _folder = State(initialValue: cipher.wrappedValue?.folderID ?? nil as String?)
            _favorite = State(initialValue: cipher.wrappedValue?.favorite ?? false)
            reprompt = RepromptState.fromInt(cipher.wrappedValue?.reprompt ?? 0)
            _notes = State(initialValue: cipher.wrappedValue?.notes ?? "")
            _fields = State(initialValue: cipher.wrappedValue?.fields ?? [])
        }
        
        
        
        func save() async throws {
                let index = account.user.getIndex(of: cipher!)
                
                var modCipher = cipher!
                modCipher.name = name
                
                modCipher.notes = notes
                modCipher.fields = fields
                
                
                modCipher.favorite = favorite
                modCipher.reprompt = reprompt.toInt()
                modCipher.folderID = folder
                
                try await account.user.updateCipher(cipher: modCipher, index: index)
                            
                cipher = modCipher
        }
        
        var body: some View {
            Group {
                VStack {
                    HStack {
                        Icon(itemType: .secureNote)
                        VStack {
                            TextField("No Name", text: $name)
                                .font(.system(size: 15))
                                .fontWeight(.semibold)
                                .textFieldStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.bottom, -5)
                            Text(verbatim: "Secure Note")
                                .font(.system(size: 10))
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        FavoriteEditingButton(favorite: $favorite)
                    }
                        .padding([.leading,.trailing], 5)
                    Divider()
                    ScrollView {
                        VStack {
                            Group {
                                NotesEditView(Binding<String>(
                                    get: {
                                        return notes
                                    },
                                    set: { newValue in
                                        notes = newValue
                                    }
                                ))
                                CustomFieldsEdit(fields: $fields)
                            }
                            Divider()
                            CipherOptions(folder: $folder, favorite: $favorite, reprompt: $reprompt)
                                .environmentObject(account)
                                .padding(.bottom, 24)
                        }
                        .padding(.trailing)
                        .padding(.leading)
                    }
                    .frame(maxWidth: .infinity)
                    .toolbar {
                        EditingToolbarOptions(cipher: $cipher, editing: $editing, account: account, save: save)
                    }
                }
            }
        }
    }
}
struct ItemView_SecureNoteEditing_Previews: PreviewProvider {
    static var previews: some View {
        ItemView.SecureNoteEditing(cipher: .constant(nil), editing: .constant(true), account: .init())
    }
}
