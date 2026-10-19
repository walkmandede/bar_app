-- sql/003_seed.sql
-- First user and starter categories. Change the password right away.

select create_app_user('admin', 'Admin', 'change-me-123');

insert into categories (name) values
  ('Whisky'), ('Vodka'), ('Gin'), ('Rum'), ('Tequila'),
  ('Beer'), ('Wine'), ('Soft Drink'), ('Mixer')
on conflict do nothing;

-- Add more users later:
  select create_app_user('staff1', 'Staff One', 'secret123');
-- Reset a password:
--   update app_users set password_hash = crypt('newpass123', gen_salt('bf')) where username = 'staff1';