import Foundation
import Supabase

let supabase = SupabaseClient(
//    supabaseURL: URL(string: "http://127.0.0.1:54321")!,
//    supabaseKey: "sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz",
    supabaseURL: URL(string: "https://vskjfzcykzqieztpputw.supabase.co")!,
    supabaseKey: "sb_publishable_FmmDe_Ttr-9Dcr_tV2vNmw_2CbyJz6p",
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            autoRefreshToken: true,
            emitLocalSessionAsInitialSession: true
        )
    )
)
