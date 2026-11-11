import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Helper for safe, paginated, error-checked storage cleanup
async function cleanBucketStorage(
  supabaseAdmin: any,
  bucket: string,
  targetUserId: string
): Promise<{ cleaned: number; error: string | null }> {
  let totalCleaned = 0;
  let hasMore = true;

  while (hasMore) {
    const { data: fileList, error: listErr } = await supabaseAdmin.storage
      .from(bucket)
      .list(targetUserId, { limit: 100, offset: 0, sortBy: { column: "name", order: "asc" } });

    if (listErr) {
      const errMessage = listErr.message || "";
      if (
        errMessage.toLowerCase().includes("not found") ||
        errMessage.toLowerCase().includes("does not exist") ||
        errMessage.toLowerCase().includes("404")
      ) {
        console.log(`[STAGE 7] Storage bucket '${bucket}' not found. Skipping.`);
        return { cleaned: 0, error: null };
      }
      return {
        cleaned: totalCleaned,
        error: `Storage list error in bucket '${bucket}': ${errMessage}`,
      };
    }

    if (!fileList || fileList.length === 0) {
      hasMore = false;
      break;
    }

    const filesToRemove = fileList.map((f: any) => `${targetUserId}/${f.name}`);
    const { error: removeErr } = await supabaseAdmin.storage
      .from(bucket)
      .remove(filesToRemove);

    if (removeErr) {
      return {
        cleaned: totalCleaned,
        error: `Storage remove error in bucket '${bucket}': ${removeErr.message}`,
      };
    }

    totalCleaned += fileList.length;
    if (fileList.length < 100) {
      hasMore = false;
    }
  }

  return { cleaned: totalCleaned, error: null };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("[STAGE 1] Received delete-user request.");
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      console.error("[STAGE 1] Failed: Missing Authorization header.");
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    const token = authHeader.replace("Bearer ", "").trim();

    // 1. Authenticate caller JWT
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      console.error("[STAGE 1] Failed: Invalid session token.", userError);
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid session token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    console.log(`[STAGE 1] Authenticated caller user ID: ${user.id}`);

    // 2. Server-Side Super Admin Role Verification on caller user ID
    console.log(`[STAGE 2] Verifying super_admin role for user ${user.id}...`);
    const { data: adminRole, error: roleError } = await supabaseAdmin
      .from("admin_roles")
      .select("role, is_active")
      .eq("user_id", user.id)
      .eq("role", "super_admin")
      .maybeSingle();

    if (roleError || !adminRole || adminRole.is_active === false) {
      console.error("[STAGE 2] Failed: Caller lacks active super_admin role.", roleError);
      return new Response(
        JSON.stringify({ error: "Forbidden: Active super_admin role required" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    console.log("[STAGE 2] Super admin authorization confirmed.");

    // 3. Parse & Validate Input Body Parameters
    console.log("[STAGE 3] Parsing request body...");
    const body = await req.json().catch(() => ({}));
    const { target_user_id, confirm_username, reason } = body;

    if (!target_user_id || typeof target_user_id !== "string" || target_user_id.trim() === "") {
      console.error("[STAGE 3] Failed: Target user ID missing.");
      return new Response(
        JSON.stringify({ error: "Validation failed: target_user_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!confirm_username || typeof confirm_username !== "string" || confirm_username.trim() === "") {
      console.error("[STAGE 3] Failed: Confirmation username missing.");
      return new Response(
        JSON.stringify({ error: "Validation failed: confirm_username is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!reason || typeof reason !== "string" || reason.trim() === "") {
      console.error("[STAGE 3] Failed: Deletion reason missing.");
      return new Response(
        JSON.stringify({ error: "Validation failed: deletion reason is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const trimmedTargetId = target_user_id.trim();
    const trimmedConfirmUsername = confirm_username.trim();
    const trimmedReason = reason.trim();

    // 4. Protect Official @high5 Account and Calling Admin
    console.log(`[STAGE 4] Checking target protection for ID: ${trimmedTargetId}...`);
    if (trimmedTargetId === "084ed6d9-7354-4301-9c73-d7f4a6a22a19" || trimmedTargetId === user.id) {
      console.error("[STAGE 4] Failed: Attempted to delete protected super admin account.");
      return new Response(
        JSON.stringify({ error: "Forbidden: Cannot delete super administrator account" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: targetAdminRole } = await supabaseAdmin
      .from("admin_roles")
      .select("role")
      .eq("user_id", trimmedTargetId)
      .eq("role", "super_admin")
      .maybeSingle();

    if (targetAdminRole) {
      console.error("[STAGE 4] Failed: Target holds super_admin role.");
      return new Response(
        JSON.stringify({ error: "Forbidden: Super administrator accounts cannot be deleted" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Fetch Target Profile or Operation Record (Idempotent Retry Support)
    console.log(`[STAGE 5] Fetching profile for target ${trimmedTargetId}...`);
    let confirmedUsername = trimmedConfirmUsername;
    const { data: targetProfile, error: profileFetchError } = await supabaseAdmin
      .from("profiles")
      .select("username")
      .eq("id", trimmedTargetId)
      .maybeSingle();

    if (profileFetchError) {
      console.error("[STAGE 5] Error fetching profile:", profileFetchError);
      return new Response(
        JSON.stringify({ error: `Error fetching profile: ${profileFetchError.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (targetProfile) {
      confirmedUsername = (targetProfile.username ?? "").trim();
      if (trimmedConfirmUsername !== confirmedUsername) {
        console.error(`[STAGE 5] Failed: Username mismatch '${trimmedConfirmUsername}' vs '${confirmedUsername}'.`);
        return new Response(
          JSON.stringify({
            error: `Confirmation username '${trimmedConfirmUsername}' does not match target profile '${confirmedUsername}'`,
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } else {
      // Retry branch: Verify prior authorized deletion operation record
      console.log("[STAGE 5] Profile not found. Checking prior deletion operation record...");
      const { data: priorOp } = await supabaseAdmin
        .from("admin_deletion_operations")
        .select("confirmed_username, status")
        .eq("target_user_id", trimmedTargetId)
        .maybeSingle();

      if (!priorOp) {
        console.error("[STAGE 5] Failed: Target profile not found and no prior operation record exists.");
        return new Response(
          JSON.stringify({
            error: "Target profile not found and no prior deletion operation was recorded for this account.",
          }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (trimmedConfirmUsername !== priorOp.confirmed_username.trim()) {
        console.error("[STAGE 5] Failed: Retry username mismatch.");
        return new Response(
          JSON.stringify({
            error: `Confirmation username '${trimmedConfirmUsername}' does not match recorded operation '${priorOp.confirmed_username}'`,
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      confirmedUsername = priorOp.confirmed_username;
    }

    // 6. Record Deletion Operation Tracking & Audit Log
    console.log("[STAGE 6] Recording deletion operation tracking & audit log...");
    const { error: opUpsertError } = await supabaseAdmin
      .from("admin_deletion_operations")
      .upsert(
        {
          target_user_id: trimmedTargetId,
          confirmed_username: confirmedUsername,
          admin_id: user.id,
          reason: trimmedReason,
          status: "PENDING",
          updated_at: new Date().toISOString(),
        },
        { onConflict: "target_user_id" }
      );

    if (opUpsertError) {
      console.warn("[STAGE 6] admin_deletion_operations notice:", opUpsertError.message);
    }

    const { error: auditError } = await supabaseAdmin.from("admin_audit_logs").insert({
      admin_id: user.id,
      target_type: "USER",
      target_id: trimmedTargetId,
      action: "DELETE_USER",
      reason: trimmedReason,
      metadata: { target_username: confirmedUsername },
    });

    if (auditError) {
      console.warn("[STAGE 6] admin_audit_logs notice:", auditError.message);
    }

    // 7. Paginated Storage Cleanup across 5 verified buckets
    console.log("[STAGE 7] Cleaning storage buckets...");
    const storageBuckets = ["avatars", "memes", "question-images", "report_screenshots", "snaps"];
    for (const bucket of storageBuckets) {
      const storageResult = await cleanBucketStorage(supabaseAdmin, bucket, trimmedTargetId);
      if (storageResult.error) {
        console.error(`[STAGE 7] Storage cleanup error in bucket ${bucket}:`, storageResult.error);
        return new Response(
          JSON.stringify({ error: `Storage cleanup failed in bucket '${bucket}': ${storageResult.error}` }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 8. Execute Database Data Cleanup
    console.log(`[STAGE 8] Executing database data cleanup for target ${trimmedTargetId}...`);
    const { error: rpcError } = await supabaseAdmin.rpc("admin_delete_user_data", {
      target_user_id: trimmedTargetId,
    });

    if (rpcError) {
      console.warn(`[STAGE 8] RPC admin_delete_user_data notice: ${rpcError.message}. Executing service-role table cleanup...`);

      // Service-role direct table cleanup
      await supabaseAdmin.from("blocks").delete().or(`blocker_id.eq.${trimmedTargetId},blocked_id.eq.${trimmedTargetId}`);
      await supabaseAdmin.from("notifications").delete().eq("user_id", trimmedTargetId);
      await supabaseAdmin.from("reports").delete().or(`user_id.eq.${trimmedTargetId},reported_user_id.eq.${trimmedTargetId}`);
      await supabaseAdmin.from("answers").delete().eq("user_id", trimmedTargetId);
      await supabaseAdmin.from("snap_recipients").delete().eq("recipient_id", trimmedTargetId);
      await supabaseAdmin.from("snaps").delete().eq("sender_id", trimmedTargetId);
      await supabaseAdmin.from("saved_profiles").delete().or(`user_id.eq.${trimmedTargetId},saved_user_id.eq.${trimmedTargetId}`);
      await supabaseAdmin.from("friend_requests").delete().or(`sender_id.eq.${trimmedTargetId},receiver_id.eq.${trimmedTargetId}`);
      await supabaseAdmin.from("friends").delete().or(`user1_id.eq.${trimmedTargetId},user2_id.eq.${trimmedTargetId}`);

      const { error: profileDelError } = await supabaseAdmin.from("profiles").delete().eq("id", trimmedTargetId);
      if (profileDelError) {
        console.error("[STAGE 8] Profile row delete error:", profileDelError);
        return new Response(
          JSON.stringify({ error: `Database cleanup failed: ${profileDelError.message}` }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 9. Delete Supabase Auth User
    console.log(`[STAGE 9] Removing Auth user account ${trimmedTargetId}...`);
    const { error: authDeleteError } = await supabaseAdmin.auth.admin.deleteUser(trimmedTargetId);

    if (authDeleteError) {
      console.error("[STAGE 9] Auth deleteUser error:", authDeleteError);
      return new Response(
        JSON.stringify({
          error: `Database cleaned, but Auth account removal failed: ${authDeleteError.message}`,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 10. Mark Completion & Return Success
    console.log(`[STAGE 10] Deletion of account @${confirmedUsername} completed successfully!`);
    await supabaseAdmin
      .from("admin_deletion_operations")
      .update({
        status: "COMPLETED",
        updated_at: new Date().toISOString(),
      })
      .eq("target_user_id", trimmedTargetId);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Account @${confirmedUsername} permanently deleted successfully.`,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("delete-user unhandled exception:", err);
    return new Response(
      JSON.stringify({ error: err.message ?? "Unhandled server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
