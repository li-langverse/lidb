-- WP-020 stub seed: DE tax categories (expanded in WP-210 to 80–120 rows)
-- Apply after 007_finance_org.sql

INSERT INTO de_tax_category (code, name, tax_domains, deductibility_pct, vat_rate, ustva_line)
VALUES
  ('EXP_OFFICE', 'Bürobedarf', ARRAY['freelance', 'company'], 100, 19, 'KZ66'),
  ('EXP_SOFTWARE', 'Software & SaaS', ARRAY['freelance', 'company'], 100, 19, 'KZ66'),
  ('EXP_BEWIRTUNG_70', 'Bewirtung (70%)', ARRAY['freelance', 'company'], 70, 19, 'KZ66'),
  ('EXP_TRAVEL', 'Reisekosten', ARRAY['freelance', 'company'], 100, 19, 'KZ66'),
  ('EXP_KLEINUNTERNEHMER', 'Kleinunternehmer Ausgabe', ARRAY['freelance'], 100, 0, NULL),
  ('REV_STANDARD_19', 'Umsatz 19% USt', ARRAY['freelance', 'company'], NULL, 19, 'KZ81'),
  ('REV_KLEINUNTERNEHMER', 'Kleinunternehmer Umsatz', ARRAY['freelance'], NULL, 0, 'KZ86'),
  ('INC_SALARY', 'Gehalt / Einkommen', ARRAY['income'], NULL, NULL, NULL)
ON CONFLICT (code) DO NOTHING;
