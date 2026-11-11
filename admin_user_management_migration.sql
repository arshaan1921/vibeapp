-- ====================================================================
-- HIGH5 ADMIN MODE — USER MANAGEMENT & AUDIT LOGGING MIGRATION
-- Run this in your Supabase SQL Editor
-- ====================================================================

-- 1. Ensure Moderation columns exist in public.profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS banned_until TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS is_shadow_banned BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS strike_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS report_count INT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_profiles_is_banned ON public.profiles(is_banned);
CREATE INDEX IF NOT EXISTS idx_profiles_is_shadow_banned ON public.profiles(is_shadow_banned);

-- 2. Ensure public.admin_roles table & is_active column exist
CREATE TABLE IF NOT EXISTS public.admin_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_admin_user_role UNIQUE (user_id, role)
);

ALTER TABLE public.admin_roles
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 3. Authorization Helper Function (Must be defined BEFORE RLS policies referencing it)
CREATE OR REPLACE FUNCTION public.is_high5_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.admin_roles
        WHERE user_id = auth.uid()
          AND role = 'super_admin'
          AND (is_active IS NULL OR is_active = TRUE)
    );
END;
$$;

-- 4. Ensure public.admin_audit_logs table matches schema & RLS
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    target_type TEXT DEFAULT 'USER',
    target_id TEXT NULL,
    action TEXT NOT NULL,
    reason TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Super admins can view audit logs" ON public.admin_audit_logs;
CREATE POLICY "Super admins can view audit logs"
    ON public.admin_audit_logs FOR SELECT
    USING (public.is_high5_admin());

DROP POLICY IF EXISTS "Super admins can insert audit logs" ON public.admin_audit_logs;
CREATE POLICY "Super admins can insert audit logs"
    ON public.admin_audit_logs FOR INSERT
    WITH CHECK (public.is_high5_admin());

-- 5. Server-Side Account Deletion Tracking Table for Idempotent Retries
CREATE TABLE IF NOT EXISTS public.admin_deletion_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_user_id UUID NOT NULL UNIQUE, -- Unique constraint for target_user_id upsert
    confirmed_username TEXT NOT NULL,
    admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'AUDITED', 'DATA_CLEANED', 'COMPLETED', 'FAILED'
    error_message TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.admin_deletion_operations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Super admins can manage deletion operations" ON public.admin_deletion_operations;
CREATE POLICY "Super admins can manage deletion operations"
    ON public.admin_deletion_operations FOR ALL
    USING (public.is_high5_admin());

