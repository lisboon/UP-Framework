SET @account_id = '00000000-0000-0000-0000-000000000011';
SET @character_id = '00000000-0000-0000-0000-000000000012';

INSERT INTO up_core_accounts (id, status) VALUES (@account_id, 'active');
INSERT INTO up_core_characters
    (id, account_id, passport, first_name, last_name, birth_date, metadata)
VALUES
    (@character_id, @account_id, 4242, 'Maria', 'Souza', '1998-06-15', JSON_OBJECT());
