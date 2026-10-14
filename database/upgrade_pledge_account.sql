-- Optional upgrade: remember which logged-in account made each donation pledge,
-- so the admin dashboard can show who donated even when the donor typed no email.
-- Run once in phpMyAdmin: select the clean_energy database > SQL tab > paste > Go.
-- (XAMPP uses MariaDB, which understands IF NOT EXISTS, so running it twice is safe.)
-- The site works without this; it just won't show the Account column for donations.
USE clean_energy;
ALTER TABLE pledges ADD COLUMN IF NOT EXISTS account_email VARCHAR(190) NULL;
