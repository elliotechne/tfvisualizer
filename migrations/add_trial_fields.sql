-- Add trial fields to users table
-- Migration: Add 14-day trial support

ALTER TABLE users
ADD COLUMN is_on_trial BOOLEAN DEFAULT FALSE,
ADD COLUMN trial_start_date TIMESTAMP,
ADD COLUMN trial_end_date TIMESTAMP;

-- Update subscription_status comment to include 'trialing'
COMMENT ON COLUMN users.subscription_status IS 'Subscription status: active, inactive, canceled, trialing, past_due, etc.';
