UPDATE orgs SET org_name = 'Dew CIS Solutions Ltd', cert_number = 'C.102554', pin = 'P051165288J', vat_number = '0142653A', 
default_country_id = 'KE', currency_id = 1,
org_full_name = 'Dew CIS Solutions Ltd',
invoice_footer = 'Make all payments to : Dew CIS Solutions ltd
Thank you for your Business
We Turn your information into profitability'
WHERE org_id = 0;



INSERT INTO tenants(org_id, tenant_name, identification_number, identification_type, tenant_email, telephone_number,town, gender, nationality, marital_status, employed,self_employed, is_active) VALUES
		(0,'Natasha Buire','30215458965','National ID','nbuire@gmail.com','0789654321','Nairobi','F','KE','S',true,true,true),
		(0,'Peter Mwangi','302105611655','National ID','pmwangi@gmail.com','0723654789','Nairobi','M','KE','S',true,true,true),
		(0,'Faith Mandela','262925458965','National ID','fmandela@gmail.com','0723456987','Nairobi','F','KE','S',true,true,true),
		(0,'Maina Kihuyu','26459459459','National ID','myoz@gmail.com','0711456321','Nairobi','M','KE','S',true,true,true),
		(0,'Rachael Rabera','29546165656','National ID','rrabesh@gmail.com','0724789654','Nairobi','F','KE','S',true,true,true);

INSERT INTO landlord(org_id, landlord_name, identification_number, identification_type, landlord_email, telephone_number,town, gender, nationality, marital_status, is_active) VALUES
		(0,'Dorcas Mwigereri','30215458965','National ID','dori@gmail.com','0724563214','Nairobi','F','KE','S',true),
		(0,'Dennis Gichangi','2245697569','National ID','denno@gmail.com','07223656789','Nairobi','M','KE','M',true);	
