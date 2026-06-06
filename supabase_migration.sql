-- Migration to add Social Links and Contact Info support to profiles table
-- Run this in your Supabase SQL Editor

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS instagram_handle TEXT,
ADD COLUMN IF NOT EXISTS twitter_handle TEXT,
ADD COLUMN IF NOT EXISTS facebook_handle TEXT,
ADD COLUMN IF NOT EXISTS linkedin_handle TEXT,
ADD COLUMN IF NOT EXISTS youtube_handle TEXT,
ADD COLUMN IF NOT EXISTS tiktok_handle TEXT,
ADD COLUMN IF NOT EXISTS snapchat_handle TEXT,
ADD COLUMN IF NOT EXISTS whatsapp_handle TEXT,
ADD COLUMN IF NOT EXISTS telegram_handle TEXT,
ADD COLUMN IF NOT EXISTS show_social_links BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS gmail_address TEXT,
ADD COLUMN IF NOT EXISTS show_gmail BOOLEAN DEFAULT FALSE;

-- Create saved_profiles table
CREATE TABLE IF NOT EXISTS public.saved_profiles (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4 (),
  user_id uuid NULL,
  saved_user_id uuid NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT saved_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT unique_saved_profile UNIQUE (user_id, saved_user_id),
  CONSTRAINT saved_profiles_saved_user_id_fkey FOREIGN KEY (saved_user_id) REFERENCES auth.users (id) ON DELETE CASCADE,
  CONSTRAINT saved_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE
);

