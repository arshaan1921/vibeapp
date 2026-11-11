import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing auth header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized caller" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: isAdminData } = await supabaseAdmin.rpc("is_high5_admin");
    if (!isAdminData) {
      return new Response(JSON.stringify({ error: "Forbidden: Super admin privileges required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { target_user_id, shadow_ban, reason } = await req.json();

    if (!target_user_id || shadow_ban === undefined || !reason) {
      return new Response(JSON.stringify({ error: "Target user ID, shadow_ban status, and reason are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (target_user_id === "084ed6d9-7354-4301-9c73-d7f4a6a22a19" || target_user_id === user.id) {
      return new Response(JSON.stringify({ error: "Cannot shadow-ban super admin account" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { error: updateError } = await supabaseAdmin
      .from("profiles")
      .update({ is_shadow_banned: shadow_ban })
      .eq("id", target_user_id);

    if (updateError) throw updateError;

    const action = shadow_ban ? "SHADOW_BAN_USER" : "LIFT_SHADOW_BAN";
    await supabaseAdmin.from("admin_audit_logs").insert({
      admin_id: user.id,
      target_id: target_user_id,
      action: action,
      reason: reason,
      metadata: { shadow_ban },
    });

    return new Response(
      JSON.stringify({ success: true, message: `User ${shadow_ban ? 'shadow-banned' : 'un-shadow-banned'} successfully` }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
