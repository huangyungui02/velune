import Foundation
import Supabase

let supabaseURL = URL(string: "http://127.0.0.1:54321")!
let supabaseKey = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
//let supabaseURL = URL(string: "https://vskjfzcykzqieztpputw.supabase.co")!
//let supabaseKey = "sb_publishable_FmmDe_Ttr-9Dcr_tV2vNmw_2CbyJz6p"

let supabase = SupabaseClient(
    supabaseURL: supabaseURL,
    supabaseKey: supabaseKey,
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            autoRefreshToken: true,
            emitLocalSessionAsInitialSession: true
        )
    )
)