-- 6. Secure RPC Function: admin_suspend_user
CREATE OR REPLACE FUNCTION public.admin_suspend_user(
    target_user_id UUID,
    reason TEXT,
    duration_days INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id UUID;
    v_banned_until TIMESTAMPTZ;
BEGIN
    v_admin_id := auth.uid();

    IF NOT public.is_high5_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Super admin access required.';
    END IF;

    IF target_user_id = '084ed6d9-7354-4301-9c73-d7f4a6a22a19'::UUID OR target_user_id = v_admin_id THEN
        RAISE EXCEPTION 'Forbidden: Super administrator account cannot be suspended.';
    END IF;

    IF duration_days IS NOT NULL AND duration_days > 0 THEN
        v_banned_until := NOW() + (duration_days || ' days')::INTERVAL;
    ELSE
        v_banned_until := NULL;
    END IF;

    UPDATE public.profiles
    SET is_banned = TRUE,
        banned_until = v_banned_until
    WHERE id = target_user_id;

    INSERT INTO public.admin_audit_logs (admin_id, target_type, target_id, action, reason, metadata)
    VALUES (
        v_admin_id,
        'USER',
        target_user_id::TEXT,
        'SUSPEND_USER',
        reason,
        jsonb_build_object(
            'duration_days', duration_days,
            'banned_until', v_banned_until
        )
    );

    RETURN jsonb_build_object('success', true, 'message', 'User suspended successfully');
END;
$$;

-- 7. Secure RPC Function: admin_restore_user
CREATE OR REPLACE FUNCTION public.admin_restore_user(
    target_user_id UUID,
    reason TEXT DEFAULT 'Account restored by administrator'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    v_admin_id := auth.uid();

    IF NOT public.is_high5_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Super admin access required.';
    END IF;

    UPDATE public.profiles
    SET is_banned = FALSE,
        banned_until = NULL
    WHERE id = target_user_id;

    INSERT INTO public.admin_audit_logs (admin_id, target_type, target_id, action, reason, metadata)
    VALUES (v_admin_id, 'USER', target_user_id::TEXT, 'RESTORE_USER', reason, '{}'::jsonb);

    RETURN jsonb_build_object('success', true, 'message', 'User account restored successfully');
END;
$$;

-- 8. Secure RPC Function: admin_shadow_ban_user
CREATE OR REPLACE FUNCTION public.admin_shadow_ban_user(
    target_user_id UUID,
    shadow_ban BOOLEAN,
    reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id UUID;
    v_action TEXT;
BEGIN
    v_admin_id := auth.uid();

    IF NOT public.is_high5_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Super admin access required.';
    END IF;

    IF target_user_id = '084ed6d9-7354-4301-9c73-d7f4a6a22a19'::UUID OR target_user_id = v_admin_id THEN
        RAISE EXCEPTION 'Forbidden: Super administrator account cannot be shadow-banned.';
    END IF;

    v_action := CASE WHEN shadow_ban THEN 'SHADOW_BAN_USER' ELSE 'LIFT_SHADOW_BAN' END;

    UPDATE public.profiles
    SET is_shadow_banned = shadow_ban
    WHERE id = target_user_id;

    INSERT INTO public.admin_audit_logs (admin_id, target_type, target_id, action, reason, metadata)
    VALUES (v_admin_id, 'USER', target_user_id::TEXT, v_action, reason, jsonb_build_object('is_shadow_banned', shadow_ban));

    RETURN jsonb_build_object('success', true, 'message', 'Shadow ban status updated successfully');
END;
$$;

-- 9. Fail-Closed Data Cleanup Function: admin_delete_user_data (Only executable by service_role)
CREATE OR REPLACE FUNCTION public.admin_delete_user_data(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Fail closed: strictly require service_role
    IF COALESCE(auth.role(), current_setting('role', true)) != 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized: Only service_role can execute admin_delete_user_data.';
    END IF;

    IF target_user_id = '084ed6d9-7354-4301-9c73-d7f4a6a22a19'::UUID THEN
        RAISE EXCEPTION 'Forbidden: Cannot delete official super administrator account.';
    END IF;

    -- Delete non-cascading FK relationships (blocks, notifications)
    DELETE FROM public.blocks WHERE blocker_id = target_user_id OR blocked_id = target_user_id;
    DELETE FROM public.notifications WHERE user_id = target_user_id;

    -- Delete user content per delete_all policy
    DELETE FROM public.reports WHERE user_id = target_user_id OR reported_user_id = target_user_id;
    DELETE FROM public.answers WHERE user_id = target_user_id;
    DELETE FROM public.snap_recipients WHERE recipient_id = target_user_id;
    DELETE FROM public.snaps WHERE sender_id = target_user_id;
    DELETE FROM public.saved_profiles WHERE user_id = target_user_id OR saved_user_id = target_user_id;
    DELETE FROM public.friend_requests WHERE sender_id = target_user_id OR receiver_id = target_user_id;
    DELETE FROM public.friends WHERE user1_id = target_user_id OR user2_id = target_user_id;

    -- Delete profile
    DELETE FROM public.profiles WHERE id = target_user_id;
END;
$$;

-- 10. Explicit Permissions Setup: Revoke PUBLIC, anon, authenticated execution from admin_delete_user_data
REVOKE ALL ON FUNCTION public.admin_delete_user_data(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_user_data(UUID) TO service_role;

GRANT EXECUTE ON FUNCTION public.is_high5_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_suspend_user(UUID, TEXT, INT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_restore_user(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_shadow_ban_user(UUID, BOOLEAN, TEXT) TO authenticated, service_role;
